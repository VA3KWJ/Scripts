<#
fCln.ps1 — Hierarchical HTML report + optional cleaner
Compatible with Windows PowerShell 5.1 and later
#>

param(
    [string[]]$Path        = @(),
    [datetime]$Date,
    [int]     $Before,
    [switch]  $IncludeUser,
    [switch]  $Clean,
    [switch]  $ReportOnly,
    [string]  $ReportPath  = "$env:SystemDrive\FclnRpt"
)

#──────────────────────────────────────────────────────────────────────────────
# Require Administrator
#──────────────────────────────────────────────────────────────────────────────
$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "❌ Please rerun this script AS ADMINISTRATOR."
    exit 1
}

#──────────────────────────────────────────────────────────────────────────────
# Helpers
#──────────────────────────────────────────────────────────────────────────────
function GB($bytes) { [math]::Round($bytes / 1GB, 3) }
function MB($bytes) { [math]::Round($bytes / 1MB, 2) }
function IsUser($path){ $path -like "$env:SystemDrive\Users*" }

$CriticalNames = @('Windows','Program Files','Program Files (x86)','ProgramData')
$Failed        = @()
$tree          = @{ }

#──────────────────────────────────────────────────────────────────────────────
# Normalize -Path parameter
#──────────────────────────────────────────────────────────────────────────────
if ($Path -isnot [array]) { $Path = @($Path) }
if ($Path.Count -eq 1 -and $Path[0] -match ',') {
    $Path = $Path[0].Split(',') |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -ne '' }
}
$Path = $Path | Where-Object { $_ -is [string] }

#──────────────────────────────────────────────────────────────────────────────
# Default scan roots if none provided (exclude critical)
#──────────────────────────────────────────────────────────────────────────────
if (-not $PSBoundParameters.ContainsKey('Path') -or -not $Path) {
    $Path = Get-ChildItem C:\ -Directory -ErrorAction SilentlyContinue |
            Where-Object { $CriticalNames -notcontains $_.Name } |
            ForEach-Object FullName
}

