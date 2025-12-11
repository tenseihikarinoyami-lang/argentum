#!/usr/bin/env powershell

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                                                                           ║
# ║    🚀 START BOT + MONITOR SIGNALS IN REAL TIME                           ║
# ║                                                                           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════════╗"
Write-Host "║   🚀 TRADING BOT + REAL-TIME SIGNAL MONITOR                      ║"
Write-Host "╚═══════════════════════════════════════════════════════════════════╝"
Write-Host ""

$SUCCESS = "Green"
$ERROR = "Red"
$WARNING = "Yellow"
$INFO = "Cyan"

# Step 1: Stop any existing Python processes
Write-Host "Step 1: Cleaning up old processes..."
try {
    Get-Process python -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
    Write-Host "   ✅ Old Python processes stopped" -ForegroundColor $SUCCESS
}
catch {
    Write-Host "   ℹ️  No Python processes to stop" -ForegroundColor $INFO
}

# Step 2: Clear old logs
Write-Host ""
Write-Host "Step 2: Preparing logs..."
try {
    if (Test-Path "bot_output.log") {
        Remove-Item "bot_output.log" -Force
        Write-Host "   ✅ Old logs cleared" -ForegroundColor $SUCCESS
    }
}
catch {
    Write-Host "   ⚠️  Could not clear logs" -ForegroundColor $WARNING
}

# Step 3: Verify Chrome
Write-Host ""
Write-Host "Step 3: Verifying Chrome..."
$chrome = Get-Process chrome -ErrorAction SilentlyContinue
if ($chrome) {
    Write-Host "   ✅ Chrome is running" -ForegroundColor $SUCCESS
}
else {
    Write-Host "   ⚠️  Chrome not running. Make sure to open:" -ForegroundColor $WARNING
    Write-Host "      chrome.exe --remote-debugging-port=9222" -ForegroundColor $WARNING
}

# Step 4: Start bot
Write-Host ""
Write-Host "Step 4: Starting trading bot..."
Write-Host ""

# Create a job for the bot
$bot_job = Start-Job -ScriptBlock {
    cd "c:\Users\usuario\Documents\2"
    python run_bot.py 2>&1
} -Name "TradingBot"

Write-Host "   ✅ Bot started (Job ID: $($bot_job.Id))" -ForegroundColor $SUCCESS
Start-Sleep -Seconds 5

# Step 5: Monitor logs in real time
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════════╗"
Write-Host "║   📊 MONITORING SIGNAL GENERATION IN REAL TIME                   ║"
Write-Host "╚═══════════════════════════════════════════════════════════════════╝"
Write-Host ""
Write-Host "Watching for:"
Write-Host "  🔔 [CALLBACK]      - Candle analysis callbacks"
Write-Host "  🔧 [SIGNAL-GEN]    - Signal generation attempts"
Write-Host "  ✅ Signal detected - SUCCESSFUL signals"
Write-Host ""
Write-Host "Press Ctrl+C to stop monitoring (bot will keep running)"
Write-Host ""

$log_file = "bot_output.log"
$last_position = 0
$last_signal_count = 0
$last_callback_count = 0

while ($true) {
    try {
        if (Test-Path $log_file) {
            $content = Get-Content $log_file
            $current_lines = @($content) -split "`n"
            
            # Count occurrences
            $signal_count = ($content | Select-String "Signal detected" -AllMatches).Matches.Count
            $callback_count = ($content | Select-String "\[CALLBACK\]" -AllMatches).Matches.Count
            $cycle_count = ($content | Select-String "\[CYCLE" -AllMatches).Matches.Count
            
            # Show new signals
            if ($signal_count -gt $last_signal_count) {
                $new_signals = $signal_count - $last_signal_count
                Write-Host ""
                Write-Host "🎉 NEW SIGNALS: $new_signals" -ForegroundColor $SUCCESS
                Get-Content $log_file | Select-String "Signal detected" | Select-Object -Last $new_signals | ForEach-Object {
                    Write-Host "   $_" -ForegroundColor $SUCCESS
                }
                $last_signal_count = $signal_count
            }
            
            # Show status line
            $status = "`r📊 Cycles: $cycle_count | Callbacks: $callback_count | Signals: $signal_count"
            Write-Host $status -NoNewline
        }
        
        Start-Sleep -Milliseconds 1000
    }
    catch {
        Start-Sleep -Milliseconds 1000
    }
}

# Cleanup
Write-Host ""
Write-Host "Stopping bot..."
Stop-Job -Job $bot_job
Remove-Job -Job $bot_job