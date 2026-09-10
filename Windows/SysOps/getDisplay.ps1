<#
.SYNOPSIS
    Reports connected monitor make/model, graphics adapter(s) with VRAM, and
    current display resolution.

.DESCRIPTION
    Collects:
      - Monitor manufacturer, model, serial and year of manufacture from the
        monitor EDID (root\wmi WmiMonitorID). Falls back gracefully when a
        display (e.g. some laptop panels / KVMs) does not expose an EDID.
      - Each active graphics adapter (Win32_VideoController) with its driver
        version and video memory. AdapterRAM from WMI is a signed 32-bit value
        and wrong for cards with 4GB+, so the true size is read from the
        adapter's registry HardwareInformation.qwMemorySize when available.
      - Current resolution and refresh rate per adapter.
    The same report is printed to the console and written to C:\temp\displayInfo.txt
    (C:\temp is created if needed).

.NOTES
    No elevation required. Run in a normal PowerShell session.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$outDir  = 'C:\temp'
$outFile = Join-Path $outDir 'displayInfo.txt'

if (-not (Test-Path -Path $outDir)) {
    New-Item -Path $outDir -ItemType Directory -Force | Out-Null
}

# Collect report lines here, then emit to console + file together
$report = New-Object System.Collections.Generic.List[string]

function Add-Line {
    param([string]$Text = '')
    $report.Add($Text)
}

function ConvertFrom-EdidString {
    <#
        WmiMonitorID exposes text fields as null-terminated arrays of UInt16
        character codes (0 padded). Convert one to a clean string.
    #>
    param([UInt16[]]$Codes)

    if (-not $Codes) { return '' }
    -join ($Codes | Where-Object { $_ -gt 0 } | ForEach-Object { [char]$_ }) -replace '\s+$', ''
}

function Resolve-PnpVendor {
    <#
        Expand a 3-letter EDID/PNP manufacturer code to a friendly vendor name
        where known, otherwise return the code unchanged.
    #>
    param([string]$Code)

    $map = @{
        AAC='AcerView'; ACR='Acer'; ACI='Asus'; AOC='AOC'; API='Acer America'
        AUO='AU Optronics'; BNQ='BenQ'; CMN='Chi Mei / Innolux'; CMO='Chi Mei Optoelectronics'
        DEL='Dell'; ENC='EIZO'; GSM='LG (Goldstar)'; HPN='HP'; HWP='HP'; HSD='HannStar'
        IVM='Iiyama'; LEN='Lenovo'; LGD='LG Display'; LPL='LG Philips'; MEI='Panasonic'
        MSI='MSI'; NEC='NEC'; PHL='Philips'; SAM='Samsung'; SEC='Seiko Epson'
        SHP='Sharp'; SNY='Sony'; STA='Startek'; TOS='Toshiba'; VSC='ViewSonic'
    }
    if ($Code -and $map.ContainsKey($Code)) { return $map[$Code] }
    return $Code
}

function Get-MonitorsFromRegistryEdid {
    <#
        Fallback for when WmiMonitorID is unavailable (access denied, running in
        a remote/service session, etc). Reads the raw EDID blob each monitor
        cached under HKLM\SYSTEM\CurrentControlSet\Enum\DISPLAY and parses the
        manufacturer ID, product name and serial from it.
    #>
    $results = New-Object System.Collections.Generic.List[object]
    $root = 'HKLM:\SYSTEM\CurrentControlSet\Enum\DISPLAY'
    if (-not (Test-Path $root)) { return $results }

    foreach ($mfg in Get-ChildItem -Path $root -ErrorAction SilentlyContinue) {
        foreach ($inst in Get-ChildItem -Path $mfg.PSPath -ErrorAction SilentlyContinue) {
            $params = Get-ItemProperty -Path (Join-Path $inst.PSPath 'Device Parameters') -ErrorAction SilentlyContinue
            $edid = $params.EDID
            if (-not $edid -or $edid.Count -lt 128) { continue }

            # Manufacturer ID: bytes 8-9, big-endian, 3 x 5-bit letters (A=1).
            # Cast to [int] first - PowerShell's -shl keeps the [byte] type and
            # would truncate the high byte to 0.
            $mfgBits = ([int]$edid[8] -shl 8) -bor [int]$edid[9]
            $manufacturer = -join @(
                [char]((($mfgBits -shr 10) -band 0x1F) + 64)
                [char]((($mfgBits -shr 5)  -band 0x1F) + 64)
                [char]((($mfgBits)         -band 0x1F) + 64)
            )

            # Four 18-byte descriptors start at offset 54; tag 0xFC = name, 0xFF = serial
            $name = ''
            $serial = ''
            foreach ($off in 54, 72, 90, 108) {
                if ($edid[$off] -eq 0 -and $edid[$off + 1] -eq 0 -and $edid[$off + 2] -eq 0) {
                    $tag = $edid[$off + 3]
                    $text = (-join ($edid[($off + 5)..($off + 17)] | ForEach-Object { [char]$_ })).Trim() -replace "[`r`n].*$", ''
                    if ($tag -eq 0xFC) { $name = $text }
                    elseif ($tag -eq 0xFF) { $serial = $text }
                }
            }

            $year = $edid[17] + 1990

            $results.Add([PSCustomObject]@{
                Manufacturer = $manufacturer
                Model        = $name
                Serial       = $serial
                Year         = $year
            })
        }
    }
    return $results
}

