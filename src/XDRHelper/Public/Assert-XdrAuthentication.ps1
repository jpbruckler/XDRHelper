function Assert-XdrAuthentication {
    <#
    .SYNOPSIS
        Asserts valid authentication information exists for Defender.
    .DESCRIPTION
        Checks for the existence of stored Defender XDR authentication. If none
        is found, an error is thrown.

        If authentication is found it will check to see if the token is going
        to expire within the next 5 minutes and will attempt re-authentication
        if so.
    .EXAMPLE
        if (Assert-XdrAuthentication) {
            Get-XdrDevice -Id 01a1d0aefd1e73d7b5309f2e69231789
        }

        Checks that authentication exists and is current before retrieving
        device information.
    #>
    [CmdletBinding()]
    param()

    if (-not $Script:XdrAuthHeader.Authorization) {
        throw 'No XDR authentication context exists. Run Connect-XdrByAppID first.'
    }

    try {
        if (
            -not $Script:XdrAuthHeader.Authorization -or
            $Script:XdrAuthContext.Expires -le (Get-Date -AsUTC).AddMinutes(5)
        ) {
            Write-Verbose 'XDR authentication token is expired or approaching expiration. Renewing token.'

            Connect-XdrByAppID `
                -AppId $Script:XdrAuthContext.AppId `
                -AppSecret $Script:XdrAuthContext.AppSecret `
                -TenantId $Script:XdrAuthContext.TenantId
        }
    }
    catch {
        throw "Unable to renew Defender authentication token. $_"
    }
}
