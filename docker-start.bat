@echo off
REM ###############################################################################
REM ARGENTUM Trading Bot - Docker Quick Start Script (Windows)
REM Automated deployment and management
REM ###############################################################################

setlocal enabledelayedexpansion

REM Colors (Windows 10+)
for /F %%A in ('echo prompt $H ^| cmd') do set "BS=%%A"

:main
cls
echo.
echo ╔════════════════════════════════════════════════════════════════╗
echo ║         ARGENTUM Trading Bot - Docker Management              ║
echo ╚════════════════════════════════════════════════════════════════╝
echo.

REM Check Docker installation
where docker >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Docker is not installed or not in PATH
    echo.
    echo Install Docker Desktop from: https://www.docker.com/products/docker-desktop
    pause
    exit /b 1
)

where docker-compose >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Docker Compose is not installed or not in PATH
    pause
    exit /b 1
)

echo [OK] Docker and Docker Compose are installed
echo.

REM Check config.json
if not exist "config.json" (
    echo [WARNING] config.json not found
    if exist "config.example.json" (
        echo Creating config.json from example...
        copy config.example.json config.json
        echo [OK] config.json created (please edit with your settings)
    ) else (
        echo [ERROR] Neither config.json nor config.example.json found
        pause
        exit /b 1
    )
)

echo [OK] config.json found
echo.

REM Show menu
echo ========== MAIN MENU ==========
echo 1. Start bot
echo 2. Stop bot
echo 3. Restart bot
echo 4. Show status
echo 5. View logs
echo 6. Run tests
echo 7. Clean up
echo 8. Help
echo 9. Exit
echo.

set /p choice="Select option (1-9): "

if "%choice%"=="1" goto start
if "%choice%"=="2" goto stop
if "%choice%"=="3" goto restart
if "%choice%"=="4" goto status
if "%choice%"=="5" goto logs
if "%choice%"=="6" goto test
if "%choice%"=="7" goto clean
if "%choice%"=="8" goto help
if "%choice%"=="9" goto end
goto invalid

:start
cls
echo [INFO] Building Docker image (this may take a few minutes)...
docker-compose build --no-cache
if errorlevel 1 (
    echo [ERROR] Failed to build image
    pause
    goto main
)

echo.
echo [INFO] Starting ARGENTUM bot...
docker-compose up -d
if errorlevel 1 (
    echo [ERROR] Failed to start bot
    pause
    goto main
)

timeout /t 10 /nobreak
echo.
echo [OK] Bot started successfully
echo.
echo ========== ACCESS POINTS ==========
echo Web Dashboard:   http://localhost:5000
echo API Status:      http://localhost:5000/api/status
echo Signals:         http://localhost:5000/api/signals
echo Statistics:      http://localhost:5000/api/statistics
echo.

pause
goto main

:stop
cls
echo [INFO] Stopping ARGENTUM bot...
docker-compose down
if errorlevel 1 (
    echo [ERROR] Failed to stop bot
    pause
    goto main
)

echo [OK] Bot stopped
echo.
pause
goto main

:restart
cls
echo [INFO] Restarting ARGENTUM bot...
docker-compose restart
if errorlevel 1 (
    echo [ERROR] Failed to restart bot
    pause
    goto main
)

timeout /t 5 /nobreak
echo [OK] Bot restarted
echo.
pause
goto main

:status
cls
echo [INFO] Docker Container Status:
echo.
docker-compose ps
echo.
docker-compose logs --tail=20
echo.
pause
goto main

:logs
cls
echo [INFO] Real-time logs (Ctrl+C to exit):
echo.
docker-compose logs -f
goto main

:test
cls
echo [INFO] Running mode tests...
echo.
docker-compose exec -T argentum python test_modes_execution.py
echo.
pause
goto main

:clean
cls
echo [WARNING] This will remove containers and volumes (data will be lost)
set /p confirm="Are you sure? (y/N): "
if /i "%confirm%"=="y" (
    docker-compose down -v
    echo [OK] Cleaned up
) else (
    echo Cancelled
)
echo.
pause
goto main

:help
cls
echo ========== HELP ==========
echo.
echo 1. Start bot
echo    Builds the Docker image and starts the bot in background
echo    Access at: http://localhost:5000
echo.
echo 2. Stop bot
echo    Stops the running bot container
echo.
echo 3. Restart bot
echo    Restarts the bot container
echo.
echo 4. Show status
echo    Shows container status and recent logs
echo.
echo 5. View logs
echo    Shows real-time logs (Ctrl+C to exit)
echo.
echo 6. Run tests
echo    Verifies all operation modes (MONITOR, SEMI_AUTO, AUTO, HYBRID)
echo.
echo 7. Clean up
echo    Removes all containers and volumes
echo.
echo Configuration:
echo    - Edit config.json for bot settings
echo    - Restart bot after changes
echo.
echo Support:
echo    - Check logs for errors
echo    - Verify config.json syntax
echo    - Monitor with Docker Desktop
echo.
pause
goto main

:invalid
echo [ERROR] Invalid option
timeout /t 2 /nobreak
goto main

:end
exit /b 0
