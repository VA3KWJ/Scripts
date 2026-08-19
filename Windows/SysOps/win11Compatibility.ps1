<#
.SYNOPSIS
    Checks the local machine against Windows 11 minimum hardware requirements.

.DESCRIPTION
    Evaluates CPU architecture/cores/speed, RAM, system drive free space, TPM version,
    Secure Boot capability, and UEFI firmware mode. Prints a PASS/FAIL report to the
    console and writes the same report to C:\temp\win11.txt (creating C:\temp if needed).

.NOTES
    Run as Administrator for the most reliable TPM / Secure Boot results.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$outDir  = 'C:\temp'
$outFile = Join-Path $outDir 'win11.txt'

if (-not (Test-Path -Path $outDir)) {
    New-Item -Path $outDir -ItemType Directory -Force | Out-Null
}

# Collect report lines here, then emit to console + file together
$report = New-Object System.Collections.Generic.List[string]

function Add-Line {
    param([string]$Text = '')
    $report.Add($Text)
}

function Add-Result {
    param(
        [string]$Check,
        [bool]$Passed,
        [string]$Detail
    )
    $status = if ($Passed) { 'PASS' } else { 'FAIL' }
    Add-Line ('[{0}] {1} - {2}' -f $status, $Check, $Detail)
    return $Passed
}

Add-Line '=========================================='
Add-Line ' Windows 11 Compatibility Check'
Add-Line (' Computer: {0}' -f $env:COMPUTERNAME)
Add-Line (' Date:     {0}' -f (Get-Date))
Add-Line '=========================================='
Add-Line ''

$allPassed = $true

function Get-CpuGenerationStatus {
    <#
        Best-effort parse of a CPU name string to estimate whether it meets the
        Windows 11 minimum of Intel 8th Gen (Coffee Lake) / AMD Ryzen 3000 or newer.
        This is a heuristic based on model-number conventions, not Microsoft's
        official supported-CPU list, so exceptions (e.g. Ryzen 2700X) are not
        accounted for. Anything that can't be confidently parsed is treated as FAIL.
    #>
    param([string]$Name)

    $name = $Name.Trim()

    # Intel "Core Ultra" (Meteor Lake and newer) - all newer than 8th Gen
    if ($name -match 'Core\(TM\)\s+Ultra|Core\s+Ultra') {
        return [PSCustomObject]@{ Supported = $true; Detail = 'Intel Core Ultra (newer than 8th Gen)' }
    }

    # Intel Core i3/i5/i7/i9-##### (desktop: 10700K -> 10th gen, mobile: 1135G7 -> 11th gen)
    if ($name -match 'i[3579]-(\d{3,5})') {
        $modelNum = $Matches[1]
        $gen = [int]$modelNum.Substring(0, 1)
        if ($modelNum.Length -ge 2) {
            $twoDigit = [int]$modelNum.Substring(0, 2)
            if ($twoDigit -ge 10 -and $twoDigit -le 14) {
                $gen = $twoDigit
            }
        }
        $supported = $gen -ge 8
        return [PSCustomObject]@{ Supported = $supported; Detail = ('Intel Core, detected {0}th Gen (model {1})' -f $gen, $Matches[0]) }
    }

    # AMD Ryzen Threadripper #### (no class digit, e.g. Threadripper 3960X -> 3000 series)
    if ($name -match 'Ryzen\s+Threadripper\s+(?:PRO\s+)?(\d{3,5})') {
        $modelNum = $Matches[1]
        $series = [int]$modelNum.Substring(0, 1)
        $supported = $series -ge 3
        return [PSCustomObject]@{ Supported = $supported; Detail = ('AMD Ryzen Threadripper, detected {0}000 series (model {1})' -f $series, $Matches[1]) }
    }

    # AMD Ryzen # #### (e.g. Ryzen 5 3600 -> 3000 series, Ryzen 7 5800X -> 5000 series)
    if ($name -match 'Ryzen\s+[3579]\s+(?:PRO\s+)?(\d{3,5})') {
        $modelNum = $Matches[1]
        $series = [int]$modelNum.Substring(0, 1)
        $supported = $series -ge 3
        return [PSCustomObject]@{ Supported = $supported; Detail = ('AMD Ryzen, detected {0}000 series (model {1})' -f $series, $Matches[1]) }
    }

    return [PSCustomObject]@{ Supported = $false; Detail = 'Could not determine CPU generation from name; verify manually against Microsoft''s supported CPU list' }
}

# ---- OS Architecture ----
try {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $is64Bit = $os.OSArchitecture -like '64*'
    $allPassed = (Add-Result 'OS Architecture' $is64Bit $os.OSArchitecture) -and $allPassed
} catch {
    Add-Line ('[FAIL] OS Architecture - Error: {0}' -f $_.Exception.Message)
    $allPassed = $false
}

