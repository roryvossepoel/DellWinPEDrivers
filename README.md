# DellWinPEDrivers

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/DellWinPEDrivers?label=PowerShell%20Gallery)](https://www.powershellgallery.com/packages/DellWinPEDrivers)
[![CI](https://github.com/roryvossepoel/DellWinPEDrivers/actions/workflows/ci.yml/badge.svg)](https://github.com/roryvossepoel/DellWinPEDrivers/actions/workflows/ci.yml)

`DellWinPEDrivers` is a PowerShell module that discovers and downloads the current Dell Command | Deploy WinPE driver packs from Dell's official Driver Pack Catalog.

The module intentionally focuses on **repository discovery and download/extraction**. It does not inject drivers into a Windows PE image.

## Why

Dell publishes a machine-readable driver catalog at:

```text
https://downloads.dell.com/catalog/DriverPackCatalog.cab
```

The CAB contains `DriverPackCatalog.xml`, which includes metadata for both system driver packs and WinPE driver packs. Dell identifies WinPE packages with `type="WinPE"`.

This means the module does not need to scrape Dell support pages or maintain a static list of WinPE package URLs.

## How it works

1. Download Dell's official `DriverPackCatalog.cab`.
2. Extract `DriverPackCatalog.xml`.
3. Select packages where `type = WinPE`.
4. Read the operating-system architecture/version metadata published by Dell.
5. Build the package URL from the catalog `baseLocation` and package `path`.
6. Optionally download and extract the selected WinPE CAB.
7. Record the selected package in a small JSON metadata file.

## Commands

### Discover Dell WinPE driver packs

```powershell
Get-DellWinPEDriverPack
```

Filter to x64:

```powershell
Get-DellWinPEDriverPack -Architecture x64
```

Filter to the current WinPE 11 generation:

```powershell
Get-DellWinPEDriverPack -Architecture x64 -MajorVersion 10
```

> Dell currently represents WinPE applicability through the operating-system metadata in `DriverPackCatalog.xml`. The module exposes that metadata instead of maintaining its own version map.

### Download a driver pack

```powershell
Save-DellWinPEDriverPack `
    -Architecture x64 `
    -Path 'C:\WinPE\Dell'
```

By default, when multiple WinPE packages match the supplied filters, the newest package is selected by release date and Dell version.

Use `-PassThru` to return the resulting metadata object.

### Build a manifest without downloading the driver CAB

```powershell
New-DellWinPEManifest -Path '.\DellWinPE.Manifest.json'
```

This is useful for CI and for detecting upstream Dell catalog changes.

## Output

A successful save creates a package-specific folder containing the extracted Dell WinPE drivers and metadata:

```text
C:\WinPE\Dell\
└── WinPE-11-A10-x64\
    ├── ... extracted Dell driver folders ...
    └── .dellwinpe.json
```

The exact folder name is derived from Dell's current package metadata.

## Dell sources

The module uses Dell-maintained sources at runtime:

- [Dell Command | Deploy WinPE Driver Packs](https://www.dell.com/support/kbdoc/en-us/000107478/dell-command-deploy-winpe-driver-packs)
- [Dell Command | Deploy Driver Pack Catalog](https://www.dell.com/support/kbdoc/en-us/000122176/driver-pack-catalog)
- `https://downloads.dell.com/catalog/DriverPackCatalog.cab`

Dell documents `DriverPackCatalog.xml` as the machine-readable catalog for current System and WinPE driver packs and recommends using the package `type`, `SupportedOperatingSystems`, `baseLocation`, and `path` metadata for automated discovery.

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- Windows for CAB extraction through `expand.exe`
- Internet access to `downloads.dell.com`

`Get-DellWinPEDriverPack` and `New-DellWinPEManifest` can also parse a previously extracted local `DriverPackCatalog.xml` by using `-CatalogPath`.

## CI

The repository includes:

- module import validation on Windows PowerShell 5.1 and PowerShell 7;
- Pester tests for catalog parsing, filtering, URL construction, and selection;
- a weekly live catalog smoke test against Dell's current `DriverPackCatalog.cab`.

## Scope

This project does **not**:

- inject drivers into boot.wim or winre.wim;
- maintain model-specific full Windows driver packs;
- scrape Dell support pages for package URLs;
- replace Dell Command | Deploy.

Its job is deliberately small: reliably discover and obtain Dell's current WinPE driver packs.

## License

MIT
