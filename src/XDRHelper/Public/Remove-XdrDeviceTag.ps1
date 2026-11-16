function Remove-XdrDeviceTag {
    <#
    .SYNOPSIS
        Removes one or more tags from one or more devices.
    .DESCRIPTION
        Removes tags from devices in Microsoft Defender for Endpoint.

        Device IDs can be supplied directly or from the pipeline, including the
        output of Get-XdrDevice. All devices received are collected first, then
        each tag is removed in as few API calls as possible: a single device
        uses the per-device endpoint, several devices use the bulk endpoint in
        batches of up to 500.

        A device ID that does not exist in Defender is reported as a
        non-terminating error and the remaining devices are still processed.
        Any other API failure stops the command.

        Only tags applied through the portal or the API can be removed. Tags set
        on the device itself (registry or MDM policy) are not affected.

        Tag changes can alter device group membership, and with it RBAC scope
        and policy targeting. Use -WhatIf to preview.
    .PARAMETER Id
        The ID of one or more devices. This is not the hostname, but the unique
        ID of the device in Defender.
    .PARAMETER Tag
        One or more tags to remove. Duplicate values are sent once.
    .PARAMETER PassThru
        Returns the updated device objects. Each device is returned once,
        reflecting its state after the last tag was processed. By default
        nothing is returned.
    .EXAMPLE
        Remove-XdrDeviceTag -Id caab196872d62e639a7b7cdf8593601cf632b4eb -Tag 'Tier0'

        Removes the tag Tier0 from a single device.
    .EXAMPLE
        Get-XdrDevice -Query @{ '$filter' = "startsWith(computerDnsName, 'svr-det')" } |
            Remove-XdrDeviceTag -Tag 'Site-DET', 'Server'

        Removes two tags from every device whose name starts with svr-det.
    .EXAMPLE
        Remove-XdrDeviceTag -Id $ids -Tag 'Tier0' -WhatIf

        Shows which devices would be changed without calling the API.
    .NOTES
        Requires the Machine.ReadWrite.All application permission.

        https://learn.microsoft.com/en-us/defender-endpoint/api/add-or-remove-machine-tags
        https://learn.microsoft.com/en-us/defender-endpoint/api/add-or-remove-multiple-machine-tags
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
        [Alias('Tags')]
        [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) },
            ErrorMessage = 'A tag cannot be empty or whitespace.')]
        [string[]] $Tag,

        [switch] $PassThru
    )

    begin {
        Assert-XdrAuthentication

        # Collected across the whole pipeline so the bulk endpoint can be used.
        $deviceIds = [System.Collections.Generic.List[string]]::new()
        $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    }

    process {
        foreach ($device in $Id) {
            if ($seen.Add($device)) { $deviceIds.Add($device) }
        }
    }

    end {
        if ($deviceIds.Count -eq 0) { return }

        $target = if ($deviceIds.Count -eq 1) { "device $($deviceIds[0])" } else { "$($deviceIds.Count) devices" }
        $updated = [ordered]@{}

        foreach ($value in ($Tag | Select-Object -Unique)) {
            if (-not $PSCmdlet.ShouldProcess($target, "Remove tag '$value'")) { continue }

            $result = Invoke-XdrDeviceTagRequest -Action 'Remove' -Tag $value -Id $deviceIds
            if (-not $PassThru) { continue }

            # Keep only the most recent copy of each device; earlier copies are missing later tags.
            foreach ($item in $result) {
                if ($item.id) { $updated[[string]$item.id] = $item }
                else { $item }
            }
        }

        if ($PassThru) { $updated.Values }
    }
}
