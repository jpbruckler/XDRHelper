function Assert-XdrAuthentication {
    <#
    .SYNOPSIS
        Asserts valid authentication information exists for Defender.
    .DESCRIPTION
        Checks for the existence of stored Defender XDR authentication.

        If no stored Defender XDR authentication is found, an eexception is
        thrown.

        If authentication is found it will check to see if the token is going
        to expire within the next 5 minutes and will attempt re-authentication
        if so. If re-authentication fails, an exception is thrown.
    .EXAMPLE
        try {
            Assert-XdrAuthentication
            Get-XdrDevice -DeviceId 01a1d27ac48972b18c57edc582c15c3caca0ab45
        }
        catch {
            # handle your error....
        }

        Checks that authentication exists and is current before retrieving
        device information. Throws if no authentication exists from a Connect-Xdr*
        command, or if re-authentication fails.
    #>
    [CmdletBinding()]
    param()

    if (-not $Script:XdrAuthHeader.Authorization) {
        throw 'No XDR authentication context exists. Run Connect-XdrByAppID first.'
    }

    try {
        if ($Script:XdrAuthContext.Expires -le (Get-Date -AsUTC).AddMinutes(5)) {
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
