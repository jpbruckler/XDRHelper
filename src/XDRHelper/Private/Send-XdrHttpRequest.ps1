function Send-XdrHttpRequest {
    # The seam for testing: one HTTP call, no logic. Mock this in Pester.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Method,
        [Parameter(Mandatory)][uri]$Uri,
        [Parameter(Mandatory)][hashtable]$Headers,
        [string]$Body
    )

    $params = @{
        Method                  = $Method
        Uri                     = $Uri
        Headers                 = $Headers
        SkipHttpErrorCheck      = $true      # HTTP errors come back as data, not exceptions
        StatusCodeVariable      = 'statusCode'
        ResponseHeadersVariable = 'responseHeaders'
        ErrorAction             = 'Stop'     # transport failures (DNS, reset, timeout) still throw
    }
    if ($Body) { $params.Body = $Body }

    $content = Invoke-RestMethod @params

    [pscustomobject]@{
        StatusCode = [int]$statusCode
        Headers    = $responseHeaders
        Content    = $content
    }
}