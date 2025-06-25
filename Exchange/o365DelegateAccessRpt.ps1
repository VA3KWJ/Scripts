# Requires Exchange Online PowerShell Module
# Connect to Exchange Online if not already connected
try {
    Get-EXOMailbox -ResultSize 1 > $null
} catch {
    Write-Host "Connecting to Exchange Online..." -ForegroundColor Cyan
    Connect-ExchangeOnline
}

# Prepare an array to hold results
$results = @()

# Get all mailboxes
$mailboxes = Get-EXOMailbox -ResultSize Unlimited

foreach ($mbx in $mailboxes) {
    $primarySMTP = $mbx.PrimarySmtpAddress.ToString()

    # Get Full Access Permissions
    $fullAccess = Get-MailboxPermission -Identity $primarySMTP -ErrorAction SilentlyContinue | Where-Object {
        ($_.User -ne "NT AUTHORITY\SELF") -and 
        ($_.User -notlike "S-1-5-*") -and 
        (-not $_.IsInherited)
    }

    foreach ($perm in $fullAccess) {
        $results += [PSCustomObject]@{
            Mailbox          = $primarySMTP
            DelegatedUser    = $perm.User.ToString()
            PermissionType   = "FullAccess"
        }
    }

    # Get Send As Permissions
    $sendAs = Get-RecipientPermission -Identity $primarySMTP -ErrorAction SilentlyContinue | Where-Object {
        $_.Trustee -ne $null
    }

    foreach ($perm in $sendAs) {
        $results += [PSCustomObject]@{
            Mailbox          = $primarySMTP
            DelegatedUser    = $perm.Trustee.ToString()
            PermissionType   = "SendAs"
        }
    }

    # Get Send on Behalf permissions
    if ($mbx.GrantSendOnBehalfTo.Count -gt 0) {
        foreach ($delegate in $mbx.GrantSendOnBehalfTo) {
            $results += [PSCustomObject]@{
                Mailbox          = $primarySMTP
                DelegatedUser    = $delegate.Name
                PermissionType   = "SendOnBehalf"
            }
        }
    }
}

# Display results
$results | Sort-Object Mailbox, DelegatedUser | Format-Table -AutoSize

# Optional: Export to CSV
# $results | Export-Csv -Path "DelegatedAccessReport.csv" -NoTypeInformation -Encoding UTF8
