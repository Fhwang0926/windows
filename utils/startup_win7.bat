@echo off

set count=0
set gatewayConfigured=No


@REM for /f "tokens=3" %%a in ('netsh interface ip show config name^="%adapterName%" ^| findstr /C:"기본 게이트웨이" /C:"Default Gateway"') do (
@REM     if not "%%a"=="" set gatewayConfigured=Yes

@REM     set /a count+=1
@REM     echo %%a %count%
@REM )


echo excute script
net use Z: \\host.lan\common /persistent:yes
echo connected host.lan

call Z:\auto_ip_set.bat

@REM if "%gatewayConfigured%"=="Yes" (
    
@REM ) else (
@REM     echo already first nic gateway connected
@REM )

net use Z: /delete /y

ipconfig

pause

:end

endlocal

