<#
.SYNOPSIS
    Resets Windows Update components on Windows 10 and 11.
.DESCRIPTION
    Stops update services, clears caches, re-registers update DLLs, resets WinSock, and forces a scan.
.NOTES
    Tested on Windows 10 and 11. Requires Administrator privileges.
    Will automatically reboot if not aborted.
#>
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script must be run as Administrator.`nExiting..."
    exit 1
}
Write-Host '*** Resetting Windows Update Components ***' -ForegroundColor Cyan
$qmgrPath = Join-Path $env:ProgramData 'Microsoft\Network\Downloader\qmgr*.dat'
$softDist = Join-Path $env:SystemRoot 'SoftwareDistribution'
$catRoot  = Join-Path $env:SystemRoot 'System32\Catroot2'
$services = @('BITS','wuauserv','cryptsvc')
Write-Host '1) Stopping update-related services...' -ForegroundColor Yellow
foreach ($svc in $services) {
    if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
        Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
    }
}
Write-Host '2) Removing QMGR data files...' -ForegroundColor Yellow
Remove-Item -Path $qmgrPath -Force -ErrorAction SilentlyContinue
Write-Host '3) Deleting SoftwareDistribution and Catroot2 folders...' -ForegroundColor Yellow
Remove-Item -Path $softDist -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path $catRoot  -Recurse -Force -ErrorAction SilentlyContinue
Write-Host '4) Resetting service ACLs...' -ForegroundColor Yellow
sc.exe sdset BITS      "D:(A;CI;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU)"
sc.exe sdset wuauserv "D:(A;;CCLCSWRPLORC;;;AU)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;SY)"
sc.exe sdset cryptsvc "D:(A;;CCLCSWRPLORC;;;AU)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;SY)"
Write-Host '5) Re-registering update-related DLLs...' -ForegroundColor Yellow
$dllFolder = Join-Path $env:SystemRoot 'System32'
$dlls = @(
    'atl.dll','urlmon.dll','mshtml.dll','shdocvw.dll','browseui.dll',
    'jscript.dll','vbscript.dll','scrrun.dll','msxml.dll','msxml3.dll','msxml6.dll',
    'actxprxy.dll','softpub.dll','wintrust.dll','dssenh.dll','rsaenh.dll','gpkcsp.dll',
    'sccbase.dll','slbcsp.dll','cryptdlg.dll','oleaut32.dll','ole32.dll','shell32.dll',
    'initpki.dll','wuapi.dll','wuaueng.dll','wuaueng1.dll','wucltui.dll','wups.dll',
    'wups2.dll','wuweb.dll','qmgr.dll','qmgrprxy.dll','wucltux.dll','muweb.dll','wuwebv.dll'
)
foreach ($dll in $dlls) {
    $dllPath = Join-Path $dllFolder $dll
    if (Test-Path $dllPath) {
        & "$dllFolder\regsvr32.exe" /s "$dllPath"
    }
}
Write-Host '6) Resetting WinSock...' -ForegroundColor Yellow
netsh winsock reset | Out-Null
Write-Host '7) Starting update-related services...' -ForegroundColor Yellow
foreach ($svc in $services) {
    Start-Service -Name $svc -ErrorAction SilentlyContinue
}
Write-Host '8) Forcing update detection...' -ForegroundColor Yellow
if (Get-Command USOClient.exe -ErrorAction SilentlyContinue) {
    USOClient.exe RefreshSettings
    USOClient.exe StartScan
} elseif (Get-Command wuauclt.exe -ErrorAction SilentlyContinue) {
    wuauclt.exe /resetauthorization /detectnow
}
Write-Host '*** Reset complete. Please reboot your system to finalize changes. ***' -ForegroundColor Green

$timeout = 30
Write-Host "Rebooting in $timeout seconds... Press any key to cancel." -ForegroundColor Yellow
$stopwatch = [Diagnostics.Stopwatch]::StartNew()
while ($stopwatch.Elapsed.TotalSeconds -lt $timeout) {
    if ([Console]::KeyAvailable) {
        [Console]::ReadKey($true) | Out-Null
        Write-Host "Reboot canceled by user." -ForegroundColor Cyan
        exit 0
    }
    Start-Sleep -Seconds 1
}
Restart-Computer -Force
