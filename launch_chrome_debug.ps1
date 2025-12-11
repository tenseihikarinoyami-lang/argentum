#!/usr/bin/env powershell
# Script para iniciar Chrome con debugging remoto

Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         LAUNCHING CHROME WITH REMOTE DEBUGGING PORT 9222       ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Detener Chrome existente
Write-Host "[1] Stopping existing Chrome processes..." -ForegroundColor Yellow
Get-Process chrome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Encontrar Chrome
$ChromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
if (-Not (Test-Path $ChromePath)) {
    $ChromePath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
}

if (-Not (Test-Path $ChromePath)) {
    Write-Host "[ERROR] Chrome not found in standard locations" -ForegroundColor Red
    exit 1
}

Write-Host "[2] Chrome found at: $ChromePath" -ForegroundColor Green
Write-Host "[3] Launching Chrome with remote debugging..." -ForegroundColor Yellow
Write-Host ""

# Iniciar Chrome con debugging en foreground
& $ChromePath --remote-debugging-port=9222 --no-first-run --no-default-browser-check "https://qxbroker.com/es/demo-trade"

# El script se bloqueará aquí mientras Chrome esté corriendo
Write-Host "[DONE] Chrome session ended" -ForegroundColor Yellow