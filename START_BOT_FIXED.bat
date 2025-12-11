@echo off
REM ============================================================================
REM                    START BOT WITH PROFESSIONAL FIXES
REM ============================================================================
REM Run this file to start the trading bot with all fixes applied

chcp 65001 > nul
cls

echo.
echo ============================================================================
echo                    STARTING TRADING BOT (FIXED VERSION)
echo ============================================================================
echo.

REM Change to bot directory
cd /d C:\Users\usuario\Documents\2

REM Verify Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python not found. Please install Python 3.8+ first.
    echo Download from: https://www.python.org/downloads/
    pause
    exit /b 1
)

echo [OK] Python found: 
python --version

REM Verify main.py exists
if not exist main.py (
    echo ERROR: main.py not found in current directory
    echo Current directory: %cd%
    pause
    exit /b 1
)

echo [OK] main.py found

REM Verify config.json exists
if not exist config.json (
    echo ERROR: config.json not found. Please create it first.
    pause
    exit /b 1
)

echo [OK] config.json found

REM Verify database exists (or create it)
if not exist trading_signals.db (
    echo [INFO] Database will be created on first run
)

echo.
echo ============================================================================
echo VERIFICATION CHECKLIST
echo ============================================================================

REM Check Fix #1: Math error corrected
findstr "last_wl" main.py >nul
if errorlevel 1 (
    echo [WARN] Fix #1 might not be applied (last_wl not found)
) else (
    echo [OK] Fix #1: Math error corrected
)

REM Check Fix #3: ML threshold lowered
findstr "threshold = 0.01" main.py >nul
if errorlevel 1 (
    echo [WARN] Fix #3 might not be applied (threshold not found)
) else (
    echo [OK] Fix #3: ML threshold lowered
)

REM Check Fix #2: Method exists
findstr "def save_ml_training_data" database.py >nul
if errorlevel 1 (
    echo [WARN] Fix #2 might not be applied (method not found)
) else (
    echo [OK] Fix #2: save_ml_training_data method exists
)

echo.
echo ============================================================================
echo STARTING BOT
echo ============================================================================
echo.
echo Bot will start in a moment...
echo Press Ctrl+C to stop the bot
echo.
echo Web interface will be available at:
echo   http://localhost:8080
echo.
timeout /t 3

REM Start the bot
python main.py

REM If bot crashes, show error
if errorlevel 1 (
    echo.
    echo ============================================================================
    echo ERROR: Bot crashed or failed to start
    echo ============================================================================
    echo.
    echo Check the error messages above for details.
    echo.
    echo Common issues:
    echo   1. Browser not installed or not working
    echo   2. Config file has wrong settings
    echo   3. Port 8080 already in use
    echo   4. Missing dependencies (pip install -r requirements.txt)
    echo.
    pause
    exit /b 1
)

pause
