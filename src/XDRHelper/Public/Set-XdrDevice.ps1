function Set-XdrDevice {
    <#
    .SYNOPSIS
        Sets a device's Value or Tag collection.
    .DESCRIPTION
        Set the DeviceValue or Tag collection for one or more devices. When
        setting tags with this cmdlet, the existing tag collection will be
        replaced by the collection provided in -Tag. If you just want to append
        one or more tags, use Add-XdrDeviceTag instead.

        Device IDs can be supplied directly or from the pipeline, including
        the output of Get-XdrDevice.

        A device ID that does not exist in Defender is reported as a
        non-terminating error and the remaining devices are still processed.
        Any other API/HTTP failure stops the command.

        Device value and tag changes can alter device group membership, and
        with it RBAC scope and policy targeting. Use -WhatIf to preview
        changes.
    .PARAMETER Id
        The ID of one or more devices. This is not the hostname, but the unique
        ID of the device in Defender.
    .PARAMETER DeviceValue
        The device value to set. Must be one of: High, Normal, Low
    .PARAMETER Tag
        One or more tags to apply to a device. Replaces all tags with the tags
        provided with the exception of tags set via registry keys.
    .PARAMETER PassThru
        Returns the updated device objects. Each device is returned once,
        reflecting its state after the device value was changed. By default
        nothing is returned.
    .EXAMPLE
        Set-XdrDevice -Id caab196872d62e639a7b7cdf8593601cf632b4eb -DeviceValue High

        Sets the device value to High for the given device.
    .EXAMPLE
        Get-XdrDevice -Query @{ '$filter' = "startsWith(computerDnsName, 'svr-dc')" } |
            Set-XdrDevice -DeviceValue High

        Sets the device value to High for every device whose name starts with
        svr-dc.
    .EXAMPLE
        Set-XdrDevice -Id $ids -Tags Windows11, admin

        Sets the tags for all the given device IDs to Windows11 and admin. If
        the device had other tags assigned they will be overwritten with the
        new value - unless those tags were set via registry key.
    .NOTES
        Requires the Machine.ReadWrite.All application permission.

        https://learn.microsoft.com/en-us/defender-endpoint/api/update-machine-method
        https://learn.microsoft.com/en-us/defender-endpoint/machine-tags
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

        [ValidateSet('Normal', 'Low', 'High')]
        [string] $DeviceValue,

        [string[]] $Tag,

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
            $whatIfMsg = @()
            $path = "machines/$device"
            $body = @{}

            if ($PSBoundParameters.ContainsKey('DeviceValue')) {
                $whatIfMsg += "Set value '$DeviceValue'"
                $body['deviceValue'] = $DeviceValue = [ValueEnum]::$DeviceValue
            }

            if ($PSBoundParameters.ContainsKey('Tag')) {
                $whatIfMsg += "Set tag '$($Tag -join ',')'"
                $body['machineTags'] = @($Tag)
            }

            if (-not $PSCmdlet.ShouldProcess($device, ($whatIfMsg -join '; '))) { continue }

            try {
                $result = Invoke-XdrApiRequest -Method PATCH -Path $path -Body $body

                if ($PassThru) {
                    $result
                }
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