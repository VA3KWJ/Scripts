# Exchange Scripts

Utilities for Exchange Online and on‑premises management.

## AddDomainUsersWithGroup.ps1
Creates Active Directory accounts from a CSV file and adds them to a chosen
group. Edit `$groupName` and the CSV path at the top of the script. The CSV must
contain the columns `Name`, `SamAccountName`, `UserPrincipalName`, `OU` and
`Password`.

## ConvertIMCEAEXtoX500.ps1
Converts an IMCEAEX bounce address to an X.500 alias. If the `-IMCEAEX` parameter
is omitted the script prompts for the string and outputs a sample `Set-Mailbox`
command.

## GetAllOffice365EmailAddresses.ps1
Third‑party script that connects with modern authentication and exports all
addresses and aliases to CSV. See
[m365scripts.com](https://m365scripts.com/microsoft365/get-all-office-365-email-address-and-alias-using-powershell)
for full documentation.

## MFAStatus.ps1
Uses the MSOnline module to create a CSV report of user MFA enrollment status.

## o365DelegateAccessRpt.ps1
Enumerates mailbox delegate permissions (Full Access, Send As and Send on
Behalf) and can export the results to CSV.
