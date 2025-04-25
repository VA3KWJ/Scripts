<#
 Fcln.ps1 – clean hierarchical HTML/PDF report • optional cleaner
 Windows PowerShell 5.1 compatible

 EXAMPLE
   .\Fcln.ps1 -Before 1 -IncludeUser           # report-only, opens HTML
   .\Fcln.ps1 -Before 1 -IncludeUser -Clean    # delete, report, opens HTML
   .\Fcln.ps1 -Before 30 -Format PDF           # PDF only, opens PDF
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

#──────────────── Elevate if needed ─────────────────────────────────────
$win = [Security.Principal.WindowsIdentity]::GetCurrent()
$adm = (New-Object Security.Principal.WindowsPrincipal $win
       ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $adm) {
    $args = $MyInvocation.Line.Split(' ',2)[1]
    Start-Process powershell "-Exec Bypass -File `"$PSCommandPath`" $args" -Verb RunAs
    exit
}

#──────────────── Validate switches ─────────────────────────────────────
if (-not $Date -and -not $PSBoundParameters.ContainsKey('Before')) {
    Write-Host 'Supply -Date or -Before.'; exit }
if ($Date -and $PSBoundParameters.ContainsKey('Before')) { throw 'Use one selector.' }
if ($PSBoundParameters.ContainsKey('Before') -and $Before -lt 0){throw '-Before ≥ 0'}
if ($Clean -and $ReportOnly) { throw 'Use -Clean OR -ReportOnly' }

$DoDelete = $Clean.IsPresent -and (-not $ReportOnly.IsPresent)
$Cutoff   = $Date; if (-not $Date){ $Cutoff = (Get-Date).AddDays(-$Before) }

# auto-add C:\Users
if ($IncludeUser){
    $u = "$env:SystemDrive\Users"
    if (-not ($Path | Where-Object { $_.TrimEnd('\') -ieq $u })) { $Path += $u }
}

#──────────────── Prepare output paths ──────────────────────────────────
if (-not (Test-Path $ReportPath)){New-Item -Type Directory $ReportPath|Out-Null}
$stamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
$html   = Join-Path $ReportPath "FclnRpt_$stamp.html"
$pdf    = [IO.Path]::ChangeExtension($html,'pdf')

#──────────────── Edge (for PDF) ────────────────────────────────────────
function Get-Edge{
    param($ov)
    if ($ov -and (Test-Path $ov)){return $ov}
    foreach($p in @("$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
                    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe")){
        if (Test-Path $p){return $p}}
    $null
}
$Edge = Get-Edge $EdgePath
if ($Format -ne 'HTML' -and -not $Edge){
    Write-Warning 'Edge not found – switching to HTML'; $Format='HTML'
}

#──────────────── Helpers ───────────────────────────────────────────────
$userRoot="$env:SystemDrive\Users"
function IsUser($p){$p -like "$userRoot*"}
function GB($b){[math]::Round($b/1GB,3)}
function MB($b){[math]::Round($b/1MB,2)}

#──────────────── Build dir tree ────────────────────────────────────────
$tree=@{}
foreach($root in $Path){
    if(-not (Test-Path $root)){Write-Warning "Skip '$root'";continue}
    Get-ChildItem -Lit $root -Recurse -File -EA SilentlyContinue|
    Where-Object{
        $_.LastWriteTime -lt $Cutoff -and
        -not $_.Attributes.ToString().Split(',').Contains('System') -and
        -not $_.Attributes.ToString().Split(',').Contains('Hidden') -and
        ($IncludeUser -or -not (IsUser $_.FullName))
    }|ForEach-Object{
        $d=$_.DirectoryName
        while($d){
            if(-not $tree.ContainsKey($d)){
                $tree[$d]=[ordered]@{Files=@();Bytes=0;Sub=@{}}
            }
            if($d -eq $_.DirectoryName){$tree[$d].Files += $_}
            $tree[$d].Bytes += $_.Length
            $p=[IO.Path]::GetDirectoryName($d)
            if($p){
                if(-not $tree.ContainsKey($p)){
                    $tree[$p]=[ordered]@{Files=@();Bytes=0;Sub=@{}}
                }
                $tree[$p].Sub[$d]=$tree[$d]
            }
            $d=$p
        }
    }
}

#──────────────── Delete if -Clean ──────────────────────────────────────
if($DoDelete){
    $del=$tree.Values|ForEach-Object{$_.Files}|Where-Object{$_}
    if($del.Count -gt 0 -and $PSCmdlet.ShouldProcess('matched files','Delete')){
        $del|Remove-Item -Force -EA SilentlyContinue
    }
}

#──────────────── HTML output (table + details) ─────────────────────────
function DirHtml{
    param($path,$node,[int]$lvl)
    $pad = 20*$lvl
    $safe=$path -replace '<','&lt;' -replace '>','&gt;'
    $cnt =$node.Files.Count
    $gb  =GB $node.Bytes
    $h= "<details class='dir' style='margin-left:${pad}px'>"
    $h+= "<summary>&#8250;<span class='col path'>$safe</span>" +
         "<span class='col num'>$cnt</span><span class='col num'>$gb&nbsp;GB</span></summary>"
    if($cnt){
        $h+="<table>"
        foreach($f in $node.Files){
            $fs=$f.Name -replace '<','&lt;' -replace '>','&gt;'
            $h+="<tr><td class='file'>$fs</td><td class='num'>$(MB $f.Length)&nbsp;MB</td></tr>"
        }
        $h+="</table>"
    }
    foreach($kv in $node.Sub.GetEnumerator()|Sort-Object Key){
        $h+=DirHtml $kv.Key $kv.Value ($lvl+1)
    }
    $h+="</details>"
    return $h
}

$css=@"
<style>
body{font-family:Segoe UI,Arial;margin:40px;max-width:1000px;}
summary{cursor:pointer;font-weight:bold;}
.dir{margin-top:6px;}
summary{display:grid;grid-template-columns:20px 1fr 80px 100px;gap:10px;align-items:center;}
summary>.col{padding:2px 0;}
.col.num{font-family:Consolas,monospace;text-align:right;}
.dir table{border-collapse:collapse;margin:6px 0 0 30px;font-size:13px;}
.dir td{border:1px solid #ccc;padding:2px 6px;}
.file{font-style:italic;color:#555;}
summary::-webkit-details-marker{display:none;}
</style>
"@

@"
<!DOCTYPE html><html><head><meta charset='utf-8'>
<title>File Clean-up Report</title>$css</head><body>
<h1>File Clean-up Report</h1>
<p><b>Run:</b> $(Get-Date)&emsp;<b>Cut-off:</b> $Cutoff<br>
<b>Mode:</b> $(if($DoDelete){'Clean'}else{'Report-only'})&emsp;
<b>User data included:</b> $($IncludeUser.IsPresent)</p>
"@ | Set-Content $html

foreach($root in $Path|Sort-Object){
    if($tree[$root]){Add-Content $html (DirHtml $root $tree[$root] 0)}
}

Add-Content $html "</body></html>"

#──────────────── PDF if requested ─────────────────────────────────────
if($Format -eq 'PDF' -or $Format -eq 'Both'){
    & $Edge --headless --disable-gpu --print-to-pdf="$pdf" "file:///$html" 2>$null
    if($Format -eq 'PDF'){Remove-Item $html}
}

#──────────────── Open report + console note ───────────────────────────
if($Format -eq 'HTML'){ Start-Process $html; Write-Output "✔ HTML: $html" }
elseif($Format -eq 'PDF'){ Start-Process $pdf; Write-Output "✔ PDF: $pdf" }
else{ Start-Process $html; Write-Output "✔ HTML: $html  |  PDF: $pdf" }

Write-Output ($(if($DoDelete){'✔ Clean-up complete.'}else{'✔ Report-only run – no deletions.'}))
