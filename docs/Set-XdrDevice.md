---
external help file: XDRHelper-help.xml
Module Name: XDRHelper
online version:
schema: 2.0.0
---

# Set-XdrDevice

## SYNOPSIS

Sets a device's Value or Tag collection.

## SYNTAX

```powershell
Set-XdrDevice [-Id] <String[]> [[-DeviceValue] <String>] [[-Tag] <String[]>] [-PassThru]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION

Set the DeviceValue or Tag collection for one or more devices.
When
setting tags with this cmdlet, the existing tag collection will be
replaced by the collection provided in -Tag.
If you just want to append
one or more tags, use Add-XdrDeviceTag instead.

Device IDs can be supplied directly or from the pipeline, including
the output of Get-XdrDevice.

A device ID that does not exist in Defender is reported as a
non-terminating error and the remaining devices are still processed.
Any other API/HTTP failure stops the command.

Device value and tag changes can alter device group membership, and
with it RBAC scope and policy targeting.
Use -WhatIf to preview
changes.

## EXAMPLES

### EXAMPLE 1

```powershell
Set-XdrDevice -Id caab196872d62e639a7b7cdf8593601cf632b4eb -DeviceValue High
```

Sets the device value to High for the given device.

### EXAMPLE 2

```powershell
Get-XdrDevice -Query @{ '$filter' = "startsWith(computerDnsName, 'svr-dc')" } |
    Set-XdrDevice -DeviceValue High
```

Sets the device value to High for every device whose name starts with
svr-dc.

### EXAMPLE 3

```powershell
Set-XdrDevice -Id $ids -Tags Windows11, admin
```

Sets the tags for all the given device IDs to Windows11 and admin.
If
the device had other tags assigned they will be overwritten with the
new value - unless those tags were set via registry key.

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

### -DeviceValue

The device value to set.
Must be one of: High, Normal, Low

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Tag

One or more tags to apply to a device.
Replaces all tags with the tags
provided with the exception of tags set via registry keys.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PassThru

Returns the updated device objects.
Each device is returned once,
reflecting its state after the device value was changed.
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

https://learn.microsoft.com/en-us/defender-endpoint/api/update-machine-method
https://learn.microsoft.com/en-us/defender-endpoint/machine-tags

## RELATED LINKS
