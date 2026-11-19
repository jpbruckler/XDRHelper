# Bootstrap build dependencies for CI (GitHub Actions).
# Invoked by .github/workflows/wf_Windows_Core.yml before Invoke-Build runs.
# Keep the versions here in sync with what src/XDRHelper.build.ps1 expects.

$ErrorActionPreference = 'Stop'

# https://learn.microsoft.com/powershell/module/packagemanagement/get-packageprovider
Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null

# https://learn.microsoft.com/powershell/module/powershellget/set-psrepository
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

# Modules required by the build.
#   MinimumVersion/MaximumVersion = a version range; RequiredVersion = an exact pin.
$modulesToInstall = @(
    # https://github.com/pester/Pester  (build file requires 6.x)
    @{ Name = 'Pester';           MinimumVersion = '6.2.0'; MaximumVersion = '6.99.99' }
    # https://github.com/nightroman/Invoke-Build
    @{ Name = 'InvokeBuild';      MinimumVersion = '5.0.0' }
    # https://github.com/PowerShell/PSScriptAnalyzer
    @{ Name = 'PSScriptAnalyzer'; MinimumVersion = '1.21.0' }
    # https://github.com/PowerShell/platyPS  (build file imports exactly 0.12.0)
    @{ Name = 'platyPS';          RequiredVersion = '0.12.0' }
)

'Installing PowerShell Modules'
foreach ($module in $modulesToInstall) {
    $installSplat = $module.Clone()
    $installSplat.Repository         = 'PSGallery'
    $installSplat.SkipPublisherCheck = $true   # Windows ships an old, differently-signed Pester
    $installSplat.Force              = $true
    $installSplat.AllowClobber       = $true
    try {
        Install-Module @installSplat
        '  - Successfully installed {0}' -f $module.Name
    }
    catch {
        '  - Failed to install {0}' -f $module.Name
        throw
    }
}
