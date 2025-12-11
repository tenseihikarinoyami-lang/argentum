@echo off
REM ============================================================================
REM TRADING BOT EXECUTION - WITH FIXES VERIFICATION
REM Verifies all corrections before running
REM ============================================================================

setlocal enabledelayedexpansion

echo.
echo ================================================================================
echo         TRADING BOT - COMPLETE SYSTEM (WITH FIXES)
echo ================================================================================
echo.

REM Check Python installation
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python not found
    pause
    exit /b 1
)

echo [SETUP] Installing dependencies...
pip install -q tensorflow lightgbm pandas numpy scikit-learn requests pygame pillow colorama flask flask-cors prometheus-client --no-warn-script-location

if errorlevel 1 (
    echo [ERROR] Dependency installation failed
    pause
    exit /b 1
)

echo [SETUP] Dependencies installed successfully!
echo.

REM Verify all fixes are applied
echo [1/3] Verifying fixes...
python verify_fixes.py
if errorlevel 1 (
    echo.
    echo [WARNING] Some fixes may not be applied correctly
    echo [INFO] Continuing anyway...
    echo.
)

echo.
echo [2/3] Checking dependencies...
pip show colorama >nul 2>&1
if errorlevel 1 (
    pip install -q colorama
)

echo.
echo [3/3] Starting Trading Bot with Fixes...
echo.
echo ================================================================================
echo STATUS: Ready to start
echo TIME: %date% %time%
echo ================================================================================
echo.

python main.py

if errorlevel 1 (
    echo.
    echo [ERROR] Bot encountered an error
    pause
    exit /b 1
)

echo.
echo ================================================================================
echo BOT STOPPED SUCCESSFULLY
echo ================================================================================
pause
exit /b 0
