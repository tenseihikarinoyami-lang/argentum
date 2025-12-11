#!/usr/bin/env powershell
<#
.DESCRIPTION
    Complete bot startup script - Launches Chrome with debugging and starts the trading bot
#>

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                 QUOTEX TRADING BOT - COMPLETE STARTUP SEQUENCE                 ║" -ForegroundColor Cyan
Write-Host "║                   Real Data Extraction with DOM Fallback                      ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# STEP 1: Kill existing processes
# ============================================================================
Write-Host "[STEP 1] Cleaning up existing processes..." -ForegroundColor Yellow
Write-Host ""

Write-Host "   Stopping Chrome processes..." -ForegroundColor Gray
Get-Process chrome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue 2>$null

Write-Host "   Stopping Python processes..." -ForegroundColor Gray
Get-Process python -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match "main\.py|trading|bot" } | Stop-Process -Force -ErrorAction SilentlyContinue 2>$null

Start-Sleep -Seconds 2
Write-Host "   ✅ Cleanup complete" -ForegroundColor Green
Write-Host ""

# ============================================================================
# STEP 2: Start Chrome with debugging
# ============================================================================
Write-Host "[STEP 2] Starting Chrome with Remote Debugging on port 9222..." -ForegroundColor Yellow
Write-Host ""

$ChromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
if (-Not (Test-Path $ChromePath)) {
    $ChromePath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
}

if (-Not (Test-Path $ChromePath)) {
    Write-Host "   ❌ ERROR: Chrome not found in standard locations" -ForegroundColor Red
    exit 1
}

Write-Host "   Chrome found at: $ChromePath" -ForegroundColor Green

# Start Chrome in background
Write-Host "   Launching Chrome..." -ForegroundColor Gray
$ChromeProcess = Start-Process -FilePath $ChromePath `
    -ArgumentList '--remote-debugging-port=9222', '--no-first-run', '--no-default-browser-check', 'https://qxbroker.com/es/demo-trade' `
    -WindowStyle Normal -PassThru

Write-Host "   Chrome PID: $($ChromeProcess.Id)" -ForegroundColor Green
Write-Host ""

# Wait for Chrome to fully load
Write-Host "[STEP 3] Waiting for Chrome to fully load..." -ForegroundColor Yellow
Start-Sleep -Seconds 12
Write-Host "   ✅ Chrome should be ready" -ForegroundColor Green
Write-Host ""

# ============================================================================
# STEP 4: Verify debugging port is accessible
# ============================================================================
Write-Host "[STEP 4] Verifying debugging port 9222 is accessible..." -ForegroundColor Yellow

$MaxRetries = 10
$Retry = 0
$PortReady = $false

while ($Retry -lt $MaxRetries -and -not $PortReady) {
    try {
        $Socket = New-Object System.Net.Sockets.TcpClient
        $Socket.Connect('127.0.0.1', 9222)
        if ($Socket.Connected) {
            Write-Host "   ✅ Port 9222 is OPEN and ready" -ForegroundColor Green
            $PortReady = $true
            $Socket.Close()
        }
    } catch {
        $Retry++
        if ($Retry -lt $MaxRetries) {
            Write-Host "   ⏳ Retrying... ($Retry/$MaxRetries)" -ForegroundColor Gray
            Start-Sleep -Seconds 2
        }
    }
}

if (-not $PortReady) {
    Write-Host "   ❌ ERROR: Port 9222 is not responding" -ForegroundColor Red
    Write-Host "   Chrome might not be running correctly" -ForegroundColor Red
    exit 1
}
Write-Host ""

# ============================================================================
# STEP 5: Start the trading bot
# ============================================================================
Write-Host "[STEP 5] Starting Trading Bot..." -ForegroundColor Yellow
Write-Host ""

$BotDir = "c:\Users\usuario\Documents\2"
Set-Location $BotDir

Write-Host "   Python version:" -ForegroundColor Gray
python --version

Write-Host "   Starting bot with real data extraction..." -ForegroundColor Gray
Write-Host ""

# Run the bot
python "$BotDir\main.py"

Write-Host ""
Write-Host "❌ Bot has stopped" -ForegroundColor Red
Write-Host ""