# SysOps Scripts

Windows maintenance utilities.

## deepClean.ps1
Performs a thorough disk cleanup by purging temp folders, caches and shadow
copies. Use `-IncludeDownloads` to also clear user Download folders and
`-RemoveOST` to delete Outlook OST files. The script reports reclaimed disk space
at the end.

## WinUpdate.ps1
Stops update services, clears caches, re-registers DLLs and forces a new scan.
Run as Administrator and reboot when prompted.

## vssComponents.bat
Re-registers core Volume Shadow Copy Service components and restarts related
services.
