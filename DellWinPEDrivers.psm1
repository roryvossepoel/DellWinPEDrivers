Set-StrictMode -Version Latest

$script:DellCatalogUrl = 'https://downloads.dell.com/catalog/DriverPackCatalog.cab'

function Test-DellWindows {
    [CmdletBinding()]
    param()

    if ($PSVersionTable.PSVersion.Major -lt 6) {
        return $true
    }

    return [bool]$IsWindows
}

function Get-DellCatalogDocument {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string] $CatalogPath
    )

    if ($CatalogPath) {
        if (-not (Test-Path -LiteralPath $CatalogPath -PathType Leaf)) {
            throw "CatalogPath '$CatalogPath' does not exist."
        }

        if ([System.IO.Path]::GetExtension($CatalogPath) -ieq '.xml') {
            [System.Xml.XmlDocument] $document = New-Object System.Xml.XmlDocument
            $document.Load($CatalogPath)
            return ,$document
        }

        throw "CatalogPath must point to an extracted DriverPackCatalog.xml file."
    }

    if (-not (Test-DellWindows)) {
        throw 'Downloading Dell''s CAB catalog requires Windows because expand.exe is used to extract DriverPackCatalog.xml. Supply -CatalogPath with an extracted XML file on non-Windows systems.'
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('DellWinPEDrivers-' + [guid]::NewGuid().ToString('N'))
    $cabPath = Join-Path $tempRoot 'DriverPackCatalog.cab'
    $xmlPath = Join-Path $tempRoot 'DriverPackCatalog.xml'

    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

    try {
        $null = Invoke-WebRequest -Uri $script:DellCatalogUrl -OutFile $cabPath -UseBasicParsing

        $expand = Join-Path $env:SystemRoot 'System32\expand.exe'
        if (-not (Test-Path -LiteralPath $expand)) {
            throw 'expand.exe was not found.'
        }

        & $expand $cabPath $xmlPath | Out-Null
        $expandExitCode = $LASTEXITCODE
        if ($expandExitCode -ne 0 -or -not (Test-Path -LiteralPath $xmlPath)) {
            throw "Failed to extract DriverPackCatalog.xml from Dell catalog CAB. expand.exe exit code: $expandExitCode"
        }

        [System.Xml.XmlDocument] $document = New-Object System.Xml.XmlDocument
        $document.Load($xmlPath)
        return ,$document
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function ConvertFrom-DellWinPEPackageNode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlElement] $Node,

        [Parameter(Mandatory)]
        [string] $BaseLocation
    )

    $operatingSystems = @($Node.SelectNodes("./*[local-name()='SupportedOperatingSystems']/*[local-name()='OperatingSystem']"))
    if ($operatingSystems.Count -eq 0) {
        $operatingSystems = @($null)
    }

    $displayName = $null
    $displayNodes = @($Node.SelectNodes("./*[local-name()='Name']/*[local-name()='Display']"))
    if ($displayNodes.Count -gt 0) {
        $display = $displayNodes | Where-Object { $_.GetAttribute('lang') -eq 'en' } | Select-Object -First 1
        if (-not $display) {
            $display = $displayNodes | Select-Object -First 1
        }
        if ($display) {
            $displayName = [string]$display.InnerText
        }
    }

    $releaseDate = $null
    $dateTimeValue = [string]$Node.GetAttribute('dateTime')
    if ($dateTimeValue) {
        [datetime]$parsedDate = [datetime]::MinValue
        if ([datetime]::TryParse($dateTimeValue, [ref]$parsedDate)) {
            $releaseDate = $parsedDate
        }
    }

    $packagePath = ([string]$Node.GetAttribute('path')).TrimStart('/')
    $base = $BaseLocation.Trim().TrimEnd('/')
    if ($base -notmatch '^https?://') {
        $base = 'https://' + $base
    }
    $downloadUrl = if ($packagePath) { "$base/$packagePath" } else { $null }

    $winPEVersion = $null
    $versionSource = if ($displayName) { $displayName } else { [string]$Node.GetAttribute('path') }
    if ($versionSource -match '(?i)WinPE(?<Version>\d+(?:\.\d+)?)') {
        $winPEVersion = $Matches.Version
    }

    foreach ($os in $operatingSystems) {
        [pscustomobject]@{
            PSTypeName      = 'DellWinPEDrivers.Package'
            Name            = $displayName
            Type            = [string]$Node.GetAttribute('type')
            WinPEVersion    = $winPEVersion
            DellVersion     = [string]$Node.GetAttribute('dellVersion')
            ReleaseId       = [string]$Node.GetAttribute('releaseID')
            ReleaseDate     = $releaseDate
            Path            = [string]$Node.GetAttribute('path')
            DownloadUrl     = $downloadUrl
            Architecture    = if ($os) { [string]$os.GetAttribute('osArch') } else { $null }
            OSVendor        = if ($os) { [string]$os.GetAttribute('osVendor') } else { $null }
            MajorVersion    = if ($os) { [string]$os.GetAttribute('majorVersion') } else { $null }
            MinorVersion    = if ($os) { [string]$os.GetAttribute('minorVersion') } else { $null }
            SPMajorVersion  = if ($os) { [string]$os.GetAttribute('spMajorVersion') } else { $null }
            SPMinorVersion  = if ($os) { [string]$os.GetAttribute('spMinorVersion') } else { $null }
        }
    }
}

