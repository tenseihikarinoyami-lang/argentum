#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Verificación rápida de las correcciones aplicadas al bot
    
.DESCRIPTION
    Script que verifica:
    1. Chrome está abierto en puerto 9222
    2. Bot está ejecutando
    3. Se generan señales correctamente
    4. Dashboard está respondiendo
    5. Pestañas no se acumulan
#>

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "🔍  VERIFICACIÓN DE CORRECCIONES - GENERACIÓN DE SEÑALES" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Función para imprimir resultados
function Print-Result {
    param(
        [string]$Test,
        [bool]$Passed,
        [string]$Details = ""
    )
    
    if ($Passed) {
        Write-Host "✅ $Test" -ForegroundColor Green
    } else {
        Write-Host "❌ $Test" -ForegroundColor Red
    }
    
    if ($Details) {
        Write-Host "   → $Details" -ForegroundColor Gray
    }
}

$allTestsPassed = $true

# TEST 1: Chrome en puerto 9222
Write-Host ""
Write-Host "📍 TEST 1: Verificando Chrome en puerto 9222..." -ForegroundColor Yellow
try {
    $connection = New-Object System.Net.Sockets.TcpClient
    $connection.Connect("127.0.0.1", 9222)
    $connection.Close()
    Print-Result "Chrome conectado en 9222" $true "Debugger está activo"
} catch {
    Print-Result "Chrome conectado en 9222" $false "No hay respuesta en puerto 9222"
    Write-Host "   💡 Solución: Ejecuta: chrome.exe --remote-debugging-port=9222 https://qxbroker.com/es/demo-trade" -ForegroundColor Yellow
    $allTestsPassed = $false
}

# TEST 2: Bot ejecutando
Write-Host ""
Write-Host "📍 TEST 2: Verificando si el bot está ejecutando..." -ForegroundColor Yellow
$pythonProcess = Get-Process python -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -eq "python" }
if ($pythonProcess) {
    Print-Result "Bot ejecutando" $true "PID: $($pythonProcess.Id)"
} else {
    Print-Result "Bot ejecutando" $false "No hay proceso Python activo"
    Write-Host "   💡 Solución: Ejecuta: python run_bot.py" -ForegroundColor Yellow
    $allTestsPassed = $false
}

# TEST 3: Dashboard respondiendo
Write-Host ""
Write-Host "📍 TEST 3: Verificando Dashboard..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:5000/api/status" -Method GET -TimeoutSec 5 -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        $json = $response.Content | ConvertFrom-Json
        
        # Verificar si hay bot_status
        if ($json.bot_status) {
            $botStatus = $json.bot_status
            Write-Host "   Estado del Bot: $($botStatus.estado_del_bot)" -ForegroundColor Green
            Write-Host "   Conexión DB: $($botStatus.conexion_a_db)" -ForegroundColor Green
            Write-Host "   Activos monitoreados: $($botStatus.activos_monitoreados)" -ForegroundColor Green
            Print-Result "Dashboard con información" $true "Bot status visible"
        } else {
            Print-Result "Dashboard con información" $false "No hay bot_status en respuesta"
            $allTestsPassed = $false
        }
        
        # Verificar señales
        $signals = $json.current_signals
        if ($signals -and $signals.Count -gt 0) {
            Print-Result "Señales generándose" $true "Total: $($signals.Count) señales"
        } else {
            Print-Result "Señales generándose" $false "No hay señales aún (espera 30-60 segundos)"
        }
    }
} catch {
    Print-Result "Dashboard respondiendo" $false "Error conectando a http://localhost:5000"
    Write-Host "   Error: $_" -ForegroundColor Yellow
    $allTestsPassed = $false
}

