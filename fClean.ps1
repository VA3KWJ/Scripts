<#
 Fcln.ps1 – hierarchical HTML report • optional cleaner
 Windows PowerShell 5.1 compatible

 EXAMPLES
   .\Fcln.ps1 -Before 30
   .\Fcln.ps1 -Before 7 -Path C:\Temp,'D:\Logs'
   .\Fcln.ps1 -Date 2024-01-01 -IncludeUser -Clean
#>

param(
    [string[]]$Path,
    [datetime]$Date,
    [int]      $Before,
    [switch]   $IncludeUser,
    [switch]   $Clean,
    [switch]   $ReportOnly,
    [string]   $ReportPath = "$env:SystemDrive\FclnRpt"
)

#── Helpers ──────────────────────────────────────────────────────────────
function IsUser($p){ $p -like "$env:SystemDrive\Users*" }
function GB($b){ [math]::Round($b/1GB,3) }
function MB($b){ [math]::Round($b/1MB,2) }

$CriticalNames = @('Windows','Program Files','Program Files (x86)','ProgramData')

#── Normalize comma-delimited -Path ─────────────────────────────────────
if ($Path -and $Path.Count -eq 1 -and $Path[0] -match ',') {
    $Path = $Path[0].Split(',') |
            ForEach-Object { $_.Trim() } |
            Where-Object   { $_ }
}

