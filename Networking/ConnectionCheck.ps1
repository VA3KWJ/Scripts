# Set the target computer (name or IP address)
$computer = "TargetComputerName"  # Replace with the actual computer name or IP

# Set the log file path
$logFile = "C:\Path\To\Your\LogFile.txt"  # Replace with the desired log file path

# Store the time when the last summary was logged
$lastSummaryTime = Get-Date

while ($true) {
    $currentTime = Get-Date
    # Ping the target computer once (-Count 1) with a simple boolean result
    $isConnected = Test-Connection -ComputerName $computer -Count 1 -Quiet

    # Log a disconnect event if the ping fails
    if (-not $isConnected) {
        $timeStamp = $currentTime.ToString("yyyy-MM-dd HH:mm:ss")
        $logMessage = "$timeStamp - Connection to $computer failed."
        Add-Content -Path $logFile -Value $logMessage
    }

    # Check if 5 minutes have elapsed since the last summary
    if (($currentTime - $lastSummaryTime).TotalMinutes -ge 5) {
        # Log a good connection summary only if the current check is successful
        if ($isConnected) {
            $timeStamp = $currentTime.ToString("yyyy-MM-dd HH:mm:ss")
            $logMessage = "$timeStamp - Connection to $computer is stable."
            Add-Content -Path $logFile -Value $logMessage
        }
        # Reset the summary timer regardless of the connection state
        $lastSummaryTime = $currentTime
    }
    
    # Wait for 5 seconds before the next check
    Start-Sleep -Seconds 5
}

