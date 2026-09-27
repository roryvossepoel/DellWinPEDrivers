@{
    RootModule        = 'DellWinPEDrivers.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '50bd3f75-d8dc-48d1-8794-4657c9dc5f7d'
    Author            = 'Rory Vossepoel'
    CompanyName       = ''
    Copyright         = '(c) 2026 Rory Vossepoel. Licensed under the MIT License.'
    Description       = 'Discovers and downloads Dell Command | Deploy WinPE driver packs from Dell''s official Driver Pack Catalog.'
    PowerShellVersion = '5.1'

    FunctionsToExport = @(
        'Get-DellWinPEDriverPack'
        'Save-DellWinPEDriverPack'
        'New-DellWinPEManifest'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags       = @('Dell', 'WinPE', 'Drivers', 'Deployment', 'OSD', 'DellCommandDeploy', 'WindowsPE', 'Automation')
            LicenseUri = 'https://github.com/roryvossepoel/DellWinPEDrivers/blob/main/LICENSE'
            ProjectUri = 'https://github.com/roryvossepoel/DellWinPEDrivers'
            ReleaseNotes = 'Initial stable release. Discovers Dell WinPE driver packs from DriverPackCatalog.cab, supports explicit WinPE version filtering, manifest generation, download/extraction, and PowerShell 5.1/7.'
        }
    }
}
