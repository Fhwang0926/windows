@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

ping 1.1.1.1 -n 5

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

@REM all disabled

set "firstAdapterFound=0"

for /f "tokens=3,* delims=: " %%i in ('netsh interface show interface ^| findstr /R /C:"^.*연결됨" /C:"^.*Connected"') do (
    if "!firstAdapterFound!"=="0" (
        set "firstAdapterFound=1"
        echo pass first nic: %%j
    ) else (
        echo disable nic: %%j
        netsh interface set interface "%%j" admin=disable
    )
)

@REM cls

echo nic configuration complete

pause