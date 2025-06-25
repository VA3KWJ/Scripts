# PowerShell Script Collection

This repository hosts a variety of PowerShell and batch utilities for Exchange,
networking and general Windows administration.

## Running Scripts

Run scripts with the **Bypass** execution policy:

```powershell
powershell.exe -ExecutionPolicy Bypass -File <ScriptPath.ps1>
```

## Folder Structure

- **Exchange** – Administration scripts for Exchange Online and on‑premises
  servers.
- **Networking** – Lightweight connectivity monitoring tools.
- **Windows** – General utilities divided into **FileMGMT** and **SysOps**.

Each folder provides a README with detailed usage notes and prerequisites.

## Script Overview

### Exchange
- `AddDomainUsersWithGroup.ps1` – Creates AD users from a CSV and adds them to a
  specified group.
- `ConvertIMCEAEXtoX500.ps1` – Converts an IMCEAEX NDR address to an X.500
  alias string.
- `GetAllOffice365EmailAddresses.ps1` – Third‑party script that exports all
  addresses and aliases from Exchange Online.
- `MFAStatus.ps1` – Reports user MFA enrollment status via the MSOnline module.
- `o365DelegateAccessRpt.ps1` – Generates a report of mailbox delegate
  permissions.

### Networking
- `ConnectionCheck.ps1` – Continuously pings a host and logs outages. Configure
  the host and log file inside the script.
- `ConnectionPortCheck.ps1` – Tests a range of ports in a loop and logs success
  or failure. Host, ports and log path are defined at the top of the script.

### Windows/FileMGMT
- `fCln.ps1` – Cleans files older than a given date. Supports interactive mode
  or parameters such as `-Path`, `-Date` or `-Before`.
- `fClnPS4.ps1` – PowerShell 4 friendly version of **fCln** that outputs a CSV
  report.
- `fGen.ps1` – Interactively generates random files between two dates.
- `simOS.ps1` – Builds a fake data set or Windows‑like directory tree for
  testing cleanup routines.

### Windows/SysOps
- `deepClean.ps1` – Thorough disk cleanup that can also remove Downloads and
  OST files.
- `WinUpdate.ps1` – Resets Windows Update components and forces a new scan.
- `vssComponents.bat` – Re‑registers core Volume Shadow Copy Service
  components.
