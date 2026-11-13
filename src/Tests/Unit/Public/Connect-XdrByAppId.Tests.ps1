
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingConvertToSecureStringWithPlainText',
    '',
    Justification = 'Test credential contains no sensitive information.'
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
    BeforeAll {
        $Now = [datetime]::new(2026, 11, 12, 18, 0, 0, [DateTimeKind]::Utc)
    }
    Describe 'Connect-XdrByAppId public function tests' -Tag Unit {
        BeforeAll {
            Mock -ModuleName XDRHelper Get-Date { $Now } -ParameterFilter { $AsUTC }
            $AppId = '11111111-1111-1111-1111-111111111111'
            $TenantId = '22222222-2222-2222-2222-222222222222'
            $AppSecret = ConvertTo-SecureString 'FakeSecret' -AsPlainText -Force
        }

        Context 'When authentication succeeds' {
            BeforeEach {
                Mock Invoke-RestMethod {
                    @{
                        token_type   = 'Bearer'
                        expires_in   = 3599
                        access_token = 'FakeAccessToken'
                    }
                }
            }

            It 'Requests a token using client credentials' {
                Connect-XdrByAppId -AppId $AppId -AppSecret $AppSecret -TenantId $TenantId

                Should -Invoke Invoke-RestMethod `
                    -Times 1 `
                    -Exactly `
                    -ParameterFilter {
                    $Method -eq 'Post' -and
                    $Uri -eq "https://login.microsoftonline.com/$TenantId/oauth2/token" -and
                    $Body.client_id -eq $AppId -and
                    $Body.grant_type -eq 'client_credentials' -and
                    $Body.resource -eq 'https://api.securitycenter.microsoft.com'
                }
            }

            It 'creates the authorization header' {

                Connect-XdrByAppID `
                    -AppId $AppId `
                    -AppSecret $AppSecret `
                    -TenantId $TenantId

                InModuleScope XDRHelper {
                    $Script:XdrAuthHeader.Authorization |
                    Should -Be 'Bearer FakeAccessToken'
                }
            }

            It 'stores the authentication context' {

                Connect-XdrByAppID `
                    -AppId $AppId `
                    -AppSecret $AppSecret `
                    -TenantId $TenantId

                InModuleScope XDRHelper {
                    $Script:XdrAuthContext |
                    Should -Not -BeNullOrEmpty

                    $Script:XdrAuthContext.Expires |
                    Should -BeGreaterThan (Get-Date -AsUTC)
                }
            }

            It 'stores an expiry based on expires_in' {
                Connect-XdrByAppID `
                    -AppId $AppId `
                    -AppSecret $AppSecret `
                    -TenantId $TenantId
                InModuleScope XDRHelper { $script:XdrAuthContext.Expires } | Should -Be $Now.AddSeconds(3599)
                InModuleScope XDRHelper { $script:XdrAuthHeader.Authorization } | Should -Be 'Bearer FakeAccessToken'            }
        }

        Context 'When authentication fails' {

            BeforeEach {
                Mock Invoke-RestMethod -ModuleName XDRHelper {
                    throw 'Invalid client secret'
                }
            }

            It 'throws an authentication error' {

                {
                    Connect-XdrByAppID `
                        -AppId $AppId `
                        -AppSecret $AppSecret `
                        -TenantId $TenantId
                } | Should -Throw '*Failed to authenticate*'
            }
        }
    }
}