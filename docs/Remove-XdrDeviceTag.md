---
external help file: XDRHelper-help.xml
Module Name: XDRHelper
online version:
schema: 2.0.0
---

# Remove-XdrDeviceTag

## SYNOPSIS

Removes one or more tags from one or more devices.

## SYNTAX

```powershell
Remove-XdrDeviceTag [-Id] <String[]> [-Tag] <String[]> [-PassThru]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION

Removes tags from devices in Microsoft Defender for Endpoint.

Device IDs can be supplied directly or from the pipeline, including the
output of Get-XdrDevice.
All devices received are collected first, then
each tag is removed in as few API calls as possible: a single device
uses the per-device endpoint, several devices use the bulk endpoint in
batches of up to 500.

A device ID that does not exist in Defender is reported as a
non-terminating error and the remaining devices are still processed.
Any other API failure stops the command.

Only tags applied through the portal or the API can be removed.
Tags set
on the device itself (registry or MDM policy) are not affected.

Tag changes can alter device group membership, and with it RBAC scope
and policy targeting.
Use -WhatIf to preview.

## EXAMPLES

### EXAMPLE 1

```powershell
Remove-XdrDeviceTag -Id caab196872d62e639a7b7cdf8593601cf632b4eb -Tag 'Tier0'
```

Removes the tag Tier0 from a single device.

### EXAMPLE 2

```powershell
Get-XdrDevice -Query @{ '$filter' = "startsWith(computerDnsName, 'svr-det')" } |
    Remove-XdrDeviceTag -Tag 'Site-DET', 'Server'
```

Removes two tags from every device whose name starts with svr-det.

### EXAMPLE 3

```powershell
Remove-XdrDeviceTag -Id $ids -Tag 'Tier0' -WhatIf
```

Shows which devices would be changed without calling the API.

## PARAMETERS

### -Id

The ID of one or more devices.
This is not the hostname, but the unique
ID of the device in Defender.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases: DeviceId, MachineId, SenseMachineId

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -Tag

One or more tags to remove.
Duplicate values are sent once.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases: Tags

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PassThru

Returns the updated device objects.
Each device is returned once,
reflecting its state after the last tag was processed.
By default
nothing is returned.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf

Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm

Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable, -Verbose, -WarningAction, -WarningVariable, and -ProgressAction. 
For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Management.Automation.PSObject

## NOTES

Requires the Machine.ReadWrite.All application permission.

https://learn.microsoft.com/en-us/defender-endpoint/api/add-or-remove-machine-tags
https://learn.microsoft.com/en-us/defender-endpoint/api/add-or-remove-multiple-machine-tags

## RELATED LINKS