# TEST 4: Logs mostrando cambios de activo
Write-Host ""
Write-Host "📍 TEST 4: Analizando logs..." -ForegroundColor Yellow
if (Test-Path "bot_output.log") {
    $logContent = Get-Content "bot_output.log" -Tail 100 -Raw
    
    # Buscar ciclos de activos
    $cycles = $logContent | Select-String "CYCLE.*Switching to:" | Measure-Object | Select-Object -ExpandProperty Count
    if ($cycles -gt 0) {
        Print-Result "Cambios de activo detectados" $true "$cycles ciclos en últimas líneas"
    } else {
        Print-Result "Cambios de activo detectados" $false "No se ven cambios de activos en logs"
        $allTestsPassed = $false
    }
    
    # Buscar señales
    $signals = $logContent | Select-String "Signal detected" | Measure-Object | Select-Object -ExpandProperty Count
    if ($signals -gt 0) {
        Print-Result "Señales en logs" $true "$signals señales detectadas"
    } else {
        Print-Result "Señales en logs" $false "Espera 30-60 segundos para primera señal"
    }
    
    # Buscar errores
    $errors = $logContent | Select-String "ERROR" | Measure-Object | Select-Object -ExpandProperty Count
    if ($errors -eq 0) {
        Print-Result "Sin errores críticos" $true "Logs limpios"
    } else {
        Print-Result "Sin errores críticos" $false "$errors errores encontrados"
        Write-Host "   Últimos errores:" -ForegroundColor Yellow
        $logContent | Select-String "ERROR" -Context 0, 1 | Tail -3 | ForEach-Object { Write-Host "   $_" }
        $allTestsPassed = $false
    }
} else {
    Print-Result "Archivo de logs" $false "bot_output.log no encontrado"
    $allTestsPassed = $false
}

# TEST 5: Verificar cierre de pestañas
Write-Host ""
Write-Host "📍 TEST 5: Verificando gestión de pestañas..." -ForegroundColor Yellow
$logContent = Get-Content "bot_output.log" -Tail 50 -Raw
$cleanupLines = $logContent | Select-String "CLEANUP.*cerrada" | Measure-Object | Select-Object -ExpandProperty Count
if ($cleanupLines -gt 0) {
    Print-Result "Cierre de pestañas" $true "$cleanupLines limpiezas de tabs registradas"
} else {
    Write-Host "   ℹ️  No hay limpiezas aún (normal si acaba de iniciar)" -ForegroundColor Gray
}

# RESUMEN FINAL
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

if ($allTestsPassed) {
    Write-Host "✅ TODAS LAS PRUEBAS PASARON" -ForegroundColor Green
    Write-Host ""
    Write-Host "El bot debería estar generando señales ahora." -ForegroundColor Green
    Write-Host ""
    Write-Host "Próximos pasos:" -ForegroundColor Yellow
    Write-Host "1. 📊 Abre dashboard: http://localhost:5000" -ForegroundColor Yellow
    Write-Host "2. 📝 Observa los logs: Get-Content bot_output.log -Wait" -ForegroundColor Yellow
    Write-Host "3. 📱 Revisa Telegram para notificaciones de señales" -ForegroundColor Yellow
    Write-Host "4. 💰 Cuando confiés, abre Quotex y tradea manualmente o automáticamente" -ForegroundColor Yellow
} else {
    Write-Host "⚠️  ALGUNAS PRUEBAS FALLARON" -ForegroundColor Red
    Write-Host ""
    Write-Host "Acciones recomendadas:" -ForegroundColor Yellow
    Write-Host "1. Verifica que Chrome esté abierto en puerto 9222" -ForegroundColor Yellow
    Write-Host "2. Verifica que el bot esté ejecutando: python run_bot.py" -ForegroundColor Yellow
    Write-Host "3. Si necesitas reiniciar:" -ForegroundColor Yellow
    Write-Host "   Stop-Process -Name python -Force" -ForegroundColor Gray
    Write-Host "   Stop-Process -Name chrome -Force" -ForegroundColor Gray
    Write-Host "   python run_bot.py" -ForegroundColor Gray
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Ofrecer ver logs completos si hay errores
if (-not $allTestsPassed) {
    Write-Host "¿Deseas ver los últimos 30 líneas de los logs? (S/N)" -ForegroundColor Yellow
    $response = Read-Host
    if ($response -eq "S" -or $response -eq "s") {
        Write-Host ""
        Get-Content "bot_output.log" -Tail 30 | ForEach-Object { Write-Host $_ }
    }
}
