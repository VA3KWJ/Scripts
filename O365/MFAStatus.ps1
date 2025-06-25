<# Script will retrieve users and the MFA status
 Written by Stu 2025/04/02
 Script will conenct to MSOnline
#>

# Install, load, and connect to MSOnline
#Install-Module MSOnline -Force
#Import-Module MSOnline
Connect-MsolService

# Retrieve all users with custom properties and export to CSV
Get-MsolUser -All |
	Select-Object `
		DisplayName,
		@{Name="Email Address"; Expression={$_.UserPrincipalName}},
		@{Name="Is Guest"; Expression={if ($_.UserType -eq "Guest") {$true} else {$false} }},
		isLicensed,
		@{Name="MFA Enabled"; Expression={if ($_.StrongAuthenticationMethods.Count -gt 0) {$true} else {$false} }} |
	Export-Csv -Path "C:\temp\MFA_Status.csv" -NoTypeInformation
