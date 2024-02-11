@echo off
setlocal enableextensions enabledelayedexpansion

@REM get first nic name
for /f "tokens=4" %%i in ('netsh interface show interface ^| findstr /R /C:"^.*Enabled" /C:"^.*활성화"') do (
    set INTERFACE_NAME=%%i
    goto checkGateway
)

:checkGateway
set GATEWAY_FOUND=0
for /f "tokens=2" %%a in ('netsh interface ipv4 show config name^="%INTERFACE_NAME%" ^| findstr /C:"Default Gateway" /C:"기본 게이트웨이"') do (
    echo %%a
    if not "%%a"=="" (
        set GATEWAY_FOUND=1
    )
)


if !GATEWAY_FOUND! EQU 0 (
    echo excute script
    call \\host.lan\common\auto_ip.bat
) else (
    echo connected
)

endlocal