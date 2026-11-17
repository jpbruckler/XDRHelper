BeforeDiscovery {
    Set-Location -Path $PSScriptRoot
    $ModuleName = 'XDRHelper'
    $PathToManifest = [System.IO.Path]::Combine('..', '..', '..', $ModuleName, "$ModuleName.psd1")
    #if the module is already in memory, remove it
    Get-Module $ModuleName -ErrorAction SilentlyContinue | Remove-Module -Force
    Import-Module $PathToManifest -Force
}

InModuleScope 'XDRHelper' {
    Describe 'Set-XdrDeviceValue Public function tests' {
        BeforeAll {
            $IdA = 'caab196872d62e639a7b7cdf8593601cf632b4eb'
            $IdB = '1e5bc9d7e413ddd7902c2932e418702b84d0cc07'
            $IdC = 'ABCDEF0123456789abcdef0123456789ABCDEF01'
        }

        BeforeEach {
            Mock Assert-XdrAuthentication { }
            # Stand-in for the worker: one "machine" per device, carrying the tag just processed.
            Mock Invoke-XdrApiRequest {
                foreach ($deviceId in $Id) { [pscustomobject]@{ id = $deviceId; deviceValue = $DeviceValue } }
            }
        }

        Context 'parameters' {
            It 'makes <Parameter> mandatory' -ForEach @(
                @{ Parameter = 'Id' }
                @{ Parameter = 'DeviceValue' }
            ) {
                (Get-Command Set-XdrDeviceValue).Parameters[$Parameter].Attributes.Where({ $_ -is [Parameter] }).Mandatory |
                Should-BeTrue
            }

            It 'supports -WhatIf and -Confirm' {
                (Get-Command Set-XdrDeviceValue).Parameters.Keys | Should -Contain 'WhatIf'
                (Get-Command Set-XdrDeviceValue).Parameters.Keys | Should -Contain 'Confirm'
            }

            It 'does not prompt by default' {
                # ConfirmImpact must stay below the default $ConfirmPreference (High) or automation would hang.
                (Get-Command Set-XdrDeviceValue).ScriptBlock.Attributes.Where({ $_ -is [CmdletBinding] }).ConfirmImpact |
                    Should -Not -Be 'High'
            }

            It 'accepts -<Alias> as an alias for -Id' -ForEach @(
                @{ Alias = 'DeviceId' }
                @{ Alias = 'MachineId' }
                @{ Alias = 'SenseMachineId' }
            ) {
                $splat = @{ $Alias = $IdA }

                Set-XdrDeviceValue @splat -DeviceValue Low

                Should -Invoke Invoke-XdrApiRequest -Times 1 -Exactly -ParameterFilter { $Path -eq "machines/$IdA/setDeviceValue" }
            }
        }
    }
}
