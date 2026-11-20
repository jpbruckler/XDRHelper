---
external help file: XDRHelper-help.xml
Module Name: XDRHelper
online version:
schema: 2.0.0
---

# Connect-XdrByAppId

## SYNOPSIS

Authenticates to Microsoft Defender XDR using an AppID and App secret.

## SYNTAX

### Credential

```powershell
Connect-XdrByAppId -Credential <PSCredential> -TenantId <Guid>
 [<CommonParameters>]
```

### AppId

```powershell
Connect-XdrByAppId -AppId <Guid> -AppSecret <SecureString> -TenantId <Guid>
 [<CommonParameters>]
```

## DESCRIPTION

Performs an OAuth client credential flow with the provided app registration ID and secret.
Authentication token is cached locally for use with subsequent calls to this module's
functions.

## EXAMPLES

### EXAMPLE 1

```powershell
$AppId = '11111111-1111-1111-1111-111111111111'
$TenantId = '22222222-2222-2222-2222-222222222222'
$AppSecret = ConvertTo-SecureString 'FakeSecret' -AsPlainText -Force
Connect-XdrByAppId -AppId $AppId -AppSecret $AppSecret -TenantId $TenantId
```

Authenticates to Entra and stores the returned JWT token for future use.

## PARAMETERS

### -Credential

A credential object representing an Entra App registration and client secret.

```yaml
Type: PSCredential
Parameter Sets: Credential
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -AppId

The application ID for an Entra App Registration.

```yaml
Type: Guid
Parameter Sets: AppId
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -AppSecret

The client secret for an Entra App Registration as a SecureString.

```yaml
Type: SecureString
Parameter Sets: AppId
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -TenantId

The ID of the Entra tenant to authenticate against.

```yaml
Type: Guid
Parameter Sets: (All)
Aliases:

Required: True
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

## NOTES

## RELATED LINKS
