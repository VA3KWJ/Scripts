<#
Script Title      : fCln.ps1
Description       : File clean up by date with CSV reporting and PowerShell v4 compatibility
Initial Date      : 2026-06-01
Latest Revision   : 2025-06-25
Version           : 2.1.1 - Capture LastWriteTime before removing empty folders for CSV
Author            : Stuart Waller
GitHub            : https://github.com/VA3KWJ
#>

# ——————————————————————————————————————————————————————————————————————————————
# Parameter definitions
# ——————————————————————————————————————————————————————————————————————————————
param(
    [string[]]$Path        = @(),
    [datetime] $Date,
    [int]      $Before,
    [switch]   $IncludeUser,
    [switch]   $Delete,
    [switch]   $ReportOnly,
    [switch]   $ForceExec,
    [string]   $ReportDir   = "$env:SystemDrive\FclnRpt"
)

# ——————————————————————————————————————————————————————————————————————————————
# Interactive Mode Setup
# ——————————————————————————————————————————————————————————————————————————————
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
        elseif ($iu -eq 'Y')      { $IncludeUser = $true;  break }
    } while ($true)

    do {
        $mode = Read-Host "Mode - Delete (D) or Report (R) [R]"
        $mode = $mode.Trim().ToUpper()
        if ($mode -eq '' -or $mode -eq 'R') { $ReportOnly = $true; $Delete = $false; break }
        elseif ($mode -eq 'D')              { $Delete     = $true; $ReportOnly = $false; break }
    } while ($true)

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

# ——————————————————————————————————————————————————————————————————————————————
# Ensure running as Administrator
# ——————————————————————————————————————————————————————————————————————————————
$me = [Security.Principal.WindowsIdentity]::GetCurrent()
$pr = New-Object Security.Principal.WindowsPrincipal($me)
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Please rerun this script as Administrator."
    exit 1
}

# ——————————————————————————————————————————————————————————————————————————————
# Validate non-interactive parameters
# ——————————————————————————————————————————————————————————————————————————————
if (-not $Interactive) {
    if ($Delete -and $ReportOnly) { throw 'Use either -Delete or -ReportOnly.' }
    if (-not ($Delete -or $ReportOnly)) { $ReportOnly = $true }
}

# ——————————————————————————————————————————————————————————————————————————————
# Determine mode text for naming
# ——————————————————————————————————————————————————————————————————————————————
$ModeText = if ($Delete) { 'Delete' } else { 'Report' }

# ——————————————————————————————————————————————————————————————————————————————
# Validate -Date vs -Before logic
# ——————————————————————————————————————————————————————————————————————————————
if (-not $Interactive) {
    if (-not $Date -and -not $PSBoundParameters.ContainsKey('Before')) {
        Write-Error 'Supply -Date or -Before.'; exit
    }
    if ($Date -and $PSBoundParameters.ContainsKey('Before')) {
        throw 'Use -Date OR -Before, not both.'
    }
    if ($Before -lt 0) { throw '-Before must be >= 0.' }
}

# ——————————————————————————————————————————————————————————————————————————————
# Compute cutoff timestamp
# ——————————————————————————————————————————————————————————————————————————————
$Cutoff = if ($Date) { $Date } else { (Get-Date).AddDays(-$Before) }

