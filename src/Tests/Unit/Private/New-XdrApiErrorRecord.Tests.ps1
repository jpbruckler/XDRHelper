[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseShouldProcessForStateChangingFunctions',
    '',
    Justification = 'The function makes to system changes.'
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
    Describe 'New-XdrApiErrorRecord private function tests' -Tag Unit {
        BeforeAll {
            $Uri = [uri]'https://api.security.microsoft.com/api/machines/abc?$top=1'

            function New-TestResponse {
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                    'PSUseShouldProcessForStateChangingFunctions',
                    '',
                    Justification = 'The function makes to system changes.'
                )]
                param([int]$StatusCode, $Content)
                [pscustomobject]@{ StatusCode = $StatusCode; Headers = @{}; Content = $Content }
            }
        }

        Context 'response body carries a Defender API error object' {
            BeforeAll {
                $response = New-TestResponse -StatusCode 404 -Content ([pscustomobject]@{
                        error = [pscustomobject]@{
                            code    = 'ResourceNotFound'
                            message = 'Machine abc was not found'
                            target  = '5c7a2f6e-0000-4000-8000-000000000001'
                        }
                    })
                $record = New-XdrApiErrorRecord -Response $response -Method 'GET' -Uri $Uri
            }

            It 'returns an ErrorRecord' {
                $record | Should -BeOfType ([System.Management.Automation.ErrorRecord])
            }

            It 'builds the error id from the API error code' {
                $record.FullyQualifiedErrorId | Should -Be 'Xdr.ResourceNotFound'
            }

            It 'uses the request as the target object' {
                $record.TargetObject | Should -Be "GET $Uri"
            }

            It 'includes status, code, method, path and API message in the exception message' {
                $record.Exception.Message |
                Should -Be 'Defender API returned 404 ResourceNotFound on GET /api/machines/abc: Machine abc was not found (correlation id: 5c7a2f6e-0000-4000-8000-000000000001)'
            }

            It 'leaves the query string out of the exception message' {
                $record.Exception.Message | Should -Not -BeLike '*$top*'
            }

            It 'exposes status code, error code and correlation id in Exception.Data' {
                $record.Exception.Data['StatusCode'] | Should -Be 404
                $record.Exception.Data['ErrorCode'] | Should -Be 'ResourceNotFound'
                $record.Exception.Data['CorrelationId'] | Should -Be '5c7a2f6e-0000-4000-8000-000000000001'
            }
        }

        Context 'response body has no API error object' {
            It 'falls back to Http<status> and the raw content' {
                $response = New-TestResponse -StatusCode 502 -Content 'Bad Gateway'
                $record = New-XdrApiErrorRecord -Response $response -Method 'POST' -Uri $Uri

                $record.FullyQualifiedErrorId | Should -Be 'Xdr.Http502'
                $record.Exception.Message | Should -Be 'Defender API returned 502 Http502 on POST /api/machines/abc: Bad Gateway'
                $record.Exception.Data['ErrorCode'] | Should -Be 'Http502'
                $record.Exception.Data['CorrelationId'] | Should -BeNullOrEmpty
            }

            It 'copes with an empty body' {
                $response = New-TestResponse -StatusCode 500 -Content $null
                $record = New-XdrApiErrorRecord -Response $response -Method 'GET' -Uri $Uri

                $record.FullyQualifiedErrorId | Should -Be 'Xdr.Http500'
                $record.Exception.Message | Should -Not -BeLike '*correlation id*'
            }
        }

        Context 'error category' {
            It 'maps HTTP <StatusCode> to <Category>' -ForEach @(
                @{ StatusCode = 400; Category = 'InvalidArgument' }
                @{ StatusCode = 401; Category = 'AuthenticationError' }
                @{ StatusCode = 403; Category = 'PermissionDenied' }
                @{ StatusCode = 404; Category = 'ObjectNotFound' }
                @{ StatusCode = 429; Category = 'LimitsExceeded' }
                @{ StatusCode = 409; Category = 'ResourceUnavailable' }
                @{ StatusCode = 500; Category = 'ResourceUnavailable' }
                @{ StatusCode = 503; Category = 'ResourceUnavailable' }
            ) {
                $response = New-TestResponse -StatusCode $StatusCode -Content $null
                $record = New-XdrApiErrorRecord -Response $response -Method 'GET' -Uri $Uri

                $record.CategoryInfo.Category | Should -Be $Category
            }
        }
    }
}
