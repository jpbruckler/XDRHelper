BeforeDiscovery {
    Set-Location -Path $PSScriptRoot
    $ModuleName = 'XDRHelper'
    $PathToManifest = [System.IO.Path]::Combine('..', '..', '..', $ModuleName, "$ModuleName.psd1")
    #if the module is already in memory, remove it
    Get-Module $ModuleName -ErrorAction SilentlyContinue | Remove-Module -Force
    Import-Module $PathToManifest -Force
}

InModuleScope 'XDRHelper' {
    Describe 'Send-XdrHttpRequest private function tests' -Tag Unit {
        BeforeAll {
            $Uri = [uri]'https://api.security.microsoft.com/api/machines'
            $Headers = @{ Authorization = 'Bearer fake-token' }
        }

        Context 'request construction' {
            BeforeEach {
                Mock Invoke-RestMethod { [pscustomobject]@{ id = 'abc' } }
            }

            It 'passes method, URI and headers through to Invoke-RestMethod' {
                Send-XdrHttpRequest -Method 'GET' -Uri $Uri -Headers $Headers

                Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                    $Method -eq 'GET' -and
                    $Uri -eq 'https://api.security.microsoft.com/api/machines' -and
                    $Headers.Authorization -eq 'Bearer fake-token'
                }
            }

            It 'asks for HTTP errors as data and transport errors as exceptions' {
                Send-XdrHttpRequest -Method 'GET' -Uri $Uri -Headers $Headers

                Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                    $SkipHttpErrorCheck -and
                    $StatusCodeVariable -eq 'statusCode' -and
                    $ResponseHeadersVariable -eq 'responseHeaders' -and
                    $ErrorAction -eq 'Stop'
                }
            }

            It 'sends the body when one is supplied' {
                Send-XdrHttpRequest -Method 'POST' -Uri $Uri -Headers $Headers -Body '{"Value":"tag"}'

                Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                    $Method -eq 'POST' -and $Body -eq '{"Value":"tag"}'
                }
            }

            It 'omits the body parameter when the body is <Name>' -ForEach @(
                @{ Name = 'not supplied'; Splat = @{} }
                @{ Name = 'empty'; Splat = @{ Body = '' } }
            ) {
                Send-XdrHttpRequest -Method 'GET' -Uri $Uri -Headers $Headers @Splat

                Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                    -not $PSBoundParameters.ContainsKey('Body')
                }
            }
        }

        Context 'response shaping' {
            It 'returns status code, headers and content as one object' {
                Mock Invoke-RestMethod {
                    # Stand in for -StatusCodeVariable / -ResponseHeadersVariable, which write
                    # into the calling function's scope. Pester puts a few scopes between the
                    # mock body and Send-XdrHttpRequest, so find the caller by its $params local.
                    $scope = 1
                    while (-not (Get-Variable -Name params -Scope $scope -ErrorAction Ignore)) { $scope++ }
                    Set-Variable -Name $StatusCodeVariable -Value 429 -Scope $scope
                    Set-Variable -Name $ResponseHeadersVariable -Value @{ 'Retry-After' = @('7') } -Scope $scope
                    [pscustomobject]@{ error = [pscustomobject]@{ code = 'TooManyRequests' } }
                }

                $result = Send-XdrHttpRequest -Method 'GET' -Uri $Uri -Headers $Headers

                $result.StatusCode | Should -Be 429
                $result.StatusCode | Should -BeOfType ([int])
                $result.Headers['Retry-After'] | Should -Be '7'
                $result.Content.error.code | Should -Be 'TooManyRequests'
            }

            It 'does not swallow transport failures' {
                Mock Invoke-RestMethod { throw 'No such host is known.' }

                { Send-XdrHttpRequest -Method 'GET' -Uri $Uri -Headers $Headers } |
                    Should -Throw '*No such host is known.*'
            }
        }
    }
}
