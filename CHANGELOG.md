## v0.1.1 (2026-11-16)

### Fix

- **XDRHelper.psd1**: remove internal references
- **XDRHelper.psd1**: remove internal references

## v0.1.0 (2026-11-16)

### Feat

- **Remove-XdrDeviceTag**: add ability to remove device tags
- **Add-XdrDeviceTag**: add ability to apply device tags
- **Disconnect-Xdr**: add function to clean up connection info locally
- **device**: add Get-XdrDevice to retrieve device information from Defender
- **api**: add private module functions for interacting with Defender api
- **auth**: Add functions for authenticating to Defender XDR API

### Fix

- **Get-XdrDevice**: improper retry and exception message handling

### Refactor

- **Connect-XdrByAppId**: change AppId and TenantId input params to [guid] type
- **Assert-XdrAuthentication**: fix typos and incorrect example in comments
- **auth**: Adjust behavior of Assert-XdrAuthentication to only throw or return null
