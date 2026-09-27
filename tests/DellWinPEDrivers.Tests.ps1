BeforeAll {
    Import-Module "$PSScriptRoot/../DellWinPEDrivers.psd1" -Force

    $script:CatalogPath = Join-Path $TestDrive 'DriverPackCatalog.xml'
    @'
<?xml version="1.0" encoding="utf-8"?>
<DriverPackManifest baseLocation="downloads.dell.com">
  <DriverPackage type="WinPE" dellVersion="A10" releaseID="XCXDW" path="FOLDER/WinPE11.cab" dateTime="2026-05-29T00:00:00">
    <Name><Display lang="en">Dell Command | Deploy WinPE 11.0 Driver Pack</Display></Name>
    <SupportedOperatingSystems>
      <OperatingSystem osVendor="Microsoft" osArch="x64" majorVersion="10" minorVersion="0" spMajorVersion="0" spMinorVersion="0" />
    </SupportedOperatingSystems>
  </DriverPackage>
  <DriverPackage type="WinPE" dellVersion="A09" releaseID="OLD01" path="FOLDER/WinPE11-old.cab" dateTime="2026-03-25T00:00:00">
    <Name><Display lang="en">Older WinPE package</Display></Name>
    <SupportedOperatingSystems>
      <OperatingSystem osVendor="Microsoft" osArch="x64" majorVersion="10" minorVersion="0" />
    </SupportedOperatingSystems>
  </DriverPackage>
  <DriverPackage type="Win" dellVersion="A99" releaseID="SYSTEM" path="FOLDER/System.cab" dateTime="2026-09-01T00:00:00">
    <Name><Display lang="en">System Driver Pack</Display></Name>
    <SupportedOperatingSystems>
      <OperatingSystem osVendor="Microsoft" osArch="x64" majorVersion="10" minorVersion="0" />
    </SupportedOperatingSystems>
  </DriverPackage>
</DriverPackManifest>
'@ | Set-Content -LiteralPath $script:CatalogPath -Encoding UTF8
}

Describe 'Get-DellWinPEDriverPack' {
    It 'returns only WinPE packages' {
        $result = @(Get-DellWinPEDriverPack -CatalogPath $script:CatalogPath)
        $result.Count | Should -Be 2
        ($result.Type | Select-Object -Unique) | Should -Be 'WinPE'
    }

    It 'constructs an HTTPS download URL from baseLocation and path' {
        $result = Get-DellWinPEDriverPack -CatalogPath $script:CatalogPath | Select-Object -First 1
        $result.DownloadUrl | Should -Be 'https://downloads.dell.com/FOLDER/WinPE11.cab'
    }

    It 'filters by architecture and OS version' {
        $result = @(Get-DellWinPEDriverPack -CatalogPath $script:CatalogPath -Architecture x64 -MajorVersion 10 -MinorVersion 0)
        $result.Count | Should -Be 2
    }

    It 'sorts newest package first' {
        $result = @(Get-DellWinPEDriverPack -CatalogPath $script:CatalogPath)
        $result[0].DellVersion | Should -Be 'A10'
        $result[0].ReleaseId | Should -Be 'XCXDW'
    }
}

Describe 'New-DellWinPEManifest' {
    It 'writes a JSON manifest containing only WinPE packages' {
        $path = Join-Path $TestDrive 'manifest.json'
        New-DellWinPEManifest -CatalogPath $script:CatalogPath -Path $path | Out-Null

        $manifest = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        $manifest.Manufacturer | Should -Be 'Dell'
        @($manifest.Packages).Count | Should -Be 2
        @($manifest.Packages | Where-Object Type -ne 'WinPE').Count | Should -Be 0
    }
}
