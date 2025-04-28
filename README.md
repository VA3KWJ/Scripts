# PowerShell
This is a collection of personal PS scripts

Run scripts with: `powershell.exe -ExecutionPolicy Bypass -File .\ScriptName.ps1`

**fCln.ps1**:\
This is a file cleanup script, designed to find files older than a specified date for perminent deletion.
- Must be run with Administrator
- Will always generate a report in HTML
- The script will ignore critical system DIRs unless otherwise specified
- Note: Including critical DIRs will prompt for confirmation and may increase script run time
- Switches:
  - -Path (Optional) can support comma separated list of paths to scan
  - -Date (Required 1) Specify an exact date to find files created before
  - -Before (Required 2) Specify a number of days
  - -IncludeUser (Optional) specify if you want to include scanning user dirs (c:\users)
  - -ReportOnly (Optional) run in report only mode, default if unspecified
  - -ReportPath (Optional) specify the path to save the report, default c:\FclnRpt
  - -Clean (Optional) perform deletions on files matched with either -Date or -Before
  
Examples:
- powershell.exe -ExecutionPolicy Bypass -File .\Fcln.ps1 -Path C:\Temp -Before 90 # Scans the C:\Temp folder for files created >90 days ago and makes a report\
- powershell.exe -ExecutionPolicy Bypass -File .\Fcln.ps1 -Path C:\Temp -Date 2025-01-01 # Scans the C:\Temp folder for files created before Jan 1, 2025 and makes a report\
- powershell.exe -ExecutionPolicy Bypass -File .\Fcln.ps1 -Path C:\Temp -Before 90 -Clean # Scans the C:\Temp folder for files >90s and deletes them\
- powershell.exe -ExecutionPolicy Bypass -File .\Fcln.ps1 -IncludeUser -Date 2025-01-01 # Scans the entire C:\drive including C:\Users for files created before Jan 1, 2025 and makes a report\

**fGen.ps1**:\
This is a file generation script used for validating fClean. It can generate a set number of files between 1-50Mb in size and place them into the DIR specified. It can also generate a set number of DIRs within the specified folder and randomly scatter the file throughout\
The file names, extensions, and sizes are random\
Script will prompt for Folder, Start Date, End Date, Sub Dir


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
