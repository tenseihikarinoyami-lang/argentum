# PowerShell Script to Start Chrome with Debugging and Run Tests

Write-Host "=================================" -ForegroundColor Cyan
Write-Host "[STARTUP] Starting Chrome with Remote Debugging" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Kill any existing Chrome processes
Write-Host "[1/4] Cleaning up existing Chrome processes..." -ForegroundColor Yellow
Get-Process chrome -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

# Start Chrome with remote debugging port
Write-Host "[2/4] Starting Chrome with debugging on port 9222..." -ForegroundColor Yellow
$ChromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"

if (-Not (Test-Path $ChromePath)) {
    $ChromePath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
}

if (-Not (Test-Path $ChromePath)) {
    Write-Host "[ERROR] Chrome not found at standard paths!" -ForegroundColor Red
    exit 1
}

# Start Chrome in the background
Start-Process $ChromePath -ArgumentList "--remote-debugging-port=9222 --no-first-run --no-default-browser-check https://qxbroker.com/demo-trade"

# Wait for Chrome to start
Write-Host "[3/4] Waiting for Chrome to start (15 seconds)..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# Run the Python test
Write-Host "[4/4] Running DOM price extraction test..." -ForegroundColor Yellow
Write-Host ""

Set-Location "C:\Users\usuario\Documents\2"
python test_dom_price_extraction_complete.py

Write-Host ""
Write-Host "=================================" -ForegroundColor Cyan
Write-Host "[DONE] Test completed" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan