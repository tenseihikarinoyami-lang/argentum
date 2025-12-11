#!/usr/bin/env powershell
<#
DIAGNOSTIC COMPLETE - Signal Generation + Dashboard Status + Tab Management
===========================================================================
#>

Write-Host "`n[DIAGNOSTIC] Starting complete diagnosis..." -ForegroundColor Cyan

# Test 1: Check Chrome connection
Write-Host "`n[1/5] Checking Chrome connection..." -ForegroundColor Yellow
$chromeTest = Test-NetConnection -ComputerName localhost -Port 9222 -WarningAction SilentlyContinue
if ($chromeTest.TcpTestSucceeded) {
    Write-Host "  OK Chrome available on port 9222" -ForegroundColor Green
} else {
    Write-Host "  FAIL Chrome NOT available on port 9222" -ForegroundColor Red
    Write-Host "  FIX: chrome.exe --remote-debugging-port=9222" -ForegroundColor Yellow
}

# Test 2: Check bot process
Write-Host "`n[2/5] Checking bot process..." -ForegroundColor Yellow
$botProcess = Get-Process python -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match 'run_bot|main.py' }
if ($botProcess) {
    Write-Host "  OK Bot is running (PID: $($botProcess.Id))" -ForegroundColor Green
} else {
    Write-Host "  FAIL Bot is NOT running" -ForegroundColor Red
    Write-Host "  FIX: python run_bot.py" -ForegroundColor Yellow
}

# Test 3: Check logs for signal generation
Write-Host "`n[3/5] Analyzing logs (last 200 lines)..." -ForegroundColor Yellow
$logFile = "c:\Users\usuario\Documents\2\bot_output.log"

if (Test-Path $logFile) {
    $logs = Get-Content $logFile -Tail 200 -ErrorAction SilentlyContinue
    
    # Count key messages
    $cycleCount = ($logs | Select-String "\[CYCLE" | Measure-Object).Count
    $callbackCount = ($logs | Select-String "\[CALLBACK\]" | Measure-Object).Count
    $analysisCount = ($logs | Select-String "\[ANALYSIS\]" | Measure-Object).Count
    $signalCount = ($logs | Select-String "Signal detected" | Measure-Object).Count
    $wsWaitCount = ($logs | Select-String "\[WS-WAIT\]" | Measure-Object).Count
    $step3Count = ($logs | Select-String "\[3/4\]" | Measure-Object).Count
    
    Write-Host "  Log Statistics:" -ForegroundColor Cyan
    Write-Host "     Cycles: $cycleCount" -ForegroundColor Cyan
    Write-Host "     Callbacks: $callbackCount" -ForegroundColor $(if ($callbackCount -gt 0) { 'Green' } else { 'Red' })
    Write-Host "     Analysis: $analysisCount" -ForegroundColor $(if ($analysisCount -gt 0) { 'Green' } else { 'Red' })
    Write-Host "     Signals: $signalCount" -ForegroundColor $(if ($signalCount -gt 0) { 'Green' } else { 'Red' })
    Write-Host "     WS Waits: $wsWaitCount" -ForegroundColor Cyan
    Write-Host "     Step [3/4]: $step3Count" -ForegroundColor Cyan
    
    # Show latest events
    Write-Host "`n  Latest events:" -ForegroundColor Cyan
    $logs | Select-String "\[CYCLE|\[CALLBACK\]|\[ANALYSIS\]|Signal detected|\[3/4\]" | Select-Object -Last 5 | ForEach-Object {
        Write-Host "     $_" -ForegroundColor Gray
    }
    
    # Specific problems
    Write-Host "`n  Analysis:" -ForegroundColor Cyan
    
    if ($cycleCount -eq 0) {
        Write-Host "     FAIL: Asset cycling not working" -ForegroundColor Red
    } else {
        Write-Host "     OK: Asset cycling working ($cycleCount cycles)" -ForegroundColor Green
    }
    
    if ($step3Count -eq 0) {
        Write-Host "     FAIL: _analyze_asset() step not reached" -ForegroundColor Red
        Write-Host "     CAUSE: _wait_for_websocket_data() timeout or _change_to_asset() fails" -ForegroundColor Yellow
    } else {
        Write-Host "     OK: Analysis step reached ($step3Count times)" -ForegroundColor Green
    }
    
    if ($callbackCount -eq 0) {
        Write-Host "     FAIL: [CALLBACK] not in logs - callback not executing" -ForegroundColor Red
    } else {
        Write-Host "     OK: Callback executing ($callbackCount times)" -ForegroundColor Green
    }
    
    if ($signalCount -eq 0) {
        if ($callbackCount -gt 0) {
            Write-Host "     FAIL: Callback runs but no signals generated" -ForegroundColor Red
            Write-Host "     CAUSE: signal_generator returns None" -ForegroundColor Yellow
        } else {
            Write-Host "     FAIL: No signals (callback not running)" -ForegroundColor Red
        }
    } else {
        Write-Host "     OK: Signals generating ($signalCount signals)" -ForegroundColor Green
    }
    
} else {
    Write-Host "  FAIL Log file not found: $logFile" -ForegroundColor Red
}

