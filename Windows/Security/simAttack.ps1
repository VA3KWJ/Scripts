<#
.SCRIPT       simAttack.ps1
.DESCRIPTION  Simulates a ransomware attack
.INITIALDATE  2026-01-12
.LASTREVISION 2026-01-13
.VERSION      1.2 - drop note into all folders
.GITHUB       https://github.com/VA3KWJ
#>
# CONFIGURATION
# IMPORTANT: Ensure this path exists and contains your fake data
$TargetDirectory = "C:\SimulatedData"
$EncryptedExtension = ".LOCKED"
$TargetExtensions = @(".txt", ".docx", ".pdf", ".jpg", ".png", ".xlsx")
$LogSource = "SimulationDrill"

# --- 1. SETUP & CHECKS ---
if (-not (Test-Path $TargetDirectory)) {
    Write-Host "ERROR: The target directory '$TargetDirectory' does not exist!" -ForegroundColor Red
    Write-Host "Please create the folder and populate it with junk files before running."
    exit
}

if (![System.Diagnostics.EventLog]::SourceExists($LogSource)) {
    New-EventLog -LogName Application -Source $LogSource
}

Write-Host "--- STARTING SIMULATION ---" -ForegroundColor Yellow
Write-Host "Targeting Folder: $TargetDirectory" -ForegroundColor Cyan

# --- 2. TRIGGER BITDEFENDER (The Bonus) ---
Write-Host "Dropping EICAR test file to trigger AV..."
$EicarString = 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'
$EicarPath = Join-Path $TargetDirectory "malware_test.com"
try {
    Set-Content -Path $EicarPath -Value $EicarString -ErrorAction Stop
    Write-EventLog -LogName Application -Source $LogSource -EntryType Warning -EventId 100 -Message "Suspicious file drop detected: $EicarPath"
}
catch {
    Write-Host "AV likely blocked the EICAR file creation. Good sign!" -ForegroundColor Green
    Write-EventLog -LogName Application -Source $LogSource -EntryType Error -EventId 101 -Message "AV blocked payload drop."
}

# --- 3. SIMULATE ENCRYPTION ---
Write-Host "Scanning for files to 'encrypt'..."

# Get all files recursively
$Files = Get-ChildItem -Path $TargetDirectory -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in $TargetExtensions }

if ($Files.Count -eq 0) {
    Write-Host "WARNING: No matching files found to encrypt." -ForegroundColor Red
}
else {
    Write-Host "Found $($Files.Count) files. Starting encryption simulation..." -ForegroundColor Magenta

    foreach ($File in $Files) {
        $NewName = $File.Name + $EncryptedExtension
        try {
            Rename-Item -Path $File.FullName -NewName $NewName -ErrorAction SilentlyContinue
            Write-Host "Encrypted: $($File.Name)" -ForegroundColor DarkGray
        }
        catch {
            Write-Host "Failed to rename: $($File.Name)" -ForegroundColor Red
        }
    }

    Write-EventLog -LogName Application -Source $LogSource -EntryType Error -EventId 666 -Message "Files in $TargetDirectory have been encrypted by SIMULATION_CRYPT."
}

# --- 4. GENERATE RANSOM NOTES (UPDATED) ---
Write-Host "Dropping Ransom Notes in all directories..."
$NoteContent = @"
!!! YOUR FILES ARE ENCRYPTED (SIMULATION) !!!

You have 24 hours to send 100 CryptoCurrency or your data will be lost forever

Crypto Wallet: 1111AAAA2222BBBB

Date: $(Get-Date)

This is a drill. No data was lost.
"@

# Get the root folder + all subfolders
$AllFolders = Get-ChildItem -Path $TargetDirectory -Recurse -Directory -ErrorAction SilentlyContinue
$AllFolders += Get-Item $TargetDirectory # Add the root folder itself to the list

foreach ($Folder in $AllFolders) {
    $NotePath = Join-Path $Folder.FullName "RANSOM_NOTE.txt"
    try {
        Set-Content -Path $NotePath -Value $NoteContent -ErrorAction SilentlyContinue
        Write-Host "Note dropped in: $($Folder.FullName)" -ForegroundColor DarkGreen
    }
    catch {
        Write-Host "Could not drop note in $($Folder.FullName)" -ForegroundColor Yellow
    }
}

# Also drop one on the Desktop for visibility
$DesktopPath = [Environment]::GetFolderPath("Desktop")
Set-Content -Path "$DesktopPath\RANSOM_NOTE.txt" -Value $NoteContent
Invoke-Item "$DesktopPath\RANSOM_NOTE.txt"

Write-Host "--- SIMULATION COMPLETE ---" -ForegroundColor Red
