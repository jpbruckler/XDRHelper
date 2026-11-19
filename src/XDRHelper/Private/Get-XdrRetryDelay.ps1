function Get-XdrRetryDelay {
    [CmdletBinding()]
    param($Response, [int]$Attempt)

    $seconds = 0
    $retryAfter = if ($Response.Headers) { $Response.Headers['Retry-After'] | Select-Object -First 1 }
    if ([int]::TryParse($retryAfter, [ref]$seconds)) { return $seconds }

    # No usable Retry-After (typically 5xx): exponential backoff with jitter, capped.
    [math]::Min(60, [math]::Pow(2, $Attempt)) + (Get-Random -Minimum 0.0 -Maximum 1.0)
}