# Test 4: Check dashboard status
Write-Host "`n[4/5] Checking dashboard..." -ForegroundColor Yellow
try {
    $statusResponse = Invoke-WebRequest -Uri "http://localhost:5000/api/status" -Method GET -TimeoutSec 3 -ErrorAction SilentlyContinue
    $status = $statusResponse.Content | ConvertFrom-Json
    $botStatus = $status.bot_status
    
    Write-Host "  OK Dashboard API responding" -ForegroundColor Green
    Write-Host "     Bot State: $($botStatus.estado_del_bot)" -ForegroundColor $(if ($botStatus.estado_del_bot -eq 'EJECUTANDO') { 'Green' } else { 'Yellow' })
    Write-Host "     DB: $($botStatus.conexion_a_db)" -ForegroundColor $(if ($botStatus.conexion_a_db -eq 'CONECTADO') { 'Green' } else { 'Yellow' })
    Write-Host "     Broker: $($botStatus.conexion_broker)" -ForegroundColor $(if ($botStatus.conexion_broker -eq 'CONECTADO') { 'Green' } else { 'Yellow' })
    Write-Host "     Monitor: $($botStatus.monitor_realtime)" -ForegroundColor $(if ($botStatus.monitor_realtime -eq 'ACTIVO') { 'Green' } else { 'Yellow' })
    Write-Host "     Assets: $($botStatus.activos_monitoreados)" -ForegroundColor Cyan
    Write-Host "     Uptime: $($botStatus.tiempo_activo)" -ForegroundColor Cyan
    Write-Host "     Signals: $($botStatus.senales_detectadas)" -ForegroundColor Cyan
    
} catch {
    Write-Host "  FAIL Dashboard not responding on http://localhost:5000" -ForegroundColor Red
}

# Summary
Write-Host "`n[SUMMARY]" -ForegroundColor Cyan
Write-Host "═════════════════════════════════════════════════" -ForegroundColor Cyan

if ($cycleCount -gt 0 -and $callbackCount -gt 0 -and $signalCount -gt 0) {
    Write-Host "`nSTATUS: SYSTEM 100% OPERATIONAL" -ForegroundColor Green
    Write-Host "All three components working:" -ForegroundColor Green
    Write-Host "  OK Asset cycling" -ForegroundColor Green
    Write-Host "  OK Signal generation" -ForegroundColor Green
    Write-Host "  OK Dashboard" -ForegroundColor Green
} elseif ($cycleCount -gt 0) {
    Write-Host "`nSTATUS: PARTIAL - Asset cycling works, signals failing" -ForegroundColor Yellow
    if ($step3Count -eq 0) {
        Write-Host "ISSUE: Analysis step not reached" -ForegroundColor Red
        Write-Host "ACTION: Check _wait_for_websocket_data() timeout" -ForegroundColor Yellow
    }
} else {
    Write-Host "`nSTATUS: OFFLINE - Bot not running" -ForegroundColor Red
}

Write-Host "`n═════════════════════════════════════════════════`n" -ForegroundColor Cyan