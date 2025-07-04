<#
Script Title      : fCln.ps1
Description       : File clean up by date with CSV reporting, deletion logging, WhatIf support, and PowerShell v4 compatibility
Initial Date      : 2026-06-01
Latest Revision   : 2025-07-04
Version           : 2.2.8
Author            : Stuart Waller
GitHub            : https://github.com/VA3KWJ
#>

<#
Change Log
==========

Version 2.2.8 - 2025-07-04
--------------------------
- Added -RemoveEmpty switch for non-interactive mode
- Respects this flag during deletion if set

Version 2.2.7 - 2025-07-04
--------------------------
- Added summary line(s) to deletion log file when deletions actually occur
- Summary includes file count, recovered size, and removed folder count (if applicable)

Version 2.2.6 - 2025-07-04
--------------------------
- Removed redundant prompt for "Remove empty folders?" in deletion phase
- Execution now respects the previously set $RemoveEmpty flag from interactive setup

Version 2.2.5 - 2025-07-04
--------------------------
- Moved "Remove empty folders?" prompt into interactive setup
- Prompt shown only if Delete mode is selected

Version 2.2.4 - 2025-06-27
--------------------------
- Added interactive WhatIf prompt (Y/N) when Delete mode is selected
- Default for WhatIf is now Y (simulate deletions unless explicitly disabled)

Version 2.2.3 - 2025-06-27
--------------------------
- Fixed crash when Get-Item fails on inaccessible paths (e.g., NetHood, Recent, SendTo)
- Wrapped Get-Item in try/catch and checked PSIsContainer only if accessible

Version 2.2.2 - 2025-06-27
--------------------------
- Replaced unsupported Test-Path -PathType Container (not available in PowerShell v4)
- Used (Get-Item).PSIsContainer with fallback for PS v4 compatibility

Version 2.2.1 - 2025-06-27
--------------------------
- Fixed "Collection was modified" error during folder skip expansion
- Enumerated over a copy of $skip list to safely modify it while iterating

Version 2.2.0 - 2025-06-27
--------------------------
- Added deletion log file (Delete mode only) in $ReportDir
- Added -WhatIf parameter support (safe simulation of deletions)
- Skipped non-existent paths with warnings
- Included mode (Delete or ReportOnly) in report filename
- Ensured compatibility with PowerShell v4

Version 2.1.2 - 2025-06-27
--------------------------
- Filtered out null paths when exporting removed-folder entries to CSV

Version 2.1.1 - (internal/testing)
----------------------------------
- Not officially released (internal debug and flow improvements)

Version 2.1.0 - (baseline before major updates)
-----------------------------------------------
- Added ForceExec switch to override app-extension filtering
- Improved extension filtering for executables and scripts
- Interactive date selection supports exact date or "days before" input

Version 2.0.0 - Initial Public Release (2025-06)
------------------------------------------------
- Interactive mode support (Path, Date, Delete/Report, User folders)
- Delete or ReportOnly modes
- Cutoff by last write date
- CSV reporting of matching files
- Optional removal of empty folders
- Compatible with PowerShell v4+
#>

param(
    [string[]]$Path,
    [datetime] $Date,
    [int]      $Before,
    [switch]   $IncludeUser,
    [switch]   $Delete,
    [switch]   $ReportOnly,
    [switch]   $ForceExec,
    [switch]   $WhatIf,
    [switch]   $RemoveEmpty,
    [string]   $ReportDir   = "$env:SystemDrive\FclnRpt"
)

if (-not $Path) { $Path = @() }

# Interactive Mode Setup
$Interactive = ($PSBoundParameters.Count -eq 0)
if ($Interactive) {
    cls
    Write-Host "Interactive Setup (defaults in brackets):"

    $p = Read-Host "Enter path(s) to scan, comma-separated [C:\]"
    if ($p) { $Path = $p.Split(',') | ForEach-Object { $_.Trim() } } else { $Path = 'C:\' }

    do {
        $iu = Read-Host "Include user folders? (Y/N) [N]"
        $iu = $iu.Trim().ToUpper()
        if ($iu -eq '' -or $iu -eq 'N') { $IncludeUser = $false; break }
        elseif ($iu -eq 'Y')            { $IncludeUser = $true; break }
    } while ($true)

    do {
        $mode = Read-Host "Mode - Delete (D) or Report (R) [R]"
        $mode = $mode.Trim().ToUpper()
        if ($mode -eq '' -or $mode -eq 'R') { $ReportOnly = $true; $Delete = $false; break }
        elseif ($mode -eq 'D')              { $Delete     = $true; $ReportOnly = $false; break }
    } while ($true)

    # WhatIf prompt only if Delete selected (default = Y)
    if ($Delete) {
        do {
            $wf = Read-Host "Enable WhatIf (simulate only)? (Y/N) [Y]"
            $wf = $wf.Trim().ToUpper()
            if ($wf -eq '' -or $wf -eq 'Y') { $WhatIf = $true; break }
            elseif ($wf -eq 'N')            { $WhatIf = $false; break }
        } while ($true)

        do {
            $re = Read-Host "Remove empty folders? (Y/N) [N]"
            $re = $re.Trim().ToUpper()
            if ($re -eq '' -or $re -eq 'N') { $RemoveEmpty = $false; break }
            elseif ($re -eq 'Y')            { $RemoveEmpty = $true; break }
        } while ($true)
    }

    do {
        $c = Read-Host "Cutoff by Date or Days? Enter 'Date' or 'Before' [Date]"
        $c = $c.Trim().ToUpper()
        if ($c -eq '' -or $c -eq 'DATE') {
            do {
                $def       = (Get-Date).ToString('yyyy-MM-dd')
                $dateInput = Read-Host "Enter cutoff date (yyyy-MM-dd) [$def]"
                if (-not $dateInput) { $Date = Get-Date; break }
                try {
                    $Date = [DateTime]::ParseExact($dateInput, 'yyyy-MM-dd', $null)
                    break
                } catch {
                    Write-Host "Invalid date format. Please use yyyy-MM-dd." -ForegroundColor Yellow
                }
            } while ($true)
            break
        } elseif ($c -eq 'BEFORE') {
            do {
                $b = Read-Host "Enter number of days before cutoff [30]"
                if (-not $b) { $Before = 30; break }
            } while (-not ([int]::TryParse($b, [ref]$null) -and [int]$b -ge 0))
            if ($b) { $Before = [int]$b }
            break
        }
    } while ($true)
}

# Admin Check
$me = [Security.Principal.WindowsIdentity]::GetCurrent()
$pr = New-Object Security.Principal.WindowsPrincipal($me)
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Please rerun this script as Administrator."; exit 1
}

