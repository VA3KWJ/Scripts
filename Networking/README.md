# Networking Scripts

Two lightweight monitoring tools.

## ConnectionCheck.ps1
Edit `$computer` and `$logFile` in the script to suit your environment. It pings
the target in a loop, logging failures immediately and a "connection stable"
message every five minutes of uptime.

## ConnectionPortCheck.ps1
Configure `$computer`, `$ports` and `$logFile` at the top of the script. Each
port is tested repeatedly and results are logged. When all ports stay reachable
for five minutes a summary entry is written.
