#!/usr/bin/env powershell

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                                                                           ║
# ║       DIAGNOSTIC SCRIPT - SIGNAL GENERATION TROUBLESHOOTING              ║
# ║                                                                           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗"
Write-Host "║  🔍 SIGNAL GENERATION DIAGNOSTIC TOOL                         ║"
Write-Host "╚════════════════════════════════════════════════════════════════╝"
Write-Host ""

# Colors
$SUCCESS = "Green"
$ERROR = "Red"
$WARNING = "Yellow"
$INFO = "Cyan"

# 1. Check if bot is running
Write-Host "1️⃣  Checking if Python bot process is running..."
$bot_process = Get-Process python -ErrorAction SilentlyContinue
if ($bot_process) {
    Write-Host "   ✅ Python process found" -ForegroundColor $SUCCESS
} else {
    Write-Host "   ❌ NO Python process running. Start the bot first!" -ForegroundColor $ERROR
    exit 1
}

# 2. Check if Chrome is running on debug port
Write-Host ""
Write-Host "2️⃣  Checking Chrome debug port 9222..."
try {
    $chrome_test = Test-NetConnection -ComputerName localhost -Port 9222 -WarningAction SilentlyContinue
    if ($chrome_test.TcpTestSucceeded) {
        Write-Host "   ✅ Chrome debug port 9222 is open" -ForegroundColor $SUCCESS
    } else {
        Write-Host "   ⚠️  Chrome debug port NOT responding" -ForegroundColor $WARNING
    }
} catch {
    Write-Host "   ⚠️  Could not test port 9222" -ForegroundColor $WARNING
}

# 3. Check logs for CALLBACK messages
Write-Host ""
Write-Host "3️⃣  Checking bot logs for CALLBACK executions..."
if (Test-Path "bot_output.log") {
    $callback_count = (Get-Content "bot_output.log" | Select-String "\[CALLBACK\]" -ErrorAction SilentlyContinue).Count
    if ($callback_count -gt 0) {
        Write-Host "   ✅ Found $callback_count [CALLBACK] entries in logs" -ForegroundColor $SUCCESS
        Write-Host "   Last few callbacks:" -ForegroundColor $INFO
        Get-Content "bot_output.log" | Select-String "\[CALLBACK\]" | Select-Object -Last 3 | ForEach-Object {
            Write-Host "      $_" -ForegroundColor $INFO
        }
    } else {
        Write-Host "   ❌ NO [CALLBACK] entries in logs - callback is not being executed!" -ForegroundColor $ERROR
    }
} else {
    Write-Host "   ⚠️  bot_output.log not found" -ForegroundColor $WARNING
}

# 4. Check for signals
Write-Host ""
Write-Host "4️⃣  Checking for SIGNAL DETECTED messages..."
if (Test-Path "bot_output.log") {
    $signal_count = (Get-Content "bot_output.log" | Select-String "Signal detected" -ErrorAction SilentlyContinue).Count
    if ($signal_count -gt 0) {
        Write-Host "   ✅ Found $signal_count signals in logs" -ForegroundColor $SUCCESS
        Get-Content "bot_output.log" | Select-String "Signal detected" | Select-Object -Last 5 | ForEach-Object {
            Write-Host "      $_" -ForegroundColor $INFO
        }
    } else {
        Write-Host "   ❌ NO signals detected. Pipeline is broken!" -ForegroundColor $ERROR
    }
} else {
    Write-Host "   ⚠️  bot_output.log not found" -ForegroundColor $WARNING
}

# 5. Check for CYCLE messages
Write-Host ""
Write-Host "5️⃣  Checking for asset CYCLE messages..."
if (Test-Path "bot_output.log") {
    $cycle_count = (Get-Content "bot_output.log" | Select-String "\[CYCLE" -ErrorAction SilentlyContinue).Count
    if ($cycle_count -gt 0) {
        Write-Host "   ✅ Found $cycle_count CYCLE entries in logs" -ForegroundColor $SUCCESS
        Get-Content "bot_output.log" | Select-String "\[CYCLE" | Select-Object -Last 3 | ForEach-Object {
            Write-Host "      $_" -ForegroundColor $INFO
        }
    } else {
        Write-Host "   ⚠️  No CYCLE entries found" -ForegroundColor $WARNING
    }
} else {
    Write-Host "   ⚠️  bot_output.log not found" -ForegroundColor $WARNING
}

