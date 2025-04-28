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


**o365DelegateAccessRpt.ps1**:
This is a script to enumerate all users within a O365 tenancy and produce a report of delegate access and user rights
