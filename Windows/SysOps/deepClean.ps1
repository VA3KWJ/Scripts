<#
.SYNOPSIS
    Disk cleanup script to free up disk space by purging temp, cache, shadow copies, recycle bins, browser and app caches, and optionally Downloads and OST files.
.DESCRIPTION
    Automatically purges system and user temp/cache directories, deletes all Volume Shadow Copies if enabled,
    empties Recycle Bins for all users, clears caches for common browsers (Chrome, Firefox, Edge),
    clears caches for a wide range of business apps (Teams, Slack, Zoom, Webex, Skype, OneDrive, Dropbox),
    clears Microsoft Store app caches and data, and optionally purges Downloads folders and removes OST files for all users.
.VERSION
    1.5.1 - Fixed disk usage formatting (2025-06-10)
#>
[CmdletBinding()]
Param(
    [switch]$IncludeDownloads,   # Switch to also purge Users\Downloads
    [switch]$RemoveOST           # Switch to find and remove .ost files in user profiles
)

# Helper: Remove all items in a given folder
function Remove-ItemsInFolder {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FolderPath
    )
    if (Test-Path -Path $FolderPath) {
        Write-Verbose "Removing items in: $FolderPath"
        Get-ChildItem -Path $FolderPath -Force -Recurse -ErrorAction SilentlyContinue |
            Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    }
}

# Section: Clear system and user temp/cache directories
function Clear-TempAndCache {
    Write-Output "[1/8] Clearing system and user temp/cache directories..."
    Remove-ItemsInFolder -FolderPath "$env:SystemRoot\Temp"
    Remove-ItemsInFolder -FolderPath $env:TEMP
    Remove-ItemsInFolder -FolderPath $env:TMP
    Get-ChildItem -Path C:\Users -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-ItemsInFolder -FolderPath (Join-Path $_.FullName 'AppData\Local\Temp')
    }
}

# Section: Clear browser caches (Chrome, Firefox, Edge)
function Clear-BrowserCache {
    Write-Output "[2/8] Clearing browser cache for Chrome, Firefox, and Edge..."
    Get-ChildItem -Path C:\Users -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $user = $_.FullName
        Remove-ItemsInFolder -FolderPath (Join-Path $user 'AppData\Local\Google\Chrome\User Data\*\Cache')
        Remove-ItemsInFolder -FolderPath (Join-Path $user 'AppData\Local\Microsoft\Edge\User Data\*\Cache')
        Get-ChildItem -Path (Join-Path $user 'AppData\Local\Mozilla\Firefox\Profiles') -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-ItemsInFolder -FolderPath (Join-Path $_.FullName 'cache2')
        }
    }
}

# Section: Clear caches for common business applications
function Clear-AppCaches {
    Write-Output "[3/8] Clearing caches for business apps (Teams, Slack, Zoom, Webex, Skype, OneDrive, Dropbox)..."
    Get-ChildItem -Path C:\Users -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $user = $_.FullName
        Remove-ItemsInFolder -FolderPath (Join-Path $user 'AppData\Local\Microsoft\Teams\Cache')
        Remove-ItemsInFolder -FolderPath (Join-Path $user 'AppData\Roaming\Slack\Cache')
        Remove-ItemsInFolder -FolderPath (Join-Path $user 'AppData\Roaming\Zoom\bin\cache')
        Remove-ItemsInFolder -FolderPath (Join-Path $user 'AppData\Roaming\Zoom\logs')
        Remove-ItemsInFolder -FolderPath (Join-Path $user 'AppData\Local\Cisco\Webex')
        Remove-ItemsInFolder -FolderPath (Join-Path $user 'AppData\Local\Webex')
        Remove-ItemsInFolder -FolderPath (Join-Path $user 'AppData\Roaming\Skype')
        Remove-ItemsInFolder -FolderPath (Join-Path $user 'AppData\Local\Microsoft\OneDrive')
        Remove-ItemsInFolder -FolderPath (Join-Path $user 'AppData\Local\Dropbox\cache')
    }
}

# Section: Clear Microsoft Store app caches and data
function Clear-StoreAppCaches {
    Write-Output "[4/8] Clearing Microsoft Store app caches and data..."
    $packages = Join-Path $env:LOCALAPPDATA 'Packages'
    Get-ChildItem -Path $packages -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $pkg = $_.FullName
        Remove-ItemsInFolder -FolderPath (Join-Path $pkg 'LocalCache')
        Remove-ItemsInFolder -FolderPath (Join-Path $pkg 'LocalState')
        Remove-ItemsInFolder -FolderPath (Join-Path $pkg 'AC')
    }
}

# Section: Remove all Volume Shadow Copies if present
function Remove-ShadowCopies {
    Write-Output "[5/8] Removing Volume Shadow Copies if enabled..."
    try {
        $shadows = vssadmin list shadows 2>&1
        if ($shadows -match 'Shadow Copy') {
            vssadmin delete shadows /all /quiet
            Write-Output "    All Volume Shadow Copies removed."
        } else {
            Write-Output "    No Volume Shadow Copies found."
        }
    } catch {
        Write-Warning "    Could not remove shadow copies: $($_.Exception.Message)"
    }
}

# Section: Empty Recycle Bins for all users
function Clear-RecycleBins {
    Write-Output "[6/8] Emptying Recycle Bins for all users..."
    Get-ChildItem -Path C:\$Recycle.Bin -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-ItemsInFolder -FolderPath $_.FullName
    }
}

# Section: Optionally purge Downloads folders
function Clear-Downloads {
    Write-Output "[7/8] Purging Downloads folders for all users..."
    Get-ChildItem -Path C:\Users -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-ItemsInFolder -FolderPath (Join-Path $_.FullName 'Downloads')
    }
}

# Section: Optionally remove OST files
function Remove-OSTFiles {
    Write-Output "[8/8] Removing OST files in user profiles..."
    Get-ChildItem -Path C:\Users -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        Get-ChildItem -Path $_.FullName -Include *.ost -File -Recurse -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

# MAIN EXECUTION
# Measure free space before cleanup
$drive = Get-PSDrive -Name C -ErrorAction Stop
$before = $drive.Free
Write-Output ("Free space before cleanup: {0:N2} GB" -f ($before/1GB))

Write-Output "=== Disk cleanup started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
Clear-TempAndCache
Clear-BrowserCache
Clear-AppCaches
Clear-StoreAppCaches
Remove-ShadowCopies
Clear-RecycleBins
if ($IncludeDownloads) { Clear-Downloads }
if ($RemoveOST) { Remove-OSTFiles }

# Measure free space after cleanup
$drive = Get-PSDrive -Name C -ErrorAction Stop
$after = $drive.Free
$reclaimed = $after - $before
Write-Output "=== Disk cleanup completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
Write-Output ("Free space after cleanup : {0:N2} GB" -f ($after/1GB))
Write-Output ("Space reclaimed          : {0:N2} GB" -f ($reclaimed/1GB))
