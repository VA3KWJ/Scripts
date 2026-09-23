<#
.SYNOPSIS
    Updates Microsoft Defender signatures and runs a full system scan.

.DESCRIPTION
    Updates the Defender virus/spyware definitions, then runs a full scan and
    reports any threat detections found. Start-MpScan runs synchronously, so
    this console is blocked for the duration of the scan (there is no separate
    progress window). The full console transcript, including a threat summary,
    is written to C:\temp\scanResults.txt (C:\temp is created if needed, and
    each run is appended rather than overwriting the previous log).

.NOTES
    Requires Administrator privileges (Update-MpSignature / Start-MpScan).
#>
[CmdletBinding()]
param()

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script must be run as Administrator.`nExiting..."
    exit 1
}

$logDir  = 'C:\temp'
$logFile = Join-Path $logDir 'scanResults.txt'

if (-not (Test-Path -Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

Start-Transcript -Path $logFile -Append | Out-Null

try {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "   MICROSOFT DEFENDER AUTOMATED SCAN     " -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Run started: $(Get-Date)" -ForegroundColor DarkGray

    # ---- 1. Update Defender signatures ----
    Write-Host "`n[1/2] Checking for latest spyware and virus definitions..." -ForegroundColor Yellow
    try {
        Update-MpSignature -ErrorAction Stop
        Write-Host "Definitions updated successfully." -ForegroundColor Green
    } catch {
        Write-Warning "Definition update failed or timed out: $($_.Exception.Message). Proceeding with scan anyway..."
    }

    # ---- 2. Run full scan ----
    Write-Host "`n[2/2] Starting Full System Scan..." -ForegroundColor Yellow
    Write-Host "This blocks the console until the scan finishes; it can take a while on large disks." -ForegroundColor Gray

    try {
        Start-MpScan -ScanType FullScan -ErrorAction Stop
        Write-Host "`n=========================================" -ForegroundColor Green
        Write-Host "FULL SYSTEM SCAN COMPLETED SUCCESSFULLY!" -ForegroundColor Green
        Write-Host "=========================================" -ForegroundColor Green

        # Report every threat Defender has on record, including the actual
        # file(s) each one was found in. Written line-by-line with Write-Host
        # rather than Format-Table -AutoSize, which truncates the Resources
        # column (and any wide output) to fit the console width.
        $threats = Get-MpThreatDetection
        if ($threats) {
            # ThreatID -> friendly name lookup (Get-MpThreatDetection doesn't include the name itself).
            $threatNames = @{}
            try {
                Get-MpThreat -ErrorAction Stop | ForEach-Object { $threatNames[$_.ThreatID] = $_.ThreatName }
            } catch {
                Write-Warning "Could not resolve threat names: $($_.Exception.Message)"
            }

            Write-Host "`nThreat detections found ($($threats.Count)):" -ForegroundColor Red
            foreach ($t in $threats) {
                $name = $threatNames[$t.ThreatID]
                if (-not $name) { $name = "Unknown threat (ID $($t.ThreatID))" }

                Write-Host ("  Threat:   {0}" -f $name) -ForegroundColor Red
                Write-Host ("    Detected: {0}" -f $t.InitialDetectionTime)
                Write-Host ("    Status:   {0}" -f $t.ThreatStatusID)
                Write-Host "    File(s):"
                if ($t.Resources) {
                    foreach ($resource in $t.Resources) {
                        # Defender prefixes filesystem resources with "file:_"; strip it for readability.
                        Write-Host ("      {0}" -f ($resource -replace '^file:_', ''))
                    }
                } else {
                    Write-Host "      (no file path recorded)"
                }
                Write-Host ""
            }
        } else {
            Write-Host "`nNo threats detected." -ForegroundColor Green
        }
    } catch {
        Write-Warning "Full scan failed: $($_.Exception.Message)"
    }

    Write-Host "`nRun finished: $(Get-Date)" -ForegroundColor DarkGray
    Write-Host "Full log written to $logFile" -ForegroundColor Cyan
} finally {
    # Always stop the transcript, even if something above threw.
    Stop-Transcript | Out-Null
}

Pause
