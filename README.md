# PowerShell
This is a collection of personal PS scripts

Run scripts with: `powershell.exe -ExecutionPolicy Bypass -File .\ScriptName.ps1`

**fCln.ps1**:\
Version 2.0 changes:
- Interactive mode
  - Execute the script without any switches to run in an interactive mode using defaults or specified parameters
- Script will now ignore all folders containing Application related files:
  - *.exe,*.dll,*.com,*.sys,*.ocx,*.msi,*.msu,*.msp,*.drv,*.cpl,*.msc,*.scr,*.vbs,*.ps1,*.bat,*.cmd,*.jar,*.py,*.sh
- Script will not delete non-empty folders even if their modified date matches
  
Examples:
- powershell.exe -ExecutionPolicy Bypass -File .\Fcln.ps1 -Path C:\Temp -Before 90 # Scans the C:\Temp folder for files created >90 days ago and makes a report\
- powershell.exe -ExecutionPolicy Bypass -File .\Fcln.ps1 -Path C:\Temp -Date 2025-01-01 # Scans the C:\Temp folder for files created before Jan 1, 2025 and makes a report\
- powershell.exe -ExecutionPolicy Bypass -File .\Fcln.ps1 -Path C:\Temp -Before 90 -Clean # Scans the C:\Temp folder for files >90s and deletes them\
- powershell.exe -ExecutionPolicy Bypass -File .\Fcln.ps1 -IncludeUser -Date 2025-01-01 # Scans the entire C:\drive including C:\Users for files created before Jan 1, 2025 and makes a report\

**osSIM.ps1**\
Inerative version 2.0 of fGen.ps1\
This version is designed to more accurately represent a woring file system or live operation system for testing fCln against\
Like the original, this script will produce a set number of files and folders within the specified start & end dates, with file sizes between 1 to 10mb.\
Expanded feature set:
- Data Only mode: Replicates a data partition or folder
- OS Mode: Replicates a working Windows Operating System, complete with \Users, \Program Files \Program Files (x86), etc
- Application generation: When enabled it will prompt for number of application folders and generate files with application related extensions (.exe, .dll, etc) and place within the App- folder
  - To make life easier, folders with applications begin with App-
  - The Application **do not** count against the total file or folder count

**fGen.ps1**:\
This is the original script for validating fCln functionallity. It functions in an interactive mode and will generate a set number of files & folders within a specified start & end date.\
File names and extensions are randomly generated.\
File sizes are between 1mb and 50mb.

**o365DelegateAccessRpt.ps1**:\
This is a script to enumerate all users within a O365 tenancy and produce a report of delegate access and user rights

**AddDomainUsersWithGroup.ps1**:\
Quick and dirty script to create new users and assign them to a specified group from a CSV file.

**ConnectionCheck.ps1**:\
This is another quick and dirty script to check connectivity by pinging a target computer and logging the results\
Sends a single ping to the target, if there is a reply nothing happens. If there is no reply the a failed log is recorded with time stamp.\
The script checks every 5 min if there have been any failures, if not it will add output to the log indicating connection is stable. This is more of a sanity check

**ConnectionPortCheck.ps1**:\
Similar to the Connection Check script, however it attempts to connect to specific port(s) on the target computer & log the results.\
This script runs in an endless loop regardless of the results it will loop back to the first port.\
Ports can be sequential `6000..6060` or comma separated `80,145,443`

**ConvertIMCEAEXtoX500.ps1**:\
Script is used for OnPerm Exchange issues where an alias needs to be converted from IMCEAEX NDR to X500

**GetAllOffice365EmailAddresses.ps1**:\
**Not my script** https://m365scripts.com/microsoft365/get-all-office-365-email-address-and-alias-using-powershell

**MFAStatus.ps1**:\
This is a simple script to connect to EXO and check what users have enrolled in MFA then output to CSV
