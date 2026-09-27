[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path $PSScriptRoot 'out')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$moduleName = 'DellWinPEDrivers'
$modulePath = Join-Path $OutputPath $moduleName

if (Test-Path -LiteralPath $modulePath) {
    Remove-Item -LiteralPath $modulePath -Recurse -Force
}
New-Item -ItemType Directory -Path $modulePath -Force | Out-Null

Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'DellWinPEDrivers.psd1') -Destination $modulePath
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'DellWinPEDrivers.psm1') -Destination $modulePath

foreach ($optionalFile in @('README.md', 'LICENSE')) {
    $source = Join-Path $PSScriptRoot $optionalFile
    if (Test-Path -LiteralPath $source) {
        Copy-Item -LiteralPath $source -Destination $modulePath
    }
}

$manifestPath = Join-Path $modulePath 'DellWinPEDrivers.psd1'
$manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop

[pscustomobject]@{
    ModuleName    = $manifest.Name
    ModuleVersion = $manifest.Version.ToString()
    Path          = $modulePath
}
