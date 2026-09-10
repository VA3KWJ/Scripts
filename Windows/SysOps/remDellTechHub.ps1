<#
.SYNOPSIS
    Removes Dell TechHub and its related Dell client components.

.DESCRIPTION
    Dell TechHub is a shared background service ("C:\Program Files\Dell\TechHub\Dell.TechHub.exe")
    installed alongside Dell Display Manager, Dell Peripheral Manager, Dell Pair, Dell Display and
    Peripheral Manager (DDPM) and Dell Core Services. This script:

      1. Stops and disables the related services and kills the running processes.
      2. Removes matching MSIX/AppX packages (provisioned and per-user).
      3. Runs the uninstall string for every matching entry in the 32/64-bit and per-user
         Uninstall registry hives (MSI products are removed silently via msiexec /x).
      4. Deletes matching scheduled tasks.
      5. Cleans up leftover program folders and the "Dell\TechHub" registry keys.

    By default only Dell TechHub and its direct dependencies are targeted. Use -Products to
    override the match list, or -WhatIf to preview what would be removed.

.PARAMETER Products
    Wildcard patterns matched (case-insensitive) against display names / package names.
    Defaults to Dell TechHub and the components that bundle it.

.PARAMETER KeepFolders
    Skip deletion of leftover program folders under C:\Program Files\Dell.

.NOTES
    Requires Administrator privileges. Tested on Windows 10 and 11.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [string[]]$Products = @(
        '*Dell TechHub*',
        '*DellTechHub*',
        '*Dell Core Services*',
        '*Dell Pair*',
        '*Dell Display Manager*',
        '*Dell Peripheral Manager*',
        '*Dell Display and Peripheral Manager*'
    ),
    [switch]$KeepFolders
)

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script must be run as Administrator.`nExiting..."
    exit 1
}

$ErrorActionPreference = 'Continue'

function Test-Match {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    foreach ($pattern in $Products) {
        if ($Text -like $pattern) { return $true }
    }
    return $false
}

Write-Host '*** Removing Dell TechHub and related components ***' -ForegroundColor Cyan
Write-Host ("Match patterns: {0}" -f ($Products -join ', ')) -ForegroundColor DarkGray

# ---- 1. Stop / disable services and kill processes ----
Write-Host '[1/6] Stopping services and processes...' -ForegroundColor Yellow

$serviceNames = @('Dell TechHub', 'DellTechHub', 'Dell Core Services', 'DellClientManagementService')
Get-Service -ErrorAction SilentlyContinue |
    Where-Object { (Test-Match $_.Name) -or (Test-Match $_.DisplayName) -or ($serviceNames -contains $_.Name) } |
    ForEach-Object {
        if ($PSCmdlet.ShouldProcess($_.Name, 'Stop and disable service')) {
            Write-Host "    service: $($_.Name)"
            Stop-Service -Name $_.Name -Force -ErrorAction SilentlyContinue
            Set-Service  -Name $_.Name -StartupType Disabled -ErrorAction SilentlyContinue
        }
    }

Get-Process -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -like '*\Dell\TechHub\*' -or (Test-Match $_.Description) -or $_.Name -like 'Dell.TechHub*' } |
    ForEach-Object {
        if ($PSCmdlet.ShouldProcess($_.Name, 'Stop process')) {
            Write-Host "    process: $($_.Name) (pid $($_.Id))"
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }
    }

# ---- 2. Remove MSIX / AppX packages ----
Write-Host '[2/6] Removing MSIX / AppX packages...' -ForegroundColor Yellow

Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
    Where-Object { (Test-Match $_.Name) -or (Test-Match $_.PackageFullName) } |
    ForEach-Object {
        if ($PSCmdlet.ShouldProcess($_.PackageFullName, 'Remove AppX package (all users)')) {
            Write-Host "    package: $($_.PackageFullName)"
            Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue
        }
    }

Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
    Where-Object { (Test-Match $_.DisplayName) -or (Test-Match $_.PackageName) } |
    ForEach-Object {
        if ($PSCmdlet.ShouldProcess($_.PackageName, 'Remove provisioned AppX package')) {
            Write-Host "    provisioned: $($_.PackageName)"
            Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null
        }
    }

# ---- 3. Run uninstall strings from the registry ----
Write-Host '[3/6] Uninstalling from Programs and Features...' -ForegroundColor Yellow

$uninstallRoots = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
)

foreach ($root in $uninstallRoots) {
    Get-ChildItem -Path $root -ErrorAction SilentlyContinue | ForEach-Object {
        $props = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
        if (-not (Test-Match $props.DisplayName)) { return }

        $name = $props.DisplayName
        $cmd  = $props.QuietUninstallString
        if ([string]::IsNullOrWhiteSpace($cmd)) { $cmd = $props.UninstallString }
        if ([string]::IsNullOrWhiteSpace($cmd)) {
            Write-Warning "    '$name' has no uninstall string; skipping."
            return
        }

        if (-not $PSCmdlet.ShouldProcess($name, 'Uninstall')) { return }
        Write-Host "    uninstalling: $name"

        try {
            if ($cmd -match 'msiexec') {
                # Normalise "/I{guid}" -> "/X{guid}" and force a silent, no-reboot removal.
                $guid = $props.PSChildName
                Start-Process -FilePath 'msiexec.exe' -ArgumentList "/x $guid /qn /norestart" -Wait -NoNewWindow
            }
            elseif ($cmd -match '^\s*"([^"]+)"\s*(.*)$') {
                $exe    = $Matches[1]
                $argStr = $Matches[2]
                if ($argStr -notmatch '(?i)(/quiet|/silent|-silent|/S\b|/VERYSILENT)') {
                    $argStr = "$argStr /quiet /norestart"
                }
                Start-Process -FilePath $exe -ArgumentList $argStr.Trim() -Wait -NoNewWindow
            }
            else {
                Start-Process -FilePath 'cmd.exe' -ArgumentList "/c `"$cmd`"" -Wait -NoNewWindow
            }
        }
        catch {
            Write-Warning "    Failed to uninstall '$name': $($_.Exception.Message)"
        }
    }
}

