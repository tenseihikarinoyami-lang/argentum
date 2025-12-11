# 🔍 FULL DIAGNOSTIC SCRIPT - RUN THIS WITH CHROME ON PORT 9222

Write-Host "="*80 -ForegroundColor Cyan
Write-Host "🔍 FULL PIPELINE DIAGNOSTIC - Starting bot and monitoring all data flows" -ForegroundColor Cyan
Write-Host "="*80 -ForegroundColor Cyan
Write-Host ""
Write-Host "PREREQUISITE: Chrome must be running with port 9222" -ForegroundColor Yellow
Write-Host "  Command: chrome.exe --remote-debugging-port=9222" -ForegroundColor Yellow
Write-Host ""

# Clean previous logs
Write-Host "🧹 Cleaning previous logs..." -ForegroundColor Cyan
Remove-Item -Path "bot_output.log" -ErrorAction SilentlyContinue
Remove-Item -Path "bot_error.log" -ErrorAction SilentlyContinue
Remove-Item -Path "pipeline_diagnostic.log" -ErrorAction SilentlyContinue

Write-Host "✅ Logs cleaned" -ForegroundColor Green
Write-Host ""

# Start the bot in background
Write-Host "🤖 Starting bot in background..." -ForegroundColor Cyan
$botProcess = Start-Process python -ArgumentList "run_bot.py" -PassThru -NoNewWindow -RedirectStandardOutput "bot_output.log" -RedirectStandardError "bot_error.log"
Write-Host "✅ Bot started (PID: $($botProcess.Id))" -ForegroundColor Green
Write-Host ""

# Wait for bot to initialize
Write-Host "⏳ Waiting 3 seconds for bot to initialize..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

# Start diagnostic in background
Write-Host "📡 Starting diagnostic in monitor mode..." -ForegroundColor Cyan
$diagProcess = Start-Process python -ArgumentList "DIAGNOSE_FULL_PIPELINE.py", "--monitor" -PassThru -NoNewWindow -RedirectStandardOutput "pipeline_diagnostic.log"
Write-Host "✅ Diagnostic started (PID: $($diagProcess.Id))" -ForegroundColor Green
Write-Host ""

Write-Host "="*80 -ForegroundColor Cyan
Write-Host "📊 MONITORING OUTPUT:" -ForegroundColor Cyan
Write-Host "="*80 -ForegroundColor Cyan
Write-Host ""

# Monitor output in real time
$lastBotLines = 0
$lastDiagLines = 0

for ($i = 0; $i -lt 120; $i++) {
    Write-Host "[$($i+1)/120] Time: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray
    
    # Show new bot output
    if (Test-Path "bot_output.log") {
        $botContent = Get-Content "bot_output.log" -ErrorAction SilentlyContinue
        if ($botContent) {
            $botLines = @($botContent).Count
            if ($botLines -gt $lastBotLines) {
                $newLines = $botLines - $lastBotLines
                Write-Host "   🤖 Bot: $newLines new lines" -ForegroundColor Green
                $lastBotLines = $botLines
            }
        }
    }
    
    # Show new diagnostic output
    if (Test-Path "pipeline_diagnostic.log") {
        $diagContent = Get-Content "pipeline_diagnostic.log" -ErrorAction SilentlyContinue
        if ($diagContent) {
            $diagLines = @($diagContent).Count
            if ($diagLines -gt $lastDiagLines) {
                $newLines = $diagLines - $lastDiagLines
                Write-Host "   📡 Diagnostic: $newLines new lines" -ForegroundColor Green
                $lastDiagLines = $diagLines
            }
        }
    }
    
    Start-Sleep -Seconds 5
}

Write-Host ""
Write-Host "="*80 -ForegroundColor Cyan
Write-Host "✅ MONITORING COMPLETE - Check output files:" -ForegroundColor Cyan
Write-Host "="*80 -ForegroundColor Cyan
Write-Host ""
Write-Host "📄 Bot output:        bot_output.log" -ForegroundColor Cyan
Write-Host "📊 Diagnostic output: pipeline_diagnostic.log" -ForegroundColor Cyan
Write-Host ""

# Kill processes
Write-Host "🛑 Stopping processes..." -ForegroundColor Yellow
Stop-Process -Id $botProcess.Id -Force -ErrorAction SilentlyContinue
Stop-Process -Id $diagProcess.Id -Force -ErrorAction SilentlyContinue
Write-Host "✅ Stopped" -ForegroundColor Green

# Show diagnostic summary
Write-Host ""
Write-Host "="*80 -ForegroundColor Cyan
Write-Host "📋 DIAGNOSTIC SUMMARY:" -ForegroundColor Cyan
Write-Host "="*80 -ForegroundColor Cyan
Write-Host ""
if (Test-Path "pipeline_diagnostic.log") {
    Get-Content "pipeline_diagnostic.log" | Select-String "CHECK|✅|❌|⚠️" | Select-Object -Last 30
}

Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host "1. Check pipeline_diagnostic.log for full details" -ForegroundColor Yellow
Write-Host "2. Identify which step in the pipeline is breaking" -ForegroundColor Yellow
Write-Host "3. Based on results, we'll fix the issue" -ForegroundColor Yellow