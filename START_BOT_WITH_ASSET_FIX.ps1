# ==============================================================================
# 🤖 INICIAR BOT CON FIX DE DETECCIÓN DE ACTIVOS
# ==============================================================================
# Este script inicia el bot con la solución de detección automática de activos
# El bot detectará primero qué activos tienen datos disponibles,
# luego analizará solo esos activos
# ==============================================================================

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗"
Write-Host "║                      🤖 TRADING BOT - DETECCIÓN DE ACTIVOS                   ║"
Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝"
Write-Host ""

# Paso 1: Verificar que Chrome esté abierto
Write-Host "📋 PASO 1: Verificando Chrome..."
Write-Host ""

$chromeOpen = Get-Process chrome -ErrorAction SilentlyContinue | Where-Object { $_.Handles -gt 0 }
if ($chromeOpen) {
    Write-Host "   ✅ Chrome está abierto"
} else {
    Write-Host "   ⚠️  Chrome no está abierto"
    Write-Host ""
    Write-Host "   Para abrir Chrome con Remote Debugging:"
    Write-Host "   ► chrome.exe --remote-debugging-port=9222 https://qxbroker.com/es/demo-trade"
    Write-Host ""
    Read-Host "   Presiona Enter cuando Chrome esté abierto y en Quotex"
}

Write-Host ""
Write-Host "📋 PASO 2: Limpiando archivos temporales..."
Write-Host ""

# Limpiar logs viejos
if (Test-Path "bot_output.log") {
    Remove-Item "bot_output.log" -Force -ErrorAction SilentlyContinue
    Write-Host "   ✅ Logs limpios"
}

Write-Host ""
Write-Host "📋 PASO 3: Iniciando BOT..."
Write-Host ""
Write-Host "⏱️  El bot iniciará con la siguiente secuencia:"
Write-Host ""
Write-Host "   1️⃣  Conectar a Chrome (Puerto 9222)"
Write-Host "   2️⃣  Iniciar sistema de datos anti-bot"
Write-Host "   3️⃣  STARTUP: Detectar activos disponibles (15 segundos)"
Write-Host "   4️⃣  OPERACIÓN: Monitorear solo activos con datos"
Write-Host "   5️⃣  SEÑALES: Generar automáticamente cuando se detecte oportunidad"
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════"
Write-Host ""

# Iniciar el bot
python run_bot.py

# Si el bot se detiene
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════"
Write-Host "🛑 Bot detenido"
Write-Host ""
Write-Host "Próximas opciones:"
Write-Host "  1. Reinicia el bot (ejecuta este script de nuevo)"
Write-Host "  2. Verifica que Quotex esté abierto en Chrome"
Write-Host "  3. Revisa el archivo bot_output.log para más detalles"
Write-Host ""
Read-Host "Presiona Enter para salir"