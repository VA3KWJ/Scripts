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
    Add-Line '     NOTE: This does not verify the CPU model is on Microsoft''s official supported list.'
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
