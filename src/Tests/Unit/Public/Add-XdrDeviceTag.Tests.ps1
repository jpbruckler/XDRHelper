BeforeDiscovery {
    Set-Location -Path $PSScriptRoot
    $ModuleName = 'XDRHelper'
    $PathToManifest = [System.IO.Path]::Combine('..', '..', '..', $ModuleName, "$ModuleName.psd1")
    #if the module is already in memory, remove it
    Get-Module $ModuleName -ErrorAction SilentlyContinue | Remove-Module -Force
    Import-Module $PathToManifest -Force
}

InModuleScope 'XDRHelper' {
    Describe 'Add-XdrDeviceTag public function tests' -Tag Unit {
        BeforeAll {
            $IdA = 'caab196872d62e639a7b7cdf8593601cf632b4eb'
            $IdB = '1e5bc9d7e413ddd7902c2932e418702b84d0cc07'
            $IdC = 'ABCDEF0123456789abcdef0123456789ABCDEF01'
        }

        BeforeEach {
            Mock Assert-XdrAuthentication { }
            # Stand-in for the worker: one "machine" per device, carrying the tag just processed.
            Mock Invoke-XdrDeviceTagRequest {
                foreach ($deviceId in $Id) { [pscustomobject]@{ id = $deviceId; lastTag = $Tag } }
            }
        }

        Context 'parameters' {
            It 'makes <Parameter> mandatory' -ForEach @(
                @{ Parameter = 'Id' }
                @{ Parameter = 'Tag' }
            ) {
                (Get-Command Add-XdrDeviceTag).Parameters[$Parameter].Attributes.Where({ $_ -is [Parameter] }).Mandatory |
                    Should -BeTrue
            }

            It 'supports -WhatIf and -Confirm' {
                (Get-Command Add-XdrDeviceTag).Parameters.Keys | Should -Contain 'WhatIf'
                (Get-Command Add-XdrDeviceTag).Parameters.Keys | Should -Contain 'Confirm'
            }

            It 'does not prompt by default' {
                # ConfirmImpact must stay below the default $ConfirmPreference (High) or automation would hang.
                (Get-Command Add-XdrDeviceTag).ScriptBlock.Attributes.Where({ $_ -is [CmdletBinding] }).ConfirmImpact |
                    Should -Not -Be 'High'
            }

            It 'accepts -Tags as an alias for -Tag' {
                Add-XdrDeviceTag -Id $IdA -Tags 'Tier0'

                Should -Invoke Invoke-XdrDeviceTagRequest -Times 1 -Exactly -ParameterFilter { $Tag -eq 'Tier0' }
            }

            It 'accepts -<Alias> as an alias for -Id' -ForEach @(
                @{ Alias = 'DeviceId' }
                @{ Alias = 'MachineId' }
                @{ Alias = 'SenseMachineId' }
            ) {
                $splat = @{ $Alias = $IdA }

                Add-XdrDeviceTag @splat -Tag 'Tier0'

                Should -Invoke Invoke-XdrDeviceTagRequest -Times 1 -Exactly -ParameterFilter { $Id -eq $IdA }
            }
        }

        Context 'Id validation' {
            It 'rejects <Name>' -ForEach @(
                @{ Name = 'a hostname'; Value = 'svr-det-dc01' }
                @{ Name = 'a 39-character id'; Value = 'caab196872d62e639a7b7cdf8593601cf632b4e' }
                @{ Name = 'a 41-character id'; Value = 'caab196872d62e639a7b7cdf8593601cf632b4eb0' }
                @{ Name = 'non-hex characters'; Value = 'zaab196872d62e639a7b7cdf8593601cf632b4eb' }
                @{ Name = 'a path traversal attempt'; Value = '../alerts/caab196872d62e639a7b7cdf8593601c' }
                @{ Name = 'one bad id among good ones'; Value = @('caab196872d62e639a7b7cdf8593601cf632b4eb', 'nope') }
                @{ Name = 'an empty array'; Value = @() }
                @{ Name = '$null'; Value = $null }
                @{ Name = 'an empty string'; Value = '' }
            ) {
                { Add-XdrDeviceTag -Id $Value -Tag 'Tier0' } | Should -Throw -ErrorId 'Parameter*'
                Should -Invoke Invoke-XdrDeviceTagRequest -Times 0 -Exactly
            }
        }

        Context 'Tag validation' {
            It 'rejects <Name>' -ForEach @(
                @{ Name = 'an empty array'; Value = @() }
                @{ Name = '$null'; Value = $null }
                @{ Name = 'an empty string'; Value = '' }
                @{ Name = 'a whitespace-only tag'; Value = '   ' }
                @{ Name = 'a blank tag among good ones'; Value = @('Tier0', ' ') }
            ) {
                { Add-XdrDeviceTag -Id $IdA -Tag $Value } | Should -Throw -ErrorId 'Parameter*'
                Should -Invoke Invoke-XdrDeviceTagRequest -Times 0 -Exactly
            }

            It 'explains why a blank tag was rejected' {
                { Add-XdrDeviceTag -Id $IdA -Tag ' ' } | Should -Throw '*A tag cannot be empty or whitespace.*'
            }
        }

        Context 'calling the worker' {
            It 'asks for the Add action' {
                Add-XdrDeviceTag -Id $IdA -Tag 'Tier0'

                Should -Invoke Invoke-XdrDeviceTagRequest -Times 1 -Exactly
                Should -Invoke Invoke-XdrDeviceTagRequest -Times 1 -Exactly -ParameterFilter {
                    $Action -eq 'Add' -and $Tag -eq 'Tier0' -and $Id.Count -eq 1 -and $Id[0] -eq $IdA
                }
            }

            It 'makes one worker call per tag, each with every device' {
                Add-XdrDeviceTag -Id $IdA, $IdB, $IdC -Tag 'Tier0', 'Server'

                Should -Invoke Invoke-XdrDeviceTagRequest -Times 2 -Exactly
                foreach ($value in 'Tier0', 'Server') {
                    Should -Invoke Invoke-XdrDeviceTagRequest -Times 1 -Exactly -ParameterFilter {
                        $Tag -eq $value -and ($Id -join ',') -eq "$IdA,$IdB,$IdC"
                    }
                }
            }

            It 'sends a repeated tag only once' {
                Add-XdrDeviceTag -Id $IdA -Tag 'Tier0', 'Server', 'Tier0'

                Should -Invoke Invoke-XdrDeviceTagRequest -Times 2 -Exactly
                Should -Invoke Invoke-XdrDeviceTagRequest -Times 1 -Exactly -ParameterFilter { $Tag -eq 'Tier0' }
            }

            It 'treats tags that differ only by case as different tags' {
                Add-XdrDeviceTag -Id $IdA -Tag 'Tier0', 'tier0'

                Should -Invoke Invoke-XdrDeviceTagRequest -Times 2 -Exactly
            }

            It 'sends a repeated device only once, ignoring case' {
                Add-XdrDeviceTag -Id $IdC, $IdA, $IdC.ToLower(), $IdA -Tag 'Tier0'

                Should -Invoke Invoke-XdrDeviceTagRequest -Times 1 -Exactly -ParameterFilter {
                    ($Id -join ',') -ceq "$IdC,$IdA"
                }
            }

            It 'does not alter the tag text' {
                Add-XdrDeviceTag -Id $IdA -Tag ' Site: DET '

                Should -Invoke Invoke-XdrDeviceTagRequest -Times 1 -Exactly -ParameterFilter { $Tag -ceq ' Site: DET ' }
            }

            It 'checks authentication once, before doing anything' {
                $IdA, $IdB, $IdC | Add-XdrDeviceTag -Tag 'Tier0', 'Server'

                Should -Invoke Assert-XdrAuthentication -Times 1 -Exactly
            }
        }

        Context 'pipeline input' {
            It 'collects ids piped by value into a single worker call' {
                $IdA, $IdB, $IdC | Add-XdrDeviceTag -Tag 'Tier0'

                Should -Invoke Invoke-XdrDeviceTagRequest -Times 1 -Exactly
                Should -Invoke Invoke-XdrDeviceTagRequest -Times 1 -Exactly -ParameterFilter {
                    ($Id -join ',') -eq "$IdA,$IdB,$IdC"
                }
            }

            It 'accepts objects with a <Property> property' -ForEach @(
                @{ Property = 'Id' }
                @{ Property = 'DeviceId' }
                @{ Property = 'MachineId' }
                @{ Property = 'SenseMachineId' }
            ) {
                [pscustomobject]@{ $Property = $IdA }, [pscustomobject]@{ $Property = $IdB } | Add-XdrDeviceTag -Tag 'Tier0'

                Should -Invoke Invoke-XdrDeviceTagRequest -Times 1 -Exactly -ParameterFilter {
                    ($Id -join ',') -eq "$IdA,$IdB"
                }
            }

            It 'accepts Get-XdrDevice output without binding its existing tags' {
                $device = [pscustomobject]@{ id = $IdA; computerDnsName = 'svr-det-dc01'; machineTags = @('Existing') }

                $device | Add-XdrDeviceTag -Tag 'Tier0'

                Should -Invoke Invoke-XdrDeviceTagRequest -Times 1 -Exactly
                Should -Invoke Invoke-XdrDeviceTagRequest -Times 1 -Exactly -ParameterFilter { $Tag -eq 'Tier0' -and $Id -eq $IdA }
            }

            It 'does nothing when the pipeline is empty' {
                @() | Add-XdrDeviceTag -Tag 'Tier0'

                Should -Invoke Invoke-XdrDeviceTagRequest -Times 0 -Exactly
            }
        }

        Context 'output' {
            It 'returns nothing by default' {
                $result = Add-XdrDeviceTag -Id $IdA, $IdB -Tag 'Tier0', 'Server'

                $result | Should -BeNullOrEmpty
            }

            It 'returns each device once with -PassThru, in input order' {
                $result = @(Add-XdrDeviceTag -Id $IdA, $IdB, $IdC -Tag 'Tier0' -PassThru)

                $result.id | Should -Be @($IdA, $IdB, $IdC)
            }

            It 'returns the copy from the last tag processed, not one per tag' {
                $result = @(Add-XdrDeviceTag -Id $IdA, $IdB -Tag 'Tier0', 'Server', 'Site-DET' -PassThru)

                $result.Count | Should -Be 2
                $result.lastTag | Should -Be @('Site-DET', 'Site-DET')
            }

            It 'leaves out a device the worker returned nothing for' {
                Mock Invoke-XdrDeviceTagRequest {
                    foreach ($deviceId in $Id) { if ($deviceId -ne $IdB) { [pscustomobject]@{ id = $deviceId; lastTag = $Tag } } }
                }

                $result = @(Add-XdrDeviceTag -Id $IdA, $IdB, $IdC -Tag 'Tier0' -PassThru)

                $result.id | Should -Be @($IdA, $IdC)
            }

            It 'still returns anything the API sent back that has no id' {
                Mock Invoke-XdrDeviceTagRequest { 'unexpected' }

                Add-XdrDeviceTag -Id $IdA -Tag 'Tier0' -PassThru | Should -Be 'unexpected'
            }
        }

        Context '-WhatIf' {
            It 'makes no worker calls' {
                Add-XdrDeviceTag -Id $IdA, $IdB -Tag 'Tier0', 'Server' -WhatIf

                Should -Invoke Invoke-XdrDeviceTagRequest -Times 0 -Exactly
            }

            It 'returns nothing, even with -PassThru' {
                Add-XdrDeviceTag -Id $IdA -Tag 'Tier0' -PassThru -WhatIf | Should -BeNullOrEmpty
            }
        }

        Context 'errors from the worker' {
            It 'passes non-terminating errors through and keeps going with the next tag' {
                Mock Invoke-XdrDeviceTagRequest { Write-Error "Device $IdB was not found" }

                $output = Add-XdrDeviceTag -Id $IdA, $IdB -Tag 'Tier0', 'Server' 2>&1
                $errors = @($output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })

                $errors.Count | Should -Be 2
                Should -Invoke Invoke-XdrDeviceTagRequest -Times 2 -Exactly
            }

            It 'stops at the first terminating error and does not process later tags' {
                Mock Invoke-XdrDeviceTagRequest { throw 'Defender API returned 403 Forbidden' }

                { Add-XdrDeviceTag -Id $IdA, $IdB -Tag 'Tier0', 'Server' } | Should -Throw '*403 Forbidden*'
                Should -Invoke Invoke-XdrDeviceTagRequest -Times 1 -Exactly
            }
        }

        Context 'not authenticated' {
            It 'throws before calling the worker' {
                Mock Assert-XdrAuthentication { throw 'No XDR authentication context exists. Run Connect-XdrByAppID first.' }

                { Add-XdrDeviceTag -Id $IdA -Tag 'Tier0' } | Should -Throw '*Run Connect-XdrByAppID first*'
                Should -Invoke Invoke-XdrDeviceTagRequest -Times 0 -Exactly
            }
        }
    }
}
