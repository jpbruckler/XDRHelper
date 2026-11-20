BeforeDiscovery {
    Set-Location -Path $PSScriptRoot
    $ModuleName = 'XDRHelper'
    $PathToManifest = [System.IO.Path]::Combine('..', '..', '..', $ModuleName, "$ModuleName.psd1")
    #if the module is already in memory, remove it
    Get-Module $ModuleName -ErrorAction SilentlyContinue | Remove-Module -Force
    Import-Module $PathToManifest -Force
}

InModuleScope 'XDRHelper' {
    BeforeAll {
        $IdA = 'caab196872d62e639a7b7cdf8593601cf632b4eb'
        $IdB = '1e5bc9d7e413ddd7902c2932e418702b84d0cc07'
        $IdC = 'ABCDEF0123456789abcdef0123456789ABCDEF01'
    }

    Describe 'Set-XdrDevice Public function tests' -Tag Unit {
        # Each skipped test below is a question to answer about Set-XdrDevice.
        # Replace the name with what should happen, write the body, and remove -Skip.
        # Copy a line for each separate answer; delete the ones that do not apply.
        #
        # Once a test passes, break the function on purpose (change a path, delete a
        # check). If no test goes red, something is still uncovered.

        BeforeEach {
            Mock Assert-XdrAuthentication {}
            Mock Invoke-XdrApiRequest {
                return [PSCustomObject]@{
                    id = $IdA
                }
            }

        }

        Context 'what it sends' {
            It 'uses the right case for DeviceValue (Provided: <DeviceValue> Expected: <Expected>)' -ForEach @(
                @{ DeviceValue = 'HIGH'; Expected = 'High' },
                @{ DeviceValue = 'hIgH'; Expected = 'High' },
                @{ DeviceValue = 'nOrmal'; Expected = 'Normal' },
                @{ DeviceValue = 'NORMAL'; Expected = 'Normal' },
                @{ DeviceValue = 'low'; Expected = 'Low' },
                @{ DeviceValue = 'lOW'; Expected = 'Low' }
            ) {
                Set-XdrDevice -Id $IdA -DeviceValue $DeviceValue

                Should-Invoke Invoke-XdrApiRequest -Times 1 -Exactly -ParameterFilter {
                    $Body['deviceValue'] -ceq $Expected
                }
            }

            It 'sends tags as an array' {
                Set-XdrDevice -Id $IdB -Tag Windows11,admin

                Should-Invoke Invoke-XdrApiRequest -Times 1 -Exactly -ParameterFilter {
                    $Body['machineTags'] -is [array]
                }
            }

            It 'generates the correct path' {
                Set-XdrDevice -Id $IdB -DeviceValue High

                Should-Invoke Invoke-XdrApiRequest -Times 1 -Exactly -ParameterFilter {
                    $Path -eq "machines/$IdB"
                }

            }
        }

        Context 'what it gives back' {
            BeforeEach {
                Mock Assert-XdrAuthentication {}
                Mock Invoke-XdrApiRequest {
                    return [PSCustomObject]@{
                        id = $IdA
                    }
                }
            }

            It 'returns nothing by default' {
                $result = Set-XdrDevice -Id $IdA -DeviceValue High
                $result | Should-BeNull
            }

            It 'returns the API response with -PassThru' {
                $result = Set-XdrDevice -Id $IdA -DeviceValue High -PassThru

                $result | Should-NotBeNull
                Should -BeExactly -ActualValue $result.id -ExpectedValue $IdA
            }
        }

        Context 'what input it refuses' {
            It 'rejects malformed Device IDs' {
                $message = 'Cannot validate argument on parameter ''Id''. The argument "caab196872d62e639a7b7cdf8593601cf632b4" does not match the "^[0-9a-fA-F]{40}$" pattern. Supply an argument that matches "^[0-9a-fA-F]{40}$" and try the command again.'
                { Set-XdrDevice -Id ($IdA.Substring(0,38)) } | Should-Throw -ExceptionMessage ([System.Management.Automation.WildcardPattern]::Escape($message))
            }
        }

        Context 'when the thing it calls fails' {
            It 'TODO: reports or stops as intended for each kind of failure' -Skip { }
        }

        Context 'what it must never do' {
            It 'TODO: makes no changes with -WhatIf, and does not treat empty input as everything' -Skip { }
        }

        Context 'zero, one, many and duplicates' {
            It 'TODO: behaves correctly for no items, one item, several items and repeated items' -Skip { }
        }
    }
}
