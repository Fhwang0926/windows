# PowerShell version of startup.bat

$count = 0
$gatewayConfigured = "No"

# Commented out section - gateway detection logic
# for /f "tokens=3" %%a in ('netsh interface ip show config name^="%adapterName%" ^| findstr /C:"기본 게이트웨이" /C:"Default Gateway"') do (
#     if not "%%a"=="" set gatewayConfigured=Yes
#     set /a count+=1
#     echo %%a %count%
# )

Write-Host "excute script"

# Map network drive
New-PSDrive -Name "Z" -PSProvider FileSystem -Root "\\host.lan\common" -Persist:$true
Write-Host "connected host.lan"

# Execute the auto_ip_set script
& "Z:\auto_ip_set.ps1"

# Commented out conditional logic
# if ($gatewayConfigured -eq "Yes") {
#     
# } else {
#     Write-Host "already first nic gateway connected"
# }

# Remove network drive
Remove-PSDrive -Name "Z" -Force

# Display IP configuration
ipconfig

# Pause for user input
Read-Host "Press Enter to continue"