function Get-DellWinPEDriverPack {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('x64', 'x86')]
        [string] $Architecture,

        [Parameter()]
        [string] $WinPEVersion,

        [Parameter()]
        [string] $MajorVersion,

        [Parameter()]
        [string] $MinorVersion,

        [Parameter()]
        [string] $CatalogPath
    )

    $catalog = Get-DellCatalogDocument -CatalogPath $CatalogPath

    if ($catalog -is [System.Xml.XmlDocument]) {
        $manifest = $catalog.DocumentElement
    }
    elseif ($catalog -is [System.Xml.XmlElement]) {
        $manifest = $catalog
    }
    else {
        throw "Unexpected Dell catalog object type: $($catalog.GetType().FullName)"
    }

    if (-not $manifest -or $manifest.LocalName -ne 'DriverPackManifest') {
        throw 'The supplied XML is not a Dell DriverPackCatalog document.'
    }

    $baseLocation = [string]$manifest.GetAttribute('baseLocation')
    if ([string]::IsNullOrWhiteSpace($baseLocation)) {
        throw 'Dell catalog does not contain DriverPackManifest.baseLocation.'
    }

    $packageNodes = @($manifest.SelectNodes("./*[local-name()='DriverPackage']"))

    $packages = foreach ($node in $packageNodes) {
        if ([string]$node.GetAttribute('type') -ine 'WinPE') {
            continue
        }

        ConvertFrom-DellWinPEPackageNode -Node $node -BaseLocation $baseLocation
    }

    if ($Architecture) {
        $packages = @($packages | Where-Object Architecture -EQ $Architecture)
    }
    if ($WinPEVersion) {
        $packages = @($packages | Where-Object WinPEVersion -EQ $WinPEVersion)
    }
    if ($MajorVersion) {
        $packages = @($packages | Where-Object MajorVersion -EQ $MajorVersion)
    }
    if ($MinorVersion) {
        $packages = @($packages | Where-Object MinorVersion -EQ $MinorVersion)
    }

    $packages | Sort-Object ReleaseDate, DellVersion -Descending
}

function Select-DellWinPEDriverPack {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]] $Package
    )

    $candidate = @($Package | Sort-Object ReleaseDate, DellVersion -Descending | Select-Object -First 1)
    if ($candidate.Count -eq 0) {
        throw 'No Dell WinPE driver pack matched the supplied filters.'
    }

    $candidate[0]
}

function New-DellWinPEManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter()]
        [ValidateSet('x64', 'x86')]
        [string] $Architecture,

        [Parameter()]
        [string] $WinPEVersion,

        [Parameter()]
        [string] $MajorVersion,

        [Parameter()]
        [string] $MinorVersion,

        [Parameter()]
        [string] $CatalogPath
    )

    $getParams = @{}
    if ($PSBoundParameters.ContainsKey('Architecture')) { $getParams.Architecture = $Architecture }
    if ($PSBoundParameters.ContainsKey('WinPEVersion')) { $getParams.WinPEVersion = $WinPEVersion }
    if ($PSBoundParameters.ContainsKey('MajorVersion')) { $getParams.MajorVersion = $MajorVersion }
    if ($PSBoundParameters.ContainsKey('MinorVersion')) { $getParams.MinorVersion = $MinorVersion }
    if ($PSBoundParameters.ContainsKey('CatalogPath')) { $getParams.CatalogPath = $CatalogPath }

    $packages = @(Get-DellWinPEDriverPack @getParams -ErrorAction Stop)

    $manifest = [ordered]@{
        SchemaVersion = 1
        GeneratedAtUtc = [datetime]::UtcNow.ToString('o')
        Manufacturer = 'Dell'
        CatalogUrl = $script:DellCatalogUrl
        Packages = @($packages | ForEach-Object {
            [ordered]@{
                Name = $_.Name
                Type = $_.Type
                WinPEVersion = $_.WinPEVersion
                DellVersion = $_.DellVersion
                ReleaseId = $_.ReleaseId
                ReleaseDate = if ($_.ReleaseDate) { $_.ReleaseDate.ToString('o') } else { $null }
                Architecture = $_.Architecture
                MajorVersion = $_.MajorVersion
                MinorVersion = $_.MinorVersion
                DownloadUrl = $_.DownloadUrl
                Path = $_.Path
            }
        })
    }

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $Path -Encoding UTF8
    Get-Item -LiteralPath $Path
}

