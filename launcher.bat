@echo off
setlocal enabledelayedexpansion

echo ========================================
echo  Hospital NMS - Starting Services
echo ========================================
echo.

:: Set working directory to script location
cd /d "%~dp0"

:: Check if Go is installed
where go >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Go is not installed or not in PATH.
    echo Please install Go from https://go.microsoft.com/fwlink/?linkid=2240696
    pause
    exit /b 1
)

:: Set default backend path
set BACKEND_DIR=backend
set SERVER_EXE=server.exe

:: Build the Go backend
echo [1/4] Building Go backend...
cd /d "%BACKEND_DIR%"
go build -ldflags="-s -w" -o "%SERVER_EXE%" ./cmd/server/
if %errorlevel% neq 0 (
    echo [ERROR] Failed to build Go backend.
    pause
    exit /b 1
)
echo [OK] Go backend built successfully.

:: Kill any existing backend process
echo [2/4] Checking for existing backend processes...
tasklist /FI "IMAGENAME eq server.exe" 2>NUL | find /I /N "server.exe" >NUL
if %errorlevel% equ 0 (
    echo [INFO] Stopping existing backend process...
    taskkill /F /IM server.exe >nul 2>&1
    timeout /t 2 /nobreak >nul
)

:: Start the Go backend
echo [3/4] Starting Go backend on port 8080...
start "Hospital NMS Backend" /B /MIN "%SERVER_EXE%"
if %errorlevel% neq 0 (
    echo [ERROR] Failed to start Go backend.
    pause
    exit /b 1
)
echo [OK] Go backend started.

:: Wait for backend to be ready
echo [INFO] Waiting for backend to accept connections...
set BACKEND_READY=false
for /l %%i in (1,1,30) do (
    >nul 2>&1 (
        curl -s http://localhost:8080/health >nul
    ) && (
        set BACKEND_READY=true
        goto :backend_ready
    )
    timeout /t 1 /nobreak >nul
)

:backend_ready
if "%BACKEND_READY%"=="true" (
    echo [OK] Backend is ready.
) else (
    echo [WARNING] Backend did not respond within 30 seconds.
    echo [INFO] Continuing anyway - the Flutter app will retry.
)

:: Return to project root
cd /d "%~dp0"

:: Start Flutter app
echo [4/4] Starting Flutter application...
echo.
echo ========================================
echo  Flutter app will open in a new window.
echo  Close this window to stop all services.
echo ========================================
echo.

start "Hospital NMS Flutter" /B /MIN flutter run -d windows

:: Wait for user to press Ctrl+C or close window
echo Press Ctrl+C to stop all services...
echo.

:: Keep the window open and handle cleanup on exit
>nul 2>&1 (
    waitfor NeverGoingToHappen /T 86400
)

:cleanup
echo.
echo Shutting down all services...
taskkill /F /IM server.exe >nul 2>&1
echo [OK] All services stopped.
pause
exit /b 0
