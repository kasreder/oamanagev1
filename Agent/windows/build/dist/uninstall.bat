@echo off
REM ============================================================================
REM OA Agent Windows 제거 스크립트
REM
REM 관리자 권한으로 실행하세요.
REM ============================================================================

echo.
echo ========================================
echo   OA Agent Windows Uninstaller
echo ========================================
echo.

REM 관리자 권한 확인
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [오류] 관리자 권한이 필요합니다.
    pause
    exit /b 1
)

set INSTALL_DIR=%ProgramFiles%\OAAgent

REM 실행 중인 프로세스 종료
echo [1/4] 실행 중인 에이전트 종료 중...
taskkill /F /IM javaw.exe /FI "WINDOWTITLE eq OA Agent*" >nul 2>&1

REM Task Scheduler 등록 해제
echo [2/4] 자동 시작 등록 해제 중...
schtasks /Delete /TN "OAAgent_Startup" /F >nul 2>&1
schtasks /Delete /TN "OAAgent_Heartbeat" /F >nul 2>&1
schtasks /Delete /TN "OAAgent_Heartbeat_Periodic" /F >nul 2>&1
echo       완료

REM 설치 파일 삭제
echo [3/4] 설치 파일 삭제 중...
if exist "%INSTALL_DIR%" (
    rmdir /S /Q "%INSTALL_DIR%"
    echo       완료: %INSTALL_DIR% 삭제됨
) else (
    echo       설치 디렉토리 없음
)

REM 설정 파일 삭제 확인
echo [4/4] 설정 파일 처리...
set CONFIG_DIR=%APPDATA%\OAAgent
if exist "%CONFIG_DIR%" (
    set /p DEL_CONFIG="설정 파일도 삭제하시겠습니까? (Y/N): "
    if /i "!DEL_CONFIG!"=="Y" (
        rmdir /S /Q "%CONFIG_DIR%"
        echo       설정 파일 삭제됨
    ) else (
        echo       설정 파일 유지: %CONFIG_DIR%
    )
) else (
    echo       설정 파일 없음
)

echo.
echo ========================================
echo   제거 완료!
echo ========================================
echo.

pause
