function Disconnect-Xdr {
    <#
    .SYNOPSIS
        Removes authentication token from local memory.
    .DESCRIPTION
        Microsoft does not provide a disconnect method, client credentials
        will stay active for about an hour. Disconnect is local only.
    .EXAMPLE
        Disconnect-Xdr
    #>
    [CmdletBinding()]
    param()

    $Script:XdrAuthContext = $null
    $Script:XdrAuthHeader = $null
}