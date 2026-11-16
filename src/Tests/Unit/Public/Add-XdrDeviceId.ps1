function Add-XdrDeviceTag {
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            ValueFromPipeline = $true)]
        [Alias('DeviceId', 'MachineId', 'SenseMachineId')]
        [ValidatePattern('^[0-9a-fA-F]{40}$')]
        [string[]] $Id,

        [string[]] $Tags
    )

    begin {
        if ($Id.Count -gt 1) {
            $multiMachine = $true
        }
    }

    process {
        # TODO: How does the API respond to adding a tag when
        # the device already has that tag?

        # TODO: The multi-machine endpoint has a limit of 500
        # Ids at one time, will need to slice the Ids array if
        # more than 500
        $path = "machines/$Id"

        foreach ($tag in $Tags) {
            $body = @{
                Value = "$tag"
                Action = "Add"
            }

            if ($multiMachine) {
                $path = 'machines/AddOrRemoveTagForMultipleMachines'
                $body['MachineIds'] = $Id
            }

            Invoke-XdrApiRequest -Method Post -Path $path -Body $body

        }
    }
}