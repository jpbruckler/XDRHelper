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
        function Set-TestAuthState([timespan]$ExpiresIn) {
            InModuleScope XDRHelper -Parameters @{ Expires = $Now + $ExpiresIn } {
                $script:XdrAuthHeader = @{ Authorization = 'Bearer fake-token' }
                $script:XdrAuthContext = @{
                    AppId     = '11111111-1111-1111-1111-111111111111'
                    AppSecret = ConvertTo-SecureString 'x' -AsPlainText -Force
                    TenantId  = '22222222-2222-2222-2222-222222222222'
                    Expires   = $ExpiresIn
                }
            }
        }
    }
    Describe 'Disconnect-Xdr Public function tests' {

        Context 'local cleanup' {
            BeforeEach {
                Set-TestAuthState -ExpiresIn ([timespan]::FromMinutes(59))
            }

            It 'should remove XdrAuthHeader and XdrAuthContext' {
                Disconnect-Xdr

                $Script:XdrAuthContext | Should-BeNull
                $Script:XdrAuthHeader | Should-BeNull
            }
        }

        Context "don't throw, no authentication exists" {
            It "should exit silently if XdrAuthHeader and XdrAuthContext don't exist" {
                { Disconnect-Xdr } | Should -Not -Throw
            }
        }
    }
}
