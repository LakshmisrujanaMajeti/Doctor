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
echo [*] Starting Fast Production Web Portal on port 54321...
set PORT=54321
cd /d "%DIR%frontend\build\web"

where python >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    start "OPD Connect Web Server" /min python -m http.server %PORT% --bind 127.0.0.1
    goto OPEN_WEB
)

where py >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    start "OPD Connect Web Server" /min py -m http.server %PORT% --bind 127.0.0.1
    goto OPEN_WEB
)

where npx >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    start "OPD Connect Web Server" /min npx -y serve -s . -l %PORT%
    goto OPEN_WEB
)

start "" "%DIR%frontend\build\web\index.html"
exit /b 0

:OPEN_WEB
timeout /t 2 >nul
echo [OK] Opening Web Portal in browser...
start http://127.0.0.1:%PORT%
echo.
echo [OK] Web Portal is running at http://127.0.0.1:%PORT%
echo Keep this window open while using the portal.
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
