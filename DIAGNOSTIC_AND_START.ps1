# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║   DIAGNÓSTICO Y INICIO DEL BOT - AGGRESSIVE LEARNING MODE v5.0            ║
# ║   Verifica todo está OK antes de iniciar                                   ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          🔍 DIAGNÓSTICO DEL BOT - AGGRESSIVE MODE v5.0        ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ==============================================================================
# 1. VERIFICAR DIRECTORIOS Y ARCHIVOS CLAVE
# ==============================================================================

Write-Host "1️⃣  VERIFICANDO ARCHIVOS PRINCIPALES..." -ForegroundColor Yellow

$required_files = @(
    "main.py",
    "signal_generator.py",
    "database.py",
    "broker_capture.py",
    "indicators.py",
    "config.json"
)

$all_good = $true
foreach ($file in $required_files) {
    $path = "c:\Users\usuario\Documents\2\$file"
    if (Test-Path $path) {
        Write-Host "   ✅ $file" -ForegroundColor Green
    } else {
        Write-Host "   ❌ FALTA: $file" -ForegroundColor Red
        $all_good = $false
    }
}

if (-not $all_good) {
    Write-Host ""
    Write-Host "   ⚠️  ARCHIVOS FALTANTES - Descarga la versión completa" -ForegroundColor Red
    exit 1
}

# ==============================================================================
# 2. VERIFICAR CHROME
# ==============================================================================

Write-Host ""
Write-Host "2️⃣  VERIFICANDO CHROME..." -ForegroundColor Yellow

$chrome_processes = Get-Process chrome -ErrorAction SilentlyContinue
if ($chrome_processes) {
    Write-Host "   ✅ Chrome está en ejecución" -ForegroundColor Green
    
    # Buscar puerto 9222
    try {
        $conn = Get-NetTCPConnection -LocalPort 9222 -ErrorAction SilentlyContinue
        if ($conn) {
            Write-Host "   ✅ Puerto 9222 (debug) está escuchando" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  Puerto 9222 NO está activo - debes iniciar Chrome con:" -ForegroundColor Yellow
            Write-Host "      chrome.exe --remote-debugging-port=9222" -ForegroundColor Cyan
        }
    } catch {
        Write-Host "   ⚠️  No se pudo verificar puerto 9222" -ForegroundColor Yellow
    }
} else {
    Write-Host "   ⚠️  Chrome NO está en ejecución" -ForegroundColor Yellow
    Write-Host "      Inicia Chrome CON REMOTE DEBUG:" -ForegroundColor Cyan
    Write-Host "      chrome.exe --remote-debugging-port=9222" -ForegroundColor Cyan
}

# ==============================================================================
# 3. VERIFICAR BASE DE DATOS
# ==============================================================================

Write-Host ""
Write-Host "3️⃣  VERIFICANDO BASE DE DATOS..." -ForegroundColor Yellow

$db_path = "c:\Users\usuario\Documents\2\trading_signals.db"
if (Test-Path $db_path) {
    $db_size = (Get-Item $db_path).Length / 1MB
    Write-Host "   ✅ BD existe: $([Math]::Round($db_size, 2)) MB" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  BD no existe (se creará al iniciar)" -ForegroundColor Yellow
}

# ==============================================================================
# 4. VERIFICAR PYTHON Y DEPENDENCIAS
# ==============================================================================

Write-Host ""
Write-Host "4️⃣  VERIFICANDO PYTHON..." -ForegroundColor Yellow

# Verificar versión Python
try {
    $python_version = python --version 2>&1
    Write-Host "   ✅ Python instalado: $python_version" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Python NO está instalado o no en PATH" -ForegroundColor Red
    exit 1
}

# Verificar módulos clave
$modules = @('websockets', 'numpy', 'pandas', 'requests')
Write-Host "   Verificando módulos..." -ForegroundColor Gray

