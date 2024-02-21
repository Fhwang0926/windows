@echo off
setlocal enableextensions enabledelayedexpansion

@REM get first nic name
for /f "tokens=3,* delims= " %%i in ('netsh interface show interface ^| findstr /R /C:"^.*Enabled" /C:"^.*활성화"') do (
    set INTERFACE_NAME=%%j
    goto checkGateway
)

:checkGateway
set has_gateway=0
set count=0
for /f "tokens=2 delims=:" %%a in ('netsh interface ipv4 show config name^="!INTERFACE_NAME!" ^| findstr /C:"Default Gateway" /C:"기본 게이트웨이"') do (
    set /a count+=1
    if not "%%a"=="" (
        set has_gateway=1
    )
)

@REM if !count! EQU 1 (
@REM     echo already actived
@REM     goto :eof
@REM ) else (
@REM     echo continue network setting
@REM )

if !has_gateway! EQU 0 (
    echo execute script
    @REM net use Z: /delete /y
    net use Z: \\host.lan\common /persistent:yes
    echo connected host.lan

    call Z:\auto_ip_set.bat
) else (
    echo already first nic gateway connected
)

net use Z: /delete /y

ipconfig

pause

:end
endlocal