# ---- 4. Remove scheduled tasks ----
Write-Host '[4/6] Removing scheduled tasks...' -ForegroundColor Yellow

Get-ScheduledTask -ErrorAction SilentlyContinue |
    Where-Object { (Test-Match $_.TaskName) -or (Test-Match $_.TaskPath) } |
    ForEach-Object {
        if ($PSCmdlet.ShouldProcess("$($_.TaskPath)$($_.TaskName)", 'Unregister scheduled task')) {
            Write-Host "    task: $($_.TaskPath)$($_.TaskName)"
            Unregister-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -Confirm:$false -ErrorAction SilentlyContinue
        }
    }

# ---- 5. Clean up leftover folders ----
Write-Host '[5/6] Cleaning up leftover folders...' -ForegroundColor Yellow

if ($KeepFolders) {
    Write-Host '    skipped (-KeepFolders).'
} else {
    $folders = @(
        "$env:ProgramFiles\Dell\TechHub",
        "${env:ProgramFiles(x86)}\Dell\TechHub",
        "$env:ProgramData\Dell\TechHub",
        "$env:ProgramFiles\Dell\PairAndDisplayManager",
        "$env:ProgramFiles\Dell\DisplayManager",
        "$env:ProgramFiles\Dell\PeripheralManager"
    )
    foreach ($folder in $folders) {
        if (Test-Path -LiteralPath $folder) {
            if ($PSCmdlet.ShouldProcess($folder, 'Delete folder')) {
                Write-Host "    folder: $folder"
                Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
    # Remove the parent Dell folder only if it is now empty.
    $dellRoot = "$env:ProgramFiles\Dell"
    if ((Test-Path -LiteralPath $dellRoot) -and -not (Get-ChildItem -LiteralPath $dellRoot -Force -ErrorAction SilentlyContinue)) {
        if ($PSCmdlet.ShouldProcess($dellRoot, 'Delete empty folder')) {
            Remove-Item -LiteralPath $dellRoot -Force -ErrorAction SilentlyContinue
        }
    }
}

# ---- 6. Clean up leftover registry keys ----
Write-Host '[6/6] Cleaning up leftover registry keys...' -ForegroundColor Yellow

$regKeys = @(
    'HKLM:\SOFTWARE\Dell\TechHub',
    'HKLM:\SOFTWARE\WOW6432Node\Dell\TechHub'
)
foreach ($key in $regKeys) {
    if (Test-Path -LiteralPath $key) {
        if ($PSCmdlet.ShouldProcess($key, 'Delete registry key')) {
            Write-Host "    key: $key"
            Remove-Item -LiteralPath $key -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host ''
Write-Host 'Done. A reboot is recommended to clear any locked files.' -ForegroundColor Green

# Report anything still present.
$leftEntries = foreach ($root in $uninstallRoots) {
    Get-ChildItem -Path $root -ErrorAction SilentlyContinue | ForEach-Object {
        $p = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
        if (Test-Match $p.DisplayName) { $p.DisplayName }
    }
}
if ($leftEntries) {
    Write-Warning ("Still listed in Programs and Features: {0}" -f ($leftEntries -join ', '))
}
if (Test-Path -LiteralPath "$env:ProgramFiles\Dell\TechHub") {
    Write-Warning "Folder still present (likely locked): $env:ProgramFiles\Dell\TechHub"
}
