@echo off
REM ============================================================================
REM COMPLETE TRADING BOT EXECUTION COMMAND
REM Phase 5 - Production Ready with Auto-Dependencies
REM ============================================================================

setlocal enabledelayedexpansion

echo.
echo ================================================================================
echo         TRADING BOT - COMPLETE SYSTEM INITIALIZATION & EXECUTION
echo ================================================================================
echo.

REM Check Python installation
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.8+ from https://www.python.org/
    pause
    exit /b 1
)

echo [SETUP] Installing required dependencies...
echo [SETUP] This may take 2-5 minutes on first run...
echo.

REM Install core dependencies silently
pip install -q tensorflow lightgbm pandas numpy scikit-learn requests pygame pillow colorama --no-warn-script-location

if errorlevel 1 (
    echo ERROR: Failed to install dependencies
    echo Please run: pip install tensorflow lightgbm pandas numpy scikit-learn
    pause
    exit /b 1
)

echo [SETUP] Dependencies installed successfully!
echo.
echo [1/4] Validating Phase 5 Integration...
python VALIDATE_PHASE5_COMPLETE.py
if errorlevel 1 (
    echo ERROR: Validation failed. Check logs above.
    pause
    exit /b 1
)

echo.
echo [2/4] Checking dependencies...
pip show colorama >nul 2>&1
if errorlevel 1 (
    echo Installing required packages...
    pip install -q colorama
)

echo.
echo [3/4] Starting Trading Bot...
echo.
echo SYSTEM STATUS: [OK] All validations passed
echo TIME: %date% %time%
echo.

python main.py

if errorlevel 1 (
    echo.
    echo ERROR: Bot encountered an error
    echo Check logs for details
    pause
    exit /b 1
)

echo.
echo ================================================================================
echo         BOT STOPPED SUCCESSFULLY
echo ================================================================================
pause
exit /b 0
