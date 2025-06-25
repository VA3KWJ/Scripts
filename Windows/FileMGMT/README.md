# FileMGMT Scripts

Tools for generating or cleaning up files.

## fCln.ps1
Deletes or reports files older than a given date. If no parameters are supplied the script runs in an interactive mode asking for paths, cutoff dates and whether to delete or recycle files. Reports are produced in CSV and HTML formats.

## fClnPS4.ps1
A PowerShell 4 compatible build of **fCln** with CSV reporting.

## fGen.ps1
Interactively generates a specified number of random files between two dates. File sizes range from 1 MB to 50 MB and names and extensions are random.

## simOS.ps1
Creates a simulated file system for testing cleanup routines. Can generate a simple data folder or a full Windows-like directory tree with optional application folders.
