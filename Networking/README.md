# Networking Scripts

Simple connectivity monitors.

## ConnectionCheck.ps1
Pings a target computer in a loop and logs failures with timestamps. Every five minutes it logs a "connection stable" message if no failures have occurred.

## ConnectionPortCheck.ps1
Tests connectivity to one or more ports on a host. Results for each port are logged continuously, and a summary entry is written when all ports remain reachable for five minutes.