#──────────────────────────────────────────────────────────────────────────────
# Warn and confirm if user explicitly included critical folders
#──────────────────────────────────────────────────────────────────────────────
$explicit = @()
foreach ($p in $Path) {
    $name = ([string]$p).TrimEnd('\') -replace '^[A-Za-z]:\\',''
    if ($CriticalNames -contains $name) { $explicit += $p }
}
if ($explicit) {
    Write-Warning "You’ve explicitly included critical folder(s):`n$($explicit -join "`n")"
    if ((Read-Host "Type Y to continue") -ne 'Y') {
        Write-Host 'Aborted.'
        exit
    }
}

#──────────────────────────────────────────────────────────────────────────────
# Validate Date/Before and mode combinations
#──────────────────────────────────────────────────────────────────────────────
if (-not $Date -and -not $PSBoundParameters.ContainsKey('Before')) {
    Write-Error '❌ Supply -Date or -Before.'; exit
}
if ($Date -and $PSBoundParameters.ContainsKey('Before')) {
    throw '❌ Use -Date OR -Before, not both.'
}
if ($PSBoundParameters.ContainsKey('Before') -and $Before -lt 0) {
    throw '❌ -Before must be ≥ 0.'
}
if ($Clean -and $ReportOnly) {
    throw '❌ Use -Clean OR -ReportOnly, not both.'
}

$DoDelete = $Clean.IsPresent -and -not $ReportOnly.IsPresent
$Cutoff   = if ($Date) { $Date } else { (Get-Date).AddDays(-$Before) }

#──────────────────────────────────────────────────────────────────────────────
# Optionally include C:\Users
#──────────────────────────────────────────────────────────────────────────────
if ($IncludeUser) {
    $u = "$env:SystemDrive\Users"
    if ($Path -notcontains $u) { $Path += $u }
}

#──────────────────────────────────────────────────────────────────────────────
# Prepare report folder and filename
#──────────────────────────────────────────────────────────────────────────────
if (-not (Test-Path $ReportPath)) {
    New-Item -Type Directory -Path $ReportPath | Out-Null
}
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$html  = Join-Path $ReportPath "FclnRpt_$stamp.html"

#──────────────────────────────────────────────────────────────────────────────
# 1) Build in-memory tree of matched files
#──────────────────────────────────────────────────────────────────────────────
foreach ($root in $Path) {
    if (-not (Test-Path $root)) {
        Write-Warning "Skip path not found: $root"
        continue
    }
    Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue |
    Where-Object {
        $_.LastWriteTime -lt $Cutoff -and
        -not $_.Attributes.ToString().Split(',').Contains('System') -and
        -not $_.Attributes.ToString().Split(',').Contains('Hidden') -and
        ($IncludeUser -or -not (IsUser $_.FullName))
    } | ForEach-Object {
        $item      = $_
        $directory = $item.DirectoryName
        while ($directory) {
            if (-not $tree.ContainsKey($directory)) {
                $tree[$directory] = [ordered]@{ Files = @(); Bytes = 0; Sub = @{} }
            }
            $tree[$directory].Files += $item
            $tree[$directory].Bytes += $item.Length

            $parent = [IO.Path]::GetDirectoryName($directory)
            if ($parent) {
                if (-not $tree.ContainsKey($parent)) {
                    $tree[$parent] = [ordered]@{ Files = @(); Bytes = 0; Sub = @{} }
                }
                $tree[$parent].Sub[$directory] = $tree[$directory]
            }
            $directory = $parent
        }
    }
}

#──────────────────────────────────────────────────────────────────────────────
# 2) Compute stats & capture free-space BEFORE deletion
#──────────────────────────────────────────────────────────────────────────────
$unique      = $tree.Values | ForEach-Object Files | Select-Object -ExpandProperty FullName -Unique
$totalBefore = $unique.Count

$driveLetters  = $Path | ForEach-Object { ($_ -split ':')[0] } | Sort-Object -Unique
$freeBeforeMap = @{}
foreach ($dl in $driveLetters) {
    $vol = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='${dl}:'"
    if ($vol) { $freeBeforeMap[$dl] = [int64]$vol.FreeSpace }
}

#──────────────────────────────────────────────────────────────────────────────
# 3) Perform deletion if requested (track deleted files & errors)
#──────────────────────────────────────────────────────────────────────────────
$DeletedList = @()
if ($DoDelete) {
    foreach ($f in $unique) {
        try {
            $length = (Get-Item $f -ErrorAction Stop).Length
            Remove-Item $f -Force -ErrorAction Stop
            $DeletedList += [pscustomobject]@{ FullName = $f; Length = $length }
        } catch {
            $Failed += $f
        }
    }
    $Failed = $Failed | Where-Object { Test-Path $_ }

    # remove empty directories that held matched files (deepest first)
    $tree.Keys |
      Where-Object { $tree[$_].Files.Count -gt 0 } |
      Sort-Object { $_.Split('\').Count } -Descending |
      ForEach-Object {
        try { Remove-Item $_ -Force -Recurse -ErrorAction Stop }
        catch { $Failed += $_ }
      }
}

#──────────────────────────────────────────────────────────────────────────────
# 4) Capture free-space AFTER deletion & compute recovered space
#──────────────────────────────────────────────────────────────────────────────
$freeAfterMap = @{}
foreach ($dl in $driveLetters) {
    $vol = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='${dl}:'"
    if ($vol) { $freeAfterMap[$dl] = [int64]$vol.FreeSpace }
}

$driveRecovered = 0
foreach ($dl in $driveLetters) {
    $driveRecovered += ($freeBeforeMap[$dl] - $freeAfterMap[$dl])
}

# compute used before and after
$driveUsedBefore = 0
foreach ($dl in $driveLetters) {
    $vol = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='${dl}:'"
    if ($vol) {
        $driveUsedBefore += ($vol.Size - $freeBeforeMap[$dl])
    }
}
$driveUsedAfter = $driveUsedBefore - $driveRecovered

#──────────────────────────────────────────────────────────────────────────────
# 5) HTML rendering function
#──────────────────────────────────────────────────────────────────────────────
function DirHtml($path, $node, $level) {
    $pad  = 20 * $level
    $safe = $path -replace '<','&lt;' -replace '>','&gt;'
    $cnt  = $node.Files.Count
    $gb   = GB $node.Bytes
    $open = "<a href='file:///$($path -replace '\\','/')' target='_blank' style='font-size:small;margin-left:8px;'>(Open)</a>"

    $html = "<details class='dir' style='margin-left:${pad}px'><summary>"
    $html += "&#8250;<span class='path'>$safe</span><span class='num'>$cnt</span><span class='num'>$gb GB</span> $open"
    $html += "</summary>"

    if ($cnt -gt 0) {
        $html += "<table>"
        foreach ($f in $node.Files) {
            $name = $f.Name -replace '<','&lt;' -replace '>','&gt;'
            if ($Failed -contains $f.FullName) {
                $name = "<span style='color:red'>$name</span>"
            }
            $sz = MB $f.Length
            $html += "<tr><td class='file'>$name</td><td class='num'>$sz MB</td></tr>"
        }
        $html += "</table>"
    }

    foreach ($kv in $node.Sub.GetEnumerator() | Sort-Object Key) {
        $html += DirHtml $kv.Key $kv.Value ($level + 1)
    }
    $html += "</details>"
    return $html
}

$css = @"
<style>
body{font-family:Segoe UI,Arial;margin:40px;max-width:1000px;}
.dir{margin-top:6px;}
summary{cursor:pointer;font-weight:bold;display:grid;grid-template-columns:20px 1fr 80px 100px;gap:10px;align-items:center;}
summary::-webkit-details-marker{display:none;}
.path{text-overflow:ellipsis;overflow:hidden;white-space:nowrap;}
.num{font-family:Consolas,monospace;text-align:right;}
.dir table{border-collapse:collapse;margin:6px 0 0 35px;font-size:13px;width:auto;}
.dir td{border:1px solid #ccc;padding:2px 6px;}
.file{font-style:italic;color:#555;word-break:break-all;max-width:600px;}
</style>
"@

#──────────────────────────────────────────────────────────────────────────────
# 6) Build HTML summary
#──────────────────────────────────────────────────────────────────────────────
$totalAfter = if ($DoDelete) { $totalBefore - $DeletedList.Count } else { $totalBefore }
$failCount  = $Failed.Count

$summary  = "<p><b>Run:</b> $(Get-Date -Format 'yyyy-MM-dd')&emsp;<b>Cut-off:</b> $(Get-Date $Cutoff -Format 'yyyy-MM-dd')<br>"
if ($DoDelete) {
    $summary += "<b>Total files before:</b> $totalBefore&emsp;<b>Total files after:</b> $totalAfter&emsp;<b>Files removed:</b> $($DeletedList.Count)&emsp;<b>Failures:</b> $failCount<br>"
    $summary += "<b>Disk used before:</b> $(GB $driveUsedBefore) GB&emsp;<b>Disk used after:</b> $(GB $driveUsedAfter) GB&emsp;<b>Disk recovered:</b> $(GB $driveRecovered) GB</p>"
    $summary += "<h2>Deleted Files</h2><ul>"
    foreach ($d in $DeletedList) {
        $summary += "<li>$($d.FullName) — $(MB $d.Length) MB</li>"
    }
    $summary += "</ul>"
}
else {
    $summary += "<b>Total files:</b> $totalBefore&emsp;<b>Disk used:</b> $(GB $driveUsedBefore) GB<br>"
    $summary += "<b>Mode:</b> Report-only&emsp;<b>User data included:</b> $($IncludeUser.IsPresent)</p>"
}

#──────────────────────────────────────────────────────────────────────────────
# 7) Write out HTML report
#──────────────────────────────────────────────────────────────────────────────
@"
<!DOCTYPE html>
<html>
<head><meta charset='utf-8'><title>File Clean-up Report</title>$css</head>
<body>
<h1>File Clean-up Report</h1>
$summary
"@ | Set-Content -Path $html

foreach ($r in $Path | Sort-Object) {
    if ($tree.ContainsKey($r)) {
        Add-Content -Path $html -Value (DirHtml $r $tree[$r] 0)
    }
}
Add-Content -Path $html -Value "</body></html>"

#──────────────────────────────────────────────────────────────────────────────
# 8) Open report & finalize
#──────────────────────────────────────────────────────────────────────────────
Invoke-Item -Path $html
Write-Output "✔ Report generated: $html"
if ($DoDelete) {
    Write-Output "✔ Clean-up complete. ($($DeletedList.Count) files removed)"
} else {
    Write-Output "✔ Report-only — no deletions performed."
}
