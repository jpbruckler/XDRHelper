---
external help file: XDRHelper-help.xml
Module Name: XDRHelper
online version:
schema: 2.0.0
---

# Assert-XdrAuthentication

## SYNOPSIS

Asserts valid authentication information exists for Defender.

## SYNTAX

```powershell
Assert-XdrAuthentication [<CommonParameters>]
```

## DESCRIPTION

Checks for the existence of stored Defender XDR authentication.

If no stored Defender XDR authentication is found, an eexception is
thrown.

If authentication is found it will check to see if the token is going
to expire within the next 5 minutes and will attempt re-authentication
if so.
If re-authentication fails, an exception is thrown.

## EXAMPLES

### EXAMPLE 1

```powershell
try {
    Assert-XdrAuthentication
    Get-XdrDevice -DeviceId 01a1d27ac48972b18c57edc582c15c3caca0ab45
}
catch {
    # handle your error....
}
```

Checks that authentication exists and is current before retrieving
device information.
Throws if no authentication exists from a Connect-Xdr*
command, or if re-authentication fails.

## PARAMETERS

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable, -Verbose, -WarningAction, -WarningVariable, and -ProgressAction. 
For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
