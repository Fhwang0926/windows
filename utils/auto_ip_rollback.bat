@echo off
setlocal ENABLEDELAYEDEXPANSION
ping 1.1.1.1 -n 2

@REM get first nic name
for /f "tokens=4" %%i in ('netsh interface show interface ^| findstr /R /C:"^.*Enabled" /C:"^.*활성화"') do (
    set INTERFACE_NAME=%%i
    goto setAddress
)

:setAddress
IF NOT "!INTERFACE_NAME!"=="" (
    netsh interface ipv4 set address name="!INTERFACE_NAME!" dhcp
    netsh interface ipv4 set dnsservers name="!INTERFACE_NAME!" dhcp

    echo renew dhcp !INTERFACE_NAME!
) ELSE (
    echo not found nic !INTERFACE_NAME!
)

@REM cls

echo nic rollback complete

echo .
echo .

pause