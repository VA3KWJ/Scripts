# PowerShell Script Collection

This repository hosts a variety of PowerShell and batch utilities for Exchange,
networking and general Windows administration.

## Running Scripts

Run scripts with the **Bypass** execution policy:

```powershell
powershell.exe -ExecutionPolicy Bypass -File <ScriptPath.ps1>
```

## Folder Structure

- **Exchange** – Utilities for Exchange Online and on‑premises servers.
- **Networking** – Lightweight connectivity monitoring tools.
- **O365** – Office 365 reporting scripts.
- **Windows** – General utilities divided into **AD**, **FileMGMT**, **Security**
  and **SysOps**.

Each folder provides a README with detailed usage notes and prerequisites.

## Script Overview

### Exchange
- `ConvertIMCEAEXtoX500.ps1` – Converts an IMCEAEX NDR address to an X.500
  alias string.
- `getActive.ps1` – Flags every user mailbox as Active or Inactive based on the
  newest Inbox and Sent Items dates, groups the results by SMTP domain and
  exports to CSV. Works against Exchange Online or on‑premises.

### O365
- `GetAllOffice365EmailAddresses.ps1` – Exports all addresses and aliases from
  Exchange Online.
- `MFAStatus.ps1` – Reports user MFA enrollment status via the MSOnline module.
- `o365DelegateAccessRpt.ps1` – Generates a report of mailbox delegate
  permissions.

### Networking
- `ConnectionCheck.ps1` – Continuously pings a host and logs outages. Configure
  the host and log file inside the script.
- `ConnectionPortCheck.ps1` – Tests a range of ports in a loop and logs success
  or failure. Host, ports and log path are defined at the top of the script.

### Windows/AD
- `CSVaddUser.ps1` – Creates Active Directory users from a CSV file and adds
  them to a specified group.
- `addGroupOU.ps1` – Adds every user in a given OU to a security group; suitable
  for use as a scheduled task. Set `$OU` and `$Group` inside the script.

### Windows/FileMGMT
- `fCln.ps1` – Cleans files older than a given date. Supports interactive mode
  or parameters such as `-Path`, `-Date` or `-Before`.
- `fClnPS4.ps1` – PowerShell 4 friendly version of **fCln** that outputs a CSV
  report.
- `fGen.ps1` – Interactively generates random files between two dates.
- `simOS.ps1` – Builds a fake data set or Windows‑like directory tree for
  testing cleanup routines.
- `simOSv2.ps1` – Version 2 of the data generator that produces valid,
  openable files at the cost of a longer run time.

### Windows/Security
- `simAttack.ps1` – Simulates a ransomware attack without encrypting or
  modifying data: downloads the EICAR test file, renames files with a `.LOCK`
  extension and drops a ransom note in each directory.
- `simDecrypt.ps1` – Reverses `simAttack.ps1` by removing the `.LOCK`
  extension and deleting the ransom notes.

### Windows/SysOps
- `deepClean.ps1` – Thorough disk cleanup that can also remove Downloads and
  OST files.
- `WinUpdate.ps1` – Resets Windows Update components and forces a new scan.
- `win11Compatibility.ps1` – Checks the local machine against Windows 11
  minimum hardware requirements and writes a PASS/FAIL/WARN report to
  `C:\temp\win11.txt`.
- `vssComponents.bat` – Re‑registers core Volume Shadow Copy Service
  components.
