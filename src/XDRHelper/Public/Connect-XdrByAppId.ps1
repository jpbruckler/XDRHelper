function Connect-XdrByAppId {
    <#
    .SYNOPSIS
        Authenticates to Microsoft Defender XDR using an AppID and App secret.
    .DESCRIPTION
        Performs an OAuth client credential flow with the provided app registration ID and secret.
        Authentication token is cached locally for use with subsequent calls to this module's
        functions.
    .PARAMETER AppId
        The application ID for an Entra App Registration.
    .PARAMETER AppSecret
        The client secret for an Entra App Registration as a SecureString.
    .PARAMETER TenantId
        The ID of the Entra tenant to authenticate against.
    .EXAMPLE
        $AppId = '11111111-1111-1111-1111-111111111111'
        $TenantId = '22222222-2222-2222-2222-222222222222'
        $AppSecret = ConvertTo-SecureString 'FakeSecret' -AsPlainText -Force
        Connect-XdrByAppId -AppId $AppId -AppSecret $AppSecret -TenantId $TenantId

        Authenticates to Entra and stores the returned JWT token for future use.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [guid] $AppId,

        [Parameter(Mandatory)]
        [securestring]$AppSecret,

        [Parameter(Mandatory)]
        [guid] $TenantId
    )

    $sourceAppIdUri = 'https://api.securitycenter.microsoft.com'
    $OAuthURI = "https://login.microsoftonline.com/$TenantId/oauth2/token"

    $authBody = [ordered]@{
        resource      = $sourceAppIdUri
        client_id     = $AppId
        client_secret = ($AppSecret | ConvertFrom-SecureString -AsPlainText)
        grant_type    = 'client_credentials'
    }

    try {
        $response = Invoke-RestMethod `
            -Method Post `
            -Uri $OAuthURI `
            -Body $authBody `
            -ErrorAction Stop

        # Store the authentication information needed for renewal.
        $Script:XdrAuthContext = @{
            AppId     = $AppId
            AppSecret = $AppSecret
            TenantId  = $TenantId
            Expires   = (Get-Date -AsUTC).AddSeconds([int]$response.expires_in)
        }

        $Script:XdrAuthHeader = @{
            'Content-Type' = 'application/json'
            Accept         = 'application/json'
            Authorization  = "Bearer $($response.access_token)"
        }

        Write-Verbose "Connected to Defender XDR. Token expires at $($Script:XdrAuthContext.Expires.ToString('u'))"
    }
    catch {
        throw "Failed to authenticate to Defender XDR: AADSTS: $($_.ErrorDetails.Message.error_description) HTTP: $($_.Exception.Message)"
    }
}