#── Elevate if not Administrator ────────────────────────────────────────
$wi  = [Security.Principal.WindowsIdentity]::GetCurrent()
$adm = (New-Object Security.Principal.WindowsPrincipal $wi).
       IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $adm) {
    $args=@()
    foreach($kv in $PSBoundParameters.GetEnumerator()){
        if($kv.Value -is [switch]){
            if($kv.Value.IsPresent){ $args += "-$($kv.Key)" }
        } elseif($kv.Value -is [string[]]){
            foreach($v in $kv.Value){ $args += "-$($kv.Key)"; $args += "`"$v`"" }
        } else {
            $args += "-$($kv.Key)"; $args += "`"$($kv.Value)`""
        }
    }
    Start-Process powershell "-ExecutionPolicy Bypass -File `"$PSCommandPath`" $($args -join ' ')" -Verb RunAs
    exit
}

#── Auto-derive -Path if omitted ─────────────────────────────────────────
if (-not $PSBoundParameters.ContainsKey('Path')) {
    $Path = Get-CimInstance Win32_LogicalDisk |
            Where-Object DriveType -eq 3 |
            ForEach-Object { "$($_.DeviceID)\" }
}

#── Validate selectors ──────────────────────────────────────────────────
if (-not $Date -and -not $PSBoundParameters.ContainsKey('Before')) {
    Write-Host 'Supply -Date or -Before.'; exit
}
if ($Date -and $PSBoundParameters.ContainsKey('Before')) {
    throw 'Use -Date OR -Before, not both.'
}
if ($PSBoundParameters.ContainsKey('Before') -and $Before -lt 0) {
    throw '-Before must be ≥ 0.'
}
if ($Clean -and $ReportOnly) {
    throw 'Use -Clean OR -ReportOnly, not both.'
}

$DoDelete = $Clean.IsPresent -and (-not $ReportOnly.IsPresent)
$Cutoff   = if ($Date) { $Date } else { (Get-Date).AddDays(-$Before) }

#── Include C:\Users if requested ───────────────────────────────────────
if ($IncludeUser) {
    $u = "$env:SystemDrive\Users"
    if (-not ($Path | Where-Object { $_.TrimEnd('\') -ieq $u })) {
        $Path += $u
    }
}

#── Prepare HTML report path ────────────────────────────────────────────
if (-not (Test-Path $ReportPath)) {
    New-Item -Type Directory $ReportPath | Out-Null
}
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$html  = Join-Path $ReportPath "FclnRpt_$stamp.html"

#── Build tree of matched files ─────────────────────────────────────────
$tree = @{}
foreach ($root in $Path) {
    if (-not (Test-Path $root)) {
        Write-Warning "Skip '$root' (not found)"; continue
    }

    if ($root -match '^[A-Za-z]:\\$') {
        # root-level files
        $files = Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue
        # then subdirs except critical
        $dirs = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
                Where-Object { $CriticalNames -notcontains $_.Name }
        foreach ($d in $dirs) {
            $files += Get-ChildItem -LiteralPath $d.FullName -File -Recurse -ErrorAction SilentlyContinue
        }
    }
    else {
        $files = Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue
    }

    foreach ($f in $files) {
        if ($f.LastWriteTime -ge $Cutoff)            { continue }
        if ($f.Attributes -match 'System|Hidden')     { continue }
        if (-not $IncludeUser.IsPresent -and (IsUser $f.FullName)) { continue }

        $d = $f.DirectoryName
        while ($d) {
            if (-not $tree[$d]) {
                $tree[$d] = [ordered]@{ Files=@(); Bytes=0; Sub=@{} }
            }
            $tree[$d].Files += $f
            $tree[$d].Bytes += $f.Length

            $p = [IO.Path]::GetDirectoryName($d)
            if ($p) {
                if (-not $tree[$p]) {
                    $tree[$p] = [ordered]@{ Files=@(); Bytes=0; Sub=@{} }
                }
                $tree[$p].Sub[$d] = $tree[$d]
            }
            $d = $p
        }
    }
}

#── Delete if requested ─────────────────────────────────────────────────
if ($DoDelete) {
    $toDel = $tree.Values | ForEach-Object { $_.Files } | Where-Object { $_ }
    if ($toDel.Count -gt 0 -and $PSCmdlet.ShouldProcess('matched files','Delete')) {
        $toDel | Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

#── Recursive HTML builder ──────────────────────────────────────────────
function DirHtml([string]$path, $node, [int]$lvl) {
    $pad  = 20 * $lvl
    $safe = $path -replace '<','&lt;' -replace '>','&gt;'
    $cnt  = $node.Files.Count
    $gb   = GB $node.Bytes

    $h  = "<details class='dir' style='margin-left:${pad}px'>"
    $h += "<summary>&#8250;<span class='path'>$safe</span>"
    $h += "<span class='num'>$cnt</span><span class='num'>$gb&nbsp;GB</span></summary>"

    if ($lvl -gt 0 -and $cnt) {
        $h += "<table>"
        foreach ($f in $node.Files) {
            $fn = $f.Name -replace '<','&lt;' -replace '>','&gt;'
            $ms = MB $f.Length
            $h += "<tr><td class='file'>$fn</td><td class='num'>$ms&nbsp;MB</td></tr>"
        }
        $h += "</table>"
    }

    foreach ($kv in $node.Sub.GetEnumerator() | Sort-Object Key) {
        $h += DirHtml $kv.Key $kv.Value ($lvl+1)
    }
    $h += "</details>"
    return $h
}

#── Write HTML ──────────────────────────────────────────────────────────
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

@"
<!DOCTYPE html>
<html><head><meta charset='utf-8'><title>File Clean-up Report</title>$css</head><body>
<h1>File Clean-up Report</h1>
<p><b>Run:</b> $(Get-Date)&emsp;<b>Cut-off:</b> $Cutoff<br>
<b>Mode:</b> $(if($DoDelete){'Clean'}else{'Report-only'})&emsp;
<b>User data included:</b> $($IncludeUser.IsPresent)</p>
"@ | Set-Content $html

foreach ($r in $Path | Sort-Object) {
    if ($tree[$r]) {
        Add-Content $html (DirHtml $r $tree[$r] 0)
    }
}

Add-Content $html "</body></html>"

#── Launch report ───────────────────────────────────────────────────────
Invoke-Item $html
Write-Output "✔ HTML report: $html"
if ($DoDelete) {
    Write-Output '✔ Clean-up complete.'
} else {
    Write-Output '✔ Report-only run – no deletions.'
}
