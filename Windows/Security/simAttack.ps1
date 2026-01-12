<#
.SCRIPT       simAttack.ps1
.DESCRIPTION  Simulates a ransomware attack
.INITIALDATE  2026-01-12
.LASTREVISION .
.VERSION      1.1 - safety net
.GITHUB       https://github.com/VA3KWJ
#>

# CONFIGURATION
# IMPORTANT: Change this path to point ONLY to your junk data folder
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

# We use -ErrorAction SilentlyContinue to skip system folders we don't have permission for
$Files = Get-ChildItem -Path $TargetDirectory -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in $TargetExtensions }

$Count = $Files.Count
if ($Count -eq 0) {
    Write-Host "WARNING: No matching files found in $TargetDirectory to encrypt." -ForegroundColor Red
    Write-Host "Ensure the folder contains files with extensions: $($TargetExtensions -join ', ')"
}
else {
    Write-Host "Found $Count files. Starting encryption simulation..." -ForegroundColor Magenta

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

    # Log the 'Encryption' completion
    Write-EventLog -LogName Application -Source $LogSource -EntryType Error -EventId 666 -Message "Files in $TargetDirectory have been encrypted by SIMULATION_CRYPT."
}

# --- 4. GENERATE RANSOM NOTE ---
Write-Host "Dropping Ransom Note..."
$NoteContent = @"
!!! YOUR FILES ARE ENCRYPTED (SIMULATION) !!!
ID: SIM-99281
Date: $(Get-Date)
"@

$DesktopPath = [Environment]::GetFolderPath("Desktop")
Set-Content -Path "$DesktopPath\RANSOM_NOTE.txt" -Value $NoteContent
Invoke-Item "$DesktopPath\RANSOM_NOTE.txt"

Write-Host "--- SIMULATION COMPLETE ---" -ForegroundColor Red
