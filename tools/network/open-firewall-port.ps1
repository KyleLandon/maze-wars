# Run once on the HOST pc as Administrator to allow guests to join.
# Right-click -> Run with PowerShell (Admin)

$ErrorActionPreference = "Stop"
$ruleName = "Maze Wars LAN UDP 7777"

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
        -Profile Any
    Write-Host "Added firewall rule: $ruleName"
}

Write-Host ""
Write-Host "Host IP addresses on this PC:"
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" } | ForEach-Object {
    Write-Host "  $($_.IPAddress)"
}
Write-Host ""
Write-Host "Give your guest one of the 192.168.x.x addresses above."
Read-Host "Press Enter to close"
