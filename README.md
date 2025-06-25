# PowerShell Scripts

This repository contains various PowerShell and batch scripts organized by category. Each folder includes a README with details about the scripts it holds.

## Running Scripts

Use PowerShell with the **Bypass** execution policy to run any script:

```powershell
powershell.exe -ExecutionPolicy Bypass -File <ScriptName.ps1>
```

## Folder Overview

- **Exchange** – Scripts for Microsoft Exchange and Office&nbsp;365 administration.
- **Networking** – Simple connectivity monitoring tools.
- **Windows** – Windows utilities, split into **FileMGMT** and **SysOps**.

See the README in each folder for usage information.

## Script Summary

### Exchange
- **AddDomainUsersWithGroup.ps1** – Creates Active Directory users from a CSV file and adds them to a chosen group.
- **ConvertIMCEAEXtoX500.ps1** – Converts an IMCEAEX bounce address into an X.500 alias string.
- **GetAllOffice365EmailAddresses.ps1** – Third‑party script that exports all mail addresses and aliases from Exchange&nbsp;Online.
- **MFAStatus.ps1** – Connects to MSOnline and exports users with their MFA enrollment status.
- **o365DelegateAccessRpt.ps1** – Generates a report of mailbox delegate permissions (Full Access, Send As and Send on Behalf).

### Networking
- **ConnectionCheck.ps1** – Continuously pings a target computer and logs failures or stability summaries every five minutes.
- **ConnectionPortCheck.ps1** – Repeatedly tests a list of ports on a host and logs success or failure for each.

### Windows/FileMGMT
- **fCln.ps1** – Cleans files older than a specific date. Supports interactive mode and produces CSV/HTML reports.
- **fClnPS4.ps1** – PowerShell 4 compatible variant of fCln with CSV reporting.
- **fGen.ps1** – Generates random files between given dates for testing cleanup operations.
- **simOS.ps1** – Builds a fake data set or simulated Windows OS directory tree with optional application folders.

### Windows/SysOps
- **deepClean.ps1** – Comprehensive disk cleanup removing temp files, caches, shadow copies and more.
- **WinUpdate.ps1** – Resets Windows Update components, re-registers DLLs and forces an update scan.
- **vssComponents.bat** – Re-registers core Volume Shadow Copy Service components.
