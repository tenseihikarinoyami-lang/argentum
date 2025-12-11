# Complete Bot Startup Script - Start Chrome and Run Bot with Real Data

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         QUOTEX TRADING BOT - STARTING WITH REAL DATA EXTRACTION              ║" -ForegroundColor Cyan
Write-Host "║           DOM-Based Price Extraction + WebSocket Interception                 ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Step 1: Kill existing Chrome processes
Write-Host "STEP 1/5: Cleaning up existing processes..." -ForegroundColor Yellow
Get-Process chrome -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process python -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match "main\.py" } | Stop-Process -Force
Start-Sleep -Seconds 2

# Step 2: Start Chrome with remote debugging
Write-Host "STEP 2/5: Starting Chrome with Remote Debugging on port 9222..." -ForegroundColor Yellow
$ChromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"

if (-Not (Test-Path $ChromePath)) {
    $ChromePath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
}

if (-Not (Test-Path $ChromePath)) {
    Write-Host "[ERROR] Chrome not found!" -ForegroundColor Red
    exit 1
}

# Start Chrome with debugging enabled, pointing to Quotex demo
$chromeProcess = Start-Process $ChromePath -ArgumentList "--remote-debugging-port=9222", "--no-first-run", "--no-default-browser-check", "https://qxbroker.com/demo-trade" -PassThru

Write-Host "      ✅ Chrome started (PID: $($chromeProcess.Id))" -ForegroundColor Green

# Step 3: Wait for Chrome to fully load
Write-Host "[STEP 3/5] Waiting for Chrome to fully load - 30 seconds..." -ForegroundColor Yellow
Write-Host "      Please wait while the browser initializes..." -ForegroundColor Gray

for ($i = 0; $i -lt 30; $i++) {
    Write-Host -NoNewline "."
    Start-Sleep -Seconds 1
}
Write-Host ""
Write-Host "      ✅ Chrome should be ready" -ForegroundColor Green

# Step 4: Give a final notice
Write-Host "[STEP 4/5] Pre-flight checks..." -ForegroundColor Yellow
Write-Host "      Please verify:" -ForegroundColor Gray
Write-Host "      ✓ Chrome window is open" -ForegroundColor Gray
Write-Host "      ✓ Quotex is loaded at qxbroker.com" -ForegroundColor Gray
Write-Host "      ✓ Chart is visible with real prices" -ForegroundColor Gray
Write-Host ""
Write-Host "      If any of these are not ready, cancel this script and refresh the browser." -ForegroundColor Yellow
Write-Host ""

Write-Host "[STEP 5/5] Starting Trading Bot with Real Data Mode..." -ForegroundColor Yellow
Write-Host ""

# Step 5: Run the Python bot
Set-Location "C:\Users\usuario\Documents\2"

Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "BOT STARTING..." -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Run bot
python main.py

# Cleanup on exit
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Bot stopped. Cleaning up..." -ForegroundColor Yellow
Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan

# Optional: Keep Chrome open for inspection
Write-Host ""
Write-Host "Chrome remains open for inspection. Close it manually when done." -ForegroundColor Gray