function Save-DellWinPEDriverPack {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter()]
        [ValidateSet('x64', 'x86')]
        [string] $Architecture = 'x64',

        [Parameter()]
        [string] $WinPEVersion,

        [Parameter()]
        [string] $MajorVersion,

        [Parameter()]
        [string] $MinorVersion,

        [Parameter()]
        [string] $CatalogPath,

        [Parameter()]
        [switch] $Force,

        [Parameter()]
        [switch] $PassThru
    )

    if (-not $IsWindows -and $PSVersionTable.PSVersion.Major -ge 6) {
        throw 'Save-DellWinPEDriverPack requires Windows because Dell driver CABs are extracted with expand.exe.'
    }

    $getParams = @{
        Architecture = $Architecture
    }
    if ($PSBoundParameters.ContainsKey('WinPEVersion')) { $getParams.WinPEVersion = $WinPEVersion }
    if ($PSBoundParameters.ContainsKey('MajorVersion')) { $getParams.MajorVersion = $MajorVersion }
    if ($PSBoundParameters.ContainsKey('MinorVersion')) { $getParams.MinorVersion = $MinorVersion }
    if ($PSBoundParameters.ContainsKey('CatalogPath')) { $getParams.CatalogPath = $CatalogPath }

    $packages = @(Get-DellWinPEDriverPack @getParams -ErrorAction Stop)
    $selected = Select-DellWinPEDriverPack -Package $packages

    if ([string]::IsNullOrWhiteSpace($selected.DownloadUrl)) {
        throw 'Selected Dell WinPE driver pack does not contain a download URL.'
    }

    $safeName = @(
        'WinPE'
        if ($selected.WinPEVersion) { $selected.WinPEVersion }
        if ($selected.DellVersion) { $selected.DellVersion }
        if ($selected.Architecture) { $selected.Architecture }
    ) -join '-'
    $safeName = $safeName -replace '[^A-Za-z0-9._-]', '_'

    $destination = Join-Path $Path $safeName
    $metadataPath = Join-Path $destination '.dellwinpe.json'

    if ((Test-Path -LiteralPath $metadataPath) -and -not $Force) {
        $existing = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
        if ($existing.ReleaseId -eq $selected.ReleaseId -and $existing.DellVersion -eq $selected.DellVersion) {
            if ($PassThru) {
                return [pscustomobject]@{
                    Status = 'Current'
                    Path = $destination
                    Package = $selected
                }
            }
            return
        }
    }

    if (-not $PSCmdlet.ShouldProcess($destination, "Download and extract Dell WinPE driver pack $($selected.DellVersion)")) {
        return
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('DellWinPEDrivers-' + [guid]::NewGuid().ToString('N'))
    $cabPath = Join-Path $tempRoot ([System.IO.Path]::GetFileName(([uri]$selected.DownloadUrl).AbsolutePath))

    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

    try {
        $null = Invoke-WebRequest -Uri $selected.DownloadUrl -OutFile $cabPath -UseBasicParsing

        if (Test-Path -LiteralPath $destination) {
            if ($Force) {
                Remove-Item -LiteralPath $destination -Recurse -Force
            }
            else {
                throw "Destination '$destination' already exists. Use -Force to rebuild it."
            }
        }

        New-Item -ItemType Directory -Path $destination -Force | Out-Null

        $expand = Join-Path $env:SystemRoot 'System32\expand.exe'
        if (-not (Test-Path -LiteralPath $expand)) {
            throw 'expand.exe was not found.'
        }

        & $expand $cabPath '-F:*' $destination | Out-Null
        $expandExitCode = $LASTEXITCODE
        if ($expandExitCode -ne 0) {
            throw "Failed to extract Dell WinPE driver CAB. expand.exe exit code: $expandExitCode"
        }

        $metadata = [ordered]@{
            SchemaVersion = 1
            Manufacturer = 'Dell'
            Name = $selected.Name
            WinPEVersion = $selected.WinPEVersion
            DellVersion = $selected.DellVersion
            ReleaseId = $selected.ReleaseId
            ReleaseDate = if ($selected.ReleaseDate) { $selected.ReleaseDate.ToString('o') } else { $null }
            Architecture = $selected.Architecture
            MajorVersion = $selected.MajorVersion
            MinorVersion = $selected.MinorVersion
            DownloadUrl = $selected.DownloadUrl
            SourceCatalog = $script:DellCatalogUrl
            SavedAtUtc = [datetime]::UtcNow.ToString('o')
        }

        $metadata | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $metadataPath -Encoding UTF8

        if ($PassThru) {
            [pscustomobject]@{
                Status = 'Saved'
                Path = $destination
                Package = $selected
            }
        }
    }
    catch {
        if (Test-Path -LiteralPath $destination) {
            Remove-Item -LiteralPath $destination -Recurse -Force -ErrorAction SilentlyContinue
        }
        throw
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Export-ModuleMember -Function @(
    'Get-DellWinPEDriverPack'
    'Save-DellWinPEDriverPack'
    'New-DellWinPEManifest'
)
