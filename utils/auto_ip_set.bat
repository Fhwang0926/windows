
@REM @echo off

@REM setlocal ENABLEDELAYEDEXPANSION
@REM set INTERFACE_NAME=LAN

@REM ping 1.1.1.1 -n 3

@REM @REM @REM get first nic name
@REM @REM for /f "tokens=4" %%i in ('netsh interface show interface ^| findstr /R /C:"^.*Enabled" /C:"^.*활성화"') do (
@REM @REM     set INTERFACE_NAME=%%i
@REM @REM     goto setAddress
@REM @REM )

@REM :setAddress
@REM IF NOT "!INTERFACE_NAME!"=="" (
@REM     netsh interface ip set address name="!INTERFACE_NAME!" static WIN_IP 255.255.255.0 WIN_GW 1
@REM     netsh interface ip set dns name="!INTERFACE_NAME!" static 8.8.8.8 1
@REM     netsh interface ip add dns name="!INTERFACE_NAME!" 8.8.8.8 index=2

@REM     echo renew !INTERFACE_NAME!
@REM ) ELSE (
@REM     echo not found nic !INTERFACE_NAME!
@REM )

@REM @REM all disabled

@REM set firstAdapterFound=0

@REM net use Z: \\host.lan\common /persistent:yes

@REM for /f "tokens=3,* delims=: " %%i in ('netsh interface show interface ^| findstr /R /C:"^.*연결됨" /C:"^.*Connected"') do (
@REM     if "!firstAdapterFound!"=="0" (
@REM         set "firstAdapterFound=1"
@REM         echo pass first nic: %%j
@REM     ) else (
@REM         echo disable nic: %%j
@REM         netsh interface set interface "%%j" admin=disable
@REM     )
@REM )

@REM @REM cls

@REM echo nic configuration complete

@REM pause



@echo off
setlocal

set adapterName=LAN
set ipAddress=WIN_IP
set subnetMask=WIN_SN
set gateway=WIN_GW

:: Check if the adapter has an IP address
for /f "tokens=3" %%a in ('netsh interface ip show config name^="%adapterName%" ^| findstr "IP Address"') do (
    set currentIP=%%a
)

:: If the IP address is not set, configure it
if "%currentIP%"=="" (

    net use Z: \\host.lan\common /persistent:yes

    echo Setting IP Address for %adapterName%...
    netsh interface ip set address name="%adapterName%" static %ipAddress% %subnetMask% %gateway%
    netsh interface ip set dns name="!INTERFACE_NAME!" static 8.8.8.8 1
    netsh interface ip add dns name="!INTERFACE_NAME!" 8.8.8.8 index=2
    echo IP Address has been set to %ipAddress%.
) else (
    echo %adapterName% already has an IP address (%currentIP%). No changes made.
)

echo nic configuration complete

endlocal