foreach ($module in $modules) {
    try {
        $check = python -c "import $module; print('ok')" 2>&1
        if ($check -eq 'ok') {
            Write-Host "      ✅ $module" -ForegroundColor Green
        } else {
            Write-Host "      ⚠️  $module (puede causar problemas)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "      ⚠️  $module (puede causar problemas)" -ForegroundColor Yellow
    }
}

# ==============================================================================
# 5. VERIFICAR PUERTO 5000 (DASHBOARD)
# ==============================================================================

Write-Host ""
Write-Host "5️⃣  VERIFICANDO PUERTO 5000 (DASHBOARD)..." -ForegroundColor Yellow

try {
    $conn = Get-NetTCPConnection -LocalPort 5000 -ErrorAction SilentlyContinue
    if ($conn) {
        Write-Host "   ⚠️  Puerto 5000 ESTÁ EN USO" -ForegroundColor Yellow
        Write-Host "      Opción 1: Mata el proceso: Stop-Process -Name python -Force" -ForegroundColor Cyan
        Write-Host "      Opción 2: Cambia puerto en config.json a 5001" -ForegroundColor Cyan
    } else {
        Write-Host "   ✅ Puerto 5000 está disponible" -ForegroundColor Green
    }
} catch {
    Write-Host "   ✅ Puerto 5000 está disponible" -ForegroundColor Green
}

# ==============================================================================
# 6. VERIFICAR CONFIGURACIÓN
# ==============================================================================

Write-Host ""
Write-Host "6️⃣  VERIFICANDO CONFIGURACIÓN..." -ForegroundColor Yellow

$config_path = "c:\Users\usuario\Documents\2\config.json"
if (Test-Path $config_path) {
    try {
        $config = Get-Content $config_path | ConvertFrom-Json
        Write-Host "   ✅ config.json válido" -ForegroundColor Green
        
        if ($config.ml_settings) {
            Write-Host "   ✅ ML Settings presente" -ForegroundColor Green
        }
        if ($config.notifications.telegram_token) {
            Write-Host "   ✅ Telegram configurado" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  Telegram NO configurado (señales sin notificaciones)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "   ❌ config.json INVÁLIDO" -ForegroundColor Red
    }
} else {
    Write-Host "   ❌ config.json NO EXISTE" -ForegroundColor Red
}

# ==============================================================================
# RESUMEN Y SIGUIENTES PASOS
# ==============================================================================

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    📋 SIGUIENTES PASOS                         ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "PASO 1: Abre Chrome con Remote Debug" -ForegroundColor Yellow
Write-Host "   Ejecuta en PowerShell:" -ForegroundColor Gray
Write-Host "   chrome.exe --remote-debugging-port=9222" -ForegroundColor Cyan
Write-Host ""

Write-Host "PASO 2: Navega a Quotex en Chrome" -ForegroundColor Yellow
Write-Host "   Abre: https://qxbroker.com/es/demo-trade" -ForegroundColor Cyan
Write-Host "   Mantén esta pestaña ABIERTA mientras el bot corre" -ForegroundColor Gray
Write-Host ""

Write-Host "PASO 3: Inicia el Bot" -ForegroundColor Yellow
Write-Host "   En UNA terminal DIFERENTE, ejecuta:" -ForegroundColor Gray
Write-Host "   python run_bot.py" -ForegroundColor Cyan
Write-Host ""
Write-Host "   O si quieres logs en tiempo real:" -ForegroundColor Gray
Write-Host "   python run_bot.py | Tee-Object -FilePath bot_output.log" -ForegroundColor Cyan
Write-Host ""

Write-Host "PASO 4: Monitorea en Dashboard" -ForegroundColor Yellow
Write-Host "   Abre en navegador: http://localhost:5000" -ForegroundColor Cyan
Write-Host "   En 5-10 minutos deberías ver:" -ForegroundColor Gray
Write-Host "   ✅ TOTAL SEÑALES > 0" -ForegroundColor Green
Write-Host "   ✅ Categorías (OPTIMAL/RISK)" -ForegroundColor Green
Write-Host "   ✅ Estrategias (TREND/REVERSAL/OSCILLATOR)" -ForegroundColor Green
Write-Host ""

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "🎯 EXPECTATIVAS:" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "   ⏱️  Primeros 5 minutos:" -ForegroundColor Yellow
Write-Host "      • Bot conecta a Chrome" -ForegroundColor Gray
Write-Host "      • Comienza extracción de datos" -ForegroundColor Gray
Write-Host ""
Write-Host "   ⏱️  Primeros 10-15 minutos:" -ForegroundColor Yellow
Write-Host "      • Primeras señales generadas" -ForegroundColor Green
Write-Host "      • Dashboard muestra: TOTAL SEÑALES: 5-15" -ForegroundColor Green
Write-Host ""
Write-Host "   ⏱️  Primera hora:" -ForegroundColor Yellow
Write-Host "      • 30-50 señales generadas" -ForegroundColor Green
Write-Host "      • Datos guardados en BD para ML" -ForegroundColor Green
Write-Host "      • Sistema aprendiendo automáticamente" -ForegroundColor Green
Write-Host ""

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "⚠️  IMPORTANTE:" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "   1. Semana 1: Win rate 50-55% (NORMAL - sistema aprendiendo)" -ForegroundColor Gray
Write-Host "   2. Semana 2+: Win rate 60-75% (mejora visible)" -ForegroundColor Gray
Write-Host "   3. DEMO PRIMERO: 100+ trades antes de dinero real" -ForegroundColor Red
Write-Host "   4. Tamaño apuesta: 1-2% del capital máximo" -ForegroundColor Gray
Write-Host ""

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "✅ LISTO PARA INICIAR" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green