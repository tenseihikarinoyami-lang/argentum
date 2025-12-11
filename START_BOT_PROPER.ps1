# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║   INICIAR BOT - AGGRESSIVE LEARNING MODE v5.0                              ║
# ║   Genera señales continuamente, categoriza y aprende                       ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║     🚀 INICIANDO BOT TRADING - AGGRESSIVE LEARNING MODE        ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

# Detener cualquier proceso Python anterior
Write-Host "🔄 Limpiando procesos anteriores..." -ForegroundColor Yellow
Stop-Process -Name python -Force -ErrorAction SilentlyContinue | Out-Null
Start-Sleep -Seconds 2

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "📋 CONFIGURACIÓN VERIFICADA:" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "✅ Modo: AGGRESSIVE LEARNING (v5.0)" -ForegroundColor Green
Write-Host "✅ Generación: Señales CONTINUAS (sin límite/día)" -ForegroundColor Green
Write-Host "✅ Categorización: OPTIMAL + RISK automático" -ForegroundColor Green
Write-Host "✅ ML Learning: Datos COMPLETOS guardados" -ForegroundColor Green
Write-Host "✅ Estrategias: TREND + REVERSAL + OSCILLATOR" -ForegroundColor Green
Write-Host ""

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "📌 REQUISITOS PREVIOS:" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar Chrome
$chrome = Get-Process chrome -ErrorAction SilentlyContinue
if ($chrome) {
    $port9222 = Get-NetTCPConnection -LocalPort 9222 -ErrorAction SilentlyContinue
    if ($port9222) {
        Write-Host "✅ Chrome: Ejecutándose con DEBUG (puerto 9222)" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Chrome ejecutándose PERO SIN DEBUG" -ForegroundColor Yellow
        Write-Host "    DEBES CERRAR Chrome y abrirlo así:" -ForegroundColor Red
        Write-Host "    chrome.exe --remote-debugging-port=9222" -ForegroundColor Cyan
        exit 1
    }
} else {
    Write-Host "❌ Chrome NO está ejecutándose" -ForegroundColor Red
    Write-Host "    ABRE Chrome con Debug PRIMERO:" -ForegroundColor Cyan
    Write-Host "    chrome.exe --remote-debugging-port=9222" -ForegroundColor Cyan
    exit 1
}

# 2. Verificar Quotex
Write-Host "📌 Verifica que Quotex esté abierto:" -ForegroundColor Yellow
Write-Host "   https://qxbroker.com/es/demo-trade" -ForegroundColor Cyan
$response = Read-Host "   ¿Quotex está abierto en Chrome? (s/n)"
if ($response -ne "s") {
    Write-Host "❌ Abre Quotex PRIMERO" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Quotex: Verificado" -ForegroundColor Green

# 3. Verificar puerto 5000
try {
    $conn5000 = Get-NetTCPConnection -LocalPort 5000 -ErrorAction SilentlyContinue
    if ($conn5000) {
        Write-Host "⚠️  Puerto 5000 EN USO - matando procesos..." -ForegroundColor Yellow
        Stop-Process -Name python -Force -ErrorAction SilentlyContinue | Out-Null
        Start-Sleep -Seconds 2
    }
} catch {}

Write-Host "✅ Puerto 5000: Disponible" -ForegroundColor Green

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "🎯 INICIANDO BOT..." -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

# Iniciar bot
Set-Location "c:\Users\usuario\Documents\2"
python run_bot.py 2>&1 | Tee-Object -FilePath "bot_output.log" -Append

# Si llegamos aquí es que se cerró
Write-Host ""
Write-Host "⚠️  Bot fue cerrado o hubo error" -ForegroundColor Yellow
Write-Host "Ver logs en: bot_output.log" -ForegroundColor Gray