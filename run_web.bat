@echo off
REM ==============================================================================
REM Sri Manakula Vinayagar Medical College & Hospital - OPD Connect
REM Hospital Outpatient Web Application Launcher for Windows
REM ==============================================================================

setlocal enabledelayedexpansion
title SMVMCH OPD Connect - Web Portal

set "DIR=%~dp0"
cd /d "%DIR%"

echo ================================================================================
echo    SRI MANAKULA VINAYAGAR MEDICAL COLLEGE ^& HOSPITAL - OPD CONNECT
echo    Hospital Outpatient Web Portal Launcher (Windows)
echo ================================================================================
echo.
echo Select an option (Auto-launching Option 1 in 5 seconds):
echo   [1] Fast Production Web Portal (Instant, Pre-compiled release bundle)
echo   [2] Flutter Development Server (Hot-reload with 'flutter run -d chrome')
echo   [3] Backend API Server (FastAPI on http://127.0.0.1:8000)
echo   [4] Full Stack (Start Backend API + Launch Web Portal)
echo.

choice /c 1234 /t 5 /d 1 /m "Choose launch option:"
set CHOICE_VAL=%ERRORLEVEL%

if %CHOICE_VAL% EQU 1 goto RUN_PROD_WEB
if %CHOICE_VAL% EQU 2 goto RUN_DEV_WEB
if %CHOICE_VAL% EQU 3 goto RUN_BACKEND
if %CHOICE_VAL% EQU 4 goto RUN_FULLSTACK

:RUN_PROD_WEB
echo.
echo [*] Initializing Fast Production Web Portal on port 54321...
set PORT=54321

REM Resolve compiled web app directory containing index.html
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
    echo [*] Checking for Flutter SDK to build web bundle...
    where flutter >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo [*] Compiling web application via Flutter...
        cd /d "%DIR%frontend"
        call flutter build web --release
        cd /d "%DIR%"
        set "WEB_DIR=%DIR%frontend\build\web"
    ) else (
        echo [ERROR] Web application bundle is missing and Flutter is not installed.
        echo Please ensure the 'web_app' folder exists.
        pause
        exit /b 1
    )
)

echo [✓] Serving Web Portal from: !WEB_DIR!

REM Start Server via dedicated Python script if available
if exist "%DIR%serve_web.py" (
    where python >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo [*] Launching Server via Python...
        start "OPD Connect Web Server" /min python "%DIR%serve_web.py" %PORT%
        goto OPEN_WEB
    )
    where py >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo [*] Launching Server via py launcher...
        start "OPD Connect Web Server" /min py "%DIR%serve_web.py" %PORT%
        goto OPEN_WEB
    )
)

REM Start Server via PowerShell if Python missing
if exist "%DIR%serve_web.ps1" (
    where powershell >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo [*] Launching Server via Windows PowerShell...
        start "OPD Connect Web Server" /min powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%serve_web.ps1" -Port %PORT%
        goto OPEN_WEB
    )
)

REM Fallback: cd strictly to WEB_DIR before running http.server
cd /d "!WEB_DIR!"
where python >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    start "OPD Connect Web Server" /min python -m http.server %PORT% --bind 127.0.0.1
    cd /d "%DIR%"
    goto OPEN_WEB
)
where py >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    start "OPD Connect Web Server" /min py -m http.server %PORT% --bind 127.0.0.1
    cd /d "%DIR%"
    goto OPEN_WEB
)
cd /d "%DIR%"

:OPEN_WEB
timeout /t 2 >nul
echo [✓] Opening Web Portal in browser...
start http://127.0.0.1:%PORT%
echo.
echo ================================================================================
echo  [✓] Web Portal is running at: http://127.0.0.1:%PORT%
echo  Keep this console window open while using the hospital portal.
echo ================================================================================
pause >nul
exit /b 0

:RUN_DEV_WEB
echo.
echo [*] Launching Flutter Development Web Server...
cd /d "%DIR%frontend"
flutter run -d chrome --web-renderer canvaskit
exit /b 0

:RUN_BACKEND
echo.
echo [*] Starting FastAPI Backend on http://127.0.0.1:8000...
cd /d "%DIR%backend"
if exist "venv\Scripts\activate.bat" (
    call venv\Scripts\activate.bat
)
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
exit /b 0

:RUN_FULLSTACK
echo.
echo [*] Launching Backend API in background...
start "OPD Connect Backend" cmd /k "cd /d %DIR%backend && (if exist venv\Scripts\activate.bat call venv\Scripts\activate.bat) && uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload"
timeout /t 3 >nul
goto RUN_PROD_WEB
