@echo off
setlocal

set adapterName=LAN
set ipAddress=WIN_IP
set subnetMask=WIN_SN
set gateway=WIN_GW

@REM ping -n 1 %gateway% >nul

@REM if %errorlevel%==0 (
@REM     echo Connection already.

@REM ) else (
@REM     net use Z: \\host.lan\common /persistent:yes
@REM     echo Setting network configuration for %adapterName%...

@REM     netsh interface ip set address name="%adapterName%" static %ipAddress% %subnetMask% %gateway%
@REM     netsh interface ip set dns name="%adapterName%" static 8.8.8.8 primary
@REM     netsh interface ip add dns name="%adapterName%" 8.8.8.8 index=2

@REM     echo Network configuration has been set.
@REM )

net use Z: \\host.lan\common /persistent:yes
echo Setting network configuration for %adapterName%...

netsh interface ip set address name="%adapterName%" static %ipAddress% %subnetMask% %gateway%
netsh interface ip set dns name="%adapterName%" static 8.8.8.8 primary
netsh interface ip add dns name="%adapterName%" 8.8.8.8 index=2

echo Network configuration has been set.


echo NIC configuration complete.

endlocal
