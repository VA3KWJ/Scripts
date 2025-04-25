<#
 Fcln.ps1 – Hierarchical HTML report + optional cleaner
 Windows PowerShell 5.1 compatible
#>

param(
    [string[]]$Path       = @(),
    [datetime]$Date,
    [int]    $Before,
    [switch] $IncludeUser,
    [switch] $Clean,
    [switch] $ReportOnly,
    [string] $ReportPath  = "$env:SystemDrive\FclnRpt"
)

#───────────────────────────────────────────────────────────────────────────
# Must be run as Admin
#───────────────────────────────────────────────────────────────────────────
$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "❌ Please rerun this script AS ADMINISTRATOR."
    exit 1
}

#───────────────────────────────────────────────────────────────────────────
# Helpers and globals
#───────────────────────────────────────────────────────────────────────────
$CriticalNames = @('Windows','Program Files','Program Files (x86)','ProgramData')
$Failed        = @()
$tree          = @{}
function IsUser($p){ $p -like "$env:SystemDrive\Users*" }
function GB($b)   { [math]::Round($b/1GB,3) }
function MB($b)   { [math]::Round($b/1MB,2) }

#───────────────────────────────────────────────────────────────────────────
# Normalize Path to string array
#───────────────────────────────────────────────────────────────────────────
if ($Path -isnot [array]) { $Path = @($Path) }
if ($Path.Count -eq 1 -and $Path[0] -match ',') {
    $Path = $Path[0].Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}
$Path = $Path | Where-Object { $_ -is [string] }

#───────────────────────────────────────────────────────────────────────────
# If no -Path, default to C:\ root minus critical folders
#───────────────────────────────────────────────────────────────────────────
if (-not $PSBoundParameters.ContainsKey('Path') -or -not $Path) {
    $Path = Get-ChildItem -Path C:\ -Directory -ErrorAction SilentlyContinue |
            Where-Object { $CriticalNames -notcontains $_.Name } |
            ForEach-Object { $_.FullName }
}

