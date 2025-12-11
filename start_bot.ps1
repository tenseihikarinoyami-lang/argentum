# ============================================================================
# START BOT - Script simple para iniciar el trading bot con datos reales
# ============================================================================

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  🤖 TRADING BOT - EXTRACCIÓN DE DATOS REALES                                  ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Verificar si Chrome está corriendo
Write-Host "🔍 Verificando Chrome en puerto 9222..." -ForegroundColor Yellow

$chrome_running = $false
try {
    $connection = Test-NetConnection -ComputerName 127.0.0.1 -Port 9222 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    if ($connection.TcpTestSucceeded) {
        $chrome_running = $true
        Write-Host "   ✅ Chrome está conectado en puerto 9222" -ForegroundColor Green
    }
} catch {
    # No está conectado
}

if (-not $chrome_running) {
    Write-Host "   ⚠️  Chrome NO está conectado" -ForegroundColor Red
    Write-Host ""
    Write-Host "Para conectar Chrome, abre una terminal aparte y ejecuta:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host '  "C:\Program Files\Google\Chrome\Application\chrome.exe" --remote-debugging-port=9222 https://qxbroker.com/es/demo-tradeX' -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Esperando 10 segundos... (Ctrl+C para cancelar)" -ForegroundColor Yellow
    
    for ($i = 10; $i -gt 0; $i--) {
        Write-Host "  $i..." -ForegroundColor Yellow -NoNewline
        Start-Sleep -Seconds 1
    }
    Write-Host ""
}

# Cambiar al directorio del bot
Set-Location "c:\Users\usuario\Documents\2"

# Ejecutar bot
Write-Host ""
Write-Host "🚀 Iniciando bot..." -ForegroundColor Green
Write-Host ""

python run_bot.py

Write-Host ""
Write-Host "🛑 Bot terminado" -ForegroundColor Yellow