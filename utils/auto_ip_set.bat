@echo off
setlocal

set adapterName=LAN
set ipAddress=WIN_IP
set subnetMask=WIN_SN
set gateway=WIN_GW

:: Check if the adapter has a gateway set
set gatewayConfigured=No
for /f "tokens=3" %%a in ('netsh interface ip show config name^="%adapterName%" ^| findstr /C:"Default Gateway" /C:"^.*기본 게이트웨이"') do (
    if not "%%a"=="" set gatewayConfigured=Yes
)

:: If the gateway is not set, configure the IP address, subnet mask, and gateway
if "%gatewayConfigured%"=="No" (
    net use Z: \\host.lan\common /persistent:yes

    echo Setting network configuration for %adapterName%...
    netsh interface ip set address name="%adapterName%" static %ipAddress% %subnetMask% %gateway%
    netsh interface ip set dns name="%adapterName%" static 8.8.8.8 primary
    netsh interface ip add dns name="%adapterName%" 8.8.8.8 index=2
    echo Network configuration has been set.
) else (
    echo %adapterName% already has a gateway configured. No changes made.
)

echo NIC configuration complete.

endlocal
