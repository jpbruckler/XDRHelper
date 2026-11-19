function New-XdrApiUri {
    <#
    .SYNOPSIS
        Creates a valid Defender for endpoint URI given a path and/or query.
    .DESCRIPTION
        Returns a full URI for interacting with the Defender for Endpoint REST
        API.
    .PARAMETER Path
        An API endpoint path, without including 'api/'.
    .PARAMETER Query
        A hashtable representing parts of an OData query; e.g.
        @{ '$filter' = "healthStatus eq 'Active'"; '$top' = 10000 }
    .EXAMPLE
        New-XdrApiUri -Path 'machines/caab196872d62e639a7b7cdf8593601cf632b4eb/tags'

        AbsolutePath   : /api/machines/caab196872d62e639a7b7cdf8593601cf632b4eb/tags
        AbsoluteUri    : https://api.security.microsoft.com/api/machines/caab196872d62e639a7b7cdf8593601cf6
                         32b4eb/tags
        LocalPath      : /api/machines/caab196872d62e639a7b7cdf8593601cf632b4eb/tags
        Authority      : api.security.microsoft.com
        HostNameType   : Dns
        IsDefaultPort  : True
        IsFile         : False
        IsLoopback     : False
        PathAndQuery   : /api/machines/caab196872d62e639a7b7cdf8593601cf632b4eb/tags
        Segments       : {/, api/, machines/, caab196872d62e639a7b7cdf8593601cf632b4eb/…}
        IsUnc          : False
        Host           : api.security.microsoft.com
        Port           : 443
        Query          :
        Fragment       :
        Scheme         : https
        OriginalString : https://api.security.microsoft.com/api/machines/caab196872d62e639a7b7cdf8593601cf6
                         32b4eb/tags
        DnsSafeHost    : api.security.microsoft.com
        IdnHost        : api.security.microsoft.com
        IsAbsoluteUri  : True
        UserEscaped    : False
        UserInfo       :

        Returns a System.URI object containing the absolute URI for interacting
        with Defender.
    .EXAMPLE
        New-XdrApiUri -Path 'machines' -Query @{ '$filter' = "healthStatus eq 'Active'"; '$top' = 10000 }

        AbsolutePath   : /api/machines
        AbsoluteUri    : https://api.security.microsoft.com/api/machines?$top=10000&$filter=healthStatus%20eq%20%27Active%27
        LocalPath      : /api/machines
        Authority      : api.security.microsoft.com
        HostNameType   : Dns
        IsDefaultPort  : True
        IsFile         : False
        IsLoopback     : False
        PathAndQuery   : /api/machines?$top=10000&$filter=healthStatus%20eq%20%27Active%27
        Segments       : {/, api/, machines}
        IsUnc          : False
        Host           : api.security.microsoft.com
        Port           : 443
        Query          : ?$top=10000&$filter=healthStatus%20eq%20%27Active%27
        Fragment       :
        Scheme         : https
        OriginalString : https://api.security.microsoft.com/api/machines?$top=10000&$filter=healthStatus%20eq%20%27Active%27
        DnsSafeHost    : api.security.microsoft.com
        IdnHost        : api.security.microsoft.com
        IsAbsoluteUri  : True
        UserEscaped    : False
        UserInfo       :

        Returns a System.URI object containing the absolute URI, including encoded
        OData query, for interacting with Defender.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'The function makes to system changes.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
                $p = $_.Trim().Trim('/')
                if (-not $p) { throw 'Path is empty.' }
                if ($p -match '[?#\\]') { throw "Path must not contain '?', '#' or '\'; use -Query." }
                if ($p -match '(^|/)\.{1,2}(/|$)') { throw "Path must not contain '.' or '..' segments." }
                if ($p -match '^api(/|$)') { throw "Path is relative to the API base; drop the 'api/' prefix." }
                $true
            })]
        [string]$Path,
        [System.Collections.IDictionary]$Query
    )

    if (-not $Script:XdrApiBaseUri) {
        throw 'Module base URI ($Script:XdrApiBaseUri) is not set.'
    }

    $cleanPath = $Path.Trim().Trim('/')
    $uri = '{0}/{1}' -f $Script:XdrApiBaseUri.TrimEnd('/'), $cleanPath

    $pairs = foreach ($key in ($Query.Keys | Sort-Object)) {
        if ([string]::IsNullOrWhiteSpace($key)) {
            throw "Query has an empty key. Did you write `"`$filter`" in double quotes? Use '`$filter'."
        }
        if ($key -notmatch '^\$?[A-Za-z][A-Za-z0-9]*$') {
            throw "Invalid query key: '$key'"
        }

        $value = $Query[$key]
        if ($null -eq $value -or [string]::IsNullOrWhiteSpace("$value")) { continue }

        if ($value -is [System.Collections.IEnumerable] -and $value -isnot [string]) {
            throw "Query value for '$key' is a collection; join it explicitly."
        }

        $text = switch ($value) {
            { $_ -is [bool] } { "$_".ToLowerInvariant() }
            { $_ -is [datetime] } { $_.ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss'Z'") }
            default { [string]$_ }
        }

        '{0}={1}' -f $key, [uri]::EscapeDataString($text)
    }

    if ($pairs) { $uri += '?' + ($pairs -join '&') }
    [uri]::new($uri)
}