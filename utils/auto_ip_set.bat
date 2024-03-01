@echo off
setlocal

set adapterName=LAN
set ipAddress=WIN_IP
set subnetMask=WIN_SN
set gateway=WIN_GW

ping -n 1 %gateway% >nul

if %errorlevel%==0 (
    echo Connection already.
    
) else (
    net use Z: \\host.lan\common /persistent:yes
    echo Setting network configuration for %adapterName%...

    netsh interface ip set address name="%adapterName%" static %ipAddress% %subnetMask% %gateway%
    netsh interface ip set dns name="%adapterName%" static 8.8.8.8 primary
    netsh interface ip add dns name="%adapterName%" 8.8.8.8 index=2

    echo Network configuration has been set.
)


echo NIC configuration complete.

endlocal
