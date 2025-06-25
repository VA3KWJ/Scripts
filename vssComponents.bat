@echo off
REM ===============================================================
REM Script Title   : vssComponents.bat
REM Description    : Re-registers core VSS (Volume Shadow Copy Service) DLLs and COM components
REM Initial Date   : 2025-06-25
REM Latest Revision: 2025-06-25
REM Version        : v1.0 - Initial release
REM GitHub Repo    : https://github.com/VA3KWJ
REM ===============================================================

echo ==========================================================
echo Re-registering VSS (Volume Shadow Copy Service) Components
echo ==========================================================

REM Change directory to system32
cd /d %windir%\system32

echo Registering required DLLs and components...

REM Loop through VSS-related DLLs and COM components
for %%i in (
    ole32.dll
    oleaut32.dll
    vss_ps.dll
    msxml.dll
    msxml2.dll
    msxml3.dll
    msxml4.dll
    msxml6.dll
    es.dll
    stdprov.dll
    swprv.dll
    vssui.dll
    eventcls.dll
    tsbyuv.dll
    kmddsp.tsp
    ndisp.tsp
    mspmsnsv.dll
    mspmsnsv.ax
    dciman32.dll
    atl.dll
    scrrun.dll
    wbem\wbemdisp.dll
    wbem\wbemprox.dll
    wbem\wbemsvc.dll
    wbem\fastprox.dll
    wbem\esscli.dll
    netman.dll
    rasapi32.dll
    rasman.dll
    tapi32.dll
    licwmi.dll
) do (
    echo Registering %%i...
    regsvr32 /s %%i >nul 2>&1
)

echo.
echo Restarting VSS related services...

REM Restart core VSS and COM+ services
net stop vss >nul 2>&1
net start vss

net stop COMSysApp >nul 2>&1
net start COMSysApp

net stop EventSystem >nul 2>&1
net start EventSystem

echo.
echo =======================================
echo Done! A system reboot is recommended.
echo =======================================
pause