# Non-interactive Param Validation
if (-not $Interactive) {
    if ($Delete -and $ReportOnly)          { throw 'Use either -Delete or -ReportOnly.' }
    if (-not ($Delete -or $ReportOnly))    { $ReportOnly = $true }
    if (-not $Date -and -not $PSBoundParameters.ContainsKey('Before')) { Write-Error 'Supply -Date or -Before.'; exit 1 }
    if ($Date -and $PSBoundParameters.ContainsKey('Before')) { throw 'Use -Date OR -Before, not both.' }
    if ($Before -lt 0)                     { throw '-Before must be >= 0.' }
    if ($WhatIf -and -not $Delete)         { throw '-WhatIf can only be used with -Delete mode.' }
}

# Compute Cutoff
$Cutoff = if ($Date) { $Date } else { (Get-Date).AddDays(-$Before) }

# Normalize Paths and Handle Missing Paths
if ($Path -isnot [array]) { $Path = @($Path) }
$Path = $Path | ForEach-Object { $_.TrimEnd('\','/') }

if (-not $Interactive -and -not $PSBoundParameters.ContainsKey('Path')) { $Path = 'C:\' }
if ($IncludeUser) { $Path += "$env:SystemDrive\Users" }

$existingPaths = @()
foreach ($p in $Path) {
    if (Test-Path $p) {
        $existingPaths += $p
    } else {
        Write-Warning "Skipping non-existent path: $p"
    }
}
$Path = $existingPaths
if (-not $Path) {
    Write-Error "No valid paths to scan. Exiting."
    exit 1
}

# Prepare Report Directory
if (-not (Test-Path $ReportDir)) { New-Item -ItemType Directory -Path $ReportDir | Out-Null }
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$ModeText = if ($Delete) { 'Delete' } else { 'ReportOnly' }
$rootKeyRaw = ($Path -join '_')
$rootKey = ($rootKeyRaw.Split('\')[-1] -replace '[\\/:*?"<>|]', '_')
$csvPath = Join-Path $ReportDir "$timestamp-$ModeText-$rootKey.csv"

# Prepare Deletion Log (only for Delete mode)
if ($Delete) {
    $logPath = Join-Path $ReportDir "$timestamp-DeleteLog.txt"
    "File Cleanup Deletion Log - $(Get-Date -Format 's')" | Out-File -FilePath $logPath -Encoding UTF8
    "" | Out-File -FilePath $logPath -Append
}

# Extensions to Skip
$appExts = '.exe','.dll','.com','.sys','.ocx','.msi','.msu','.msp','.drv',
           '.cpl','.msc','.scr','.vbs','.ps1','.bat','.cmd','.jar','.py','.sh'

# File Scanning
$fileList = @()
foreach ($root in $Path) {
    $dirs = @($root) + (Get-ChildItem -Path $root -Directory -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    $skip = New-Object System.Collections.ArrayList

    foreach ($d in $dirs) {
        if (-not $ForceExec) {
            if (Get-ChildItem -Path $d -File -ErrorAction SilentlyContinue | Where-Object { $appExts -contains $_.Extension.ToLower() }) {
                $skip.Add($d) | Out-Null
            }
        }
    }

    foreach ($s in @($skip)) {
        Get-ChildItem -Path $s -Directory -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            $skip.Add($_.FullName) | Out-Null
        }
    }

    foreach ($d in $dirs) {
        if ($skip.Contains($d) -and -not $ForceExec) { continue }
        Get-ChildItem -Path $d -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.LastWriteTime -lt $Cutoff -and
            -not ($_.Attributes.ToString().Split(',') -contains 'System') -and
            -not ($_.Attributes.ToString().Split(',') -contains 'Hidden') -and
            ($IncludeUser -or (-not ($_.FullName -match '\\Users\\|\\FolderRedirection\\'))) -and
            ($appExts -notcontains $_.Extension.ToLower())
        } | ForEach-Object {
            $fileList += [PSCustomObject]@{
                Root          = $root
                Directory     = $d
                Name          = $_.Name
                Length        = $_.Length
                LastWriteTime = $_.LastWriteTime
            }
        }
    }
}

$totalFilesBefore = $fileList.Count
$totalSizeBefore  = ($fileList | Measure-Object Length -Sum).Sum

# Deletion Phase
if ($Delete) {
    foreach ($f in $fileList) {
        $targetPath = Join-Path $f.Directory $f.Name
        if ($WhatIf) {
            Write-Output "WhatIf: Would delete file: $targetPath"
            Add-Content -Path $logPath -Value "WhatIf: Would delete file: $targetPath"
        } else {
            try {
                Remove-Item -LiteralPath $targetPath -Force -ErrorAction Stop
                Write-Output "Deleted: $targetPath"
                Add-Content -Path $logPath -Value "Deleted: $targetPath"
            } catch {
                Write-Warning "Failed to delete: $targetPath - $_"
                Add-Content -Path $logPath -Value "Failed to delete: $targetPath - $_"
            }
        }
    }

    # Remove Empty Folders
    function Remove-EmptyFolders {
        param([string[]]$Paths, [switch]$WhatIfLocal)
        $removed = @()
        $allDirs = foreach ($p in $Paths) { Get-ChildItem -Path $p -Directory -Recurse -Force -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName }
        $allDirs += $Paths
        $allDirs = $allDirs | Sort-Object { $_.Length } -Descending

        foreach ($d in $allDirs) {
            $dirIsContainer = $false
            try {
                $item = Get-Item $d -ErrorAction Stop
                $dirIsContainer = $item.PSIsContainer
            } catch {
                $dirIsContainer = $false
            }

            if ((Test-Path $d) -and $dirIsContainer -and -not (Get-ChildItem -LiteralPath $d -Force -ErrorAction SilentlyContinue)) {
                try {
                    $ldt = (Get-Item $d).LastWriteTime
                    if ($WhatIfLocal) {
                        Write-Output "WhatIf: Would remove empty folder: $d"
                        Add-Content -Path $logPath -Value "WhatIf: Would remove empty folder: $d"
                    } else {
                        Remove-Item -LiteralPath $d -Force -Recurse -ErrorAction Stop
                        Write-Host "Removed empty folder: $d"
                        Add-Content -Path $logPath -Value "Removed empty folder: $d"
                    }
                    $removed += [PSCustomObject]@{ Path = $d; LastWriteTime = $ldt }
                } catch {}
            }
        }
        return $removed
    }

$removedDirs = @()
if ($RemoveEmpty) {
    $removedDirs = Remove-EmptyFolders -Paths $Path -WhatIfLocal:$WhatIf
}
}

# CSV Report Generation
$reportObjects = @()
$reportObjects += $fileList | ForEach-Object { [PSCustomObject]@{
    Root          = $_.Root
    Directory     = $_.Directory
    Name          = $_.Name
    'Size (KB)'   = [math]::Round($_.Length/1KB,2)
    LastWriteTime = $_.LastWriteTime.ToString('s') } }

if ($RemoveEmpty -and $removedDirs) {
    $reportObjects += $removedDirs |
        Where-Object { $_.Path } |
        ForEach-Object { [PSCustomObject]@{
            Root          = Split-Path $_.Path -Qualifier
            Directory     = Split-Path $_.Path -Parent
            Name          = Split-Path $_.Path -Leaf
            'Size (KB)'   = 'DIR'
            LastWriteTime = $_.LastWriteTime.ToString('s') } }
}

$reportObjects | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

function fmtSize($bytes) { if ($bytes -lt 1GB) { "$( [math]::Round($bytes/1MB,2) ) MB" } else { "$( [math]::Round($bytes/1GB,2) ) GB" } }
$sizeFmt = fmtSize $totalSizeBefore

# Log summary if not WhatIf
if ($Delete -and -not $WhatIf) {
    Add-Content -Path $logPath -Value ""
    Add-Content -Path $logPath -Value "Summary:"
    Add-Content -Path $logPath -Value "Files removed: $totalFilesBefore"
    Add-Content -Path $logPath -Value "Total size recovered: $sizeFmt"
    if ($RemoveEmpty -and $removedDirs.Count -gt 0) {
        Add-Content -Path $logPath -Value "Empty folders removed: $($removedDirs.Count)"
    }
}

if ($Delete) {
    Write-Output "Files removed: $totalFilesBefore"
    Write-Output "Recovered: $sizeFmt"
    if ($WhatIf) { Write-Output "This was a WhatIf simulation. No files actually deleted." }
} else {
    Write-Output "Files to remove: $totalFilesBefore"
    Write-Output "Potential recoverable: $sizeFmt"
    Write-Output 'Report-only mode.'
}
