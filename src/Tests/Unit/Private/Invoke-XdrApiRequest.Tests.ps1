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
    Describe 'Invoke-XdrApiRequest private function tests' -Tag Unit {
        BeforeAll {
            $BaseUri = 'https://api.security.microsoft.com/api'

            function New-TestResponse {
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                    'PSUseShouldProcessForStateChangingFunctions',
                    '',
                    Justification = 'The function makes to system changes.'
                )]
                param([int]$StatusCode = 200, $Content, [hashtable]$Headers = @{})
                [pscustomobject]@{ StatusCode = $StatusCode; Headers = $Headers; Content = $Content }
            }

            function New-TestErrorResponse {
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                    'PSUseShouldProcessForStateChangingFunctions',
                    '',
                    Justification = 'The function makes to system changes.'
                )]
                param([int]$StatusCode, [string]$Code, [hashtable]$Headers = @{})
                New-TestResponse -StatusCode $StatusCode -Headers $Headers -Content ([pscustomobject]@{
                        error = [pscustomobject]@{ code = $Code; message = "$Code message"; target = 'corr-id' }
                    })
            }

            # Queue the responses Send-XdrHttpRequest should hand back, in order.
            # A scriptblock entry is invoked instead of returned (used to simulate transport errors).
            function Set-TestResponse {
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                    'PSUseShouldProcessForStateChangingFunctions',
                    '',
                    Justification = 'The function makes to system changes.'
                )]
                param([object[]]$Response)
                $script:TestResponses = [System.Collections.Generic.Queue[object]]::new()
                foreach ($r in $Response) { $script:TestResponses.Enqueue($r) }
            }
        }

        BeforeEach {
            $script:XdrAuthHeader = @{ Authorization = 'Bearer fake-token' }
            $script:XdrAuthContext = @{
                AppId     = '11111111-1111-1111-1111-111111111111'
                AppSecret = ConvertTo-SecureString 'x' -AsPlainText -Force
                TenantId  = '22222222-2222-2222-2222-222222222222'
                Expires   = [datetime]::UtcNow.AddHours(1)
            }

            Mock Assert-XdrAuthentication { }
            Mock Connect-XdrByAppId { }
            Mock Start-Sleep { }
            Mock Get-XdrRetryDelay { 3 }
            Mock Send-XdrHttpRequest {
                $next = $script:TestResponses.Dequeue()
                if ($next -is [scriptblock]) { & $next } else { $next }
            }
        }

        AfterEach {
            $script:XdrAuthHeader = $null
            $script:XdrAuthContext = $null
            $script:TestResponses = $null
        }

        Context 'request construction' {
            BeforeEach {
                Set-TestResponse (New-TestResponse -Content ([pscustomobject]@{ id = 'abc' }))
            }

            It 'defaults to GET against the API base URI with the stored auth header' {
                Invoke-XdrApiRequest -Path 'machines/abc'

                Should -Invoke Send-XdrHttpRequest -Times 1 -Exactly -ParameterFilter {
                    $Method -eq 'GET' -and
                    $Uri.AbsoluteUri -eq "$BaseUri/machines/abc" -and
                    $Headers.Authorization -eq 'Bearer fake-token'
                }
            }

            It 'encodes -Query into the request URI' {
                Invoke-XdrApiRequest -Path 'machines' -Query @{ '$filter' = "healthStatus eq 'Active'"; '$top' = 5 }

                Should -Invoke Send-XdrHttpRequest -Times 1 -Exactly -ParameterFilter {
                    $Uri.AbsoluteUri -eq "$BaseUri/machines?`$filter=healthStatus%20eq%20%27Active%27&`$top=5"
                }
            }

            It 'checks authentication before sending' {
                Invoke-XdrApiRequest -Path 'machines/abc'

                Should -Invoke Assert-XdrAuthentication -Times 1 -Exactly
            }

            It 'sends no body when -Body is not supplied' {
                Invoke-XdrApiRequest -Path 'machines/abc'

                Should -Invoke Send-XdrHttpRequest -Times 1 -Exactly -ParameterFilter {
                    [string]::IsNullOrEmpty($Body)
                }
            }

            It 'serialises -Body to compressed JSON, preserving key case' {
                Invoke-XdrApiRequest -Method 'POST' -Path 'machines/abc/tags' -Body ([ordered]@{ Value = 'Tier0'; Action = 'Add' })

                Should -Invoke Send-XdrHttpRequest -Times 1 -Exactly -ParameterFilter {
                    $Method -eq 'POST' -and $Body -ceq '{"Value":"Tier0","Action":"Add"}'
                }
            }

            It 'rejects HTTP methods outside the supported set' {
                { Invoke-XdrApiRequest -Method 'HEAD' -Path 'machines' } | Should -Throw
                Should -Invoke Send-XdrHttpRequest -Times 0 -Exactly
            }
        }

        Context 'output shaping' {
            It 'emits a single-object response as-is' {
                Set-TestResponse (New-TestResponse -Content ([pscustomobject]@{ id = 'abc'; computerDnsName = 'svr-a' }))

                $result = @(Invoke-XdrApiRequest -Path 'machines/abc')

                $result.Count | Should -Be 1
                $result[0].computerDnsName | Should -Be 'svr-a'
            }

            It 'unrolls the value array of a collection response' {
                Set-TestResponse (New-TestResponse -Content ([pscustomobject]@{
                            '@odata.context' = "$BaseUri/`$metadata#Machines"
                            value            = @([pscustomobject]@{ id = 'a' }, [pscustomobject]@{ id = 'b' })
                        }))

                $result = @(Invoke-XdrApiRequest -Path 'machines')

                $result.id | Should -Be @('a', 'b')
            }

            It 'emits nothing for an empty collection' {
                Set-TestResponse (New-TestResponse -Content ([pscustomobject]@{ value = @() }))

                @(Invoke-XdrApiRequest -Path 'machines').Count | Should -Be 0
            }

            It 'emits nothing for an empty response body (e.g. 204)' {
                Set-TestResponse (New-TestResponse -StatusCode 204 -Content $null)

                @(Invoke-XdrApiRequest -Method 'DELETE' -Path 'indicators/1').Count | Should -Be 0
            }

            It 'emits the page object untouched with -Raw' {
                Set-TestResponse (New-TestResponse -Content ([pscustomobject]@{
                            value = @([pscustomobject]@{ id = 'a' }, [pscustomobject]@{ id = 'b' })
                        }))

                $result = @(Invoke-XdrApiRequest -Path 'machines' -Raw)

                $result.Count | Should -Be 1
                $result[0].value.Count | Should -Be 2
            }
        }

        Context 'paging' {
            BeforeEach {
                $nextLink = "$BaseUri/machines?`$skip=2"
                Set-TestResponse @(
                    New-TestResponse -Content ([pscustomobject]@{
                            value             = @([pscustomobject]@{ id = 'a' }, [pscustomobject]@{ id = 'b' })
                            '@odata.nextLink' = $nextLink
                        })
                    New-TestResponse -Content ([pscustomobject]@{
                            value = @([pscustomobject]@{ id = 'c' })
                        })
                )
            }

            It 'follows @odata.nextLink until it runs out and emits every item' {
                $result = @(Invoke-XdrApiRequest -Path 'machines')

                $result.id | Should -Be @('a', 'b', 'c')
                Should -Invoke Send-XdrHttpRequest -Times 2 -Exactly
            }

            It 'requests the nextLink exactly as the API returned it' {
                Invoke-XdrApiRequest -Path 'machines' -Query @{ '$top' = 2 }

                Should -Invoke Send-XdrHttpRequest -Times 1 -Exactly -ParameterFilter {
                    "$Uri" -eq $nextLink
                }
            }

            It 're-checks authentication for every page' {
                Invoke-XdrApiRequest -Path 'machines'

                Should -Invoke Assert-XdrAuthentication -Times 2 -Exactly
            }

            It 'stops after the first page with -NoPaging' {
                $result = @(Invoke-XdrApiRequest -Path 'machines' -NoPaging)

                $result.id | Should -Be @('a', 'b')
                Should -Invoke Send-XdrHttpRequest -Times 1 -Exactly
            }

            It 'emits one object per page with -Raw' {
                $result = @(Invoke-XdrApiRequest -Path 'machines' -Raw)

                $result.Count | Should -Be 2
                $result[0].'@odata.nextLink' | Should -Be $nextLink
            }
        }

        Context 'non-retryable HTTP errors' {
            It 'throws immediately on HTTP <StatusCode>' -ForEach @(
                @{ StatusCode = 400; Code = 'BadRequest' }
                @{ StatusCode = 403; Code = 'Forbidden' }
                @{ StatusCode = 404; Code = 'ResourceNotFound' }
            ) {
                Set-TestResponse (New-TestErrorResponse -StatusCode $StatusCode -Code $Code)

                { Invoke-XdrApiRequest -Path 'machines/abc' } | Should -Throw -ErrorId "Xdr.$Code"
                Should -Invoke Send-XdrHttpRequest -Times 1 -Exactly
                Should -Invoke Start-Sleep -Times 0 -Exactly
            }

            It 'does not continue paging after an error' {
                Set-TestResponse @(
                    New-TestResponse -Content ([pscustomobject]@{
                            value             = @([pscustomobject]@{ id = 'a' })
                            '@odata.nextLink' = "$BaseUri/machines?`$skip=1"
                        })
                    New-TestErrorResponse -StatusCode 403 -Code 'Forbidden'
                )

                { Invoke-XdrApiRequest -Path 'machines' } | Should -Throw -ErrorId 'Xdr.Forbidden'
                Should -Invoke Send-XdrHttpRequest -Times 2 -Exactly
            }
        }

        Context 'HTTP 401' {
            It 'renews the token once from the stored context and retries' {
                Set-TestResponse @(
                    New-TestErrorResponse -StatusCode 401 -Code 'Unauthorized'
                    New-TestResponse -Content ([pscustomobject]@{ id = 'abc' })
                )

                $result = Invoke-XdrApiRequest -Path 'machines/abc'

                $result.id | Should -Be 'abc'
                Should -Invoke Send-XdrHttpRequest -Times 2 -Exactly
                Should -Invoke Start-Sleep -Times 0 -Exactly
                Should -Invoke Connect-XdrByAppId -Times 1 -Exactly -ParameterFilter {
                    $AppId -eq '11111111-1111-1111-1111-111111111111' -and $TenantId -eq '22222222-2222-2222-2222-222222222222' -and $AppSecret -is [securestring]
                }
            }

            It 'throws when the renewed token is rejected too' {
                Set-TestResponse @(
                    New-TestErrorResponse -StatusCode 401 -Code 'Unauthorized'
                    New-TestErrorResponse -StatusCode 401 -Code 'Unauthorized'
                )

                { Invoke-XdrApiRequest -Path 'machines/abc' } | Should -Throw -ErrorId 'Xdr.Unauthorized'
                Should -Invoke Connect-XdrByAppId -Times 1 -Exactly
                Should -Invoke Send-XdrHttpRequest -Times 2 -Exactly
            }
        }

        Context 'retryable HTTP errors (<StatusCode>)' -ForEach @(
            @{ StatusCode = 429; Code = 'TooManyRequests' }
            @{ StatusCode = 500; Code = 'InternalServerError' }
            @{ StatusCode = 503; Code = 'ServiceUnavailable' }
        ) {
            It 'sleeps for the computed delay and retries' {
                Set-TestResponse @(
                    New-TestErrorResponse -StatusCode $StatusCode -Code $Code
                    New-TestResponse -Content ([pscustomobject]@{ id = 'abc' })
                )

                $result = Invoke-XdrApiRequest -Path 'machines/abc'

                $result.id | Should -Be 'abc'
                Should -Invoke Send-XdrHttpRequest -Times 2 -Exactly
                Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 3 }
            }

            It 'hands the failed response and attempt number to Get-XdrRetryDelay' {
                Set-TestResponse @(
                    New-TestErrorResponse -StatusCode $StatusCode -Code $Code
                    New-TestErrorResponse -StatusCode $StatusCode -Code $Code
                    New-TestResponse -Content ([pscustomobject]@{ id = 'abc' })
                )

                Invoke-XdrApiRequest -Path 'machines/abc'

                Should -Invoke Get-XdrRetryDelay -Times 1 -Exactly -ParameterFilter {
                    $Attempt -eq 1 -and $Response.StatusCode -eq $StatusCode
                }
                Should -Invoke Get-XdrRetryDelay -Times 1 -Exactly -ParameterFilter { $Attempt -eq 2 }
            }

            It 'gives up after MaxRetries retries and throws the API error' {
                Set-TestResponse @(1..3 | ForEach-Object { New-TestErrorResponse -StatusCode $StatusCode -Code $Code })

                { Invoke-XdrApiRequest -Path 'machines/abc' -MaxRetries 2 } | Should -Throw -ErrorId "Xdr.$Code"
                Should -Invoke Send-XdrHttpRequest -Times 3 -Exactly    # first try + 2 retries
                Should -Invoke Start-Sleep -Times 2 -Exactly
            }

            It 'does not retry at all with -MaxRetries 0' {
                Set-TestResponse (New-TestErrorResponse -StatusCode $StatusCode -Code $Code)

                { Invoke-XdrApiRequest -Path 'machines/abc' -MaxRetries 0 } | Should -Throw -ErrorId "Xdr.$Code"
                Should -Invoke Send-XdrHttpRequest -Times 1 -Exactly
                Should -Invoke Start-Sleep -Times 0 -Exactly
            }

            It 'throws instead of sleeping when the delay exceeds MaxRetryAfterSeconds' {
                Mock Get-XdrRetryDelay { 121 }
                Set-TestResponse (New-TestErrorResponse -StatusCode $StatusCode -Code $Code)

                { Invoke-XdrApiRequest -Path 'machines/abc' } | Should -Throw -ErrorId "Xdr.$Code"
                Should -Invoke Send-XdrHttpRequest -Times 1 -Exactly
                Should -Invoke Start-Sleep -Times 0 -Exactly
            }

            It 'still sleeps when the delay equals MaxRetryAfterSeconds' {
                Mock Get-XdrRetryDelay { 30 }
                Set-TestResponse @(
                    New-TestErrorResponse -StatusCode $StatusCode -Code $Code
                    New-TestResponse -Content ([pscustomobject]@{ id = 'abc' })
                )

                Invoke-XdrApiRequest -Path 'machines/abc' -MaxRetryAfterSeconds 30

                Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 30 }
            }
        }

        Context 'transport failures' {
            It 'retries with backoff and returns the eventual response' {
                Set-TestResponse @(
                    { throw 'Connection reset by peer' }
                    New-TestResponse -Content ([pscustomobject]@{ id = 'abc' })
                )

                $result = Invoke-XdrApiRequest -Path 'machines/abc'

                $result.id | Should -Be 'abc'
                Should -Invoke Send-XdrHttpRequest -Times 2 -Exactly
                Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 3 }
                Should -Invoke Get-XdrRetryDelay -Times 1 -Exactly -ParameterFilter {
                    $null -eq $Response -and $Attempt -eq 1
                }
            }

            It 'rethrows the transport error once MaxRetries is exhausted' {
                Set-TestResponse @(1..3 | ForEach-Object { { throw 'Connection reset by peer' } })

                { Invoke-XdrApiRequest -Path 'machines/abc' -MaxRetries 2 } | Should -Throw '*Connection reset by peer*'
                Should -Invoke Send-XdrHttpRequest -Times 3 -Exactly
                Should -Invoke Start-Sleep -Times 2 -Exactly
            }
        }

        # Only GET is re-sent after a failure that may have reached the server. A POST that timed out
        # or returned 5xx could already have been acted on, so sending it again risks a duplicate action.
        Context 'methods that are not safe to re-send (<Method>)' -ForEach @(
            @{ Method = 'POST' }
            @{ Method = 'PATCH' }
            @{ Method = 'PUT' }
            @{ Method = 'DELETE' }
        ) {
            It 'does not re-send after a transport failure' {
                Set-TestResponse @(
                    { throw 'Connection reset by peer' }
                    New-TestResponse -StatusCode 201 -Content ([pscustomobject]@{ id = 'abc' })
                )

                { Invoke-XdrApiRequest -Method $Method -Path 'machines/abc/isolate' -Body @{ Comment = 'test' } } |
                    Should -Throw '*Connection reset by peer*'
                Should -Invoke Send-XdrHttpRequest -Times 1 -Exactly
                Should -Invoke Start-Sleep -Times 0 -Exactly
            }

            It 'does not re-send after HTTP <StatusCode>' -ForEach @(
                @{ StatusCode = 500; Code = 'InternalServerError' }
                @{ StatusCode = 502; Code = 'BadGateway' }
                @{ StatusCode = 503; Code = 'ServiceUnavailable' }
            ) {
                Set-TestResponse @(
                    New-TestErrorResponse -StatusCode $StatusCode -Code $Code
                    New-TestResponse -StatusCode 201 -Content ([pscustomobject]@{ id = 'abc' })
                )

                { Invoke-XdrApiRequest -Method $Method -Path 'machines/abc/isolate' -Body @{ Comment = 'test' } } |
                    Should -Throw -ErrorId "Xdr.$Code"
                Should -Invoke Send-XdrHttpRequest -Times 1 -Exactly
                Should -Invoke Start-Sleep -Times 0 -Exactly
            }

            # 429 means the API refused the request without acting on it, so a retry cannot duplicate anything.
            It 'still retries after HTTP 429' {
                Set-TestResponse @(
                    New-TestErrorResponse -StatusCode 429 -Code 'TooManyRequests'
                    New-TestResponse -StatusCode 201 -Content ([pscustomobject]@{ id = 'abc' })
                )

                $result = Invoke-XdrApiRequest -Method $Method -Path 'machines/abc/isolate' -Body @{ Comment = 'test' }

                $result.id | Should -Be 'abc'
                Should -Invoke Send-XdrHttpRequest -Times 2 -Exactly
                Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 3 }
            }

            It 'still gives up on HTTP 429 once MaxRetries is exhausted' {
                Set-TestResponse @(1..3 | ForEach-Object { New-TestErrorResponse -StatusCode 429 -Code 'TooManyRequests' })

                { Invoke-XdrApiRequest -Method $Method -Path 'machines/abc/isolate' -Body @{ Comment = 'test' } -MaxRetries 2 } |
                    Should -Throw -ErrorId 'Xdr.TooManyRequests'
                Should -Invoke Send-XdrHttpRequest -Times 3 -Exactly
            }

            # 401 also means the request was rejected before anything happened.
            It 'still renews the token and re-sends after HTTP 401' {
                Set-TestResponse @(
                    New-TestErrorResponse -StatusCode 401 -Code 'Unauthorized'
                    New-TestResponse -StatusCode 201 -Content ([pscustomobject]@{ id = 'abc' })
                )

                $result = Invoke-XdrApiRequest -Method $Method -Path 'machines/abc/isolate' -Body @{ Comment = 'test' }

                $result.id | Should -Be 'abc'
                Should -Invoke Connect-XdrByAppId -Times 1 -Exactly
                Should -Invoke Send-XdrHttpRequest -Times 2 -Exactly
            }

            It 're-sends the same body on a permitted retry' {
                Set-TestResponse @(
                    New-TestErrorResponse -StatusCode 429 -Code 'TooManyRequests'
                    New-TestResponse -StatusCode 201 -Content ([pscustomobject]@{ id = 'abc' })
                )

                Invoke-XdrApiRequest -Method $Method -Path 'machines/abc/isolate' -Body @{ Comment = 'test' }

                Should -Invoke Send-XdrHttpRequest -Times 2 -Exactly -ParameterFilter {
                    $Body -ceq '{"Comment":"test"}'
                }
            }
        }

        Context 'authentication cannot be asserted' {
            It 'throws without sending anything' {
                Mock Assert-XdrAuthentication { throw 'No XDR authentication context exists.' }
                Set-TestResponse (New-TestResponse -Content ([pscustomobject]@{ id = 'abc' }))

                { Invoke-XdrApiRequest -Path 'machines/abc' } | Should -Throw '*No XDR authentication context exists.*'
                Should -Invoke Send-XdrHttpRequest -Times 0 -Exactly
            }
        }
    }
}
