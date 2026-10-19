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
    echo [✓] Found Standalone Desktop App in desktop_builds!
    echo [*] Launching OPD Connect.exe...
    start "" "%DIR%desktop_builds\OPD Connect-win32-x64\OPD Connect.exe"
    echo [✓] Workstation application started successfully.
    timeout /t 3 >nul
    exit /b 0
)

REM 2. Check if packaged Windows executable exists in desktop\dist
if exist "%DIR%desktop\dist\OPD Connect-win32-x64\OPD Connect.exe" (
    echo [✓] Found Standalone Desktop App in desktop\dist!
    echo [*] Launching OPD Connect.exe...
    start "" "%DIR%desktop\dist\OPD Connect-win32-x64\OPD Connect.exe"
    echo [✓] Workstation application started successfully.
    timeout /t 3 >nul
    exit /b 0
)

REM 3. Resolve compiled web app directory containing index.html
set "WEB_DIR="
if exist "%DIR%web_app\index.html" (
    set "WEB_DIR=%DIR%web_app"
) else if exist "%DIR%frontend\build\web\index.html" (
    set "WEB_DIR=%DIR%frontend\build\web"
) else if exist "%DIR%desktop\web\index.html" (
    set "WEB_DIR=%DIR%desktop\web"
)

if "!WEB_DIR!"=="" (
    echo [!] Warning: Compiled web directory not found.
    echo [*] Checking for Flutter SDK to build web workstation...
    where flutter >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo [*] Compiling web application via Flutter...
        cd /d "%DIR%frontend"
        call flutter build web --release
        cd /d "%DIR%"
        set "WEB_DIR=%DIR%frontend\build\web"
    ) else (
        echo [ERROR] Web application bundle is missing and Flutter is not installed.
        echo Please ensure the 'web_app' folder exists or download the desktop build.
        pause
        exit /b 1
    )
)

echo [✓] Located Web Workstation: !WEB_DIR!
set PORT=54321

REM 4. Start Local Clinical Workstation Server (Dedicated Python / PowerShell)
if exist "%DIR%serve_web.py" (
    where python >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo [*] Starting Clinical Workstation Server via Python...
        start "OPD Connect Server" /min python "%DIR%serve_web.py" %PORT%
        goto LAUNCH_APP
    )
    where py >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo [*] Starting Clinical Workstation Server via py launcher...
        start "OPD Connect Server" /min py "%DIR%serve_web.py" %PORT%
        goto LAUNCH_APP
    )
)

if exist "%DIR%serve_web.ps1" (
    where powershell >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo [*] Starting Clinical Workstation Server via Windows PowerShell...
        start "OPD Connect Server" /min powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%serve_web.ps1" -Port %PORT%
        goto LAUNCH_APP
    )
)

REM Fallback if scripts missing: cd strictly to WEB_DIR
cd /d "!WEB_DIR!"
where python >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [*] Starting fallback HTTP server via Python in web directory...
    start "OPD Connect Server" /min python -m http.server %PORT% --bind 127.0.0.1
    cd /d "%DIR%"
    goto LAUNCH_APP
)

where py >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [*] Starting fallback HTTP server via py in web directory...
    start "OPD Connect Server" /min py -m http.server %PORT% --bind 127.0.0.1
    cd /d "%DIR%"
    goto LAUNCH_APP
)

cd /d "%DIR%"

:LAUNCH_APP
timeout /t 2 >nul

REM 5. Open in Dedicated Workstation App Window (Microsoft Edge or Google Chrome)
where msedge >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [✓] Launching in Microsoft Edge Dedicated App Mode (1280x820)...
    start "" msedge --app="http://127.0.0.1:%PORT%" --window-size=1280,820
    goto FINISH
)

where chrome >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [✓] Launching in Google Chrome Dedicated App Mode (1280x820)...
    start "" chrome --app="http://127.0.0.1:%PORT%" --window-size=1280,820
    goto FINISH
)

echo [✓] Opening Workstation in default browser...
start http://127.0.0.1:%PORT%

:FINISH
echo.
echo ================================================================================
echo  [✓] SMVMCH OPD Connect Workstation is active on: http://127.0.0.1:%PORT%
echo  Keep this console window open during clinical sessions.
echo  Press any key to close this console.
echo ================================================================================
pause >nul
