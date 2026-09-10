<#
.SYNOPSIS
    Repairs every installed version of the Microsoft Visual C++ Redistributable.

.DESCRIPTION
    Enumerates the 32/64-bit Uninstall registry hives for all "Visual C++ ...
    Redistributable" entries and triggers a silent, no-reboot repair for each one.
    Two installer technologies are handled:

      * EXE bundles (2012-2022, WiX "burn"): run  <bundle>.exe /repair /quiet /norestart
      * MSI products (2005-2010):              run  msiexec /fa[ums] {GUID} /quiet /norestart

    Entries are de-duplicated by product GUID / bundle path so x86 and x64 are each
    repaired once and the "Additional/Minimum runtime" MSI child rows are ignored.

.NOTES
    Requires Administrator privileges. Tested on Windows 10 and 11.
    Exit codes 0 (success) and 3010 (success, reboot required) are both treated as OK.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

#Requires -Version 5.1

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script must be run as Administrator.`nExiting..."
    exit 1
}

$ErrorActionPreference = 'Continue'

# Registry paths where per-machine software installations are recorded (native + WOW64).
$regPaths = @(
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

# Collect every Uninstall entry whose display name looks like a VC++ Redistributable.
$visualCApps = foreach ($path in $regPaths) {
    Get-ChildItem -Path $path -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $props = Get-ItemProperty -Path $_.PSPath -ErrorAction Stop
            if ($props.DisplayName -match 'Visual C\+\+.*Redistributable') {
                $props
            }
        } catch {
            # Skip locked or inaccessible registry keys.
        }
    }
}

if (-not $visualCApps) {
    Write-Host 'No Visual C++ Redistributable installations found.' -ForegroundColor Yellow
    return
}

Write-Host "Found $($visualCApps.Count) Visual C++ Redistributable registry entries." -ForegroundColor Cyan

# Track what we have already repaired so shared installers are not run twice.
$processed = New-Object System.Collections.Generic.HashSet[string]
$results   = @()

foreach ($app in $visualCApps) {
    $name = $app.DisplayName

    # Prefer the quiet uninstall string; fall back to the plain one.
    $cmd = $app.QuietUninstallString
    if ([string]::IsNullOrWhiteSpace($cmd)) { $cmd = $app.UninstallString }
    if ([string]::IsNullOrWhiteSpace($cmd)) {
        Write-Host "Skipping (no uninstall string): $name" -ForegroundColor DarkGray
        continue
    }

    # ---- MSI product (2005-2010): UninstallString is "MsiExec.exe /X{GUID}" ----
    if ($cmd -match '(?i)msiexec') {
        # The registry key name is the product GUID for MSI installs.
        $guid = if ($app.PSChildName -match '^\{[0-9A-Fa-f-]+\}$') {
            $app.PSChildName
        } elseif ($cmd -match '(\{[0-9A-Fa-f-]+\})') {
            $Matches[1]
        } else {
            $null
        }
        if (-not $guid) {
            Write-Host "Skipping (could not parse MSI GUID): $name" -ForegroundColor Yellow
            continue
        }
        if (-not $processed.Add("msi:$guid")) { continue }   # already repaired this product

        if ($PSCmdlet.ShouldProcess($name, 'Repair (msiexec /f)')) {
            Write-Host "Repairing (MSI): $name" -ForegroundColor Cyan
            # /faums = reinstall All files, replace User + Machine registry keys, re-cache MSI.
            $proc = Start-Process -FilePath 'msiexec.exe' `
                -ArgumentList "/faums $guid /quiet /norestart" -Wait -PassThru -NoNewWindow
            $results += [pscustomobject]@{ Name = $name; ExitCode = $proc.ExitCode }
        }
        continue
    }

    # ---- EXE bundle (2012+): "<path>\VC_redist.x64.exe" [args]  or  <path> [args] ----
    if ($cmd -match '^\s*"([^"]+)"\s*(.*)$') {
        $exePath = $Matches[1]
    } else {
        $exePath = ($cmd -split '\s+')[0]
    }

    if (-not (Test-Path -LiteralPath $exePath)) {
        Write-Host "Could not locate installer executable for: $name" -ForegroundColor Yellow
        $results += [pscustomobject]@{ Name = $name; ExitCode = 'no-installer' }
        continue
    }
    if (-not $processed.Add("exe:$($exePath.ToLower())")) { continue }   # shared bundle already done

    if ($PSCmdlet.ShouldProcess($name, 'Repair (/repair /quiet /norestart)')) {
        Write-Host "Repairing (EXE): $name" -ForegroundColor Cyan
        try {
            $proc = Start-Process -FilePath $exePath `
                -ArgumentList '/repair', '/quiet', '/norestart' -Wait -PassThru -NoNewWindow
            $results += [pscustomobject]@{ Name = $name; ExitCode = $proc.ExitCode }
        } catch {
            Write-Host "Failed to launch repair for $name : $($_.Exception.Message)" -ForegroundColor Red
            $results += [pscustomobject]@{ Name = $name; ExitCode = 'launch-failed' }
        }
    }
}

# ---- Summary ----
Write-Host ''
Write-Host '=== Repair summary ===' -ForegroundColor Cyan
$rebootNeeded = $false
foreach ($r in $results) {
    switch ($r.ExitCode) {
        0       { Write-Host "  OK        $($r.Name)" -ForegroundColor Green }
        3010    { Write-Host "  OK*       $($r.Name)  (reboot required)" -ForegroundColor Green; $rebootNeeded = $true }
        default { Write-Host "  FAILED    $($r.Name)  (exit $($r.ExitCode))" -ForegroundColor Red }
    }
}

Write-Host ''
if ($rebootNeeded) {
    Write-Host 'All repair routines completed - a reboot is required to finish.' -ForegroundColor Yellow
} else {
    Write-Host 'All Visual C++ Redistributable repair routines completed!' -ForegroundColor Green
}
