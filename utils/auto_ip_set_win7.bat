@echo off
setlocal ENABLEDELAYEDEXPANSION
ping 1.1.1.1 -n 5

@REM get first nic name
for /f "tokens=3,* delims=:" %%i in ('netsh interface show interface ^| findstr /R /C:"^.*Enabled" /C:"^.*활성화"') do (
    set INTERFACE_NAME=%%j
    set INTERFACE_NAME=!INTERFACE_NAME:~1!
    goto setAddress
)

:setAddress
IF NOT "!INTERFACE_NAME!"=="" (
    netsh interface ip set address name="!INTERFACE_NAME!" static WIN_IP 255.255.255.0 WIN_GW 1
    netsh interface ip set dns name="!INTERFACE_NAME!" static 8.8.8.8 primary
    netsh interface ip add dns name="!INTERFACE_NAME!" 8.8.8.8 index=2

    echo renew !INTERFACE_NAME!
) ELSE (
    echo not found nic !INTERFACE_NAME!
)

@REM all disabled

set "firstAdapterFound=0"

net use Z: \\host.lan\common /persistent:yes

@REM cls

echo nic configuration complete

pause
