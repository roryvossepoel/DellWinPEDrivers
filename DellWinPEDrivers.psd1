@{
    RootModule        = 'DellWinPEDrivers.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '50bd3f75-d8dc-48d1-8794-4657c9dc5f7d'
    Author            = 'Rory Vossepoel'
    CompanyName       = ''
    Copyright         = '(c) Rory Vossepoel. All rights reserved.'
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
            Tags       = @('Dell', 'WinPE', 'Drivers', 'Deployment', 'OSD', 'DellCommandDeploy')
            LicenseUri = 'https://github.com/roryvossepoel/DellWinPEDrivers/blob/main/LICENSE'
            ProjectUri = 'https://github.com/roryvossepoel/DellWinPEDrivers'
        }
    }
}
