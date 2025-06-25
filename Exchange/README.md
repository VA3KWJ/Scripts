# Exchange Scripts

Scripts for Exchange Online and on-premises administration.

## AddDomainUsersWithGroup.ps1
Creates Active Directory accounts from a CSV file and adds them to a specified group. The CSV requires the columns `Name`, `SamAccountName`, `UserPrincipalName`, `OU`, and `Password`.

## ConvertIMCEAEXtoX500.ps1
Converts an IMCEAEX bounce address to an X.500 address and provides a sample `Set-Mailbox` command.

## GetAllOffice365EmailAddresses.ps1
Third-party script that exports all email addresses and aliases from Exchange Online. See [m365scripts.com](https://m365scripts.com/microsoft365/get-all-office-365-email-address-and-alias-using-powershell) for details.

## MFAStatus.ps1
Connects to MSOnline and outputs a CSV report of users and their MFA enrollment status.

## o365DelegateAccessRpt.ps1
Enumerates delegate access for every mailbox. Reports Full Access, Send As and Send on Behalf permissions and can export the results to CSV.