# ——————————————————————————————————————————————————————————————————————————————
# Normalize and verify input paths
# ——————————————————————————————————————————————————————————————————————————————
if ($Path -isnot [array]) { $Path = @($Path) }
$Path = $Path |
    ForEach-Object { $_.TrimEnd('\','/') } |
    Where-Object  { Test-Path $_ }

if (-not $PSBoundParameters.ContainsKey('Path') -and -not $Interactive) {
    $Path = 'C:\'
}
if ($IncludeUser) {
    $Path += "$env:SystemDrive\Users"
}

# ——————————————————————————————————————————————————————————————————————————————
# Define file extensions to skip
# ——————————————————————————————————————————————————————————————————————————————
$appExts = '.exe','.dll','.com','.sys','.ocx','.msi','.msu','.msp',
           '.drv','.cpl','.msc','.scr','.vbs','.ps1','.bat','.cmd',
           '.jar','.py','.sh'

$fileList = @()

# ——————————————————————————————————————————————————————————————————————————————
# Scan directories and collect files older than cutoff
# ——————————————————————————————————————————————————————————————————————————————
foreach ($root in $Path) {
    $dirs = @($root) +
        (Get-ChildItem -Path $root -Directory -Recurse -ErrorAction SilentlyContinue |
         Select-Object -ExpandProperty FullName)

    $skip = New-Object System.Collections.ArrayList
    foreach ($d in $dirs) {
        if (-not $ForceExec) {
            if (Get-ChildItem -Path $d -File -ErrorAction SilentlyContinue |
                Where-Object { $appExts -contains $_.Extension.ToLower() }) {
                $skip.Add($d) | Out-Null
            }
        }
    }
    foreach ($s in @($skip)) {
        Get-ChildItem -Path $s -Directory -Recurse -ErrorAction SilentlyContinue |
            ForEach-Object { $skip.Add($_.FullName) | Out-Null }
    }

    foreach ($d in $dirs) {
        if ($skip.Contains($d) -and -not $ForceExec) { continue }
        Get-ChildItem -Path $d -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.LastWriteTime      -lt $Cutoff                              -and
            -not ($_.Attributes.ToString().Split(',') -contains 'System')  -and
            -not ($_.Attributes.ToString().Split(',') -contains 'Hidden')  -and
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

# ——————————————————————————————————————————————————————————————————————————————
# Totals before deletion
# ——————————————————————————————————————————————————————————————————————————————
$totalFilesBefore = $fileList.Count
$totalSizeBefore  = ($fileList | Measure-Object Length -Sum).Sum

# ——————————————————————————————————————————————————————————————————————————————
# Perform deletion if requested
# ——————————————————————————————————————————————————————————————————————————————
if ($Delete) {
    foreach ($f in $fileList) {
        try { Remove-Item (Join-Path $f.Directory $f.Name) -Force -ErrorAction Stop } catch {}
    }
    # Remove now-empty directories from file deletion
    $uniqueDirs = $fileList | Select-Object -ExpandProperty Directory -Unique
    foreach ($dir in $uniqueDirs) {
        if (Test-Path $dir -PathType Container) {
            if (-not (Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue)) {
                Remove-Item -LiteralPath $dir -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # ——————————————————————————————————————————————————————
    # Define Remove-EmptyFolders (captures LWT)
    # ——————————————————————————————————————————————————————
    function Remove-EmptyFolders {
        param([string[]]$Paths)
        $removed = @()
        $allDirs = foreach ($p in $Paths) {
            Get-ChildItem -Path $p -Directory -Recurse -Force -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty FullName
        }
        $allDirs += $Paths
        $allDirs = $allDirs | Sort-Object { $_.Length } -Descending
        foreach ($d in $allDirs) {
            if (Test-Path $d) {
                if (-not (Get-ChildItem -LiteralPath $d -Force -ErrorAction SilentlyContinue)) {
                    try {
                        $ldt = (Get-Item $d).LastWriteTime
                        Remove-Item -LiteralPath $d -Force -Recurse -ErrorAction Stop
                        $removed += [PSCustomObject]@{ Path        = $d; LastWriteTime = $ldt }
                        Write-Host "Removed empty folder: $d"
                    } catch {}
                }
            }
        }
        return $removed
    }

    # Prompt & capture removals
    $RemoveEmpty = $false
    $removedDirs = @()
    if ($Interactive) {
        do {
            $resp = Read-Host "Remove empty folders? (Y/N) [N]"
            $resp = $resp.Trim().ToUpper()
            if ($resp -eq '' -or $resp -eq 'N') { break }
            elseif ($resp -eq 'Y') {
                $RemoveEmpty = $true
                $removedDirs = Remove-EmptyFolders -Paths $Path
                break
            }
        } while ($true)
    }
}

# ——————————————————————————————————————————————————————————————————————————————
# Write report CSV including removed folders
# ——————————————————————————————————————————————————————————————————————————————
if (-not (Test-Path $ReportDir)) { New-Item -ItemType Directory -Path $ReportDir | Out-Null }
$timestamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$rootKeyRaw = ($Path -join '_')
$rootKey    = ($rootKeyRaw.Split('\')[-1] -replace '[\\/:*?"<>|]', '_')
$csvPath    = Join-Path $ReportDir "$timestamp-$ModeText-$rootKey.csv"

$reportObjects = @()

# File entries
$reportObjects += $fileList | ForEach-Object {
    [PSCustomObject]@{
        Root          = $_.Root
        Directory     = $_.Directory
        Name          = $_.Name
        'Size (KB)'   = [math]::Round($_.Length/1KB,2)
        LastWriteTime = $_.LastWriteTime.ToString('s')
    }
}
# Removed folder entries
if ($RemoveEmpty -and $removedDirs) {
    $reportObjects += $removedDirs | ForEach-Object {
        [PSCustomObject]@{
            Root          = Split-Path $_.Path -Qualifier
            Directory     = Split-Path $_.Path -Parent
            Name          = Split-Path $_.Path -Leaf
            'Size (KB)'   = 'DIR'
            LastWriteTime = $_.LastWriteTime.ToString('s')
        }
    }
}

$reportObjects | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

# ——————————————————————————————————————————————————————————————————————————————
# Summary output
# ——————————————————————————————————————————————————————————————————————————————
function fmtSize($bytes) {
    if ($bytes -lt 1GB) { "$( [math]::Round($bytes/1MB,2) ) MB" } else { "$( [math]::Round($bytes/1GB,2) ) GB" }
}
$sizeFmt = fmtSize $totalSizeBefore

if ($Delete) {
    Write-Output "Files removed: $totalFilesBefore"
    Write-Output "Recovered: $sizeFmt"
} else {
    Write-Output "Files to remove: $totalFilesBefore"
    Write-Output "Potential recoverable: $sizeFmt"
    Write-Output 'Report-only mode.'
}
