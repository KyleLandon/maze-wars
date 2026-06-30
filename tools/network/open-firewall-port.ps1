# Allow inbound UDP 7777 for the Maze Wars dedicated server.
# Run as Administrator (Run-Dedicated-Server.bat requests elevation once).

param([switch]$Quiet)

$ErrorActionPreference = "Stop"
$ruleName = "Maze Wars Server UDP 7777"

$existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Firewall rule already exists: $ruleName"
} else {
    New-NetFirewallRule `
        -DisplayName $ruleName `
        -Direction Inbound `
        -Action Allow `
        -Protocol UDP `
        -LocalPort 7777 `
        -Profile Any | Out-Null
    Write-Host "Added firewall rule: $ruleName"
}

if (-not $Quiet) {
    Write-Host ""
    Write-Host "Host IP addresses on this PC:"
    Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" } | ForEach-Object {
        Write-Host "  $($_.IPAddress)"
    }
    Write-Host ""
    Write-Host "LAN guests: use a 192.168.x.x address above."
    Write-Host "Internet guests: use your public IP (port-forward UDP 7777 on the router)."
    Read-Host "Press Enter to close"
}
