[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseShouldProcessForStateChangingFunctions',
    '',
    Justification = 'Test helper functions make no system changes.'
)]
param()

BeforeDiscovery {
    Set-Location -Path $PSScriptRoot
    $ModuleName = 'XDRHelper'
    $PathToManifest = [System.IO.Path]::Combine('..', '..', '..', $ModuleName, "$ModuleName.psd1")
    #if the module is already in memory, remove it
    Get-Module $ModuleName -ErrorAction SilentlyContinue | Remove-Module -Force
    Import-Module $PathToManifest -Force
}

InModuleScope 'XDRHelper' {
    Describe 'Invoke-XdrDeviceTagRequest private function tests' -Tag Unit {
        BeforeAll {
            $IdA = 'caab196872d62e639a7b7cdf8593601cf632b4eb'
            $IdB = '1e5bc9d7e413ddd7902c2932e418702b84d0cc07'
            $IdC = 'abcdef0123456789abcdef0123456789abcdef01'
            $BulkPath = 'machines/AddOrRemoveTagForMultipleMachines'

            # Throws what Invoke-XdrApiRequest really throws: the record New-XdrApiErrorRecord builds.
            function New-TestApiError {
                param([int]$StatusCode, [string]$Code, [string]$Path)
                $response = [pscustomobject]@{
                    StatusCode = $StatusCode
                    Headers    = @{}
                    Content    = [pscustomobject]@{
                        error = [pscustomobject]@{ code = $Code; message = "$Code message"; target = 'corr-id' }
                    }
                }
                New-XdrApiErrorRecord -Response $response -Method 'POST' -Uri "https://api.security.microsoft.com/api/$Path"
            }

            # 40-character hex ids: 0000...0001, 0000...0002, ...
            function New-TestId {
                param([int]$Count)
                1..$Count | ForEach-Object { '{0:x40}' -f $_ }
            }
        }

        BeforeEach {
            # Stand-in for the API: echo back one "machine" per device the request touched.
            Mock Invoke-XdrApiRequest {
                if ($Body.MachineIds) {
                    foreach ($machineId in $Body.MachineIds) { [pscustomobject]@{ id = $machineId; machineTags = @($Body.Value) } }
                }
                else {
                    [pscustomobject]@{ id = ($Path -split '/')[1]; machineTags = @($Body.Value) }
                }
            }
        }

        Context 'parameters' {
            It 'only accepts Add or Remove as the action' {
                { Invoke-XdrDeviceTagRequest -Action 'Replace' -Tag 'T' -Id $IdA } |
                    Should -Throw -ErrorId 'ParameterArgumentValidationError*'
            }

            It 'rejects a batch size of <BatchSize>' -ForEach @(
                @{ BatchSize = 0 }
                @{ BatchSize = 501 }
            ) {
                { Invoke-XdrDeviceTagRequest -Action 'Add' -Tag 'T' -Id $IdA -BatchSize $BatchSize } |
                    Should -Throw -ErrorId 'ParameterArgumentValidationError*'
            }

            It 'defaults to the API limit of 500 devices per bulk request' {
                (Get-Command Invoke-XdrDeviceTagRequest).ScriptBlock.Ast.Body.ParamBlock.Parameters |
                    Where-Object { $_.Name.VariablePath.UserPath -eq 'BatchSize' } |
                    ForEach-Object { $_.DefaultValue.Value } | Should -Be 500
            }
        }

        Context 'a single device (<Action>)' -ForEach @(
            @{ Action = 'Add' }
            @{ Action = 'Remove' }
        ) {
            It 'posts to the per-device tags endpoint' {
                Invoke-XdrDeviceTagRequest -Action $Action -Tag 'Tier0' -Id $IdA

                Should -Invoke Invoke-XdrApiRequest -Times 1 -Exactly
                Should -Invoke Invoke-XdrApiRequest -Times 1 -Exactly -ParameterFilter {
                    $Method -eq 'POST' -and $Path -eq "machines/$IdA/tags"
                }
            }

            It 'sends Value and Action with the casing the API requires, and nothing else' {
                Invoke-XdrDeviceTagRequest -Action $Action -Tag 'Tier0' -Id $IdA

                Should -Invoke Invoke-XdrApiRequest -Times 1 -Exactly -ParameterFilter {
                    (ConvertTo-Json -InputObject $Body -Compress) -ceq "{`"Value`":`"Tier0`",`"Action`":`"$Action`"}"
                }
            }

            It 'returns the updated device' {
                $result = @(Invoke-XdrDeviceTagRequest -Action $Action -Tag 'Tier0' -Id $IdA)

                $result.Count | Should -Be 1
                $result[0].id | Should -Be $IdA
            }

            It 'passes the tag through untouched (<Tag>)' -ForEach @(
                @{ Tag = 'Site: DET / Server' }
                @{ Tag = "O'Brien & Co" }
                @{ Tag = 'tier0' }
            ) {
                Invoke-XdrDeviceTagRequest -Action $Action -Tag $Tag -Id $IdA

                Should -Invoke Invoke-XdrApiRequest -Times 1 -Exactly -ParameterFilter { $Body.Value -ceq $Tag }
            }
        }

        Context 'several devices (<Action>)' -ForEach @(
            @{ Action = 'Add' }
            @{ Action = 'Remove' }
        ) {
            It 'sends them in one bulk request' {
                Invoke-XdrDeviceTagRequest -Action $Action -Tag 'Tier0' -Id $IdA, $IdB, $IdC

                Should -Invoke Invoke-XdrApiRequest -Times 1 -Exactly
                Should -Invoke Invoke-XdrApiRequest -Times 1 -Exactly -ParameterFilter {
                    $Method -eq 'POST' -and $Path -eq $BulkPath
                }
            }

            It 'sends Value, Action and MachineIds with the casing the API requires' {
                Invoke-XdrDeviceTagRequest -Action $Action -Tag 'Tier0' -Id $IdA, $IdB

                Should -Invoke Invoke-XdrApiRequest -Times 1 -Exactly -ParameterFilter {
                    (ConvertTo-Json -InputObject $Body -Compress) -ceq "{`"Value`":`"Tier0`",`"Action`":`"$Action`",`"MachineIds`":[`"$IdA`",`"$IdB`"]}"
                }
            }

            It 'returns every updated device' {
                $result = @(Invoke-XdrDeviceTagRequest -Action $Action -Tag 'Tier0' -Id $IdA, $IdB, $IdC)

                $result.id | Should -Be @($IdA, $IdB, $IdC)
            }
        }

        Context 'batching' {
            It 'sends exactly 500 devices in one bulk request' {
                $ids = New-TestId -Count 500

                Invoke-XdrDeviceTagRequest -Action 'Add' -Tag 'T' -Id $ids

                Should -Invoke Invoke-XdrApiRequest -Times 1 -Exactly
                Should -Invoke Invoke-XdrApiRequest -Times 1 -Exactly -ParameterFilter { $Body.MachineIds.Count -eq 500 }
            }

            It 'splits 1,200 devices into bulk requests of 500, 500 and 200' {
                $ids = New-TestId -Count 1200

                $result = @(Invoke-XdrDeviceTagRequest -Action 'Add' -Tag 'T' -Id $ids)

                Should -Invoke Invoke-XdrApiRequest -Times 3 -Exactly
                Should -Invoke Invoke-XdrApiRequest -Times 2 -Exactly -ParameterFilter { $Body.MachineIds.Count -eq 500 }
                Should -Invoke Invoke-XdrApiRequest -Times 1 -Exactly -ParameterFilter { $Body.MachineIds.Count -eq 200 }
                $result.Count | Should -Be 1200
            }

            It 'keeps device order across batches and sends each device once' {
                $ids = New-TestId -Count 5

                $result = @(Invoke-XdrDeviceTagRequest -Action 'Add' -Tag 'T' -Id $ids -BatchSize 2)

                $result.id | Should -Be $ids
                Should -Invoke Invoke-XdrApiRequest -Times 1 -Exactly -ParameterFilter {
                    $Path -eq $BulkPath -and ($Body.MachineIds -join ',') -eq ($ids[0..1] -join ',')
                }
                Should -Invoke Invoke-XdrApiRequest -Times 1 -Exactly -ParameterFilter {
                    $Path -eq $BulkPath -and ($Body.MachineIds -join ',') -eq ($ids[2..3] -join ',')
                }
            }

            It 'uses the per-device endpoint for a final batch of one' {
                $ids = New-TestId -Count 5

                Invoke-XdrDeviceTagRequest -Action 'Add' -Tag 'T' -Id $ids -BatchSize 2

                Should -Invoke Invoke-XdrApiRequest -Times 2 -Exactly -ParameterFilter { $Path -eq $BulkPath }
                Should -Invoke Invoke-XdrApiRequest -Times 1 -Exactly -ParameterFilter { $Path -eq "machines/$($ids[4])/tags" }
            }
        }

        Context 'a single device that does not exist (HTTP 404)' {
            BeforeEach {
                Mock Invoke-XdrApiRequest { throw (New-TestApiError -StatusCode 404 -Code 'ResourceNotFound' -Path $Path) }
            }

            It 'writes a non-terminating error that preserves the API error record' {
                $output = Invoke-XdrDeviceTagRequest -Action 'Add' -Tag 'T' -Id $IdA 2>&1
                $errors = @($output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })

                $errors.Count | Should -Be 1
                $errors[0].FullyQualifiedErrorId | Should -BeLike 'Xdr.ResourceNotFound*'
                $errors[0].CategoryInfo.Category | Should -Be 'ObjectNotFound'
                $errors[0].Exception.Data['StatusCode'] | Should -Be 404
                "$($errors[0])" | Should -BeLike "*$IdA*"
            }

            It 'terminates with -ErrorAction Stop' {
                { Invoke-XdrDeviceTagRequest -Action 'Add' -Tag 'T' -Id $IdA -ErrorAction Stop } |
                    Should -Throw -ErrorId 'Xdr.ResourceNotFound*'
            }
        }

        Context 'a single device fails for another reason (HTTP <StatusCode>)' -ForEach @(
            @{ StatusCode = 400; Code = 'BadRequest' }
            @{ StatusCode = 401; Code = 'Unauthorized' }
            @{ StatusCode = 403; Code = 'Forbidden' }
            @{ StatusCode = 429; Code = 'TooManyRequests' }
            @{ StatusCode = 500; Code = 'InternalServerError' }
        ) {
            It 'terminates with the API error record' {
                Mock Invoke-XdrApiRequest { throw (New-TestApiError -StatusCode $StatusCode -Code $Code -Path $Path) }

                { Invoke-XdrDeviceTagRequest -Action 'Add' -Tag 'T' -Id $IdA -ErrorAction SilentlyContinue } |
                    Should -Throw -ErrorId "Xdr.$Code*"
            }
        }

        Context 'the bulk request is rejected with HTTP <StatusCode>' -ForEach @(
            @{ StatusCode = 400; Code = 'BadRequest' }
            @{ StatusCode = 404; Code = 'ResourceNotFound' }
        ) {
            BeforeEach {
                Mock Invoke-XdrApiRequest {
                    throw (New-TestApiError -StatusCode $StatusCode -Code $Code -Path $Path)
                } -ParameterFilter { $Path -eq $BulkPath }

                # ...because IdB no longer exists.
                Mock Invoke-XdrApiRequest {
                    throw (New-TestApiError -StatusCode 404 -Code 'ResourceNotFound' -Path $Path)
                } -ParameterFilter { $Path -eq "machines/$IdB/tags" }
            }

            It 'replays the batch one device at a time' {
                $null = Invoke-XdrDeviceTagRequest -Action 'Remove' -Tag 'Tier0' -Id $IdA, $IdB, $IdC 2>&1

                Should -Invoke Invoke-XdrApiRequest -Times 1 -Exactly -ParameterFilter { $Path -eq $BulkPath }
                foreach ($id in $IdA, $IdB, $IdC) {
                    Should -Invoke Invoke-XdrApiRequest -Times 1 -Exactly -ParameterFilter {
                        $Path -eq "machines/$id/tags" -and $Body.Value -eq 'Tier0' -and $Body.Action -eq 'Remove'
                    }
                }
            }

            It 'tags the good devices and reports only the missing one' {
                $output = Invoke-XdrDeviceTagRequest -Action 'Add' -Tag 'Tier0' -Id $IdA, $IdB, $IdC 2>&1
                $errors = @($output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
                $devices = @($output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })

                $devices.id | Should -Be @($IdA, $IdC)
                $errors.Count | Should -Be 1
                "$($errors[0])" | Should -BeLike "*$IdB*"
                $errors[0].Exception.Data['StatusCode'] | Should -Be 404
            }

            It 'only replays the batch that was rejected' {
                $ids = @($IdA, $IdB) + (New-TestId -Count 2)
                Mock Invoke-XdrApiRequest {
                    foreach ($machineId in $Body.MachineIds) { [pscustomobject]@{ id = $machineId } }
                } -ParameterFilter { $Path -eq $BulkPath -and $Body.MachineIds -notcontains $IdB }

                $null = Invoke-XdrDeviceTagRequest -Action 'Add' -Tag 'T' -Id $ids -BatchSize 2 2>&1

                Should -Invoke Invoke-XdrApiRequest -Times 2 -Exactly -ParameterFilter { $Path -eq $BulkPath }
                Should -Invoke Invoke-XdrApiRequest -Times 2 -Exactly -ParameterFilter { $Path -like 'machines/*/tags' }
                Should -Invoke Invoke-XdrApiRequest -Times 0 -Exactly -ParameterFilter { $Path -eq "machines/$($ids[2])/tags" }
            }

            It 'terminates if the replay shows the request itself is the problem' {
                # e.g. an invalid tag value: every device is rejected the same way.
                Mock Invoke-XdrApiRequest {
                    throw (New-TestApiError -StatusCode 400 -Code 'BadRequest' -Path $Path)
                } -ParameterFilter { $Path -like 'machines/*/tags' }

                { Invoke-XdrDeviceTagRequest -Action 'Add' -Tag 'T' -Id $IdA, $IdB, $IdC } | Should -Throw -ErrorId 'Xdr.BadRequest*'
                Should -Invoke Invoke-XdrApiRequest -Times 1 -Exactly -ParameterFilter { $Path -like 'machines/*/tags' }
            }
        }

        Context 'the bulk request fails with HTTP <StatusCode>' -ForEach @(
            @{ StatusCode = 401; Code = 'Unauthorized' }
            @{ StatusCode = 403; Code = 'Forbidden' }
            @{ StatusCode = 429; Code = 'TooManyRequests' }
            @{ StatusCode = 500; Code = 'InternalServerError' }
            @{ StatusCode = 503; Code = 'ServiceUnavailable' }
        ) {
            BeforeEach {
                Mock Invoke-XdrApiRequest {
                    throw (New-TestApiError -StatusCode $StatusCode -Code $Code -Path $Path)
                } -ParameterFilter { $Path -eq $BulkPath }
            }

            It 'terminates without replaying per device' {
                { Invoke-XdrDeviceTagRequest -Action 'Add' -Tag 'T' -Id $IdA, $IdB, $IdC } | Should -Throw -ErrorId "Xdr.$Code*"
                Should -Invoke Invoke-XdrApiRequest -Times 0 -Exactly -ParameterFilter { $Path -like 'machines/*/tags' }
            }

            It 'does not send the remaining batches' {
                { Invoke-XdrDeviceTagRequest -Action 'Add' -Tag 'T' -Id (New-TestId -Count 6) -BatchSize 2 } | Should -Throw

                Should -Invoke Invoke-XdrApiRequest -Times 1 -Exactly
            }
        }

        Context 'the bulk request fails with no HTTP status (transport or authentication error)' {
            It 'terminates without replaying per device' {
                Mock Invoke-XdrApiRequest { throw 'Connection reset by peer' }

                { Invoke-XdrDeviceTagRequest -Action 'Add' -Tag 'T' -Id $IdA, $IdB } | Should -Throw '*Connection reset by peer*'
                Should -Invoke Invoke-XdrApiRequest -Times 1 -Exactly
            }
        }
    }
}
