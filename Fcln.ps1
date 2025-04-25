<#
 Fcln.ps1 – Hierarchical HTML/PDF report • optional cleaner
 Compatible with Windows PowerShell 5.1 and PowerShell 7

 EXAMPLES
   .\Fcln.ps1 -Before 1 -Path C:\Temp,C:\Logs           # report-only
   .\Fcln.ps1 -Before 1 -IncludeUser -Clean             # delete files
   .\Fcln.ps1 -Date 2024-01-01 -Format Both             # HTML + PDF
#>

param(
    [string[]]$Path = @("$env:SystemDrive\Temp"),

    [datetime]$Date,
    [int]      $Before,

    [switch]$IncludeUser,
    [switch]$Clean,
    [switch]$ReportOnly,

    [ValidateSet('HTML','PDF','Both')][string]$Format = 'HTML',
    [string]$EdgePath,
    [string]$ReportPath = "$env:SystemDrive\FclnRpt"
)

#── normalise -Path: split comma-separated lists passed as one string ───
if ($Path.Count -eq 1 -and $Path[0] -match ',') {
    $Path = $Path[0].Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

#──────────────── elevate if not admin ──────────────────────────────────
$iden  = [Security.Principal.WindowsIdentity]::GetCurrent()
$princ = New-Object Security.Principal.WindowsPrincipal $iden
$admin = $princ.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $admin) {
    # rebuild args so arrays (e.g. -Path) survive
    $argList = @()
    foreach ($kv in $PSBoundParameters.GetEnumerator()) {
        if ($kv.Value -is [switch]) {
            if ($kv.Value.IsPresent) { $argList += "-$($kv.Key)" }
        }
        elseif ($kv.Value -is [string[]]) {
            foreach ($v in $kv.Value) {
                $argList += "-$($kv.Key)"; $argList += ('"'+$v+'"')
            }
        }
        else {
            $argList += "-$($kv.Key)"; $argList += ('"'+$kv.Value+'"')
        }
    }
    if ($MyInvocation.UnboundArguments) { $argList += $MyInvocation.UnboundArguments }
    Start-Process powershell "-ExecutionPolicy Bypass -File `"$PSCommandPath`" $($argList -join ' ')" -Verb RunAs
    exit
}

#──────────────── validate selectors ────────────────────────────────────
if (-not $Date -and -not $PSBoundParameters.ContainsKey('Before')) {
    Write-Host 'Supply -Date or -Before.' ; exit
}
if ($Date -and $PSBoundParameters.ContainsKey('Before')) { throw 'Use -Date OR -Before.' }
if ($PSBoundParameters.ContainsKey('Before') -and $Before -lt 0) { throw '-Before ≥ 0' }
if ($Clean -and $ReportOnly) { throw 'Use -Clean OR -ReportOnly.' }

$DoDelete = $Clean.IsPresent -and (-not $ReportOnly.IsPresent)
$Cutoff   = $Date; if (-not $Date) { $Cutoff = (Get-Date).AddDays(-$Before) }

#──────────────── auto-add C:\Users when -IncludeUser ───────────────────
if ($IncludeUser) {
    $u = "$env:SystemDrive\Users"
    if (-not ($Path | Where-Object { $_.TrimEnd('\') -ieq $u })) { $Path += $u }
}

#──────────────── output paths ──────────────────────────────────────────
if (-not (Test-Path $ReportPath)) { New-Item -Type Directory $ReportPath | Out-Null }
$stamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
$html   = Join-Path $ReportPath "FclnRpt_$stamp.html"
$pdf    = [IO.Path]::ChangeExtension($html,'pdf')

#──────────────── Edge for PDF (simple search) ──────────────────────────
function Get-Edge($ov){
    if ($ov -and (Test-Path $ov)) { return $ov }
    $p1="$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
    $p2="${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
    if (Test-Path $p1){return $p1} elseif (Test-Path $p2){return $p2}
    return $null
}
$Edge = Get-Edge $EdgePath
if ($Format -ne 'HTML' -and -not $Edge) {
    Write-Warning 'Edge not found – switching to HTML.' ; $Format='HTML'
}

#──────────────── helpers ───────────────────────────────────────────────
$userRoot = "$env:SystemDrive\Users"
function IsUser($p){ $p -like "$userRoot*" }
function GB($b){ [math]::Round($b/1GB,3) }
function MB($b){ [math]::Round($b/1MB,2) }

#──────────────── build tree of matches ─────────────────────────────────
$tree=@{}
foreach ($root in $Path) {
    if (-not (Test-Path $root)) { Write-Warning "Skip '$root'"; continue }
    Get-ChildItem -Lit $root -File -Recurse -EA SilentlyContinue |
    Where-Object {
        $_.LastWriteTime -lt $Cutoff -and
        -not $_.Attributes.ToString().Split(',').Contains('System') -and
        -not $_.Attributes.ToString().Split(',').Contains('Hidden') -and
        ($IncludeUser -or -not (IsUser $_.FullName))
    } | ForEach-Object {
        $dir=$_.DirectoryName
        while($dir){
            if (-not $tree.ContainsKey($dir)){
                $tree[$dir]=[ordered]@{Files=@();Bytes=0;Sub=@{}}
            }
            if ($dir -eq $_.DirectoryName){$tree[$dir].Files += $_}
            $tree[$dir].Bytes += $_.Length
            $par=[IO.Path]::GetDirectoryName($dir)
            if($par){
                if(-not $tree.ContainsKey($par)){ $tree[$par]=[ordered]@{Files=@();Bytes=0;Sub=@{}} }
                $tree[$par].Sub[$dir]=$tree[$dir]
            }
            $dir=$par
        }
    }
}

#──────────────── delete if requested ───────────────────────────────────
if ($DoDelete){
    $del = $tree.Values | ForEach-Object {$_.Files} | Where-Object {$_}
    if ($del.Count -gt 0 -and $PSCmdlet.ShouldProcess('matched files','Delete')){
        $del | Remove-Item -Force -EA SilentlyContinue
    }
}

#──────────────── HTML report (aligned grid) ────────────────────────────
function DirHtml([string]$p,$n,[int]$d){
    $pad=20*$d
    $safe=$p -replace '<','&lt;' -replace '>','&gt;'
    $cnt =$n.Files.Count
    $gb  =GB $n.Bytes
    $h="<details class='dir' style='margin-left:${pad}px'>"
    $h+="<summary>&#8250;<span class='path'>$safe</span><span class='num'>$cnt</span><span class='num'>$gb&nbsp;GB</span></summary>"
    if($cnt){
        $h+="<table>"
        foreach($f in $n.Files){
            $fs=$f.Name -replace '<','&lt;' -replace '>','&gt;'
            $h+="<tr><td class='file'>$fs</td><td class='num'>$(MB $f.Length)&nbsp;MB</td></tr>"
        }
        $h+="</table>"
    }
    foreach($kv in $n.Sub.GetEnumerator()|Sort-Object Key){$h+=DirHtml $kv.Key $kv.Value ($d+1)}
    $h+="</details>"
    $h
}

$css=@"
<style>
body{font-family:Segoe UI,Arial;margin:40px;max-width:1000px;}
.dir{margin-top:6px;}
summary{cursor:pointer;font-weight:bold;display:grid;grid-template-columns:20px 1fr 80px 100px;gap:10px;align-items:center;}
summary::-webkit-details-marker{display:none;}
.path{text-overflow:ellipsis;overflow:hidden;white-space:nowrap;}
.num{font-family:Consolas,monospace;text-align:right;}
.dir table{border-collapse:collapse;margin:6px 0 0 35px;font-size:13px;width:auto;}
.dir td{border:1px solid #ccc;padding:2px 6px;}
.file{font-style:italic;color:#555;max-width:600px;word-break:break-all;}
</style>
"@

@"
<!DOCTYPE html><html><head><meta charset='utf-8'><title>Clean-up Report</title>$css</head><body>
<h1>File Clean-up Report</h1>
<p><b>Run:</b> $(Get-Date)&emsp;<b>Cut-off:</b> $Cutoff<br>
<b>Mode:</b> $(if($DoDelete){'Clean'}else{'Report-only'})&emsp;
<b>User data included:</b> $($IncludeUser.IsPresent)</p>
"@ | Set-Content $html

foreach($root in $Path|Sort-Object){
    if($tree.ContainsKey($root)){ Add-Content $html (DirHtml $root $tree[$root] 0) }
}

Add-Content $html "</body></html>"

#──────────────── PDF (optional) ────────────────────────────────────────
if ($Format -eq 'PDF' -or $Format -eq 'Both') {
    & $Edge --headless --disable-gpu --print-to-pdf="$pdf" "file:///$html" 2>$null
    if ($Format -eq 'PDF') { Remove-Item $html }
}

#──────────────── open report & summary ─────────────────────────────────
switch ($Format) {
    'HTML' { Start-Process $html; Write-Output "✔ HTML report: $html" }
    'PDF'  { Start-Process $pdf ; Write-Output "✔ PDF report:  $pdf"  }
    'Both' { Start-Process $html; Write-Output "✔ HTML: $html  |  PDF: $pdf" }
}
Write-Output ($(if($DoDelete){'✔ Clean-up complete.'}else{'✔ Report-only run – no deletions.'}))