# 6. Check for errors
Write-Host ""
Write-Host "6️⃣  Checking for ERROR messages in logs..."
if (Test-Path "bot_output.log") {
    $error_count = (Get-Content "bot_output.log" | Select-String "ERROR" -ErrorAction SilentlyContinue).Count
    if ($error_count -gt 0) {
        Write-Host "   ⚠️  Found $error_count ERROR entries in logs" -ForegroundColor $WARNING
        Get-Content "bot_output.log" | Select-String "ERROR" | Select-Object -Last 5 | ForEach-Object {
            Write-Host "      $_" -ForegroundColor $WARNING
        }
    } else {
        Write-Host "   ✅ No ERROR messages in logs" -ForegroundColor $SUCCESS
    }
} else {
    Write-Host "   ⚠️  bot_output.log not found" -ForegroundColor $WARNING
}

# 7. Test dashboard API
Write-Host ""
Write-Host "7️⃣  Testing dashboard API..."
try {
    $response = Invoke-WebRequest -Uri "http://localhost:5000/api/status" -Method Get -TimeoutSec 3 -ErrorAction SilentlyContinue
    if ($response.StatusCode -eq 200) {
        Write-Host "   ✅ Dashboard API responding" -ForegroundColor $SUCCESS
        $json = $response.Content | ConvertFrom-Json
        if ($json.bot_status) {
            Write-Host "   Bot status:" -ForegroundColor $INFO
            $json.bot_status | ForEach-Object {
                Write-Host "      $(($_ | Get-Member -MemberType NoteProperty).Name): $($_.Value)" -ForegroundColor $INFO
            }
        }
    }
} catch {
    Write-Host "   ⚠️  Dashboard API not responding" -ForegroundColor $WARNING
}

# Summary
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗"
Write-Host "║  📋 SUMMARY & NEXT STEPS                                       ║"
Write-Host "╚════════════════════════════════════════════════════════════════╝"
Write-Host ""

if (Test-Path "bot_output.log") {
    $last_line_time = (Get-Item "bot_output.log").LastWriteTime
    $time_diff = (Get-Date) - $last_line_time
    Write-Host "Last log update: $($time_diff.TotalSeconds) seconds ago"
    
    if ($time_diff.TotalSeconds -gt 60) {
        Write-Host "⚠️  Bot logs haven't been updated in over a minute - bot might be frozen!" -ForegroundColor $WARNING
    }
}

Write-Host ""
Write-Host "📊 What this means:"
Write-Host ""

if ($callback_count -eq 0) {
    Write-Host "❌ CALLBACKS NOT EXECUTING:" -ForegroundColor $ERROR
    Write-Host "   → The real-time monitor callback is not being triggered"
    Write-Host "   → Asset cycling might be working but candle analysis is not running"
    Write-Host "   → FIX: Check real_time_monitor.py line 259-265"
    Write-Host ""
}

if ($signal_count -eq 0 -and $callback_count -gt 0) {
    Write-Host "❌ CALLBACKS RUNNING BUT NO SIGNALS:" -ForegroundColor $ERROR
    Write-Host "   → Callback executes but signal_generator returns None"
    Write-Host "   → Indicators might be failing or signal criteria too strict"
    Write-Host "   → FIX: Check signal_generator logic"
    Write-Host ""
}

if ($signal_count -gt 0) {
    Write-Host "✅ SIGNALS ARE BEING GENERATED!" -ForegroundColor $SUCCESS
    Write-Host "   → System is working correctly"
    Write-Host "   → Check dashboard: http://localhost:5000"
    Write-Host ""
}

Write-Host "🔧 QUICK FIXES:"
Write-Host ""
Write-Host "If NO callbacks:"
Write-Host "  1. Stop bot: Stop-Process -Name python -Force"
Write-Host "  2. Verify Chrome is running on port 9222"
Write-Host "  3. Restart bot: python run_bot.py"
Write-Host "  4. Wait 60 seconds"
Write-Host ""

Write-Host "If callbacks but NO signals:"
Write-Host "  1. Check [CALLBACK] logs for error messages"
Write-Host "  2. Ensure dataframes have 20+ candles"
Write-Host "  3. Verify indicators are being calculated"
Write-Host ""

Write-Host "💡 For continuous monitoring:"
Write-Host ""
Write-Host "  Get-Content bot_output.log -Wait | Select-String '\[CALLBACK\]|\[REAL-TIME\]|Signal detected'"
Write-Host ""