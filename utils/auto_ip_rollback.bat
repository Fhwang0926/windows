@echo off
setlocal ENABLEDELAYEDEXPANSION
ping 1.1.1.1 -n 2


set adapterName=LAN

IF NOT "%adapterName%"=="" (
    netsh interface ipv4 set address name="%adapterName%" dhcp
    netsh interface ipv4 set dnsservers name="%adapterName%" dhcp

    echo renew dhcp %adapterName%
) ELSE (
    echo not found nic %adapterName%
)

@REM cls

echo nic rollback complete

ipconfig

echo .
echo .

pause