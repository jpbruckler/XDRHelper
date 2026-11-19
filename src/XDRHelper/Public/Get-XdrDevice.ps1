function Get-XdrDevice {
    <#
    .SYNOPSIS
        Retrieves device information by Device ID or by OData 4 query.
    .DESCRIPTION
        Retrieves a device or collection of devices that have communicated with
        Microsoft Defender for Endpoint.

        If provided a Id, a single object representing that device is
        returned.

        If provided a Query, the OData query results will be returned.

        Supports OData V4 queries. OData supported operators:

            $filter on the following properties:
                computerDnsName
                device
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
    .PARAMETER Id
        The ID of a device. This is not the hostname, but the unique ID of the
        device in Defender.
    .PARAMETER Query
        Hashtable representing an OData query in the form: @{ '$filter' = "healthStatus eq 'Active'"; '$top' = 10000 }
    .PARAMETER All
        When provided, this switch will return all machines.
    .EXAMPLE
        Get-XdrDevice -DeviceId 01a1d27ac48972b18c57edc582c15c3caca0ab45

        Returns a single device object.
    .EXAMPLE
        Get-XdrDevice -Query @{ '$filter' = "startsWith(computerDnsName, 'svr')"}

        Returns a collection of devices with a computerDnsName value starting
        with 'svr'
    .EXAMPLE
        Get-XdrDevice -All

        Returns all devices.
    .NOTES
        For more examples see https://learn.microsoft.com/en-us/defender-endpoint/api/exposed-apis-odata-samples
    #>
    [CmdletBinding(DefaultParameterSetName = 'ById')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            ValueFromPipeline = $true,
            ParameterSetName = 'ById')]
        [Alias('DeviceId', 'MachineId', 'SenseMachineId')]
        [ValidatePattern('^[0-9a-fA-F]{40}$')]
        [string[]]$Id,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = 'ByOdata')]
        [hashtable] $Query,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = 'AllMachines')]
        [switch] $All
    )

    begin {
        Assert-XdrAuthentication
    }

    process {
        $path = 'machines'

        switch ($PSCmdlet.ParameterSetName) {
            'AllMachines' {
                if ($All) {
                    Invoke-XdrApiRequest -Path $path
                }
            }
            'ByOdata' { Invoke-XdrApiRequest -Path $path -Query $Query }
            'ById' {
                foreach ($device in $Id) {
                    try {
                        Invoke-XdrApiRequest -Path "$path/$device"
                    }
                    catch {
                        # Continue on 404, throw on anything else
                        if ($_.Exception.Data['StatusCode'] -ne 404) { throw }

                        # preserve the output of New-XdrApiErrorRecord
                        $PSCmdlet.WriteError($_)
                    }
                }
            }
        }
    }
}