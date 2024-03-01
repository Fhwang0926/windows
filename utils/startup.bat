@echo off

set count=0
set gatewayConfigured=No


for /f "tokens=3" %%a in ('netsh interface ip show config name^="%adapterName%" ^| findstr /C:"기본 게이트웨이" /C:"Default Gateway"') do (
    if not "%%a"=="" set gatewayConfigured=Yes

    set /a count+=1
    echo %%a %count%
)

if "%gatewayConfigured%"=="Yes" (
    echo excute script
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

