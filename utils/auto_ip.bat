@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

@REM get first nic name
for /f "tokens=3" %%i in ('netsh interface show interface ^| findstr /R /C:"^.*Enabled" /C:"^.*활성화"') do (
    set INTERFACE_NAME=%%i
    goto checkGateway
)

:
IF NOT "!LAST_INTERFACE!"=="" (
    netsh interface ip set address name="!LAST_INTERFACE!" static 10.20.0.30 255.255.255.0 10.20.0.1 1
    :: DNS 서버 주소가 필요한 경우 아래 줄의 주석을 해제하고 사용
    :: netsh interface ip set dns name="!LAST_INTERFACE!" static 8.8.8.8

    echo 네트워크 설정이 적용된 인터페이스: !LAST_INTERFACE!
) ELSE (
    echo 사용 가능한 네트워크 인터페이스를 찾을 수 없습니다.
)

pause