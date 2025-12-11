#!/usr/bin/env powershell
<#
DIAGNOSTIC TEST - Signal Generation Flow
Ejecuta el bot y monitorea EXACTAMENTE dónde se generan o pierden las señales
#>

Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║    🧪 TEST SIGNAL GENERATION - DIAGNOSTIC FLOW                 ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Asegurar que Python está disponible
$pythonPath = python.exe
if (-not $pythonPath) {
    Write-Host "❌ Python no encontrado. Instala Python primero." -ForegroundColor Red
    exit 1
}

Write-Host "✅ Python disponible" -ForegroundColor Green
Write-Host ""

# Verificar que Chrome esté en puerto 9222
Write-Host "📋 PASO 1: Verificar Chrome Remote Debug" -ForegroundColor Yellow
$chromeCheck = Get-NetTCPConnection -LocalPort 9222 -ErrorAction SilentlyContinue
if ($chromeCheck) {
    Write-Host "✅ Chrome escuchando en puerto 9222" -ForegroundColor Green
} else {
    Write-Host "⚠️  Chrome NO encontrado en puerto 9222" -ForegroundColor Yellow
    Write-Host "    Asegúrate de ejecutar: chrome.exe --remote-debugging-port=9222" -ForegroundColor Yellow
    Write-Host "    O navega a https://qxbroker.com/es/demo-trade en Chrome" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "📋 PASO 2: Iniciar Bot con Logging Completo" -ForegroundColor Yellow
Write-Host "Esperando señales durante 120 segundos..." -ForegroundColor Cyan
Write-Host ""

# Limpiar log anterior
if (Test-Path "bot_output.log") {
    Remove-Item "bot_output.log" -Force
}

# Variables para tracking
$cycleCount = 0
$analysisCount = 0
$callbackCount = 0
$signalCount = 0
$errorCount = 0

Write-Host "┌─ LOG OUTPUT ─────────────────────────────────────────────────┐" -ForegroundColor Gray

# Ejecutar bot y capturar logs
$timeout = (Get-Date).AddSeconds(120)
$process = Start-Process -FilePath python.exe -ArgumentList "run_bot.py" -RedirectStandardOutput "bot_output.log" -NoNewWindow -PassThru

Start-Sleep -Seconds 5

# Monitorear logs en tiempo real
while ((Get-Date) -lt $timeout -and $null -ne $process -and -not $process.HasExited) {
    if (Test-Path "bot_output.log") {
        $newContent = Get-Content "bot_output.log" -Tail 50 -ErrorAction SilentlyContinue
        
        foreach ($line in $newContent) {
            # Contar eventos críticos
            if ($line -match "\[CYCLE \d+\]" -and -not ($line -match "Switching")) {
                if ($line -match "\[1/4\]") { $cycleCount++ }
            }
            if ($line -match "\[ANALYSIS\].*\[3/5\]") { $analysisCount++ }
            if ($line -match "\[CALLBACK\].*triggered") { $callbackCount++ }
            if ($line -match "Signal detected") { $signalCount++ }
            if ($line -match "ERROR|❌") { $errorCount++ }
            
            # Mostrar líneas importantes
            if ($line -match "\[CYCLE|ANALYSIS|CALLBACK|Signal detected|ERROR") {
                Write-Host $line -ForegroundColor Cyan
            }
        }
    }
    
    Start-Sleep -Seconds 2
}

Write-Host "└───────────────────────────────────────────────────────────────┘" -ForegroundColor Gray

# Matar proceso si aún está corriendo
if ($null -ne $process -and -not $process.HasExited) {
    Stop-Process -InputObject $process -Force
    Write-Host "✓ Bot detenido" -ForegroundColor Green
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║    📊 RESULTADOS DEL DIAGNÓSTICO                              ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# Analizar resultados
if (Test-Path "bot_output.log") {
    $fullLog = Get-Content "bot_output.log" -Raw
    
    Write-Host ""
    Write-Host "📈 ESTADÍSTICAS:" -ForegroundColor Yellow
    
    # Contar líneas completas
    $cycles = ($fullLog | Select-String "\[CYCLE \d+\] \[1/4\]" -AllMatches).Matches.Count
    $analysis = ($fullLog | Select-String "\[ANALYSIS\].*\[3/5\]" -AllMatches).Matches.Count
    $callbacks = ($fullLog | Select-String "\[CALLBACK\].*triggered" -AllMatches).Matches.Count
    $signals = ($fullLog | Select-String "Signal detected" -AllMatches).Matches.Count
    $errors = ($fullLog | Select-String "ERROR|❌ \[" -AllMatches).Matches.Count
    
    Write-Host "  [1/4] Ciclos iniciados: $cycles" -ForegroundColor White
    Write-Host "  [3/5] Análisis iniciados: $analysis" -ForegroundColor White
    Write-Host "  [CALLBACK] Callbacks ejecutados: $callbacks" -ForegroundColor White
    Write-Host "  ✅ SEÑALES GENERADAS: $signals" -ForegroundColor Cyan
    Write-Host "  ❌ Errores: $errors" -ForegroundColor Red
    
    Write-Host ""
    Write-Host "🔍 DIAGNÓSTICO:" -ForegroundColor Yellow
    
    # Análisis de flujo
    if ($cycles -gt 0) {
        Write-Host "  ✅ Bot está ciclando activos" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Bot NO está ciclando activos" -ForegroundColor Red
    }
    
    if ($analysis -gt 0) {
        Write-Host "  ✅ Análisis se está ejecutando" -ForegroundColor Green
        
        # Verificar ratio
        if ($callbacks -eq 0 -and $analysis -gt 0) {
            Write-Host "  ⚠️  PROBLEMA: Análisis ejecutándose pero callbacks NO se llaman" -ForegroundColor Yellow
            Write-Host "      Revisa real_time_monitor._analyze_asset() - el callback no se dispara" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ❌ Análisis NO se está ejecutando" -ForegroundColor Red
        if ($cycles -gt 0) {
            Write-Host "      Revisa por qué _analyze_asset() falla. Ver logs arriba." -ForegroundColor Yellow
        }
    }
    
    if ($callbacks -gt 0) {
        Write-Host "  ✅ Callbacks se están disparando" -ForegroundColor Green
        
        if ($signals -eq 0 -and $callbacks -gt 0) {
            Write-Host "  ⚠️  PROBLEMA: Callbacks se disparan pero SIN señales" -ForegroundColor Yellow
            Write-Host "      Revisa signal_generator.generate_signal() - retorna None" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ❌ Callbacks NO se disparan" -ForegroundColor Red
    }
    
    if ($signals -gt 0) {
        Write-Host "  ✅ SEÑALES SE GENERAN CORRECTAMENTE" -ForegroundColor Green
        Write-Host "  🎯 Tasa: $([math]::Round(($signals/$cycles)*100, 1))% de ciclos generan señal" -ForegroundColor Green
    } else {
        Write-Host "  ❌ NO SE GENERAN SEÑALES" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "📝 PRÓXIMOS PASOS:" -ForegroundColor Cyan
Write-Host "  1. Ver ÚLTIMO error en los logs: Get-Content bot_output.log | Select-String 'ERROR|❌' -Last 20" -ForegroundColor Gray
Write-Host "  2. Si ves '[ANALYSIS] [1/5]' pero NO '[3/5]' → problema al obtener dataframe" -ForegroundColor Gray
Write-Host "  3. Si ves '[CALLBACK] 🔔' pero NO 'Signal detected' → problema en signal_generator" -ForegroundColor Gray
Write-Host ""