@echo off
REM ============================================================================
REM OA Agent Windows 설치 스크립트
REM
REM 관리자 권한으로 실행하세요.
REM 1. JAR 파일을 Program Files에 복사
REM 2. 로그온 시 자동 시작 Task 등록
REM ============================================================================

echo.
echo ========================================
echo   OA Agent Windows Installer
echo ========================================
echo.

REM 관리자 권한 확인
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [오류] 관리자 권한이 필요합니다.
    echo 마우스 오른쪽 클릭 - "관리자 권한으로 실행"을 선택하세요.
    pause
    exit /b 1
)

REM 설치 디렉토리
set INSTALL_DIR=%ProgramFiles%\OAAgent
set JAR_NAME=windows.jar

REM 설치 디렉토리 생성
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

REM JAR 파일 복사
echo [1/3] JAR 파일 복사 중...
copy /Y "%~dp0%JAR_NAME%" "%INSTALL_DIR%\%JAR_NAME%" >nul
if %errorlevel% neq 0 (
    echo [오류] JAR 파일을 찾을 수 없습니다: %~dp0%JAR_NAME%
    pause
    exit /b 1
)
echo       완료: %INSTALL_DIR%\%JAR_NAME%

REM Java 경로 확인
echo [2/3] Java 확인 중...
where javaw.exe >nul 2>&1
if %errorlevel% neq 0 (
    echo [경고] javaw.exe를 찾을 수 없습니다.
    echo Java 17 이상을 설치하고 PATH에 추가하세요.
    echo https://adoptium.net/
    pause
    exit /b 1
)
echo       Java 확인 완료

REM Task Scheduler에 로그온 시 자동 시작 등록
echo [3/3] 자동 시작 등록 중...
schtasks /Create /SC ONLOGON /TN "OAAgent_Startup" /TR "javaw.exe -jar \"%INSTALL_DIR%\%JAR_NAME%\"" /RL HIGHEST /F >nul 2>&1
if %errorlevel% neq 0 (
    echo [경고] 자동 시작 등록 실패. 수동으로 등록하세요.
) else (
    echo       자동 시작 등록 완료
)

echo.
echo ========================================
echo   설치 완료!
echo ========================================
echo.
echo 설치 경로: %INSTALL_DIR%
echo 자동 시작: 로그온 시 실행
echo.
echo 지금 실행하려면 아래 명령을 사용하세요:
echo   javaw -jar "%INSTALL_DIR%\%JAR_NAME%"
echo.

REM 바로 실행 여부 확인
set /p RUN_NOW="지금 바로 실행하시겠습니까? (Y/N): "
if /i "%RUN_NOW%"=="Y" (
    start "" javaw.exe -jar "%INSTALL_DIR%\%JAR_NAME%"
    echo 에이전트가 시작되었습니다. 시스템 트레이를 확인하세요.
)

pause