function Format-Bytes {
    param([double]$Bytes)

    if ($Bytes -le 0) { return 'Unknown' }
    $units = 'B', 'KB', 'MB', 'GB', 'TB'
    $i = 0
    while ($Bytes -ge 1024 -and $i -lt $units.Count - 1) {
        $Bytes /= 1024
        $i++
    }
    '{0} {1}' -f [math]::Round($Bytes, 2), $units[$i]
}

function Get-AdapterVram {
    <#
        Returns the most reliable VRAM byte count for a video controller.
        Prefers the registry qwMemorySize (64-bit, accurate for 4GB+ cards),
        falling back to the WMI AdapterRAM value (capped near 4GB).
    #>
    param($Controller)

    $regBase = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
    try {
        $match = Get-ChildItem -Path $regBase -ErrorAction Stop |
            Where-Object { $_.PSChildName -match '^\d{4}$' } |
            ForEach-Object { Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue } |
            Where-Object { $_.'HardwareInformation.qwMemorySize' -and $_.DriverDesc -eq $Controller.Name } |
            Select-Object -First 1
        if ($match) {
            return [double]$match.'HardwareInformation.qwMemorySize'
        }
    } catch { }

    if ($Controller.AdapterRAM -and $Controller.AdapterRAM -gt 0) {
        return [double]$Controller.AdapterRAM
    }
    return 0
}

Add-Line '=========================================='
Add-Line ' Display Information'
Add-Line (' Computer: {0}' -f $env:COMPUTERNAME)
Add-Line (' Date:     {0}' -f (Get-Date))
Add-Line '=========================================='
Add-Line ''

# ---- Monitors (EDID) ----
Add-Line '--- Monitors ---'
$monitors = New-Object System.Collections.Generic.List[object]
try {
    $monitorIds = Get-CimInstance -Namespace 'root\wmi' -ClassName 'WmiMonitorID' -ErrorAction Stop
    foreach ($m in $monitorIds) {
        $y = if ($m.YearOfManufacture -gt 0) { $m.YearOfManufacture } else { 'Unknown' }
        $monitors.Add([PSCustomObject]@{
            Manufacturer = ConvertFrom-EdidString $m.ManufacturerName
            Model        = ConvertFrom-EdidString $m.UserFriendlyName
            Serial       = ConvertFrom-EdidString $m.SerialNumberID
            Year         = $y
        })
    }
} catch {
    Add-Line ('  WmiMonitorID unavailable ({0}); falling back to registry EDID.' -f $_.Exception.Message.Trim())
}

if ($monitors.Count -eq 0) {
    try {
        foreach ($r in Get-MonitorsFromRegistryEdid) { $monitors.Add($r) }
    } catch {
        Add-Line ('  Could not read registry EDID data: {0}' -f $_.Exception.Message)
    }
}

if ($monitors.Count -eq 0) {
    Add-Line '  No monitor make/model information available.'
}

$index = 0
foreach ($mon in $monitors) {
    $index++
    $manufacturer = if ($mon.Manufacturer) { Resolve-PnpVendor $mon.Manufacturer } else { '(unknown)' }
    $model        = if ($mon.Model)        { $mon.Model }        else { '(model not provided)' }
    $serial       = if ($mon.Serial)       { $mon.Serial }       else { 'N/A' }

    Add-Line ('  Monitor {0}: {1} {2}' -f $index, $manufacturer, $model)
    Add-Line ('    Serial: {0}   Year: {1}' -f $serial, $mon.Year)
}
Add-Line ''

# ---- Graphics adapters + resolution ----
Add-Line '--- Graphics Adapters ---'
try {
    $controllers = Get-CimInstance -ClassName 'Win32_VideoController' -ErrorAction Stop |
        Where-Object { $_.Name }

    if (-not $controllers) {
        Add-Line '  No video controllers reported by Win32_VideoController.'
    }

    $index = 0
    foreach ($c in $controllers) {
        $index++
        $vram = Get-AdapterVram -Controller $c

        Add-Line ('  Adapter {0}: {1}' -f $index, $c.Name.Trim())
        Add-Line ('    VRAM:           {0}' -f (Format-Bytes $vram))
        Add-Line ('    Driver version: {0}' -f $c.DriverVersion)

        if ($c.CurrentHorizontalResolution -and $c.CurrentVerticalResolution) {
            $res = '{0} x {1}' -f $c.CurrentHorizontalResolution, $c.CurrentVerticalResolution
            if ($c.CurrentRefreshRate) {
                $res += ' @ {0} Hz' -f $c.CurrentRefreshRate
            }
            Add-Line ('    Resolution:     {0}' -f $res)
        } else {
            Add-Line '    Resolution:     Not active / not reported'
        }
    }
} catch {
    Add-Line ('  Could not query graphics adapters: {0}' -f $_.Exception.Message)
}
Add-Line ''

Add-Line '=========================================='

# ---- Output ----
foreach ($line in $report) {
    if ($line -match '^(---|===| Display Information)') {
        Write-Host $line -ForegroundColor Cyan
    } else {
        Write-Host $line
    }
}

$report | Out-File -FilePath $outFile -Encoding UTF8

Write-Host ''
Write-Host "Report written to $outFile" -ForegroundColor Cyan
