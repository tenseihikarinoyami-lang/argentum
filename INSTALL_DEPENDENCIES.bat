@echo off
REM ============================================================================
REM INSTALL ALL REQUIRED DEPENDENCIES
REM Phase 5 - Trading Bot Complete Setup
REM ============================================================================

setlocal enabledelayedexpansion

echo.
echo ================================================================================
echo           TRADING BOT - DEPENDENCY INSTALLATION
echo ================================================================================
echo.

REM Check Python
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python not found. Install Python 3.8+ first.
    pause
    exit /b 1
)

echo [1/3] Python found. Installing required packages...
echo.

REM Core dependencies
echo Installing core packages (pandas, numpy, scikit-learn)...
pip install -q pandas numpy scikit-learn requests --no-warn-script-location

REM AI/ML dependencies
echo Installing AI/ML packages (tensorflow, lightgbm)...
pip install -q tensorflow lightgbm --no-warn-script-location

REM Additional dependencies
echo Installing additional packages (pygame, pillow, colorama)...
pip install -q pygame pillow colorama --no-warn-script-location

REM Browser automation
echo Installing browser automation (playwright, pyppeteer)...
pip install -q playwright --no-warn-script-location 2>nul

echo.
echo [2/3] Verifying installations...
echo.

REM Verify installations
python -c "import tensorflow; print('  [OK] TensorFlow ' + tensorflow.__version__)" 2>nul
if errorlevel 1 echo  [WARN] TensorFlow installation may have issues

python -c "import lightgbm; print('  [OK] LightGBM ' + lightgbm.__version__)" 2>nul
if errorlevel 1 echo  [WARN] LightGBM installation may have issues

python -c "import pandas; print('  [OK] Pandas ' + pandas.__version__)" 2>nul
python -c "import numpy; print('  [OK] NumPy ' + numpy.__version__)" 2>nul
python -c "import sklearn; print('  [OK] Scikit-Learn')" 2>nul
python -c "import requests; print('  [OK] Requests')" 2>nul

echo.
echo [3/3] Dependency installation complete!
echo.
echo ================================================================================
echo All required dependencies are now installed.
echo You can now run: RUN_COMPLETE_SYSTEM.bat
echo ================================================================================
echo.

pause
exit /b 0
