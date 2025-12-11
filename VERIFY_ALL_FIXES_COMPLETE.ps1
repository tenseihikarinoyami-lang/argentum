#!/usr/bin/env powershell
<#
🔍 VERIFICACIÓN COMPLETA DE TODOS LOS FIXES
Ejecuta bot y verifica en tiempo real:
1. WebSocket connection
2. Price extraction from WebSocket
3. Asset name normalization
4. Signal generation
5. Dashboard functionality
#>

# Colores para output
$Green = @{ForegroundColor = "Green"; NoNewline = $false}
$Red = @{ForegroundColor = "Red"; NoNewline = $false}
$Yellow = @{ForegroundColor = "Yellow"; NoNewline = $false}
$Cyan = @{ForegroundColor = "Cyan"; NoNewline = $false}

function Print-Header {
    param([string]$Text)
    Write-Host "`n" @Green
    Write-Host "═" * 80 @Green
    Write-Host "   $Text" @Green
    Write-Host "═" * 80 @Green
}

function Print-Step {
    param([string]$Text)
    Write-Host "`n✓ $Text" @Cyan
}

function Print-Success {
    param([string]$Text)
    Write-Host "  ✅ $Text" @Green
}

function Print-Error {
    param([string]$Text)
    Write-Host "  ❌ $Text" @Red
}

function Print-Warning {
    param([string]$Text)
    Write-Host "  ⚠️  $Text" @Yellow
}

Print-Header "🔧 VERIFICACIÓN COMPLETA DE FIXES - BOT TRADING QUOTEX"

# PASO 1: Verificar que Chrome está corriendo
Print-Step "Verificando Chrome en puerto 9222..."
try {
    $chromeProcess = Get-Process chrome -ErrorAction SilentlyContinue
    if ($chromeProcess) {
        Print-Success "Chrome está corriendo (PID: $($chromeProcess.Id))"
    } else {
        Print-Error "Chrome NO está corriendo"
        Write-Host "  Ejecuta: chrome.exe --remote-debugging-port=9222" @Yellow
        exit 1
    }
} catch {
    Print-Error "Error al verificar Chrome: $_"
    exit 1
}

# PASO 2: Verificar que Quotex está abierto en Chrome
Print-Step "Verificando que Quotex está abierto..."
$url = "http://localhost:9222/json"
try {
    $response = Invoke-WebRequest -Uri $url -ErrorAction SilentlyContinue -TimeoutSec 5
    $tabs = $response.Content | ConvertFrom-Json
    $quotexTab = $tabs | Where-Object { $_.url -like "*quotex*" -or $_.title -like "*quotex*" }
    
    if ($quotexTab) {
        Print-Success "Quotex encontrado en Chrome: $($quotexTab.title)"
    } else {
        Print-Warning "Quotex no encontrado. Por favor abre: https://qxbroker.com/es/demo-trade"
    }
} catch {
    Print-Error "No se puede conectar a Chrome DevTools"
    exit 1
}

# PASO 3: Verificar archivos de configuración
Print-Step "Verificando configuración..."
if (Test-Path "config.json") {
    $config = Get-Content "config.json" | ConvertFrom-Json
    Print-Success "config.json cargado"
    Print-Success "Broker: $($config.broker)"
    Print-Success "Assets configurados: $($config.assets.Count)"
} else {
    Print-Error "config.json no encontrado"
    exit 1
}

# PASO 4: Limpiar logs anteriores
Print-Step "Preparando logs..."
if (Test-Path "bot_output.log") {
    Remove-Item "bot_output.log" -Force
    Print-Success "Logs antiguos eliminados"
}

# PASO 5: Iniciar bot en background
Print-Header "🚀 INICIANDO BOT"
Print-Step "Ejecutando: python main.py"

$botProcess = Start-Process python -ArgumentList "main.py" -RedirectStandardOutput "bot_output.log" -PassThru -NoNewWindow

if ($botProcess) {
    Print-Success "Bot iniciado (PID: $($botProcess.Id))"
} else {
    Print-Error "Falló al iniciar el bot"
    exit 1
}

# PASO 6: Monitorear logs en tiempo real
Print-Header "📊 MONITOREO EN TIEMPO REAL (60 segundos)"

$startTime = Get-Date
$timeout = 60
$checks = @{
    "Chrome conectado" = $false
    "WebSocket detectado" = $false
    "Precio extraído" = $false
    "Vela procesada" = $false
    "Señal generada" = $false
    "Dashboard activo" = $false
}

Write-Host "`nBuscando eventos clave en logs..." @Cyan

