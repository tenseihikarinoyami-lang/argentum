#!/usr/bin/env powershell
<#
🔧 SCRIPT PARA VERIFICAR QUE LOS FIXES FUNCIONAN
Ejecuta el bot y monitorea en tiempo real los eventos clave
#>

param(
    [switch]$NoWait,           # No esperar a Chrome
    [int]$MonitorSeconds = 120  # Segundos de monitoreo
)

$ErrorActionPreference = 'Stop'

Write-Host "`n" -ForegroundColor Green
Write-Host "═" * 80 -ForegroundColor Green
Write-Host "   🔧 VERIFICACIÓN DE FIXES - BOT TRADING QUOTEX" -ForegroundColor Green
Write-Host "═" * 80 -ForegroundColor Green
Write-Host ""

# ========================================
# PASO 1: VERIFICAR CHROME
# ========================================

Write-Host "1️⃣  Verificando Chrome..." -ForegroundColor Cyan

$maxRetries = 5
$retryCount = 0
$chromeReady = $false

while ($retryCount -lt $maxRetries -and -not $chromeReady) {
    try {
        $response = curl.exe -s "http://localhost:9222/json" 2>$null
        if ($?) {
            $chromeReady = $true
            Write-Host "   ✅ Chrome accesible en puerto 9222" -ForegroundColor Green
            
            # Verificar que Quotex esté abierto
            $tabs = $response | ConvertFrom-Json
            $quotex = $tabs | Where-Object { $_.url -like "*quotex*" }
            if ($quotex) {
                Write-Host "   ✅ Quotex está abierto en una pestaña" -ForegroundColor Green
            } else {
                Write-Host "   ⚠️  Quotex no detectado. Ábrelo en: https://qxbroker.com/es/demo-trade" -ForegroundColor Yellow
            }
        }
    } catch {
        $retryCount++
        if ($retryCount -lt $maxRetries) {
            Write-Host "   ⏳ Esperando Chrome... ($retryCount/$maxRetries)" -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
    }
}

if (-not $chromeReady) {
    Write-Host "   ❌ Chrome NO accesible en puerto 9222" -ForegroundColor Red
    Write-Host ""
    Write-Host "   Por favor ejecuta:" -ForegroundColor Yellow
    Write-Host "   chrome.exe --remote-debugging-port=9222" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

# ========================================
# PASO 2: DETENER BOT ANTERIOR SI EXISTE
# ========================================

Write-Host "`n2️⃣  Preparando entorno..." -ForegroundColor Cyan

$botProcesses = Get-Process python -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -eq 'python' }
if ($botProcesses) {
    Write-Host "   Deteniendo procesos Python anteriores..." -ForegroundColor Yellow
    $botProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

# Limpiar log anterior
if (Test-Path "bot_output.log") {
    Remove-Item "bot_output.log" -Force
    Write-Host "   ✅ Log limpiado" -ForegroundColor Green
}

# ========================================
# PASO 3: INICIAR BOT
# ========================================

Write-Host "`n3️⃣  Iniciando bot..." -ForegroundColor Cyan
Write-Host "   Ejecutando: python main.py" -ForegroundColor Cyan

$botProcess = Start-Process python -ArgumentList "main.py" `
    -RedirectStandardOutput "bot_output.log" `
    -PassThru -NoNewWindow

if ($botProcess -and -not $botProcess.HasExited) {
    Write-Host "   ✅ Bot iniciado (PID: $($botProcess.Id))" -ForegroundColor Green
} else {
    Write-Host "   ❌ Falló al iniciar el bot" -ForegroundColor Red
    exit 1
}

# Esperar a que el bot escriba logs iniciales
Start-Sleep -Seconds 3

# ========================================
# PASO 4: MONITOREAR EVENTOS EN TIEMPO REAL
# ========================================

Write-Host "`n4️⃣  Monitoreando eventos..." -ForegroundColor Cyan
Write-Host "   Buscando eventos clave durante $MonitorSeconds segundos..." -ForegroundColor Cyan
Write-Host ""

$events = @{
    "Chrome conectado"        = $false
    "WebSocket detectado"     = $false
    "Precio extraído"         = $false
    "Vela procesada"          = $false
    "Indicador calculado"     = $false
    "Señal generada"          = $false
    "Dashboard activo"        = $false
}

$startTime = Get-Date
$lastLogCheck = 0

while ($true) {
    $elapsed = [math]::Floor(((Get-Date) - $startTime).TotalSeconds)
    
    if ($elapsed -gt $MonitorSeconds) {
        break
    }
    
    # Leer logs si existen
    if (Test-Path "bot_output.log") {
        $logs = Get-Content "bot_output.log" -ErrorAction SilentlyContinue
        $logCount = @($logs).Count
        
        # Solo procesar nuevas líneas para reducir overhead
        if ($logCount -gt $lastLogCheck) {
            $newLogs = @($logs)[($lastLogCheck)..($logCount-1)] -join "`n"
            $lastLogCheck = $logCount
            
            # Buscar eventos
            if ($newLogs -match "Puerto 9222|Chrome.*conectad|9222.*connect|Browser.*ready") {
                $events["Chrome conectado"] = $true
            }
            
            if ($newLogs -match "\[WS-|WebSocket|socket.*frame|\[FRAME") {
                $events["WebSocket detectado"] = $true
            }
            
            if ($newLogs -match "\[PRICE\]|✅.*PRICE|precio.*extraído") {
                $events["Precio extraído"] = $true
            }
            
            if ($newLogs -match "candles_cache|\[WS-DATA\]|candle.*append") {
                $events["Vela procesada"] = $true
            }
            
            if ($newLogs -match "RSI|MACD|Bollinger|ADX|Stochastic|EMA|SMA") {
                $events["Indicador calculado"] = $true
            }
            
            if ($newLogs -match "Signal detected|signal.*generated|\[SIGNAL\]|señal.*detectada") {
                $events["Señal generada"] = $true
            }
            
            if ($newLogs -match "127.0.0.1.*GET.*api|GET.*statistics|GET.*signals") {
                $events["Dashboard activo"] = $true
            }
        }
    }
    
    # Mostrar progreso
    $completedCount = ($events.Values | Where-Object { $_ -eq $true } | Measure-Object).Count
    $progressPct = [math]::Round(($elapsed / $MonitorSeconds) * 100)
    
    Write-Host -NoNewline "`r  Progreso: $progressPct% | Eventos detectados: $completedCount/7 | Tiempo: $elapsed/$MonitorSeconds s" -ForegroundColor Cyan
    
    Start-Sleep -Milliseconds 500
}

Write-Host "`n" -ForegroundColor Cyan

# ========================================
# PASO 5: MOSTRAR RESULTADOS
# ========================================

Write-Host "`n5️⃣  Resultados de verificación:" -ForegroundColor Cyan
Write-Host ""

$completedCount = 0
foreach ($event in ($events.GetEnumerator() | Sort-Object Name)) {
    if ($event.Value) {
        Write-Host "   ✅ $($event.Name)" -ForegroundColor Green
        $completedCount++
    } else {
        Write-Host "   ❌ $($event.Name)" -ForegroundColor Red
    }
}

$completionRate = [math]::Round(($completedCount / $events.Count) * 100)

Write-Host ""
Write-Host "   Estado: $completedCount/$($events.Count) eventos detectados ($completionRate%)" -ForegroundColor Cyan

# ========================================
# PASO 6: DIAGNÓSTICO
# ========================================

Write-Host "`n6️⃣  Diagnóstico:" -ForegroundColor Cyan

if ($completionRate -eq 100) {
    Write-Host "   🎉 ¡TODOS LOS FIXES FUNCIONAN CORRECTAMENTE!" -ForegroundColor Green
    Write-Host ""
    Write-Host "   El bot está:" -ForegroundColor Green
    Write-Host "   ✅ Conectado a Chrome" -ForegroundColor Green
    Write-Host "   ✅ Recibiendo datos en tiempo real vía WebSocket" -ForegroundColor Green
    Write-Host "   ✅ Extrayendo precios correctamente" -ForegroundColor Green
    Write-Host "   ✅ Procesando velas" -ForegroundColor Green
    Write-Host "   ✅ Calculando indicadores técnicos" -ForegroundColor Green
    Write-Host "   ✅ Generando señales de trading" -ForegroundColor Green
    Write-Host "   ✅ Dashboard funcional" -ForegroundColor Green
} elseif ($completionRate -ge 70) {
    Write-Host "   ⚠️  SISTEMA PARCIALMENTE FUNCIONAL ($completionRate%)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   Eventos faltantes:" -ForegroundColor Yellow
    $missing = $events.GetEnumerator() | Where-Object { $_.Value -eq $false }
    foreach ($m in $missing) {
        Write-Host "   • $($m.Name)" -ForegroundColor Yellow
    }
} else {
    Write-Host "   ❌ PROBLEMAS EN EL SISTEMA ($completionRate%)" -ForegroundColor Red
}

# ========================================
# PASO 7: MOSTRAR LOGS RELEVANTES
# ========================================

if (Test-Path "bot_output.log") {
    Write-Host "`n7️⃣  Últimos eventos importantes en log:" -ForegroundColor Cyan
    Write-Host ""
    
    $relevantLines = @()
    $logs = Get-Content "bot_output.log"
    
    # Buscar líneas importantes
    $logs | Select-String -Pattern "\[WS-|\[PRICE\]|candle|Signal|RSI|MACD|ERROR|✅|❌" | Select-Object -Last 15 | ForEach-Object {
        $line = $_.Line
        if ($line -match "ERROR|FAIL|❌") {
            Write-Host "   $line" -ForegroundColor Red
        } elseif ($line -match "Signal|✅") {
            Write-Host "   $line" -ForegroundColor Green
        } elseif ($line -match "\[PRICE\]") {
            Write-Host "   $line" -ForegroundColor Cyan
        } else {
            Write-Host "   $line" -ForegroundColor White
        }
    }
}

# ========================================
# PASO 8: ESTADO DEL BOT
# ========================================

Write-Host "`n8️⃣  Estado del bot:" -ForegroundColor Cyan

$botStillRunning = $false
try {
    $botProc = Get-Process -Id $botProcess.Id -ErrorAction SilentlyContinue
    if ($botProc -and -not $botProc.HasExited) {
        $botStillRunning = $true
        Write-Host "   ✅ Bot EN EJECUCIÓN (PID: $($botProcess.Id))" -ForegroundColor Green
        Write-Host "   📊 Puedes acceder a: http://localhost:5000" -ForegroundColor Green
        Write-Host "   📋 Revisa los logs: Get-Content bot_output.log -Wait" -ForegroundColor Green
    }
} catch {}

if (-not $botStillRunning) {
    Write-Host "   ❌ Bot NO está corriendo" -ForegroundColor Red
}

# ========================================
# CONCLUSIONES Y PRÓXIMOS PASOS
# ========================================

Write-Host ""
Write-Host "═" * 80 -ForegroundColor Green
Write-Host "   📝 PRÓXIMOS PASOS" -ForegroundColor Green
Write-Host "═" * 80 -ForegroundColor Green
Write-Host ""

if ($completionRate -eq 100) {
    Write-Host "✓ El sistema está completamente operativo" -ForegroundColor Green
    Write-Host ""
    Write-Host "Ahora:" -ForegroundColor Cyan
    Write-Host "1. Accede al dashboard: http://localhost:5000" -ForegroundColor Cyan
    Write-Host "2. Monitorea las señales generadas" -ForegroundColor Cyan
    Write-Host "3. Verifica que los precios se actualicen en tiempo real" -ForegroundColor Cyan
    Write-Host "4. Comprueba que los indicadores se calculan correctamente" -ForegroundColor Cyan
} else {
    Write-Host "El sistema necesita atención:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Revisa los logs: Get-Content bot_output.log | Select-String ERROR" -ForegroundColor Yellow
    Write-Host "2. Verifica que Quotex esté visible en Chrome" -ForegroundColor Yellow
    Write-Host "3. Comprueba la conexión WebSocket" -ForegroundColor Yellow
    Write-Host "4. Reinicia el bot y vuelve a ejecutar este script" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "El bot permanecerá activo. Para detenerlo:" -ForegroundColor Cyan
Write-Host "Stop-Process -Name python -Force" -ForegroundColor Cyan
Write-Host ""