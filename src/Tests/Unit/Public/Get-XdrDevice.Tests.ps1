BeforeDiscovery {
    Set-Location -Path $PSScriptRoot
    $ModuleName = 'XDRHelper'
    $PathToManifest = [System.IO.Path]::Combine('..', '..', '..', $ModuleName, "$ModuleName.psd1")
    #if the module is already in memory, remove it
    Get-Module $ModuleName -ErrorAction SilentlyContinue | Remove-Module -Force
    Import-Module $PathToManifest -Force
}

InModuleScope 'XDRHelper' {
    Describe 'Get-XdrDevice public function tests' -Tag Unit {
        BeforeAll {
            $IdA = 'caab196872d62e639a7b7cdf8593601cf632b4eb'
            $IdB = '1e5bc9d7e413ddd7902c2932e418702b84d0cc07'
            $IdC = 'ABCDEF0123456789abcdef0123456789ABCDEF01'
        }

        BeforeEach {
            Mock Assert-XdrAuthentication { }
            Mock Invoke-XdrApiRequest { [pscustomobject]@{ id = ($Path -split '/')[-1] } }
        }

        Context 'parameter sets' {
            It 'defaults to the ById parameter set' {
                (Get-Command Get-XdrDevice).DefaultParameterSet | Should -Be 'ById'
            }

            It 'makes <Parameter> mandatory in its own parameter set (<Set>)' -ForEach @(
                @{ Parameter = 'Id'; Set = 'ById' }
                @{ Parameter = 'Query'; Set = 'ByOdata' }
                @{ Parameter = 'All'; Set = 'AllMachines' }
            ) {
                $sets = (Get-Command Get-XdrDevice).Parameters[$Parameter].ParameterSets

                $sets.Keys | Should -Be $Set
                $sets[$Set].IsMandatory | Should -BeTrue
            }

            It 'does not allow <Name> together' -ForEach @(
                @{ Name = '-Id and -All'; Splat = @{ Id = 'caab196872d62e639a7b7cdf8593601cf632b4eb'; All = $true } }
                @{ Name = '-Id and -Query'; Splat = @{ Id = 'caab196872d62e639a7b7cdf8593601cf632b4eb'; Query = @{ '$top' = 1 } } }
                @{ Name = '-Query and -All'; Splat = @{ Query = @{ '$top' = 1 }; All = $true } }
            ) {
                { Get-XdrDevice @Splat } | Should -Throw -ErrorId 'AmbiguousParameterSet*'
                Should -Invoke Invoke-XdrApiRequest -Times 0 -Exactly
            }
        }

        Context 'Id validation' {
            It 'rejects <Name>' -ForEach @(
                @{ Name = 'a hostname'; Value = 'svr-det-dc01' }
                @{ Name = 'a 32-character id'; Value = '01a1d27ac48972b18c57edc582c15c3c' }
                @{ Name = 'a 41-character id'; Value = 'caab196872d62e639a7b7cdf8593601cf632b4eb0' }
                @{ Name = 'non-hex characters'; Value = 'zaab196872d62e639a7b7cdf8593601cf632b4eb' }
                @{ Name = 'a path traversal attempt'; Value = '../alerts/caab196872d62e639a7b7cdf8593601c' }
                @{ Name = 'one bad id among good ones'; Value = @('caab196872d62e639a7b7cdf8593601cf632b4eb', 'nope') }
            ) {
                { Get-XdrDevice -Id $Value } | Should -Throw -ErrorId 'ParameterArgumentValidationError*'
                Should -Invoke Invoke-XdrApiRequest -Times 0 -Exactly
            }

            # The guard that keeps "my filter matched nothing" from turning into "every machine".
            It 'rejects <Name> rather than falling through to all machines' -ForEach @(
                @{ Name = 'an empty array'; Value = @() }
                @{ Name = '$null'; Value = $null }
                @{ Name = 'an empty string'; Value = '' }
            ) {
                { Get-XdrDevice -Id $Value } | Should -Throw
                Should -Invoke Invoke-XdrApiRequest -Times 0 -Exactly
            }

            It 'accepts upper- and mixed-case hex' {
                { Get-XdrDevice -Id $IdC } | Should -Not -Throw
            }
        }

        Context 'by Id' {
            It 'requests machines/<id> for a single id' {
                $result = Get-XdrDevice -Id $IdA

                $result.id | Should -Be $IdA
                Should -Invoke Invoke-XdrApiRequest -Times 1 -Exactly -ParameterFilter {
                    $Path -eq "machines/$IdA" -and -not $PSBoundParameters.ContainsKey('Query')
                }
            }

            It 'makes one request per id and emits results in order' {
                $result = Get-XdrDevice -Id $IdA, $IdB, $IdC

                $result.id | Should -Be @($IdA, $IdB, $IdC)
                Should -Invoke Invoke-XdrApiRequest -Times 3 -Exactly
            }

            It 'accepts ids from the pipeline by value' {
                $result = $IdA, $IdB | Get-XdrDevice

                $result.id | Should -Be @($IdA, $IdB)
                Should -Invoke Invoke-XdrApiRequest -Times 1 -Exactly -ParameterFilter { $Path -eq "machines/$IdA" }
                Should -Invoke Invoke-XdrApiRequest -Times 1 -Exactly -ParameterFilter { $Path -eq "machines/$IdB" }
            }

            It 'accepts ids from the pipeline by property name (<Property>)' -ForEach @(
                @{ Property = 'Id' }
                @{ Property = 'id' }
                @{ Property = 'MachineId' }
                @{ Property = 'SenseMachineId' }
            ) {
                $result = [pscustomobject]@{ $Property = $IdA } | Get-XdrDevice

                $result.id | Should -Be $IdA
                Should -Invoke Invoke-XdrApiRequest -Times 1 -Exactly -ParameterFilter { $Path -eq "machines/$IdA" }
            }

            It 'checks authentication once for the whole pipeline' {
                $IdA, $IdB, $IdC | Get-XdrDevice

                Should -Invoke Assert-XdrAuthentication -Times 1 -Exactly
            }
        }

        Context 'a lookup fails part-way through' {
            BeforeAll {
                # Throws what Invoke-XdrApiRequest really throws: the record New-XdrApiErrorRecord builds.
                function New-TestApiError {
                    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                        'PSUseShouldProcessForStateChangingFunctions',
                        '',
                        Justification = 'The function makes to system changes.'
                    )]
                    param([int]$StatusCode, [string]$Code, [string]$Path)
                    $response = [pscustomobject]@{
                        StatusCode = $StatusCode
                        Headers    = @{}
                        Content    = [pscustomobject]@{
                            error = [pscustomobject]@{ code = $Code; message = "$Code message"; target = 'corr-id' }
                        }
                    }
                    New-XdrApiErrorRecord -Response $response -Method 'GET' -Uri "https://api.security.microsoft.com/api/$Path"
                }
            }

            Context 'the device does not exist (HTTP 404)' {
                BeforeEach {
                    Mock Invoke-XdrApiRequest {
                        throw (New-TestApiError -StatusCode 404 -Code 'ResourceNotFound' -Path $Path)
                    } -ParameterFilter { $Path -eq "machines/$IdB" }
                }

                It 'writes one non-terminating error and carries on with the remaining ids' {
                    # 2>&1 puts only what Get-XdrDevice wrote to the error stream into the output.
                    $output = Get-XdrDevice -Id $IdA, $IdB, $IdC 2>&1
                    $errors = @($output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
                    $devices = @($output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })

                    $devices.id | Should -Be @($IdA, $IdC)
                    $errors.Count | Should -Be 1
                }

                It 'preserves the API error record instead of replacing it' {
                    $output = Get-XdrDevice -Id $IdB 2>&1
                    $record = @($output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })[0]

                    $record.FullyQualifiedErrorId | Should -BeLike 'Xdr.ResourceNotFound*'
                    $record.CategoryInfo.Category | Should -Be 'ObjectNotFound'
                    $record.Exception.Data['StatusCode'] | Should -Be 404
                    $record.Exception.Data['ErrorCode'] | Should -Be 'ResourceNotFound'
                    $record.Exception.Data['CorrelationId'] | Should -Be 'corr-id'
                }

                It 'identifies the id that failed' {
                    $output = Get-XdrDevice -Id $IdA, $IdB 2>&1
                    $record = @($output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })[0]

                    "$record" | Should -BeLike "*$IdB*"
                }

                It 'keeps processing later pipeline input' {
                    $output = $IdB, $IdA | Get-XdrDevice 2>&1
                    $devices = @($output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })

                    $devices.id | Should -Be $IdA
                }

                It 'stops at the failing id with -ErrorAction Stop' {
                    { Get-XdrDevice -Id $IdA, $IdB, $IdC -ErrorAction Stop } |
                    Should -Throw -ErrorId 'Xdr.ResourceNotFound*'
                    Should -Invoke Invoke-XdrApiRequest -Times 0 -Exactly -ParameterFilter { $Path -eq "machines/$IdC" }
                }
            }

            # Anything other than "this device does not exist" will fail the same way for every
            # remaining id, so it must stop the command rather than be reported once per id.
            Context 'the API fails for another reason (HTTP <StatusCode>)' -ForEach @(
                @{ StatusCode = 400; Code = 'BadRequest' }
                @{ StatusCode = 401; Code = 'Unauthorized' }
                @{ StatusCode = 403; Code = 'Forbidden' }
                @{ StatusCode = 429; Code = 'TooManyRequests' }
                @{ StatusCode = 500; Code = 'InternalServerError' }
                @{ StatusCode = 503; Code = 'ServiceUnavailable' }
            ) {
                BeforeEach {
                    Mock Invoke-XdrApiRequest {
                        throw (New-TestApiError -StatusCode $StatusCode -Code $Code -Path $Path)
                    } -ParameterFilter { $Path -eq "machines/$IdB" }
                }

                It 'terminates with the API error record' {
                    { Get-XdrDevice -Id $IdA, $IdB, $IdC } | Should -Throw -ErrorId "Xdr.$Code*"
                }

                It 'does not request the remaining ids' {
                    { Get-XdrDevice -Id $IdA, $IdB, $IdC } | Should -Throw

                    Should -Invoke Invoke-XdrApiRequest -Times 1 -Exactly -ParameterFilter { $Path -eq "machines/$IdA" }
                    Should -Invoke Invoke-XdrApiRequest -Times 0 -Exactly -ParameterFilter { $Path -eq "machines/$IdC" }
                }

                It 'terminates even with -ErrorAction SilentlyContinue' {
                    { Get-XdrDevice -Id $IdA, $IdB, $IdC -ErrorAction SilentlyContinue } |
                        Should -Throw -ErrorId "Xdr.$Code*"
                }

                It 'stops the pipeline as well' {
                    { $IdB, $IdC | Get-XdrDevice } | Should -Throw -ErrorId "Xdr.$Code*"
                    Should -Invoke Invoke-XdrApiRequest -Times 0 -Exactly -ParameterFilter { $Path -eq "machines/$IdC" }
                }
            }

            Context 'the failure carries no HTTP status (transport or authentication error)' {
                BeforeEach {
                    Mock Invoke-XdrApiRequest { throw 'Unable to renew Defender authentication token.' } -ParameterFilter {
                        $Path -eq "machines/$IdB"
                    }
                }

                It 'terminates without requesting the remaining ids' {
                    { Get-XdrDevice -Id $IdA, $IdB, $IdC } | Should -Throw '*Unable to renew Defender authentication token.*'
                    Should -Invoke Invoke-XdrApiRequest -Times 0 -Exactly -ParameterFilter { $Path -eq "machines/$IdC" }
                }
            }
        }

        Context 'by OData query' {
            It 'passes the query hashtable through to machines untouched' {
                $query = @{ '$filter' = "startsWith(computerDnsName, 'svr')"; '$top' = 100 }

                Get-XdrDevice -Query $query

                Should -Invoke Invoke-XdrApiRequest -Times 1 -Exactly -ParameterFilter {
                    $Path -eq 'machines' -and
                    $Query.Count -eq 2 -and
                    $Query['$filter'] -eq "startsWith(computerDnsName, 'svr')" -and
                    $Query['$top'] -eq 100
                }
            }

            It 'emits whatever the API helper returns' {
                Mock Invoke-XdrApiRequest { [pscustomobject]@{ id = 'a' }; [pscustomobject]@{ id = 'b' } }

                $result = @(Get-XdrDevice -Query @{ '$top' = 2 })

                $result.id | Should -Be @('a', 'b')
            }

            It 'lets API errors terminate' {
                Mock Invoke-XdrApiRequest { throw 'Defender API returned 400 BadRequest' }

                { Get-XdrDevice -Query @{ '$filter' = 'nonsense' } } | Should -Throw '*400 BadRequest*'
            }
        }

        Context 'all machines' {
            It 'requests machines with no query when -All is given' {
                Get-XdrDevice -All

                Should -Invoke Invoke-XdrApiRequest -Times 1 -Exactly -ParameterFilter {
                    $Path -eq 'machines' -and -not $PSBoundParameters.ContainsKey('Query')
                }
            }
        }

        Context 'all machines, switch explicitly off' {
            It 'does not request all machines for -All:$false' {
                Get-XdrDevice -All:$false -ErrorAction SilentlyContinue

                Should -Invoke Invoke-XdrApiRequest -Times 0 -Exactly
            }
        }

        Context 'not authenticated' {
            It 'throws before making any request' {
                Mock Assert-XdrAuthentication { throw 'No XDR authentication context exists. Run Connect-XdrByAppID first.' }

                { Get-XdrDevice -Id $IdA } | Should -Throw '*Run Connect-XdrByAppID first*'
                Should -Invoke Invoke-XdrApiRequest -Times 0 -Exactly
            }
        }
    }
}