#───────────────────────────────────────────────────────────────────────────
# Confirm if user explicitly included any critical folder
#───────────────────────────────────────────────────────────────────────────
$explicit = @()
foreach ($p in $Path) {
    # strip drive letter and trailing slashes
    $name = ([string]$p).TrimEnd('\') -replace '^[A-Za-z]:\\',''
    if ($CriticalNames -contains $name) {
        $explicit += $p
    }
}
if ($explicit) {
    Write-Warning "You’ve explicitly included critical folder(s):`n$($explicit -join "`n")"
    $y = Read-Host "Type Y to CONTINUE scanning them"
    if ($y -ne 'Y') { Write-Host 'Aborted.'; exit }
}

#───────────────────────────────────────────────────────────────────────────
# Validate Date/Before and modes
#───────────────────────────────────────────────────────────────────────────
if (-not $Date -and -not $PSBoundParameters.ContainsKey('Before')) {
    Write-Host '❌ Supply -Date or -Before.'; exit
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

#───────────────────────────────────────────────────────────────────────────
# Optionally include C:\Users
#───────────────────────────────────────────────────────────────────────────
if ($IncludeUser) {
    $u = "$env:SystemDrive\Users"
    if (-not ($Path -contains $u)) { $Path += $u }
}

#───────────────────────────────────────────────────────────────────────────
# Prepare report output
#───────────────────────────────────────────────────────────────────────────
if (-not (Test-Path $ReportPath)) { New-Item -ItemType Directory -Path $ReportPath | Out-Null }
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$html  = Join-Path $ReportPath "FclnRpt_$stamp.html"

#───────────────────────────────────────────────────────────────────────────
# Build file tree
#───────────────────────────────────────────────────────────────────────────
foreach ($root in $Path) {
    if (-not (Test-Path $root)) { Write-Warning "Skip '$root'"; continue }
    $files = Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        if ($f.LastWriteTime -ge $Cutoff)                          { continue }
        if ($f.Attributes -match 'System|Hidden')                  { continue }
        if (-not $IncludeUser.IsPresent -and (IsUser $f.FullName)) { continue }

        $d = $f.DirectoryName
        while ($d) {
            if (-not $tree[$d]) { $tree[$d] = [ordered]@{ Files=@(); Bytes=0; Sub=@{} } }
            $tree[$d].Files += $f
            $tree[$d].Bytes += $f.Length

            $p = [IO.Path]::GetDirectoryName($d)
            if ($p) {
                if (-not $tree[$p]) { $tree[$p] = [ordered]@{ Files=@(); Bytes=0; Sub=@{} } }
                $tree[$p].Sub[$d] = $tree[$d]
            }
            $d = $p
        }
    }
}

#───────────────────────────────────────────────────────────────────────────
# Pre-clean stats
#───────────────────────────────────────────────────────────────────────────
if ($DoDelete) {
    $totalMatched = ($tree.Values | ForEach-Object Files | Measure-Object).Count
    $PreBytes     = ($tree.Values | ForEach-Object Bytes | Measure-Object -Sum).Sum
}

#───────────────────────────────────────────────────────────────────────────
# Perform deletion
#───────────────────────────────────────────────────────────────────────────
if ($DoDelete) {
    $toDel = $tree.Values | ForEach-Object Files | Where-Object { $_ }
    foreach ($f in $toDel) {
        try { Remove-Item $f.FullName -Force -ErrorAction Stop }
        catch { $Failed += $f.FullName }
    }
    $removed     = $toDel.Count - $Failed.Count
    $PostBytes   = ($Failed | Where-Object { Test-Path $_ } |
                    ForEach-Object { (Get-Item $_).Length } | Measure-Object -Sum).Sum
    $RemovedBytes= $PreBytes - $PostBytes
}

#───────────────────────────────────────────────────────────────────────────
# HTML rendering
#───────────────────────────────────────────────────────────────────────────
function DirHtml($path,$node,$lvl) {
    $pad  = 20 * $lvl
    $safe = $path -replace '<','&lt;' -replace '>','&gt;'
    $cnt  = $node.Files.Count
    $gb   = GB $node.Bytes
    $open = "<a href='file:///$($path -replace '\\','/')' target='_blank' " +
            "style='font-size:small;margin-left:8px;'>(Open)</a>"

    $h  = "<details class='dir' style='margin-left:${pad}px'><summary>&#8250;"
    $h += "<span class='path'>$safe</span><span class='num'>$cnt</span><span class='num'>$gb GB</span> $open</summary>"

    if ($cnt) {
        $h += "<table>"
        foreach ($f in $node.Files) {
            $n = $f.Name -replace '<','&lt;' -replace '>','&gt;'
            if ($Failed -contains $f.FullName) { $n = "<span style='color:red'>$n</span>" }
            $h += "<tr><td class='file'>$n</td><td class='num'>$(MB $f.Length) MB</td></tr>"
        }
        $h += "</table>"
    }
    foreach ($kv in $node.Sub.GetEnumerator() | Sort-Object Key) {
        $h += DirHtml $kv.Key $kv.Value ($lvl+1)
    }
    $h += "</details>"
    return $h
}

$css = @"
<style>
body{font-family:Segoe UI,Arial;margin:40px;max-width:1000px;}
.dir{margin-top:6px;}
summary{cursor:pointer;font-weight:bold;
 display:grid;grid-template-columns:20px 1fr 80px 100px;gap:10px;align-items:center;}
summary::-webkit-details-marker{display:none;}
.path{text-overflow:ellipsis;overflow:hidden;white-space:nowrap;}
.num{font-family:Consolas,monospace;text-align:right;}
.dir table{border-collapse:collapse;margin:6px 0 0 35px;font-size:13px;width:auto;}
.dir td{border:1px solid #ccc;padding:2px 6px;}
.file{font-style:italic;color:#555;word-break:break-all;max-width:600px;}
</style>
"@

$summary = "<p><b>Run:</b> $(Get-Date)&emsp;<b>Cut-off:</b> $Cutoff<br>"
if ($DoDelete) {
    $summary += "<b>Matched:</b> $totalMatched files&emsp;<b>Removed:</b> $removed files&emsp;"
    $summary += "<b>Size before:</b> $(GB $PreBytes) GB&emsp;<b>Size after:</b> $(GB $PostBytes) GB&emsp;"
    $summary += "<b>Freed:</b> $(GB $RemovedBytes) GB</p>"
} else {
    $summary += "<b>Mode:</b> Report-only&emsp;<b>User data:</b> $($IncludeUser.IsPresent)</p>"
}

@"
<!DOCTYPE html><html><head><meta charset='utf-8'><title>Clean-up Report</title>$css</head><body>
<h1>File Clean-up Report</h1>
$summary
"@ | Set-Content -Path $html

foreach ($r in $Path | Sort-Object) {
    if ($tree[$r]) {
        Add-Content -Path $html -Value (DirHtml $r $tree[$r] 0)
    }
}
Add-Content -Path $html -Value "</body></html>"

Invoke-Item -Path $html
Write-Output "✔ Report generated: $html"
if ($DoDelete) { Write-Output '✔ Clean-up complete (failures in red).' }
else         { Write-Output '✔ Report-only run — no deletions performed.' }
