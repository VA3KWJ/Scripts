# AD Scripts

Utilities for basic Active Directory administration. Both scripts require the
`ActiveDirectory` PowerShell module.

## CSVaddUser.ps1
Creates users from a CSV file and adds them to a specified group. Update `$groupName` and the CSV path in the script before running.

## addGroupOU.ps1
Adds every user in a given OU to a security group, skipping members that are
already present. Set `$OU` and `$Group` at the top of the script. Can be run as
a scheduled task to keep group membership in sync with the OU.
