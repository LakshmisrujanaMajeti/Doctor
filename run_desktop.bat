@echo off
REM ==============================================================================
REM Sri Manakula Vinayagar Medical College & Hospital - OPD Connect
REM Desktop Clinical Workstation Launcher for Windows
REM ==============================================================================

setlocal enabledelayedexpansion
title SMVMCH OPD Connect - Clinical Workstation

set "DIR=%~dp0"
cd /d "%DIR%"

echo ================================================================================
echo    SRI MANAKULA VINAYAGAR MEDICAL COLLEGE ^& HOSPITAL - OPD CONNECT
echo    Hospital Outpatient Clinical Desktop Workstation (Windows)
echo ================================================================================
echo.

REM 1. Check if packaged Windows Standalone executable exists in desktop_builds
if exist "%DIR%desktop_builds\OPD Connect-win32-x64\OPD Connect.exe" (
    echo [OK] Found Standalone Desktop App in desktop_builds!
    echo [*] Launching OPD Connect.exe...
    start "" "%DIR%desktop_builds\OPD Connect-win32-x64\OPD Connect.exe"
    echo [OK] Workstation application started successfully.
    timeout /t 3 >nul
    exit /b 0
)

REM 2. Check if packaged Windows executable exists in desktop\dist
if exist "%DIR%desktop\dist\OPD Connect-win32-x64\OPD Connect.exe" (
    echo [OK] Found Standalone Desktop App in desktop\dist!
    echo [*] Launching OPD Connect.exe...
    start "" "%DIR%desktop\dist\OPD Connect-win32-x64\OPD Connect.exe"
    echo [OK] Workstation application started successfully.
    timeout /t 3 >nul
    exit /b 0
)

REM 3. Check if Node.js / Electron can run desktop workstation
where npm >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    if exist "%DIR%desktop\package.json" (
        echo [*] Launching Desktop Workstation via Electron...
        cd /d "%DIR%desktop"
        npm start
        exit /b 0
    )
)

REM 4. Fallback: Local Embedded Clinical Workstation Web Server
echo [*] Initializing Local Clinical Workstation Server on port 54321...
set PORT=54321
cd /d "%DIR%frontend\build\web"

REM Check for Python on Windows
where python >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [*] Starting local HTTP server via Python...
    start "OPD Connect Server" /min python -m http.server %PORT% --bind 127.0.0.1
    goto LAUNCH_BROWSER
)

where py >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [*] Starting local HTTP server via py launcher...
    start "OPD Connect Server" /min py -m http.server %PORT% --bind 127.0.0.1
    goto LAUNCH_BROWSER
)

REM Check for Node.js http-server / serve
where npx >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [*] Starting local HTTP server via npx serve...
    start "OPD Connect Server" /min npx -y serve -s . -l %PORT%
    goto LAUNCH_BROWSER
)

echo [!] Notice: Serving directly via local default browser...
start "" "%DIR%frontend\build\web\index.html"
exit /b 0

:LAUNCH_BROWSER
timeout /t 2 >nul

REM Open in Dedicated App Mode (Microsoft Edge or Google Chrome)
where msedge >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [OK] Launching in Microsoft Edge Dedicated App Mode...
    start "" msedge --app="http://127.0.0.1:%PORT%" --window-size=1280,820
    goto FINISH
)

where chrome >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [OK] Launching in Google Chrome Dedicated App Mode...
    start "" chrome --app="http://127.0.0.1:%PORT%" --window-size=1280,820
    goto FINISH
)

echo [OK] Opening in default web browser...
start http://127.0.0.1:%PORT%

:FINISH
echo.
echo ================================================================================
echo  [OK] OPD Connect Workstation is active on: http://127.0.0.1:%PORT%
echo  Keep this window open during your clinical shift.
echo  Press any key to close this console.
echo ================================================================================
pause >nul
