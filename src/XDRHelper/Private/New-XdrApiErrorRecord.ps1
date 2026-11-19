function New-XdrApiErrorRecord {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions','',
        Justification = 'The function makes to system changes.')]
    [CmdletBinding()]
    param($Response, [string]$Method, [uri]$Uri)

    $apiError = $Response.Content.error   # { code, message, target } per the docs
    $code     = if ($apiError.code) { $apiError.code } else { "Http$($Response.StatusCode)" }
    $message  = if ($apiError.message) { $apiError.message } else { "$($Response.Content)" }

    $category = switch ($Response.StatusCode) {
        400     { 'InvalidArgument' }
        401     { 'AuthenticationError' }
        403     { 'PermissionDenied' }
        404     { 'ObjectNotFound' }
        429     { 'LimitsExceeded' }
        default { 'ResourceUnavailable' }
    }

    $text = "Defender API returned $($Response.StatusCode) $code on $Method $($Uri.AbsolutePath): $message"
    if ($apiError.target) { $text += " (correlation id: $($apiError.target))" }

    $exception = [System.Exception]::new($text)
    $exception.Data['StatusCode']    = $Response.StatusCode
    $exception.Data['ErrorCode']     = $code
    $exception.Data['CorrelationId'] = $apiError.target

    [System.Management.Automation.ErrorRecord]::new($exception, "Xdr.$code", $category, "$Method $Uri")
}