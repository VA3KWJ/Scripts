# SysOps Scripts

Windows maintenance utilities.

## deepClean.ps1
Performs a thorough disk cleanup by purging temporary folders, browser caches, business app data and shadow copies. Can also empty Downloads folders and remove OST files. Outputs reclaimed disk space after the run.

## WinUpdate.ps1
Resets Windows Update by stopping services, clearing caches, re-registering DLLs and forcing a new scan. Prompts for a reboot when complete.

## vssComponents.bat
Re-registers core Volume Shadow Copy Service DLLs and restarts related services.
