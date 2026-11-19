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
                    AppId     = '11111111-1111-1111-1111-111111111111'
                    AppSecret = ConvertTo-SecureString 'x' -AsPlainText -Force
                    TenantId  = '22222222-2222-2222-2222-222222222222'
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

            It 'does not attempt to reconnect' {
                Assert-XdrAuthentication
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
                Assert-XdrAuthentication
                Should -Invoke -ModuleName XDRHelper Connect-XdrByAppId -Times 1 -Exactly -ParameterFilter {
                    $AppId -eq '11111111-1111-1111-1111-111111111111' -and $TenantId -eq '22222222-2222-2222-2222-222222222222' -and $AppSecret -is [securestring]
                }
            }
        }

        Context 'renewal fails' {
            BeforeEach {
                Set-TestAuthState ([timespan]::FromMinutes(1))
                Mock -ModuleName XDRHelper Connect-XdrByAppId { throw 'AADSTS7000222: client secret expired' }
            }

            It 'should throw' {
                { Assert-XdrAuthentication } | Should-Throw
            }
        }
    }
}