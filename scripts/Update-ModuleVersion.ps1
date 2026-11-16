[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ManifestPath = Join-Path $PSScriptRoot '..' 'src' 'XDRHelper' 'XDRHelper.psd1'
$Version = $env:CZ_PRE_NEW_VERSION

if ([string]::IsNullOrWhiteSpace($Version)) {
    throw 'CZ_PRE_NEW_VERSION was not provided by Commitizen.'
}



Write-Host "Updating XDRHelper module version to $Version"

Update-ModuleManifest `
    -Path $ManifestPath `
    -ModuleVersion $Version