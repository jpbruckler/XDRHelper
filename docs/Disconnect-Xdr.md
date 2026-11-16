---
external help file: XDRHelper-help.xml
Module Name: XDRHelper
online version:
schema: 2.0.0
---

# Disconnect-Xdr

## SYNOPSIS

Removes authentication token from local memory.

## SYNTAX

```powershell
Disconnect-Xdr [<CommonParameters>]
```

## DESCRIPTION

Microsoft does not provide a disconnect method, client credentials
will stay active for about an hour.
Disconnect is local only.

## EXAMPLES

### EXAMPLE 1

```powershell
Disconnect-Xdr
```

## PARAMETERS

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable, -Verbose, -WarningAction, -WarningVariable, and -ProgressAction. 
For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
