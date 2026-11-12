[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingConvertToSecureStringWithPlainText',
    '',
    Justification = 'Test credential contains no sensitive information.'
)]
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
    BeforeAll {
        $Now = [datetime]::new(2026, 11, 12, 18, 0, 0, [DateTimeKind]::Utc)
        function Set-TestAuthState([timespan]$ExpiresIn) {
            InModuleScope XDRHelper -Parameters @{ Expires = $Now + $ExpiresIn } {
                $script:XdrAuthHeader = @{ Authorization = 'Bearer fake-token' }
                $script:XdrAuthContext = @{
                    AppId     = 'test-app-id'
                    AppSecret = ConvertTo-SecureString 'x' -AsPlainText -Force
                    TenantId  = 'test-tenant-id'
                    Expires   = $Expires
                }
            }
        }

        function Clear-TestAuthState {
            InModuleScope XDRHelper {
                $script:XdrAuthHeader = $null
                $script:XdrAuthContext = $null
            }
        }
    }

    Describe 'Assert-XdrAuthentication public function tests' {
        BeforeAll {
            # Only intercept the -AsUTC call; anything else gets the real Get-Date.
            Mock -ModuleName XDRHelper Get-Date { $Now } -ParameterFilter { $AsUTC }
            Mock -ModuleName XDRHelper Connect-XdrByAppId { }

        }

        AfterEach { Clear-TestAuthState }

        Context 'no stored authentication' {
            BeforeEach { Clear-TestAuthState }

            It 'throws without attempting to connect' {
                { Assert-XdrAuthentication } | Should -Throw '*Run Connect-XdrByAppID first*'
                Should -Invoke -ModuleName XDRHelper Connect-XdrByAppId -Times 0 -Exactly
            }
        }

        Context 'token valid for more than 5 minutes (<ExpiresIn>)' -ForEach @(
            @{ ExpiresIn = [timespan]::FromMinutes(59) }
            @{ ExpiresIn = [timespan]::FromSeconds(301) }
        ) {
            BeforeEach { Set-TestAuthState $ExpiresIn }

            It 'returns $true without reconnecting' {
                Assert-XdrAuthentication | Should -BeTrue
                Should -Invoke -ModuleName XDRHelper Connect-XdrByAppId -Times 0 -Exactly
            }
        }

        Context 'token expires in 5 minutes or less (<ExpiresIn>)' -ForEach @(
            @{ ExpiresIn = [timespan]::FromSeconds(300) }    # exact boundary: -le vs -lt
            @{ ExpiresIn = [timespan]::FromSeconds(299) }
            @{ ExpiresIn = [timespan]::Zero }
            @{ ExpiresIn = [timespan]::FromMinutes(-30) }    # already expired
        ) {
            BeforeEach { Set-TestAuthState $ExpiresIn }

            It 'reconnects once using the stored context and returns $true' {
                Assert-XdrAuthentication | Should -BeTrue
                Should -Invoke -ModuleName XDRHelper Connect-XdrByAppId -Times 1 -Exactly -ParameterFilter {
                    $AppId -eq 'test-app-id' -and $TenantId -eq 'test-tenant-id' -and $AppSecret -is [securestring]
                }
            }
        }

        Context 'renewal fails' {
            BeforeEach {
                Set-TestAuthState ([timespan]::FromMinutes(1))
                Mock -ModuleName XDRHelper Connect-XdrByAppId { throw 'AADSTS7000222: client secret expired' }
            }

            It 'returns $false' {
                Assert-XdrAuthentication | Should -BeFalse
            }
        }
    }

    Describe 'Connect-XdrByAppId' {
        BeforeAll {
            Mock -ModuleName XDRHelper Get-Date { $Now } -ParameterFilter { $AsUTC }
            Mock -ModuleName XDRHelper Invoke-RestMethod {
                [pscustomobject]@{ access_token = 'new-token'; expires_in = '3599' }
            }
        }

        It 'stores an expiry based on expires_in' {
            Connect-XdrByAppId -AppId 'a' -TenantId 't' -AppSecret (ConvertTo-SecureString 'x' -AsPlainText -Force)
            InModuleScope XDRHelper { $script:XdrAuthContext.Expires } | Should -Be $Now.AddSeconds(3599)
            InModuleScope XDRHelper { $script:XdrAuthHeader.Authorization } | Should -Be 'Bearer new-token'
        }
    }
}