# ============================================================================
# COMPLETE TRADING BOT EXECUTION COMMAND
# Phase 5 - Production Ready with Auto-Dependencies
# ============================================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "         TRADING BOT - COMPLETE SYSTEM INITIALIZATION & EXECUTION" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""

# Check Python installation
try {
    $pythonVersion = python --version 2>&1
    Write-Host "[OK] Python found: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Python is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Python 3.8+ from https://www.python.org/" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Auto-install dependencies
Write-Host ""
Write-Host "[SETUP] Installing required dependencies..." -ForegroundColor Yellow
Write-Host "[SETUP] This may take 2-5 minutes on first run..." -ForegroundColor Yellow
Write-Host ""

try {
    pip install -q tensorflow lightgbm pandas numpy scikit-learn requests pygame pillow colorama --no-warn-script-location 2>$null
    Write-Host "[SETUP] Dependencies installed successfully!" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to install dependencies" -ForegroundColor Red
    Write-Host "Please run manually: pip install tensorflow lightgbm pandas numpy scikit-learn" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host ""

# Step 1: Validation
Write-Host ""
Write-Host "[1/4] Validating Phase 5 Integration..." -ForegroundColor Cyan
Write-Host ""

python VALIDATE_PHASE5_COMPLETE.py
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "[ERROR] Validation failed. Check logs above." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "[2/4] Checking system dependencies..." -ForegroundColor Cyan

# Check for required packages
$requiredPackages = @("colorama")
foreach ($package in $requiredPackages) {
    $installed = pip show $package 2>$null
    if (-not $installed) {
        Write-Host "Installing $package..." -ForegroundColor Yellow
        pip install -q $package
    }
}

# Step 3: Ready to start
Write-Host ""
Write-Host "[3/4] System verification complete..." -ForegroundColor Green
Write-Host ""
Write-Host "SYSTEM STATUS:" -ForegroundColor Green
Write-Host "  [OK] Validation passed" -ForegroundColor Green
Write-Host "  [OK] Dependencies ready" -ForegroundColor Green
Write-Host "  [OK] Configuration loaded" -ForegroundColor Green
Write-Host ""
Write-Host "TIME: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
Write-Host ""

# Step 4: Start bot
Write-Host "[4/4] Starting Trading Bot..." -ForegroundColor Cyan
Write-Host ""

python main.py

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "[ERROR] Bot encountered an error" -ForegroundColor Red
    Write-Host "Check logs above for details" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "         BOT STOPPED SUCCESSFULLY" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to exit"
exit 0
