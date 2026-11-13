function Get-XdrDevice {
    <#
    .SYNOPSIS
        Rerieves device information by Device ID or by OData 4 query.
    .DESCRIPTION
        Retrieves a device or collection of devices that have communicated with
        Microsoft Defender for Endpoint.

        If provided a DeviceId, a single object representing that device is
        returned.

        If provided a Query, the OData query results will be returend.

        Supports OData V4 queries. OData supported operators:

            $filter on the following properties:
                computerDnsName
                id
                version
                deviceValue
                aadDeviceId
                machineTags
                lastSeen
                exposureLevel
                onboardingStatus
                lastIpAddress
                healthStatus
                osPlatform
                riskScore
                rbacGroupId
            $top with max value of 10,000.
            $skip
    .PARAMETER DeviceId
        The ID of a device. This is not the hostname, but the unique ID of the
        device in Defender.
    .PARAMETER Query
        Hashtable representing an OData query in the form: @{ '$filter' = "healthStatus eq 'Active'"; '$top' = 10000 }
    .PARAMETER All
        When provided, this switch will return all machines.
    .EXAMPLE
        Get-XdrDevice -DeviceId 01a1d27ac48972b18c57edc582c15c3c

        Returns a single device object.
    .EXAMPLE
        Get-XdrDevice -Query @{ '$filter' = "startsWith(computerDnsName, 'svr')"}

        Returns a collection of devices with a computerDnsName value starting
        with 'svr'
    .NOTES
        For more examples see https://learn.microsoft.com/en-us/defender-endpoint/api/exposed-apis-odata-samples
    #>
    [CmdletBinding(DefaultParameterSetName = 'ById')]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'ById')]
        [Alias('id', 'MachineId', 'SenseMachineId')]
        [ValidateLength(40, 40)]
        [ValidatePattern('^[0-9a-fA-F]{40}$')]
        [string[]]$DeviceId,

        [Parameter(Mandatory = $true,
            ParameterSetName = 'ByOdata')]
        [hashtable] $Query,

        [Parameter(ParameterSetName = 'ByAll')]
        [switch] $All
    )

    process {
        $splat = switch ($PSCmdlet.ParameterSetName) {
            'ById' { @{ Path = "machines/$DeviceId" } }
            'ByOdata' { @{ Path = 'machines'; Query = $Query} }
            'ByAll' { @{ Path = "machines" } }
        }

        $results = Invoke-XdrApiRequest @splat
        return $results

    }
}