# ============================================================================
# START BOT FRESH - Inicia todo limpio con datos reales
# ============================================================================

Write-Host "`n" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "INICIANDO TRADING BOT - EXTRACCION DE DATOS REALES" -ForegroundColor Cyan
Write-Host "============================================================================`n" -ForegroundColor Cyan

# Colores
$GREEN = "Green"
$RED = "Red"
$YELLOW = "Yellow"
$CYAN = "Cyan"

# Funciones
function Log-Success {
    param([string]$msg)
    Write-Host "[OK] $msg" -ForegroundColor $GREEN
}

function Log-Info {
    param([string]$msg)
    Write-Host "[*] $msg" -ForegroundColor $CYAN
}

function Log-Warning {
    param([string]$msg)
    Write-Host "[!] $msg" -ForegroundColor $YELLOW
}

function Log-Error {
    param([string]$msg)
    Write-Host "[ERROR] $msg" -ForegroundColor $RED
}

# Cambiar directorio
Set-Location "c:\Users\usuario\Documents\2"

# ============================================================================
# PASO 1: Limpiar procesos Chrome anteriores
# ============================================================================
Log-Info "Limpiando procesos Chrome anteriores..."
try {
    Get-Process -Name "chrome" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
    Log-Success "Procesos Chrome terminados"
} catch {
    Log-Warning "No había procesos Chrome activos"
}

# ============================================================================
# PASO 2: Lanzar Chrome con puerto de depuración
# ============================================================================
Log-Info "Lanzando Chrome con puerto 9222..."
$CHROME_PATH = "C:\Program Files\Google\Chrome\Application\chrome.exe"

if (-not (Test-Path $CHROME_PATH)) {
    $CHROME_PATH = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
}

if (-not (Test-Path $CHROME_PATH)) {
    Log-Error "Chrome no encontrado en rutas conocidas"
    exit 1
}

# Lanzar Chrome en background
& "$CHROME_PATH" --remote-debugging-port=9222 "https://qxbroker.com/es/demo-trade" | Out-Null &
Start-Sleep -Seconds 3

Log-Success "Chrome iniciado"

# ============================================================================
# PASO 3: Verificar puerto 9222
# ============================================================================
Log-Info "Verificando puerto 9222..."
$port_ready = $false
for ($i = 0; $i -lt 10; $i++) {
    try {
        $test = Test-NetConnection -ComputerName "127.0.0.1" -Port 9222 -ErrorAction SilentlyContinue
        if ($test.TcpTestSucceeded) {
            Log-Success "Puerto 9222 accesible"
            $port_ready = $true
            break
        }
    } catch {}
    
    Start-Sleep -Seconds 1
}

if (-not $port_ready) {
    Log-Warning "Puerto 9222 no está listo, continuando de todas formas..."
}

# ============================================================================
# PASO 4: Iniciar bot
# ============================================================================
Write-Host "`n============================================================================" -ForegroundColor $CYAN
Log-Info "Iniciando Trading Bot..."
Write-Host "============================================================================`n" -ForegroundColor $CYAN

Log-Info "El bot hará lo siguiente:"
Log-Info "  1. Conectar a Chrome en puerto 9222"
Log-Info "  2. Auto-descubrir activos con payout >80%"
Log-Info "  3. Extraer datos REALES del grafico (DOM)"
Log-Info "  4. Generar señales basadas en datos reales"
Log-Info "  5. Enviar señales a Telegram con capturas"

Write-Host "`n"

# Ejecutar el bot
python "c:\Users\usuario\Documents\2\run_bot_with_monitoring.py"

Write-Host "`n============================================================================" -ForegroundColor $CYAN
Log-Success "Bot ejecutado"
Write-Host "============================================================================`n" -ForegroundColor $CYAN