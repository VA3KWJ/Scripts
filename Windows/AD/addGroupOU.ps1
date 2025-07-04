<#
Quick and dirty script to add users in a specific OU to a security group
Replace $OU & $Group as needed
Can be made a scheduled task for automation
#>
Import-Module ActiveDirectory

$OU = "OU=Residents,DC=corp,DC=example,DC=com"
$Group = "Residents_SG"

# Get all users in the OU
$OUUsers = Get-ADUser -SearchBase $OU -Filter * -Properties DistinguishedName

# Get current group members
$GroupMembers = Get-ADGroupMember -Identity $Group -Recursive | Where-Object { $_.objectClass -eq 'user' }

# Add missing users
$UsersToAdd = $OUUsers | Where-Object { $GroupMembers.DistinguishedName -notcontains $_.DistinguishedName }

foreach ($user in $UsersToAdd) {
    Add-ADGroupMember -Identity $Group -Members $user.DistinguishedName
    Write-Host "Added $($user.SamAccountName) to $Group"
}
