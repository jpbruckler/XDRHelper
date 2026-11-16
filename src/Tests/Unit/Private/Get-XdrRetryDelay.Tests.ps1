BeforeDiscovery {
    Set-Location -Path $PSScriptRoot
    $ModuleName = 'XDRHelper'
    $PathToManifest = [System.IO.Path]::Combine('..', '..', '..', $ModuleName, "$ModuleName.psd1")
    #if the module is already in memory, remove it
    Get-Module $ModuleName -ErrorAction SilentlyContinue | Remove-Module -Force
    Import-Module $PathToManifest -Force
}

InModuleScope 'XDRHelper' {
    Describe 'Get-XdrRetryDelay private function tests' -Tag Unit {
        BeforeAll {
            # Pin the jitter so backoff values are exact.
            Mock Get-Random { 0.5 }
        }

        Context 'response carries a usable Retry-After header' {
            It 'returns the header value in seconds - <RetryAfter>' -ForEach @(
                @{ RetryAfter = '7'; Expected = 7 }
                @{ RetryAfter = '120'; Expected = 120 }
                @{ RetryAfter = '0'; Expected = 0 }
            ) {
                $response = [pscustomobject]@{ Headers = @{ 'Retry-After' = $RetryAfter } }

                Get-XdrRetryDelay -Response $response -Attempt 3 | Should -Be $Expected
                Should -Invoke Get-Random -Times 0 -Exactly
            }

            It 'uses the first value when the header is multi-valued' {
                # Invoke-RestMethod surfaces response headers as string arrays.
                $response = [pscustomobject]@{ Headers = @{ 'Retry-After' = @('15', '30') } }

                Get-XdrRetryDelay -Response $response -Attempt 1 | Should -Be 15
            }
        }

        Context 'no usable Retry-After header' {
            It 'backs off exponentially with jitter - attempt <Attempt>' -ForEach @(
                @{ Attempt = 1; Expected = 2.5 }
                @{ Attempt = 2; Expected = 4.5 }
                @{ Attempt = 3; Expected = 8.5 }
                @{ Attempt = 5; Expected = 32.5 }
            ) {
                $response = [pscustomobject]@{ Headers = @{} }

                Get-XdrRetryDelay -Response $response -Attempt $Attempt | Should -Be $Expected
            }

            It 'caps the backoff at 60 seconds plus jitter - attempt <Attempt>' -ForEach @(
                @{ Attempt = 6 }
                @{ Attempt = 10 }
            ) {
                $response = [pscustomobject]@{ Headers = @{} }

                Get-XdrRetryDelay -Response $response -Attempt $Attempt | Should -Be 60.5
            }

            It 'falls back to backoff when there is no response (transport failure)' {
                Get-XdrRetryDelay -Response $null -Attempt 2 | Should -Be 4.5
            }

            It 'falls back to backoff when Retry-After is not an integer (<RetryAfter>)' -ForEach @(
                @{ RetryAfter = 'Wed, 21 Oct 2026 07:28:00 GMT' }    # HTTP-date form is not parsed
                @{ RetryAfter = '' }
            ) {
                $response = [pscustomobject]@{ Headers = @{ 'Retry-After' = $RetryAfter } }

                Get-XdrRetryDelay -Response $response -Attempt 1 | Should -Be 2.5
            }
        }
    }
}
