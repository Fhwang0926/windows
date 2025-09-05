# PowerShell version of auto_cp.bat
Write-Host "starting copy..."

# Map network drive
New-PSDrive -Name "Y" -PSProvider FileSystem -Root "\\host.lan\download" -Persist:$false

# Copy files using robocopy
robocopy "Y:\" "$env:USERPROFILE\Downloads" /E /MOV

# Remove network drive
Remove-PSDrive -Name "Y" -Force

# Stop NFS service
Stop-Service -Name "nfs" -Force

Write-Host "copy complete."
