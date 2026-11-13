function Invoke-XdrApiRequest {
    [CmdletBinding()]
    param(
        [ValidateSet('GET', 'POST', 'PATCH', 'PUT', 'DELETE')]
        [string]$Method = 'GET',

        [Parameter(Mandatory)]
        [string]$Path,                    # 'machines', "machines/$Id/tags" — no /api prefix

        [hashtable]$Query,                # @{ '$filter' = "healthStatus eq 'Active'"; '$top' = 10000 }

        [object]$Body,                    # hashtable/pscustomobject → JSON

        [switch]$NoPaging,                # first page only
        [switch]$Raw,                     # emit page objects untouched

        [int]$MaxRetries = 4,
        [int]$MaxRetryAfterSeconds = 120  # beyond this, throw rather than silently sleep
    )

    $uri  = New-XdrApiUri -Path $Path -Query $Query
    # Body params are case-sensitive on the API side; ConvertTo-Json preserves key case.
    $json = if ($PSBoundParameters.ContainsKey('Body')) { $Body | ConvertTo-Json -Depth 10 -Compress }

    do {
        # ---- one logical request, with retries ----
        $attempt  = 0
        $reauthed = $false
        while ($true) {
            $attempt++

            # Re-checked every request: long paging + Retry-After sleeps can cross token expiry.
            # Will throw on failure.
            Assert-XdrAuthentication

            try {
                $response = Send-XdrHttpRequest -Method $Method -Uri $uri -Headers $Script:XdrAuthHeader -Body $json
            }
            catch {
                # Transport failure: no status code. Retry with backoff.
                if ($attempt -gt $MaxRetries) { throw }
                $delay = Get-XdrRetryDelay -Response $null -Attempt $attempt
                Write-Verbose "Transport error on $Method $uri ($($_.Exception.Message)); retrying in $([int]$delay)s."
                Start-Sleep -Seconds $delay
                continue
            }

            $status = $response.StatusCode
            if ($status -lt 400) { break }

            if ($status -eq 401 -and -not $reauthed) {
                # Token rejected despite not being near expiry (revoked, etc.). Force one renewal.
                $reauthed = $true
                $ctx = $Script:XdrAuthContext
                Connect-XdrByAppId -AppId $ctx.AppId -AppSecret $ctx.AppSecret -TenantId $ctx.TenantId
                continue
            }

            if (($status -eq 429 -or $status -ge 500) -and $attempt -le $MaxRetries) {
                $delay = Get-XdrRetryDelay -Response $response -Attempt $attempt
                if ($delay -le $MaxRetryAfterSeconds) {
                    Write-Verbose "HTTP $status on $Method $uri; retrying in $([int]$delay)s (attempt $attempt/$MaxRetries)."
                    Start-Sleep -Seconds $delay
                    continue
                }
            }

            # `throw`, not $PSCmdlet.ThrowTerminatingError: the latter is statement-terminating,
            # so this loop (and the caller's next line) would keep running.
            throw (New-XdrApiErrorRecord -Response $response -Method $Method -Uri $uri)
        }

        # ---- shape the output ----
        $content      = $response.Content
        $isCollection = $content -and $content.PSObject.Properties.Name -contains 'value'

        if ($Raw -or -not $isCollection) { $content }
        else                             { $content.value }   # unrolls items onto the pipeline

        # nextLink is absolute and already carries the query string; use it as-is.
        $uri = if ($isCollection -and -not $NoPaging) { $content.'@odata.nextLink' }
    } while ($uri)
}