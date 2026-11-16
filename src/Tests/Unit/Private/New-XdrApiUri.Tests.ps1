BeforeDiscovery {
    Set-Location -Path $PSScriptRoot
    $ModuleName = 'XDRHelper'
    $PathToManifest = [System.IO.Path]::Combine('..', '..', '..', $ModuleName, "$ModuleName.psd1")
    #if the module is already in memory, remove it
    Get-Module $ModuleName -ErrorAction SilentlyContinue | Remove-Module -Force
    Import-Module $PathToManifest -Force
}

InModuleScope 'XDRHelper' {
    Describe 'New-XdrApiUri private function tests' {
        Context 'correctly handles plain paths' {
            It 'properly makes boring paths - <Path>' -ForEach @(
                @{ Path = 'machines' },
                @{ Path = 'machines/caab196872d62e639a7b7cdf8593601cf632b4eb' },
                @{ Path = 'vulnerabilities/CVE-2019-0608' }
            ) {
                New-XdrApiUri -Path $Path | Should-Be "https://api.security.microsoft.com/api/$Path"
            }

            It 'rejects malformed paths - (<Path>)' -ForEach @(
                @{ Path = "machines?`$filter=healthStates eq 'Active'"; Message = "Path must not contain '?', '#' or '\'; use -Query." },
                @{ Path = '.'; Message = "Path must not contain '.' or '..' segments." },
                @{ Path = '..'; Message = "Path must not contain '.' or '..' segments." },
                @{ Path = 'api/vulnerabilities'; Message = "Path is relative to the API base; drop the 'api/' prefix." },
                @{ Path = '/'; Message = 'Path is empty.' }
            ) {
                { New-XdrApiUri -Path $Path } | Should-Throw -ExceptionMessage "Cannot validate argument on parameter 'Path'. $Message"
            }
        }

        Context 'path normalisation' {
            It 'returns an absolute https System.Uri' {
                $uri = New-XdrApiUri -Path 'machines'

                $uri | Should -BeOfType ([uri])
                $uri.IsAbsoluteUri | Should -BeTrue
                $uri.Scheme | Should -Be 'https'
            }

            It 'trims surrounding slashes and whitespace - (<Path>)' -ForEach @(
                @{ Path = '/machines' }
                @{ Path = 'machines/' }
                @{ Path = '/machines/' }
                @{ Path = '  machines  ' }
                @{ Path = ' /machines/ ' }
            ) {
                (New-XdrApiUri -Path $Path).AbsoluteUri | Should -Be 'https://api.security.microsoft.com/api/machines'
            }

            It 'keeps inner path segments intact' {
                (New-XdrApiUri -Path '/machines/caab196872d62e639a7b7cdf8593601cf632b4eb/tags/').AbsoluteUri |
                    Should -Be 'https://api.security.microsoft.com/api/machines/caab196872d62e639a7b7cdf8593601cf632b4eb/tags'
            }

            It 'allows a path that merely starts with the letters api' {
                (New-XdrApiUri -Path 'apiexplorer').AbsoluteUri | Should -Be 'https://api.security.microsoft.com/api/apiexplorer'
            }

            It 'rejects more malformed paths - (<Path>)' -ForEach @(
                @{ Path = 'machines#fragment'; Message = "Path must not contain '?', '#' or '\'; use -Query." }
                @{ Path = 'machines\abc'; Message = "Path must not contain '?', '#' or '\'; use -Query." }
                @{ Path = 'machines/../alerts'; Message = "Path must not contain '.' or '..' segments." }
                @{ Path = 'machines/./abc'; Message = "Path must not contain '.' or '..' segments." }
                @{ Path = 'machines/..'; Message = "Path must not contain '.' or '..' segments." }
                @{ Path = '/api/machines'; Message = "Path is relative to the API base; drop the 'api/' prefix." }
                @{ Path = 'API/machines'; Message = "Path is relative to the API base; drop the 'api/' prefix." }
                @{ Path = 'api'; Message = "Path is relative to the API base; drop the 'api/' prefix." }
                @{ Path = '   '; Message = 'Path is empty.' }
                @{ Path = '///'; Message = 'Path is empty.' }
            ) {
                { New-XdrApiUri -Path $Path } | Should -Throw "*$Message"
            }

            It 'rejects an empty string or $null path' -ForEach @(
                @{ Path = '' }
                @{ Path = $null }
            ) {
                { New-XdrApiUri -Path $Path } | Should -Throw -ErrorId 'ParameterArgumentValidationError*'
            }
        }

        Context 'module base URI' {
            BeforeEach { $savedBaseUri = $script:XdrApiBaseUri }
            AfterEach { $script:XdrApiBaseUri = $savedBaseUri }

            It 'throws when the base URI is <Name>' -ForEach @(
                @{ Name = 'not set'; Value = $null }
                @{ Name = 'empty'; Value = '' }
            ) {
                $script:XdrApiBaseUri = $Value

                { New-XdrApiUri -Path 'machines' } | Should -Throw '*$Script:XdrApiBaseUri*is not set.'
            }

            It 'tolerates a trailing slash on the base URI' {
                $script:XdrApiBaseUri = 'https://api.security.microsoft.com/api/'

                (New-XdrApiUri -Path 'machines').AbsoluteUri | Should -Be 'https://api.security.microsoft.com/api/machines'
            }

            It 'builds against whatever base URI the module holds' {
                $script:XdrApiBaseUri = 'https://api-gcc.securitycenter.microsoft.us/api'

                (New-XdrApiUri -Path 'machines' -Query @{ '$top' = 1 }).AbsoluteUri |
                    Should -Be 'https://api-gcc.securitycenter.microsoft.us/api/machines?$top=1'
            }
        }

        Context 'no usable query' {
            It 'adds no query string when the query is <Name>' -ForEach @(
                @{ Name = 'omitted'; Splat = @{} }
                @{ Name = '$null'; Splat = @{ Query = $null } }
                @{ Name = 'an empty hashtable'; Splat = @{ Query = @{} } }
                @{ Name = 'all null or blank values'; Splat = @{ Query = @{ '$filter' = $null; '$top' = ''; '$skip' = '   ' } } }
            ) {
                $uri = New-XdrApiUri -Path 'machines' @Splat

                $uri.AbsoluteUri | Should -Be 'https://api.security.microsoft.com/api/machines'
                $uri.Query | Should -BeNullOrEmpty
            }
        }

        Context 'query construction' {
            It 'appends a single option after a question mark' {
                (New-XdrApiUri -Path 'machines' -Query @{ '$top' = 100 }).Query | Should -Be '?$top=100'
            }

            It 'leaves the $ of an OData option name unescaped' {
                (New-XdrApiUri -Path 'machines' -Query @{ '$filter' = 'riskScore eq 1' }).Query | Should -BeLike '?$filter=*'
            }

            It 'emits options in a stable, sorted order however the hashtable was built' {
                $expected = '?$filter=x&$skip=20&$top=10'

                (New-XdrApiUri -Path 'machines' -Query @{ '$top' = 10; '$skip' = 20; '$filter' = 'x' }).Query | Should -Be $expected
                (New-XdrApiUri -Path 'machines' -Query ([ordered]@{ '$top' = 10; '$filter' = 'x'; '$skip' = 20 })).Query | Should -Be $expected
            }

            It 'drops null and blank values but keeps the rest' {
                $query = @{ '$filter' = $null; '$skip' = ''; '$top' = 5 }

                (New-XdrApiUri -Path 'machines' -Query $query).Query | Should -Be '?$top=5'
            }

            It 'keeps falsy values that are not blank (<Name>)' -ForEach @(
                @{ Name = 'zero'; Value = 0; Expected = '?$skip=0' }
                @{ Name = '$false'; Value = $false; Expected = '?$skip=false' }
            ) {
                (New-XdrApiUri -Path 'machines' -Query @{ '$skip' = $Value }).Query | Should -Be $Expected
            }

            It 'accepts option names without a $ prefix' {
                (New-XdrApiUri -Path 'machines' -Query @{ pageSize = 50 }).Query | Should -Be '?pageSize=50'
            }

            It 'accepts any IDictionary, not just a hashtable' {
                $query = [System.Collections.Generic.Dictionary[string, object]]::new()
                $query['$top'] = 3

                (New-XdrApiUri -Path 'machines' -Query $query).Query | Should -Be '?$top=3'
            }
        }

        Context 'query value encoding' {
            It 'percent-encodes <Name>' -ForEach @(
                @{ Name = 'spaces and quotes'; Value = "healthStatus eq 'Active'"; Expected = 'healthStatus%20eq%20%27Active%27' }
                @{ Name = 'parentheses and commas'; Value = "startswith(computerDnsName,'svr')"; Expected = 'startswith%28computerDnsName%2C%27svr%27%29' }
                @{ Name = 'characters that would break the query string'; Value = 'a&b=c#d?e'; Expected = 'a%26b%3Dc%23d%3Fe' }
                @{ Name = 'plus and slash'; Value = 'a+b/c'; Expected = 'a%2Bb%2Fc' }
                @{ Name = 'a doubled quote inside a literal'; Value = "computerDnsName eq 'o''brien'"; Expected = 'computerDnsName%20eq%20%27o%27%27brien%27' }
                @{ Name = 'non-ASCII characters as UTF-8'; Value = 'münchen'; Expected = 'm%C3%BCnchen' }
            ) {
                $uri = New-XdrApiUri -Path 'machines' -Query @{ '$filter' = $Value }

                # OriginalString: System.Uri's own properties re-normalise some escapes.
                $uri.OriginalString | Should -Be "https://api.security.microsoft.com/api/machines?`$filter=$Expected"
            }

            It 'round-trips the original value when decoded' {
                $filter = "machineTags/any(tag: tag eq 'Tier 0 & DC') and lastSeen gt 2026-11-01T00:00:00Z"
                $uri = New-XdrApiUri -Path 'machines' -Query @{ '$filter' = $filter }

                [uri]::UnescapeDataString(($uri.OriginalString -split '\$filter=')[1]) | Should -Be $filter
            }
        }

        Context 'query value types' {
            It 'writes <Name> as <Expected>' -ForEach @(
                @{ Name = 'an integer'; Value = 10000; Expected = '10000' }
                @{ Name = 'a numeric string'; Value = '25'; Expected = '25' }
                @{ Name = '$true'; Value = $true; Expected = 'true' }
                @{ Name = '$false'; Value = $false; Expected = 'false' }
                @{ Name = 'a UTC datetime'; Value = [datetime]::new(2026, 11, 15, 13, 5, 9, [DateTimeKind]::Utc); Expected = '2026-11-15T13%3A05%3A09Z' }
                @{ Name = 'a local datetime (converted to UTC)'; Value = [datetime]::new(2026, 11, 15, 13, 5, 9, [DateTimeKind]::Utc).ToLocalTime(); Expected = '2026-11-15T13%3A05%3A09Z' }
            ) {
                $uri = New-XdrApiUri -Path 'machines' -Query @{ value = $Value }

                $uri.OriginalString | Should -Be "https://api.security.microsoft.com/api/machines?value=$Expected"
            }

            It 'drops sub-second precision from datetimes' {
                $value = [datetime]::new(2026, 11, 15, 13, 5, 9, 987, [DateTimeKind]::Utc)

                (New-XdrApiUri -Path 'machines' -Query @{ since = $value }).OriginalString | Should -BeLike '*since=2026-11-15T13%3A05%3A09Z'
            }

            It 'rejects a collection value (<Name>) rather than guessing how to join it' -ForEach @(
                @{ Name = 'array'; Value = @('a', 'b') }
                @{ Name = 'single-element array'; Value = @('a') }
                @{ Name = 'list'; Value = [System.Collections.Generic.List[string]]@('a', 'b') }
                @{ Name = 'hashtable'; Value = @{ a = 1 } }
            ) {
                { New-XdrApiUri -Path 'machines' -Query @{ '$filter' = $Value } } |
                    Should -Throw "Query value for '`$filter' is a collection; join it explicitly."
            }
        }

        Context 'query key validation' {
            It 'explains the double-quoted $filter mistake for a <Name> key' -ForEach @(
                @{ Name = 'empty'; Key = '' }
                @{ Name = 'whitespace'; Key = '  ' }
            ) {
                { New-XdrApiUri -Path 'machines' -Query @{ $Key = "healthStatus eq 'Active'" } } |
                    Should -Throw "Query has an empty key.*Use '`$filter'."
            }

            It 'produces an empty key from "$filter" in double quotes, and catches it' {
                # What a caller actually types: the unset variable expands to an empty string.
                $query = & { $filter = $null; @{ "$filter" = "healthStatus eq 'Active'" } }

                { New-XdrApiUri -Path 'machines' -Query $query } | Should -Throw 'Query has an empty key.*'
            }

            It 'rejects the invalid key <Key>' -ForEach @(
                @{ Key = '$$top' }
                @{ Key = '$' }
                @{ Key = '$1top' }
                @{ Key = '1top' }
                @{ Key = 'fil ter' }
                @{ Key = 'api-version' }
                @{ Key = '$top&$skip' }
                @{ Key = '$top=1' }
                @{ Key = '$filter ' }
                @{ Key = '@odata.count' }
            ) {
                { New-XdrApiUri -Path 'machines' -Query @{ $Key = 1 } } | Should -Throw "Invalid query key: '$Key'"
            }

            It 'validates a key even when its value would be skipped' {
                { New-XdrApiUri -Path 'machines' -Query @{ 'bad key' = $null } } | Should -Throw "Invalid query key: 'bad key'"
            }
        }
    }
}
