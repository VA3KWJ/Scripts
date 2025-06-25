# FileMGMT Scripts

Tools for generating or cleaning up files.

## fCln.ps1
Removes or reports files older than a given date. Run without parameters for an
interactive setup or supply options such as:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\fCln.ps1 -Path C:\Logs -Before 90 -Delete
```

Reports are produced in CSV and HTML format under `$ReportDir`.

## fClnPS4.ps1
PowerShell 4 compatible build of **fCln** that always outputs a CSV report.

## fGen.ps1
Interactively generates a chosen number of random files between two dates. File
sizes range from 1 MB to 50 MB and names and extensions are random.

## simOS.ps1
Creates a simulated file system for testing cleanup routines. Choose a simple
data set or a full Windows‑like directory tree with optional application
folders.
