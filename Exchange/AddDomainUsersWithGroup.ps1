# Add users to AD & Group via CSV - Stu 2025
# CSV format:
# Name,SamAccountName,UserPrincipalName,OU,Password
# Jon Doe,jdoe,jdoe@domain.com,"OU=Users,DC=domain,DC=com",Password
# Alice Smith,asmith,asmith@domain.com,"OU=Users,DC=domain,DC=com",Password

# Specify your AD Group
$groupName = "Your AD Group"

# Import users from CSV
$users = Import-Csv -Path "C:\Path\To\CSV"

foreach ($user in $users) {
    # Create the AD account
    New-ADUser -Name $user.Name `
               -SamAccountName $user.SamAccountName `
               -UserPrincipalName $user.UserPrincipalName `
               -Path $user.OU `
               -AccountPassword (ConvertTo-SecureString $user.Password -AsPlainText -Force) `
               -Enabled $true
    Write-Host "Created user: $($user.Name)"

    # Add the new user to the specified AD Group
    Add-ADGroupMember -Identity $groupName -Members $user.SamAccountName
    Write-Host "Added $($user.SamAccountName) to $groupName"
}
