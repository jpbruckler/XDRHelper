function Invoke-XdrDeviceTagRequest {
    <#
    .SYNOPSIS
        Adds or removes a single tag on one or more devices.
    .DESCRIPTION
        Shared worker for Add-XdrDeviceTag and Remove-XdrDeviceTag.

        One device is sent to machines/{id}/tags. Several devices are sent to
        machines/AddOrRemoveTagForMultipleMachines in batches, because that
        endpoint accepts at most 500 devices per call.

        If a batch is rejected with HTTP 400 or 404 it is replayed one device
        at a time, so that a single bad device ID does not stop the rest from
        being tagged and the error names the device that caused it.

        A device that does not exist (HTTP 404) is reported as a
        non-terminating error. Any other failure terminates.
    .PARAMETER Action
        Add or Remove.
    .PARAMETER Tag
        The tag to add or remove.
    .PARAMETER Id
        One or more device IDs.
    .PARAMETER BatchSize
        Maximum number of devices per bulk request. The API limit is 500.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Add', 'Remove')]
        [string] $Action,

        [Parameter(Mandatory)]
        [string] $Tag,

        [Parameter(Mandatory)]
        [string[]] $Id,

        [ValidateRange(1, 500)]
        [int] $BatchSize = 500
    )

    # Body keys are case-sensitive on the API side.
    $sendSingle = {
        param([string] $deviceId)
        try {
            Invoke-XdrApiRequest -Method 'POST' -Path "machines/$deviceId/tags" -Body ([ordered]@{
                    Value  = $Tag
                    Action = $Action
                })
        }
        catch {
            # Continue on 404 (no such device), throw on anything else.
            if ($_.Exception.Data['StatusCode'] -ne 404) { throw }

            # preserve the output of New-XdrApiErrorRecord
            $PSCmdlet.WriteError($_)
        }
    }

    for ($offset = 0; $offset -lt $Id.Count; $offset += $BatchSize) {
        $last = [math]::Min($offset + $BatchSize, $Id.Count) - 1
        $batch = @($Id[$offset..$last])

        if ($batch.Count -eq 1) {
            & $sendSingle $batch[0]
            continue
        }

        try {
            Invoke-XdrApiRequest -Method 'POST' -Path 'machines/AddOrRemoveTagForMultipleMachines' -Body ([ordered]@{
                    Value      = $Tag
                    Action     = $Action
                    MachineIds = $batch
                })
        }
        catch {
            # The bulk endpoint is all-or-nothing. A 400/404 may be down to one device in
            # the batch, so find out which by replaying the batch one device at a time.
            if ($_.Exception.Data['StatusCode'] -notin 400, 404) { throw }

            Write-Verbose "Bulk $Action of tag '$Tag' was rejected ($($_.Exception.Message)). Retrying $($batch.Count) devices individually."
            foreach ($deviceId in $batch) { & $sendSingle $deviceId }
        }
    }
}
