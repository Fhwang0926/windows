@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

@REM get first nic name
for /f "tokens=4" %%i in ('netsh interface show interface ^| findstr /R /C:"^.*Enabled" /C:"^.*활성화"') do (
    set INTERFACE_NAME=%%i
    goto setAddress
)

:setAddress
IF NOT "!INTERFACE_NAME!"=="" (
    netsh interface ip set address name="!INTERFACE_NAME!" static 10.20.0.30 255.255.255.0 10.20.0.1 1
    netsh interface ip set dns name="!INTERFACE_NAME!" static 8.8.8.8

    echo renew !INTERFACE_NAME!
) ELSE (
    echo not found nic !INTERFACE_NAME!
)

pause