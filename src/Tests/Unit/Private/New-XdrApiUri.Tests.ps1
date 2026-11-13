BeforeDiscovery {
    Set-Location -Path $PSScriptRoot
    $ModuleName = 'XDRHelper'
    $PathToManifest = [System.IO.Path]::Combine('..', '..', '..', $ModuleName, "$ModuleName.psd1")
    #if the module is already in memory, remove it
    Get-Module $ModuleName -ErrorAction SilentlyContinue | Remove-Module -Force
    Import-Module $PathToManifest -Force
}

InModuleScope 'XDRHelper' {
    Describe 'New-XdrApiUri private function tests' {
        Context 'correctly handles plain paths' {
            It 'properly makes boring paths - <Path>' -ForEach @(
                @{ Path = 'machines' },
                @{ Path = 'machines/caab196872d62e639a7b7cdf8593601cf632b4eb' },
                @{ Path = 'vulnerabilities/CVE-2019-0608' }
            ) {
                New-XdrApiUri -Path $Path | Should-Be "https://api.security.microsoft.com/api/$Path"
            }

            It 'rejects malformed paths - (<Path>)' -ForEach @(
                @{ Path = "machines?`$filter=healthStates eq 'Active'"; Message = "Path must not contain '?', '#' or '\'; use -Query." },
                @{ Path = '.'; Message = "Path must not contain '.' or '..' segments." },
                @{ Path = '..'; Message = "Path must not contain '.' or '..' segments." },
                @{ Path = 'api/vulnerabilities'; Message = "Path is relative to the API base; drop the 'api/' prefix." },
                @{ Path = '/'; Message = 'Path is empty.' }
            ) {
                { New-XdrApiUri -Path $Path } | Should-Throw -ExceptionMessage "Cannot validate argument on parameter 'Path'. $Message"
            }
        }
    }
}