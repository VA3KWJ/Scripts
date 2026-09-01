<#
.SYNOPSIS
    Reports active vs. inactive mailboxes for Exchange Online or on-premises Exchange.

.DESCRIPTION
    Queries every user mailbox and inspects the newest item in the Inbox and Sent Items
    folders (via mailbox folder statistics, so it works the same online and on-prem and
    is not limited by the 10-day message-trace window).

    A mailbox is flagged "Active" when it has EITHER:
      - received a message within the last -ReceivedWithinDays days (default 14), OR
      - sent a message within the last -SentWithinDays days (default 7).

    Results are grouped by SMTP domain, with Active users sorted to the top of each
    domain group, and exported to CSV.

.PARAMETER Environment
    Online (default) uses the Exchange Online PowerShell (EXO) cmdlets.
    OnPremises uses the on-prem Exchange Management Shell / remote session cmdlets.

.PARAMETER ReceivedWithinDays
    Look-back window for received mail. Default 14.

.PARAMETER SentWithinDays
    Look-back window for sent mail. Default 7.

.PARAMETER Path
    CSV output path. Default C:\temp\ActiveMailboxes_<timestamp>.csv

.EXAMPLE
    .\getActive.ps1

.EXAMPLE
    .\getActive.ps1 -Environment OnPremises -Path C:\Reports\active.csv

    Written by Stu 2026/09/01
#>

[CmdletBinding()]
param(
    [ValidateSet('Online', 'OnPremises')]
    [string]$Environment = 'Online',

    [int]$ReceivedWithinDays = 14,

    [int]$SentWithinDays = 7,

    [string]$Path = "C:\temp\ActiveMailboxes_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

$receivedCutoff = (Get-Date).AddDays(-$ReceivedWithinDays)
$sentCutoff     = (Get-Date).AddDays(-$SentWithinDays)

# --- Connect / pick the right cmdlets for the environment -------------------
if ($Environment -eq 'Online') {
    try {
        Get-EXOMailbox -ResultSize 1 -ErrorAction Stop > $null
    } catch {
        Write-Host "Connecting to Exchange Online..." -ForegroundColor Cyan
        Connect-ExchangeOnline -ShowBanner:$false
    }
    $mailboxCmd = 'Get-EXOMailbox'
    $statCmd    = 'Get-EXOMailboxFolderStatistics'
} else {
    if (-not (Get-Command Get-Mailbox -ErrorAction SilentlyContinue)) {
        throw "On-premises Exchange cmdlets not found. Run this from the Exchange Management Shell or import a remote session first."
    }
    $mailboxCmd = 'Get-Mailbox'
    $statCmd    = 'Get-MailboxFolderStatistics'
}

# --- Enumerate mailboxes ---------------------------------------------------
Write-Host "Retrieving mailboxes..." -ForegroundColor Cyan
$mailboxes = & $mailboxCmd -ResultSize Unlimited -RecipientTypeDetails UserMailbox
Write-Host "  $($mailboxes.Count) user mailboxes found." -ForegroundColor Gray

$results = @()
$i = 0

foreach ($mbx in $mailboxes) {
    $i++
    $smtp   = $mbx.PrimarySmtpAddress.ToString()
    $domain = ($smtp -split '@')[-1].ToLower()

    Write-Progress -Activity "Checking mailbox activity" -Status $smtp `
        -PercentComplete (($i / [Math]::Max($mailboxes.Count, 1)) * 100)

    $lastReceived = $null
    $lastSent     = $null
    try {
        $stats = & $statCmd -Identity $smtp -FolderScope All -IncludeOldestAndNewestItems -ErrorAction Stop
        $lastReceived = ($stats | Where-Object { $_.FolderType -eq 'Inbox' }     | Select-Object -First 1).NewestItemReceivedDate
        $lastSent     = ($stats | Where-Object { $_.FolderType -eq 'SentItems' } | Select-Object -First 1).NewestItemReceivedDate
    } catch {
        Write-Warning "Could not read folder statistics for $smtp : $($_.Exception.Message)"
    }

    $receivedRecently = $lastReceived -and $lastReceived -ge $receivedCutoff
    $sentRecently     = $lastSent     -and $lastSent     -ge $sentCutoff
    $isActive         = $receivedRecently -or $sentRecently

    $results += [PSCustomObject]@{
        DisplayName      = $mbx.DisplayName
        EmailAddress     = $smtp
        Domain           = $domain
        Status           = if ($isActive) { 'Active' } else { 'Inactive' }
        LastReceived     = $lastReceived
        LastSent         = $lastSent
        ReceivedRecently = [bool]$receivedRecently
        SentRecently     = [bool]$sentRecently
    }
}
Write-Progress -Activity "Checking mailbox activity" -Completed

# --- Group by domain, Active users on top within each domain --------------
$sorted = $results | Sort-Object `
    Domain,
    @{ Expression = { if ($_.Status -eq 'Active') { 0 } else { 1 } } },
    DisplayName

# --- Export --------------------------------------------------------------
$dir = Split-Path -Parent $Path
if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force > $null
}
$sorted | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8

# --- Console summary ---------------------------------------------------
$activeCount = ($results | Where-Object { $_.Status -eq 'Active' }).Count
Write-Host ""
Write-Host "Active:   $activeCount" -ForegroundColor Green
Write-Host "Inactive: $($results.Count - $activeCount)" -ForegroundColor Yellow
Write-Host "CSV:      $Path" -ForegroundColor Cyan

$sorted | Format-Table DisplayName, EmailAddress, Domain, Status, LastReceived, LastSent -AutoSize