# ---- CPU ----
try {
    $cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    $cores = $cpu.NumberOfCores
    $speedGHz = [math]::Round($cpu.MaxClockSpeed / 1000, 2)
    $is64BitCpu = $cpu.AddressWidth -eq 64

    $cpuOk = ($cores -ge 2) -and ($speedGHz -ge 1.0) -and $is64BitCpu
    $cpuDetail = '{0}, {1} cores, {2} GHz, {3}-bit' -f $cpu.Name.Trim(), $cores, $speedGHz, $cpu.AddressWidth
    $allPassed = (Add-Result 'CPU (2+ cores, 1GHz+, 64-bit)' $cpuOk $cpuDetail) -and $allPassed

    $genStatus = Get-CpuGenerationStatus -Name $cpu.Name
    $allPassed = (Add-Result 'CPU Generation (Intel 8th Gen+ / AMD Ryzen 3000+)' $genStatus.Supported $genStatus.Detail) -and $allPassed
    Add-Line '     NOTE: Generation is inferred from the model name and does not check Microsoft''s official supported-CPU list or its exceptions.'
} catch {
    Add-Line ('[FAIL] CPU - Error: {0}' -f $_.Exception.Message)
    $allPassed = $false
}

# ---- RAM ----
try {
    $ramGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $ramOk = $ramGB -ge 4
    $allPassed = (Add-Result 'RAM (4GB+)' $ramOk ('{0} GB' -f $ramGB)) -and $allPassed
} catch {
    Add-Line ('[FAIL] RAM - Error: {0}' -f $_.Exception.Message)
    $allPassed = $false
}

# ---- Storage (system drive) ----
try {
    $sysDrive = $env:SystemDrive
    $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$sysDrive'"
    $diskGB = [math]::Round($disk.Size / 1GB, 2)
    $diskOk = $diskGB -ge 64
    $allPassed = (Add-Result 'Storage (64GB+ on system drive)' $diskOk ('{0} GB total on {1}' -f $diskGB, $sysDrive)) -and $allPassed
} catch {
    Add-Line ('[FAIL] Storage - Error: {0}' -f $_.Exception.Message)
    $allPassed = $false
}

# ---- TPM ----
try {
    $tpm = Get-Tpm -ErrorAction Stop
    $tpmPresentReady = $tpm.TpmPresent -and $tpm.TpmReady

    $tpmVersion = 'Unknown'
    try {
        $tpmWmi = Get-CimInstance -Namespace 'Root\CIMV2\Security\MicrosoftTpm' -ClassName Win32_Tpm -ErrorAction Stop
        if ($tpmWmi -and $tpmWmi.SpecVersion) {
            $tpmVersion = $tpmWmi.SpecVersion
        }
    } catch {
        # Namespace may be inaccessible without elevation; leave as Unknown
    }

    $tpm2Ok = $tpmPresentReady -and ($tpmVersion -like '2.0*')
    $tpmDetail = 'Present={0}, Ready={1}, SpecVersion={2}' -f $tpm.TpmPresent, $tpm.TpmReady, $tpmVersion
    $allPassed = (Add-Result 'TPM 2.0' $tpm2Ok $tpmDetail) -and $allPassed
} catch {
    Add-Line '[FAIL] TPM 2.0 - Could not query TPM (module unavailable or access denied; try running as Administrator).'
    $allPassed = $false
}

# ---- Secure Boot ----
try {
    $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop
    $allPassed = (Add-Result 'Secure Boot Enabled' $secureBoot ($secureBoot.ToString())) -and $allPassed
} catch {
    Add-Line '[FAIL] Secure Boot - Not supported/enabled, or firmware is not UEFI (Legacy BIOS mode).'
    $allPassed = $false
}

# ---- UEFI Firmware Mode ----
try {
    $fwType = $null
    try {
        $fwType = (Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control' -Name 'PEFirmwareType' -ErrorAction Stop).PEFirmwareType
    } catch {
        $fwType = $null
    }

    # PEFirmwareType: 1 = BIOS/Legacy, 2 = UEFI
    if ($fwType -eq 2) {
        $allPassed = (Add-Result 'UEFI Firmware' $true 'UEFI') -and $allPassed
    } elseif ($fwType -eq 1) {
        $allPassed = (Add-Result 'UEFI Firmware' $false 'Legacy BIOS') -and $allPassed
    } else {
        Add-Line '[FAIL] UEFI Firmware - Could not determine firmware type.'
        $allPassed = $false
    }
} catch {
    Add-Line ('[FAIL] UEFI Firmware - Error: {0}' -f $_.Exception.Message)
    $allPassed = $false
}

Add-Line ''
Add-Line '=========================================='
if ($allPassed) {
    Add-Line ' OVERALL RESULT: COMPATIBLE with Windows 11'
} else {
    Add-Line ' OVERALL RESULT: NOT COMPATIBLE (one or more checks failed)'
}
Add-Line '=========================================='

# ---- Output ----
foreach ($line in $report) {
    if ($line -match '^\[PASS\]') {
        Write-Host $line -ForegroundColor Green
    } elseif ($line -match '^\[FAIL\]') {
        Write-Host $line -ForegroundColor Red
    } else {
        Write-Host $line
    }
}

$report | Out-File -FilePath $outFile -Encoding UTF8

Write-Host ''
Write-Host "Report written to $outFile" -ForegroundColor Cyan
