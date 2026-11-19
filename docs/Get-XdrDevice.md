---
external help file: XDRHelper-help.xml
Module Name: XDRHelper
online version:
schema: 2.0.0
---

# Get-XdrDevice

## SYNOPSIS

Retrieves device information by Device ID or by OData 4 query.

## SYNTAX

### ById (Default)

```powershell
Get-XdrDevice -Id <String[]> [<CommonParameters>]
```

### ByOdata

```powershell
Get-XdrDevice -Query <Hashtable> [<CommonParameters>]
```

### AllMachines

```powershell
Get-XdrDevice [-All] [<CommonParameters>]
```

## DESCRIPTION

Retrieves a device or collection of devices that have communicated with
Microsoft Defender for Endpoint.

If provided a Id, a single object representing that device is
returned.

If provided a Query, the OData query results will be returned.

Supports OData V4 queries.
OData supported operators:

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

## EXAMPLES

### EXAMPLE 1

```powershell
Get-XdrDevice -DeviceId 01a1d27ac48972b18c57edc582c15c3caca0ab45
```

Returns a single device object.

### EXAMPLE 2

```powershell
Get-XdrDevice -Query @{ '$filter' = "startsWith(computerDnsName, 'svr')"}
```

Returns a collection of devices with a computerDnsName value starting
with 'svr'

### EXAMPLE 3

```powershell
Get-XdrDevice -All
```

Returns all devices.

## PARAMETERS

### -Id

The ID of a device.
This is not the hostname, but the unique ID of the
device in Defender.

```yaml
Type: String[]
Parameter Sets: ById
Aliases: DeviceId, MachineId, SenseMachineId

Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -Query

Hashtable representing an OData query in the form: @{ '$filter' = "healthStatus eq 'Active'"; '$top' = 10000 }

```yaml
Type: Hashtable
Parameter Sets: ByOdata
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -All

When provided, this switch will return all machines.

```yaml
Type: SwitchParameter
Parameter Sets: AllMachines
Aliases:

Required: True
Position: Named
Default value: False
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

For more examples see https://learn.microsoft.com/en-us/defender-endpoint/api/exposed-apis-odata-samples

## RELATED LINKS