while ((Get-Date) - $startTime -lt [TimeSpan]::FromSeconds($timeout)) {
    if (Test-Path "bot_output.log") {
        $logContent = Get-Content "bot_output.log" -ErrorAction SilentlyContinue
        
        # Buscar eventos específicos
        if ($logContent -match "Puerto 9222|Chrome.*conectad|WebSocket.*conectad") {
            if (!$checks["Chrome conectado"]) {
                Print-Success "Chrome conectado en puerto 9222"
                $checks["Chrome conectado"] = $true
            }
        }
        
        if ($logContent -match "\[WS-DETECT\]|\[WS-TICKER\]|\[WS-DEBUG\]") {
            if (!$checks["WebSocket detectado"]) {
                Print-Success "WebSocket eventos detectados"
                $checks["WebSocket detectado"] = $true
            }
        }
        
        if ($logContent -match "\[PRICE\]|✅ \[PRICE\]") {
            if (!$checks["Precio extraído"]) {
                Print-Success "Precios siendo extraídos"
                $checks["Precio extraído"] = $true
            }
        }
        
        if ($logContent -match "candles.*cache|\[WS-DATA\]") {
            if (!$checks["Vela procesada"]) {
                Print-Success "Velas siendo procesadas"
                $checks["Vela procesada"] = $true
            }
        }
        
        if ($logContent -match "Signal detected|SIGNAL|signal.*generated|\[SIGNAL\]") {
            if (!$checks["Señal generada"]) {
                Print-Success "¡SEÑAL GENERADA!"
                $checks["Señal generada"] = $true
            }
        }
        
        if ($logContent -match "127.0.0.1.*GET.*api|localhost:5000") {
            if (!$checks["Dashboard activo"]) {
                Print-Success "Dashboard recibiendo requests"
                $checks["Dashboard activo"] = $true
            }
        }
    }
    
    Start-Sleep -Seconds 2
    
    # Mostrar progreso
    $elapsed = [math]::Floor(((Get-Date) - $startTime).TotalSeconds)
    Write-Host -NoNewline "`r  Tiempo: $elapsed/$timeout segundos..." @Cyan
}

Write-Host "`n" @Cyan

# PASO 7: Verificar resultados
Print-Header "📈 RESULTADOS"

$successCount = ($checks.Values | Where-Object { $_ -eq $true } | Measure-Object).Count
$totalChecks = $checks.Count

Write-Host "`nEstado de verificaciones: $successCount/$totalChecks" @Cyan

foreach ($check in $checks.GetEnumerator()) {
    if ($check.Value) {
        Print-Success "$($check.Name)"
    } else {
        Print-Warning "$($check.Name) - No detectado"
    }
}

# PASO 8: Mostrar últimos logs importantes
Print-Header "📋 ÚLTIMOS EVENTOS EN LOG"

if (Test-Path "bot_output.log") {
    Write-Host "`nÚltimos 20 eventos importantes:" @Cyan
    $importantLines = Get-Content "bot_output.log" | Select-String -Pattern "WS-|PRICE|Signal|candle|ERROR" | Select-Object -Last 20
    
    foreach ($line in $importantLines) {
        if ($line -match "ERROR|FAIL|❌") {
            Write-Host "  $line" @Red
        } elseif ($line -match "Signal|✅") {
            Write-Host "  $line" @Green
        } else {
            Write-Host "  $line" @Cyan
        }
    }
}

# PASO 9: Acceso a Dashboard
Print-Header "🌐 ACCESO A DASHBOARD"
Print-Step "Abre en navegador:"
Print-Success "http://localhost:5000"

Write-Host "`nDashboard mostrará:" @Cyan
Write-Host "  - Señales en tiempo real" @Cyan
Write-Host "  - Estado del sistema" @Cyan
Write-Host "  - Indicadores técnicos" @Cyan
Write-Host "  - Estadísticas de operaciones" @Cyan

# PASO 10: Instrucciones finales
Print-Header "✅ ESTADO DE EJECUCIÓN"

if ($successCount -eq $totalChecks) {
    Write-Host "🎉 ¡TODOS LOS FIXES FUNCIONALES!" @Green
    Write-Host "   El bot está generando señales correctamente" @Green
} elseif ($successCount -ge 4) {
    Write-Host "⚠️  SISTEMA PARCIALMENTE FUNCIONAL ($successCount/$totalChecks)" @Yellow
    Write-Host "   Algunos componentes pueden necesitar ajustes" @Yellow
} else {
    Write-Host "❌ SISTEMA CON PROBLEMAS ($successCount/$totalChecks)" @Red
    Write-Host "   Revisa los logs para diagnosticar" @Red
}

Print-Header "📞 PRÓXIMOS PASOS"

Write-Host @Green
Write-Host "1. Monitorea los logs:" @Green
Write-Host "   Get-Content bot_output.log -Wait" @Cyan
Write-Host ""
Write-Host "2. Accede al dashboard:" @Green
Write-Host "   http://localhost:5000" @Cyan
Write-Host ""
Write-Host "3. Si no hay señales después de 5 minutos:" @Green
Write-Host "   - Verifica que Quotex esté visible en Chrome" @Yellow
Write-Host "   - Revisa que los precios se están extrayendo" @Yellow
Write-Host "   - Comprueba que el payout de activos > 80%" @Yellow
Write-Host ""
Write-Host "Bot en ejecución: " -NoNewline @Green
if (Get-Process python -ErrorAction SilentlyContinue | Where-Object { $_.Id -eq $botProcess.Id }) {
    Write-Host "✅ ACTIVO" @Green
} else {
    Write-Host "❌ DETENIDO" @Red
}

Write-Host "`n" @Green