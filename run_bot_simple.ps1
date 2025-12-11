# ============================================================================
# Trading Bot Simple Startup - One Command to Rule Them All
# ============================================================================
# Uso: powershell -ExecutionPolicy Bypass -File run_bot_simple.ps1
# ============================================================================

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "[TRADING BOT] Iniciando sesion de trading" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

# Verificar si Chrome está corriendo en puerto 9222
$chromeRunning = $null
try {
    $chromeRunning = Get-Process chrome -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -eq "chrome" }
} catch { }

$portInUse = $null
try {
    $portInUse = Get-NetTCPConnection -LocalPort 9222 -ErrorAction SilentlyContinue
} catch { }

# Si Chrome no está corriendo, iniciarlo
if (-not $chromeRunning -or -not $portInUse) {
    Write-Host ""
    Write-Host "[PASO 1/2] Iniciando Chrome en modo debugging..." -ForegroundColor Yellow
    
    # Encontrar Chrome
    $chromePaths = @(
        "C:\Program Files\Google\Chrome\Application\chrome.exe",
        "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
        "C:\Users\$env:USERNAME\AppData\Local\Google\Chrome\Application\chrome.exe"
    )
    
    $chrome = $null
    foreach ($path in $chromePaths) {
        if (Test-Path $path) {
            $chrome = $path
            break
        }
    }
    
    if (-not $chrome) {
        Write-Host "[ERROR] Chrome no encontrado" -ForegroundColor Red
        Write-Host "Por favor, instala Chrome desde: https://google.com/chrome" -ForegroundColor Red
        exit 1
    }
    
    # Terminar Chrome existente
    Write-Host "   [STOP] Cerrando Chrome existente..." -ForegroundColor Gray
    Get-Process chrome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    
    # Iniciar Chrome
    Write-Host "   [START] Lanzando Chrome en puerto 9222..." -ForegroundColor Gray
    Start-Process $chrome -ArgumentList `
        "--remote-debugging-port=9222", `
        "--user-data-dir=`"C:\Users\$env:USERNAME\Documents\2`"", `
        "https://quotex.com" `
        -ErrorAction SilentlyContinue
    
    Write-Host "   [WAIT] Esperando a que Chrome se inicie (5 segundos)..." -ForegroundColor Gray
    Start-Sleep -Seconds 5
    Write-Host "[OK] Chrome iniciado" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "[OK] Chrome ya está corriendo en puerto 9222" -ForegroundColor Green
}

# Activar venv si existe
Write-Host ""
Write-Host "[PASO 2/2] Iniciando bot..." -ForegroundColor Yellow

if (Test-Path ".venv\Scripts\Activate.ps1") {
    & .venv\Scripts\Activate.ps1
}

# Iniciar el bot
Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "[RUN] Bot iniciándose..." -ForegroundColor Green
Write-Host "[WEB] Dashboard: http://localhost:5000" -ForegroundColor Cyan
Write-Host "[STOP] Presiona Ctrl+C para detener" -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""

python main.py