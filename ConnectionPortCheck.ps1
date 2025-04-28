# Set the tartget computer (Hostname or IP)
$computer = "TargetHostOrIP"

# Define the port rante
$ports = 79..81

# Set the log path
$logFile = "C:\Temp\PortConnLog.txt"

# Init time for last stable
$lastSummaryTime = Get-Date

# Main Program
while ($true) {
    $currentTime = Get-Date
    $allPortsStable = $true

    foreach ($port in $ports) {
        # Run Test-NetConnection for the current prot
        $result = Test-NetConnection -ComputerName $computer -Port $port -WarningAction SilentlyContinue
        $timeStamp = $currentTime.ToString("yyyy-MM-dd HH:mm:ss")

        if ($result.TcpTestSucceeded) {
            # Log a success for port
            $logMessage = "$timeStamp - Connection to $computer on $port succeeded."
            Add-Content -Path $logFile -Value $logMessage
            }

        else {
            # Log failure
            $logMessage = "$timeStamp - Connection to $computer on port $port has failed."
            Add-Content -Path $logFile -Value $logMessage
            }
        }

# If all ports are stabe and 5 min has elapsed, log a message
if ($allPortsStable -and (($currentTime - $lastSummaryTime).TotalMinutes -ge 5)) {
    $timeStamp = $currentTime.ToString("yyyy-MM-dd HH:mm:ss")
    $summaryMessage = "$timeStamp - All ports on $computer are stable."
    Add-Content -Path $logFile -Value $summaryMessage
    $lastSummaryTime = $currentTime
    }

}
