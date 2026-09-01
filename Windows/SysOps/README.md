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

## win11Compatibility.ps1
Checks the local machine against Windows 11 minimum hardware requirements: CPU
architecture/cores/speed/generation, RAM, system drive size and type (SSD/HDD),
TPM 2.0, Secure Boot and UEFI firmware mode. Prints a colour-coded
PASS/FAIL/WARN report and writes the same report to `C:\temp\win11.txt`. WARN
marks soft-fail checks (e.g. HDD, Secure Boot capable but disabled) that do not
affect the overall result. Run as Administrator for reliable TPM / Secure Boot
results.

## vssComponents.bat
Re-registers core Volume Shadow Copy Service components and restarts related
services.
