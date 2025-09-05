# PowerShell version of auto_ip_rollback.bat

# Ping test
Test-Connection -ComputerName "1.1.1.1" -Count 2 -Quiet

$adapterName = "LAN"

if ($adapterName -ne "") {
    # Set network adapter to DHCP
    netsh interface ipv4 set address name="$adapterName" dhcp
    netsh interface ipv4 set dnsservers name="$adapterName" dhcp
    
    Write-Host "renew dhcp $adapterName"
} else {
    Write-Host "not found nic $adapterName"
}

# Clear screen (commented out in original)
# Clear-Host

Write-Host "nic rollback complete"

# Display IP configuration
ipconfig

Write-Host "."
Write-Host "."

# Pause for user input
Read-Host "Press Enter to continue"
