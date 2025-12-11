# ============================================================================
# 🚀 BOT STARTUP SCRIPT - REAL DATA EXTRACTION ENABLED
# ============================================================================
# Este script:
# 1. Mata todos los procesos de Chrome existentes para limpiar
# 2. Inicia Chrome con debugging en puerto 9222
# 3. Navega a Quotex trading
# 4. Inicia el trading bot con extracción de datos REALES
# ============================================================================

Write-Host "=" -ForegroundColor Cyan -NoNewline; Write-Host "=" -NoNewline; Write-Host "=" -NoNewline; Write-Host "=" -NoNewline; Write-Host "=" -NoNewline; Write-Host "=" -NoNewline; Write-Host "=" -NoNewline; Write-Host "=" -NoNewline; Write-Host "=" -NoNewline; Write-Host "=" -ForegroundColor Cyan
Write-Host "🚀 INICIANDO BOT CON EXTRACCIÓN DE DATOS REALES DEL GRÁFICO" -ForegroundColor Green -BackgroundColor Black
Write-Host "=" -ForegroundColor Cyan -NoNewline; Write-Host "=" -NoNewline; Write-Host "=" -NoNewline; Write-Host "=" -NoNewline; Write-Host "=" -NoNewline; Write-Host "=" -NoNewline; Write-Host "=" -NoNewline; Write-Host "=" -NoNewline; Write-Host "=" -NoNewline; Write-Host "=" -ForegroundColor Cyan
Write-Host ""

# Configuración
$CHROME_PATH = "C:\Program Files\Google\Chrome\Application\chrome.exe"
$BOT_ROOT = "c:\Users\usuario\Documents\2"
$DEBUG_PORT = 9222
$QUOTEX_URL = "https://qxbroker.com/es/demo-tradeX"

Write-Host "[1/4] 🔍 Buscando procesos de Chrome existentes..." -ForegroundColor Yellow
$chrome_processes = Get-Process -Name "chrome" -ErrorAction SilentlyContinue
if ($chrome_processes) {
    Write-Host "      Encontrados $($chrome_processes.Count) proceso(s) de Chrome" -ForegroundColor Yellow
    Write-Host "      🛑 Deteniendo Chrome para limpiar..." -ForegroundColor Red
    Stop-Process -Name "chrome" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Write-Host "      ✅ Chrome detenido" -ForegroundColor Green
} else {
    Write-Host "      ℹ️  No hay procesos de Chrome activos" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "[2/4] 🌐 Iniciando Chrome en modo debug (puerto $DEBUG_PORT)..." -ForegroundColor Yellow

# Crear perfil de Chrome temporal para evitar conflictos
$TEMP_CHROME_PROFILE = "$env:TEMP\chromium_debug_profile"
if (Test-Path $TEMP_CHROME_PROFILE) {
    Remove-Item -Path $TEMP_CHROME_PROFILE -Recurse -Force -ErrorAction SilentlyContinue
}

# Iniciar Chrome con remote debugging
$chrome_args = @(
    "--remote-debugging-port=$DEBUG_PORT",
    "--no-first-run",
    "--no-default-browser-check",
    "--disable-extensions",
    "--disable-plugins",
    "--disable-sync",
    "--disable-default-apps",
    "--user-data-dir=$TEMP_CHROME_PROFILE",
    "$QUOTEX_URL"
)

Write-Host "      Comando: $CHROME_PATH $($chrome_args -join ' ')" -ForegroundColor DarkGray

# Iniciar Chrome en background
Start-Process -FilePath $CHROME_PATH -ArgumentList $chrome_args -WindowStyle Normal

Write-Host "      ⏳ Esperando que Chrome inicie..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

# Verificar conexión al puerto
Write-Host "      🔗 Verificando conexión al puerto $DEBUG_PORT..." -ForegroundColor Yellow
$port_ready = $false
$max_attempts = 10
$attempt = 0

while (-not $port_ready -and $attempt -lt $max_attempts) {
    try {
        $connection = Test-NetConnection -ComputerName 127.0.0.1 -Port $DEBUG_PORT -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        if ($connection.TcpTestSucceeded) {
            $port_ready = $true
            Write-Host "      ✅ Puerto $DEBUG_PORT accesible" -ForegroundColor Green
        } else {
            $attempt++
            if ($attempt -lt $max_attempts) {
                Write-Host "      ⏳ Reintentando... ($attempt/$max_attempts)" -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            }
        }
    } catch {
        $attempt++
        if ($attempt -lt $max_attempts) {
            Write-Host "      ⏳ Reintentando... ($attempt/$max_attempts)" -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
    }
}

if (-not $port_ready) {
    Write-Host "      ⚠️  Advertencia: No se pudo confirmar puerto $DEBUG_PORT, continuando de todas formas..." -ForegroundColor Red
}

Write-Host ""
Write-Host "[3/4] ⏳ Esperando que Quotex se cargue..." -ForegroundColor Yellow
Write-Host "      Esperando 5 segundos para que la página se estabilice..." -ForegroundColor Cyan
Start-Sleep -Seconds 5

Write-Host ""
Write-Host "[4/4] 🤖 Iniciando Trading Bot..." -ForegroundColor Yellow

# Cambiar al directorio del bot
Set-Location $BOT_ROOT

# Crear script Python para iniciar el bot
$bot_startup_script = @"
#!/usr/bin/env python3
import asyncio
import sys
import os
import logging

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

async def main():
    try:
        from main import TradingBot
        
        logger.info("")
        logger.info("=" * 80)
        logger.info("🤖 TRADING BOT - MODO EXTRACCIÓN DE DATOS REALES")
        logger.info("=" * 80)
        logger.info("✅ Chrome iniciado en puerto 9222")
        logger.info("✅ Modo auto-discover HABILITADO")
        logger.info("✅ Filtro de payout >80% HABILITADO")
        logger.info("✅ Extracción de datos REALES del DOM HABILITADA")
        logger.info("✅ Telegram con screenshots HABILITADO")
        logger.info("=" * 80)
        logger.info("")
        
        # Inicializar bot
        bot = TradingBot(config_path='config.json')
        
        # Iniciar bot
        bot.start()
        
        # Mantener el bot corriendo
        logger.info("✅ Bot en ejecución. Presiona Ctrl+C para detener.")
        try:
            while True:
                await asyncio.sleep(1)
        except KeyboardInterrupt:
            logger.info("\n🛑 Bot detenido por usuario")
            sys.exit(0)
    
    except Exception as e:
        logger.error(f"❌ Error iniciando bot: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
"@

$startup_file = Join-Path $BOT_ROOT "startup_bot.py"
$bot_startup_script | Out-File -FilePath $startup_file -Encoding UTF8

Write-Host "      📝 Script de startup creado: $startup_file" -ForegroundColor Cyan

# Ejecutar el bot
Write-Host "      🚀 Ejecutando bot..." -ForegroundColor Green
Write-Host ""

& python $startup_file

Write-Host ""
Write-Host "⚠️  Bot terminado" -ForegroundColor Yellow