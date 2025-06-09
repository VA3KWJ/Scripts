<#
Fcln.ps1 — CSV-backed cleaner + HTML report with Delete/Recycle options
Compatible with Windows PowerShell 5.1+
#>

param(
    [string[]]$Path        = @(),
    [datetime]$Date,
    [int]    $Before,
    [switch] $IncludeUser,
    [switch] $Delete,       # permanent deletion
    [switch] $Recycle,      # move files to Recycle Bin
    [switch] $ReportOnly,   # report only, no deletion
    [switch] $ForceExec,    # override skipping exec-containing folders
    [string] $ReportDir     = "$env:SystemDrive\FclnRpt"
)

# Interactive mode if no parameters provided
$InteractiveMode = $PSBoundParameters.Count -eq 0
if ($InteractiveMode) {
    cls
    Write-Host "Interactive Setup (defaults in brackets):"
    # Paths
    do {
        $inputPath = Read-Host "Enter path(s) to scan, comma-separated [C:\]"
        if (-not $inputPath) { $Path = @('C:\'); break }
        $arr = $inputPath.Split(',') | ForEach-Object { $_.Trim() }
        $invalid = $arr | Where-Object { -not (Test-Path $_) }
        if ($invalid) {
            Write-Host "Invalid path(s): $($invalid -join ', ')" -ForegroundColor Yellow
        } else {
            $Path = $arr; break
        }
    } while ($true)
    # IncludeUser (Y/N)
    do {
        $iu = Read-Host "Include user folders? (Y/N) [N]"
        $iu = $iu.Trim()
        if ([string]::IsNullOrWhiteSpace($iu) -or $iu.ToUpper() -eq 'N') {
            $IncludeUser = $false; break
        } elseif ($iu.ToUpper() -eq 'Y') {
            $IncludeUser = $true; break
        } else {
            Write-Host "Please enter Y or N." -ForegroundColor Yellow
        }
    } while ($true)
    # Mode (D/R/T)
    do {
        $mode = Read-Host "Mode - Delete (D), Recycle (R), Report (T) [T]"
        $mode = $mode.Trim()
        if ([string]::IsNullOrWhiteSpace($mode) -or $mode.ToUpper() -eq 'T') {
            $ReportOnly = $true; break
        } elseif ($mode.ToUpper() -eq 'D') {
            $Delete = $true; break
        } elseif ($mode.ToUpper() -eq 'R') {
            $Recycle = $true; break
        } else {
            Write-Host "Please enter D, R, or T." -ForegroundColor Yellow
        }
    } while ($true)
    # Cutoff selection
    do {
        $choice = Read-Host "Cutoff by Date or Days? Enter 'Date' or 'Before' [Date]"
        $choice = $choice.Trim()
        if ([string]::IsNullOrWhiteSpace($choice) -or $choice.ToUpper().StartsWith('D')) {
            do {
                $defDate = Get-Date -Format 'yyyy-MM-dd'
                $dateInput = Read-Host "Enter cutoff date (yyyy-MM-dd) [$defDate]"
                $dateInput = $dateInput.Trim()
                if ([string]::IsNullOrWhiteSpace($dateInput)) {
                    $Date = [datetime]::ParseExact($defDate,'yyyy-MM-dd',$null); break
                }
                try { $Date = [datetime]::ParseExact($dateInput,'yyyy-MM-dd',$null); break } catch { Write-Host "Invalid date format." -ForegroundColor Yellow }
            } while ($true)
            break
        } elseif ($choice.ToUpper().StartsWith('B')) {
            do {
                $daysInput = Read-Host "Enter number of days before cutoff [30]"
                $daysInput = $daysInput.Trim()
                if ([string]::IsNullOrWhiteSpace($daysInput)) { $Before = 30; break }
                if ([int]::TryParse($daysInput,[ref]0) -and [int]$daysInput -ge 0) { $Before = [int]$daysInput; break }
                Write-Host "Please enter a non-negative integer." -ForegroundColor Yellow
            } while ($true)
            break
        } else {
            Write-Host "Please enter 'Date' or 'Before'." -ForegroundColor Yellow
        }
    } while ($true)
}

# Elevation check
$me = [Security.Principal.WindowsIdentity]::GetCurrent()
$pr = New-Object Security.Principal.WindowsPrincipal($me)
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Please rerun this script as Administrator."; exit 1
}

# Validate modes when not interactive
if (-not $InteractiveMode) {
    if (($Delete -and $Recycle) -or ($ReportOnly -and ($Delete -or $Recycle))) {
        throw 'Use either -Delete, -Recycle, or -ReportOnly, but not combinations.'
    }
    if (-not ($Delete -or $Recycle -or $ReportOnly)) { $ReportOnly = $true }
}

# Determine mode text
if ($Delete)      { $ModeText = 'Delete' }
elseif ($Recycle) { $ModeText = 'Recycle' }
else              { $ModeText = 'Report' }

# Compute cutoff date
$Cutoff = if ($Date) { $Date } else { (Get-Date).AddDays(-$Before) }

# Normalize Path parameter
if ($Path -isnot [array]) { $Path = @($Path) }
$Path = $Path | ForEach-Object { $_.TrimEnd('\','/') }
if (-not $InteractiveMode -and -not $PSBoundParameters.ContainsKey('Path')) { $Path = 'C:\' }
$Path = $Path | Where-Object { Test-Path $_ }
if ($IncludeUser) { $Path += "$env:SystemDrive\Users" }

# Prepare report filenames
$rootKeyRaw   = ($Path -join '_').Split('\')[-1]
$invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
$regex        = "[{0}]" -f [Regex]::Escape($invalidChars)
$rootKey      = $rootKeyRaw -replace $regex, '_'
$timestamp    = Get-Date -Format 'yyyyMMdd-HHmmss'
if (-not (Test-Path $ReportDir)) { New-Item -ItemType Directory -Path $ReportDir | Out-Null }
$csvPath      = Join-Path $ReportDir "$timestamp-$ModeText-$rootKey.csv"
$htmlPath     = Join-Path $ReportDir "$timestamp-$ModeText-$rootKey.html"

# Application-related extensions to detect
$appExts = '.exe','.dll','.com','.sys','.ocx','.msi','.msu','.msp','.drv','.cpl','.msc','.scr','.vbs','.ps1','.bat','.cmd','.jar','.py','.sh'

# 1) Stream file list to CSV
"Root,Directory,FileName,Length,LastWriteTime" | Out-File -FilePath $csvPath -Encoding UTF8
foreach ($root in $Path) {
    # Gather all directories under root
    $allDirs = @($root) + (Get-ChildItem -Path $root -Directory -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    # Build skip list of dirs containing app files
    $skip = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($dir in $allDirs) {
        if (-not $ForceExec) {
            # Check for any application-related file in this directory (case-insensitive)
            $files = Get-ChildItem -Path $dir -File -ErrorAction SilentlyContinue
            if ($files | Where-Object { $appExts -contains $_.Extension.ToLower() }) {
                $skip.Add($dir) | Out-Null
            }
        }
    }
    # Exclude subdirectories of skipped folders
    foreach ($s in $skip) {
        Get-ChildItem -Path $s -Directory -Recurse -ErrorAction SilentlyContinue | ForEach-Object { $skip.Add($_.FullName) | Out-Null }
    }
    # Process safe dirs only
    foreach ($dir in $allDirs) {
        if ($skip.Contains($dir)) { continue }
        Get-ChildItem -Path $dir -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.LastWriteTime -lt $Cutoff -and
            -not $_.Attributes.ToString().Split(',').Contains('System') -and
            -not $_.Attributes.ToString().Split(',').Contains('Hidden') -and
            ($IncludeUser -or -not ($_.FullName -like "$env:SystemDrive\Users*")) -and
            ($appExts -notcontains $_.Extension.ToLower())
        } | ForEach-Object {
            "$root,$dir,$($_.Name),$($_.Length),$($_.LastWriteTime.ToString('s'))" |
                Out-File -FilePath $csvPath -Append -Encoding UTF8
        }
    }
}

# 2) Read CSV for stats
$records          = Import-Csv -Path $csvPath
$totalFilesBefore = $records.Count
$totalSizeBefore  = ($records | Measure-Object Length -Sum).Sum

# 3) Disk stats before deletion
$drive      = $Path[0].Split(':')[0] + ':'
$volBefore  = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$drive'"
$usedBefore = $volBefore.Size - $volBefore.FreeSpace

# 4) Perform deletion if requested
$deletedCount = 0
if ($Delete -or $Recycle) {
    foreach ($r in $records) {
        $full = Join-Path $r.Directory $r.FileName
        try {
            if ($Recycle) {
                [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
                    $full,[Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                    [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
                )
            } else {
                Remove-Item $full -Force -ErrorAction Stop
            }
            $deletedCount++
        } catch { }
    }
}

# 5) Remove empty directories
if ($Delete -or $Recycle) {
    $uniqueDirs = $records | Select-Object -ExpandProperty Directory -Unique
    foreach ($dir in $uniqueDirs) {
        if (Test-Path $dir) {
            if (-not (Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue)) {
                try { Remove-Item -LiteralPath $dir -Force -ErrorAction Stop } catch { }
            }
        }
    }
}

# 6) Disk stats after deletion
$volAfter  = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$drive'"
$usedAfter = $volAfter.Size - $volAfter.FreeSpace
$recovered = $usedBefore - $usedAfter

# 7) Generate HTML report
$css = @"
<style>
body{font-family:Segoe UI,Arial;margin:20px;}
table{border-collapse:collapse;width:100%;}
th,td{border:1px solid #ccc;padding:4px;text-align:left;font-size:14px;}
th{background:#f0f0f0;}
</style>
"@
$html = @"
<!DOCTYPE html>
<html><head><meta charset='utf-8'><title>Cleanup Report</title>$css</head><body>
<h1>Cleanup Report — $rootKey ($ModeText)</h1>
<p><b>Run:</b> $(Get-Date)&ensp;<b>Cutoff:</b> $($Cutoff.ToString('yyyy-MM-dd'))</p>
<table>
<tr><th>Stat</th><th>Value</th></tr>
<tr><td>Total files</td><td>$totalFilesBefore</td></tr>
<tr><td>Total size (GB)</td><td>$([math]::Round($totalSizeBefore/1GB,3))</td></tr>
<tr><td>Disk used before (GB)</td><td>$([math]::Round($usedBefore/1GB,3))</td></tr>
<tr><td>Disk used after (GB)</td><td>$([math]::Round($usedAfter/1GB,3))</td></tr>
<tr><td>Recovered (GB)</td><td>$([math]::Round($recovered/1GB,3))</td></tr>
</table>
<h2>Files by Directory</h2>
"@

foreach ($d in ($records | Select-Object -ExpandProperty Directory -Unique)) {
    $subset = $records | Where-Object Directory -EQ $d
    $html += "<details><summary><b>$d</b> — $($subset.Count) files</summary>"
    $html += "<table><tr><th>Name</th><th>Size (MB)</th><th>Last Modified</th></tr>"
    foreach ($r in $subset) {
        $sz = [math]::Round($r.Length/1MB,2)
        $html += "<tr><td>$($r.FileName)</td><td>$sz</td><td>$($r.LastWriteTime)</td></tr>"
    }
    $html += "</table></details>"
}
$html += "</body></html>"
$html | Set-Content -Path $htmlPath -Encoding UTF8

# 8) Final output & opening
Write-Output "CSV:  $csvPath"
Write-Output "HTML: $htmlPath"
if ($Recycle) { Write-Output "Files moved to Recycle Bin: $deletedCount" } elseif ($Delete) { Write-Output "Files permanently deleted: $deletedCount" } else { Write-Output "Report-only mode." }
Start-Process $htmlPath

