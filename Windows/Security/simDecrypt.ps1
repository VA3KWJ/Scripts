$TargetDirectory = "C:\SimulatedData"
$EncryptedExtension = ".LOCKED"
$RansomNoteName = "RANSOM_NOTE.txt"

Write-Host "--- STARTING RESTORATION ---" -ForegroundColor Green

# 1. REVERT FILE NAMES
Write-Host "Restoring file extensions..."
Get-ChildItem -Path $TargetDirectory -Recurse | Where-Object { $_.Name -like "*$EncryptedExtension" } | ForEach-Object {
    $OriginalName = $_.Name.Replace($EncryptedExtension, "")
    try {
        Rename-Item -Path $_.FullName -NewName $OriginalName -ErrorAction Stop
        Write-Host "Restored: $OriginalName" -ForegroundColor Gray
    }
    catch {
        Write-Host "Error restoring $($_.Name)" -ForegroundColor Red
    }
}

# 2. REMOVE RANSOM NOTES FROM FOLDERS
Write-Host "Scrubbing ransom notes..."
Get-ChildItem -Path $TargetDirectory -Recurse -Filter $RansomNoteName | ForEach-Object {
    Remove-Item -Path $_.FullName -Force
    Write-Host "Deleted note in: $($_.DirectoryName)" -ForegroundColor DarkYellow
}

# 3. CLEAN UP DESKTOP NOTE (FIXED)
# We use the explicit Enum for 'Desktop' to be safe, and calculate the path first.
$DesktopPath = [Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
$DesktopNote = Join-Path -Path $DesktopPath -ChildPath $RansomNoteName

if (Test-Path $DesktopNote) {
    Remove-Item -Path $DesktopNote -Force
    Write-Host "Deleted note from Desktop" -ForegroundColor DarkYellow
}

Write-Host "--- RESTORATION COMPLETE ---" -ForegroundColor Green
