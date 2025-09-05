# PowerShell version of auto_ip_set.bat

# Find the first active network adapter (Korean and English support)
$adapterName = (Get-NetAdapter | Where-Object {
    $_.Status -eq "Up" -and 
    $_.InterfaceDescription -notlike "*Loopback*" -and 
    $_.InterfaceDescription -notlike "*루프백*" -and
    $_.InterfaceDescription -notlike "*Virtual*" -and
    $_.InterfaceDescription -notlike "*가상*" -and
    $_.InterfaceDescription -notlike "*Hyper-V*" -and
    $_.InterfaceDescription -notlike "*VMware*" -and
    $_.InterfaceDescription -notlike "*VirtualBox*"
} | Select-Object -First 1).Name

if ([string]::IsNullOrEmpty($adapterName)) {
    Write-Host "No active network adapter found. Using default 'LAN'"
    $adapterName = "LAN"
} else {
    Write-Host "Found network adapter: $adapterName"
}
$ipAddress = "WIN_IP"
$subnetMask = "WIN_SN"
$gateway = "WIN_GW"

# Commented out ping test and conditional logic
# ping -n 1 $gateway >nul
# if ($LASTEXITCODE -eq 0) {
#     Write-Host "Connection already."
# } else {
#     New-PSDrive -Name "Z" -PSProvider FileSystem -Root "\\host.lan\common" -Persist:$true
#     Write-Host "Setting network configuration for $adapterName..."
#     
#     netsh interface ip set address name="$adapterName" static $ipAddress $subnetMask $gateway
#     netsh interface ip set dns name="$adapterName" static 8.8.8.8 primary
#     netsh interface ip add dns name="$adapterName" 8.8.8.8 index=2
#     
#     Write-Host "Network configuration has been set."
# }

# Map network drive
New-PSDrive -Name "Z" -PSProvider FileSystem -Root "\\host.lan\common" -Persist:$true
Write-Host "Setting network configuration for $adapterName..."

# Set static IP configuration
netsh interface ip set address name="$adapterName" static $ipAddress $subnetMask $gateway
netsh interface ip set dns name="$adapterName" static 8.8.8.8 primary
netsh interface ip add dns name="$adapterName" 8.8.8.8 index=2

Write-Host "Network configuration has been set."

Write-Host "NIC configuration complete."
