function Set-XdrDeviceValue {
    <#
    .SYNOPSIS
        Sets the device value of one or more devices.
    .DESCRIPTION
        Sets device value to Low, Normal, or High for devices in Microsoft
        Defender for Endpoint.

        Device IDs can be supplied directly or from the pipeline, including the
        output of Get-XdrDevice.

        A device ID that does not exist in Defender is reported as a
        non-terminating error and the remaining devices are still processed.
        Any other API/HTTP failure stops the command.

        Device value changes can alter device group membership, and with it
        RBAC scope and policy targeting. Use -WhatIf to preview.
    .PARAMETER Id
        The ID of one or more devices. This is not the hostname, but the unique
        ID of the device in Defender.
    .PARAMETER DeviceValue
        The device value to set. Must be one of: High, Normal, Low
    .PARAMETER PassThru
        Returns the updated device objects. Each device is returned once,
        reflecting its state after the device value was changed. By default
        nothing is returned.
    .EXAMPLE
        Set-XdrDeviceValue -Id caab196872d62e639a7b7cdf8593601cf632b4eb -DeviceValue High

        Sets the device value to High for the given device.
    .EXAMPLE
        Get-XdrDevice -Query @{ '$filter' = "startsWith(computerDnsName, 'svr-dc')" } |
            Set-XdrDeviceValue -DeviceValue High

        Sets the device value to High for every device whose name starts with
        svr-dc.
    .EXAMPLE
        Set-XdrDeviceValue -Id $ids -DeviceValue High -WhatIf

        Shows which devices would be changed without calling the API.
    .NOTES
        Requires the Machine.ReadWrite.All application permission.

        https://learn.microsoft.com/en-us/defender-endpoint/api/set-device-value
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            ValueFromPipeline = $true)]
        [Alias('DeviceId', 'MachineId', 'SenseMachineId')]
        [ValidatePattern('^[0-9a-fA-F]{40}$')]
        [string[]] $Id,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Normal', 'Low', 'High')]
        [string] $DeviceValue,

        [switch] $PassThru
    )

    begin {
        Assert-XdrAuthentication

        enum ValueEnum {
            High
            Normal
            Low
        }
    }

    process {
        foreach ($device in $Id) {
            $DeviceValue = [ValueEnum]::$DeviceValue
            if (-not $PSCmdlet.ShouldProcess($device, "Set value '$DeviceValue'")) { continue }

            $path = "machines/$device/setDeviceValue"
            $body = @{
                DeviceValue = $DeviceValue
            }

            if (-not $PSCmdlet.ShouldProcess($device, "Set value '$DeviceValue'")) { continue }
            try {
                $result = Invoke-XdrApiRequest -Method 'POST' -Path $path -Body $body

                if ($PassThru) { $result }
            }
            catch {
                # Continue on 404 (no such device), throw on anything else.
                if ($_.Exception.Data['StatusCode'] -ne 404) { throw }

                # preserve the output of New-XdrApiErrorRecord
                $PSCmdlet.WriteError($_)
            }
        }
    }
}