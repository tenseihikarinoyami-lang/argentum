# 🤖 COMPLETE BOT TESTING & VERIFICATION FRAMEWORK
# ================================================
# This script orchestrates a complete bot verification workflow

param(
    [switch]$SkipDependencyCheck = $false,
    [switch]$SkipBotStart = $false,
    [int]$TestDurationSeconds = 120
)

# Colors
$Info = "Cyan"
$Success = "Green"
$Warning = "Yellow"
$Error_Color = "Red"

function Write-Header {
    param([string]$Title)
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor $Info
    Write-Host "║ $($Title.PadRight(80)) ║" -ForegroundColor $Info
    Write-Host "╚═══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor $Info
    Write-Host ""
}

function Write-Step {
    param([string]$Title, [int]$Number)
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor $Info
    Write-Host "STEP $Number: $Title" -ForegroundColor $Info
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor $Info
    Write-Host ""
}

function Test-ChromeRunning {
    Write-Host "🔍 Checking Chrome..." -ForegroundColor $Info
    
    try {
        $chrome = Get-NetTCPConnection -LocalPort 9222 -ErrorAction SilentlyContinue
        if ($chrome) {
            Write-Host "   ✅ Chrome Remote Debug is active on port 9222" -ForegroundColor $Success
            return $true
        }
        else {
            Write-Host "   ⚠️  Chrome Remote Debug not detected on port 9222" -ForegroundColor $Warning
            Write-Host ""
            Write-Host "   💡 To start Chrome with remote debug:" -ForegroundColor $Info
            Write-Host "      chrome.exe --remote-debugging-port=9222" -ForegroundColor $Warning
            Write-Host ""
            return $false
        }
    }
    catch {
        Write-Host "   ⚠️  Could not check port 9222" -ForegroundColor $Warning
        return $false
    }
}

function Test-Dependencies {
    Write-Host "🔍 Checking Python dependencies..." -ForegroundColor $Info
    
    $deps = @('playwright', 'numpy', 'requests', 'psutil')
    $missing = @()
    
    foreach ($dep in $deps) {
        try {
            $result = python -c "import $dep" 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   ✅ $dep" -ForegroundColor $Success
            }
            else {
                Write-Host "   ❌ $dep (MISSING)" -ForegroundColor $Error_Color
                $missing += $dep
            }
        }
        catch {
            Write-Host "   ⚠️  Could not check $dep" -ForegroundColor $Warning
        }
    }
    
    if ($missing.Count -eq 0) {
        Write-Host ""
        Write-Host "   ✅ All dependencies present" -ForegroundColor $Success
        return $true
    }
    else {
        Write-Host ""
        Write-Host "   ❌ Missing: $($missing -join ', ')" -ForegroundColor $Error_Color
        Write-Host ""
        Write-Host "   💡 To install missing dependencies:" -ForegroundColor $Info
        Write-Host "      pip install $($missing -join ' ')" -ForegroundColor $Warning
        Write-Host ""
        return $false
    }
}

function Test-Configuration {
    Write-Host "🔍 Checking configuration..." -ForegroundColor $Info
    
    if (Test-Path "config.json") {
        Write-Host "   ✅ config.json found" -ForegroundColor $Success
        $config = Get-Content config.json | ConvertFrom-Json
        Write-Host "      • Assets: $($config.assets.Count)" -ForegroundColor $Success
        Write-Host "      • Broker: $($config.broker)" -ForegroundColor $Success
        return $true
    }
    else {
        Write-Host "   ❌ config.json not found" -ForegroundColor $Error_Color
        return $false
    }
}

function Run-SystemTest {
    Write-Header "RUNNING SYSTEM DIAGNOSTICS"
    
    Write-Host "🚀 Executing COMPLETE_BOT_TEST.py..." -ForegroundColor $Info
    Write-Host ""
    
    python COMPLETE_BOT_TEST.py
    
    Write-Host ""
    Write-Host "✅ System diagnostics complete" -ForegroundColor $Success
}

function Start-Bot {
    Write-Header "STARTING BOT"
    
    Write-Host "🤖 Starting bot with live signal monitoring..." -ForegroundColor $Info
    Write-Host ""
    
    # Check if bot process already running
    $botProcess = Get-Process python -ErrorAction SilentlyContinue | Where-Object {$_.CommandLine -like "*run_bot.py*"}
    if ($botProcess) {
        Write-Host "⚠️  Bot process already running (PID: $($botProcess.Id))" -ForegroundColor $Warning
        Write-Host "   Stopping previous instance..." -ForegroundColor $Info
        Stop-Process -Id $botProcess.Id -Force
        Start-Sleep -Seconds 2
    }
    
    Write-Host "📝 Starting bot: python run_bot.py" -ForegroundColor $Info
    Start-Process -FilePath python -ArgumentList "run_bot.py" -NoNewWindow
    
    # Wait for bot to initialize
    Write-Host "⏳ Waiting for bot to initialize..." -ForegroundColor $Info
    Start-Sleep -Seconds 5
    
    # Check if log file exists
    if (Test-Path "bot_output.log") {
        Write-Host "✅ Bot started successfully" -ForegroundColor $Success
        return $true
    }
    else {
        Write-Host "⚠️  Bot may still be initializing..." -ForegroundColor $Warning
        return $true
    }
}

function Monitor-Signals {
    Write-Header "MONITORING SIGNAL GENERATION"
    
    Write-Host "📊 Starting real-time signal validator..." -ForegroundColor $Info
    Write-Host "   Duration: $TestDurationSeconds seconds" -ForegroundColor $Info
    Write-Host ""
    
    python SIGNAL_VALIDATOR.py
}

function Show-Results {
    Write-Header "TEST RESULTS SUMMARY"
    
    if (Test-Path "VALIDATION_REPORT.json") {
        Write-Host "📊 Reading validation results..." -ForegroundColor $Info
        Write-Host ""
        
        $report = Get-Content VALIDATION_REPORT.json | ConvertFrom-Json
        
        Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor $Info
        Write-Host "                           VALIDATION RESULTS" -ForegroundColor $Info
        Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor $Info
        Write-Host ""
        Write-Host "Duration:              $([Math]::Round($report.duration, 1)) seconds" -ForegroundColor $Success
        Write-Host "Signals Generated:     $($report.signals_detected)" -ForegroundColor $(if ($report.signals_detected -gt 5) { $Success } else { $Warning })
        Write-Host "Assets Detected:       $($report.assets_detected)" -ForegroundColor $(if ($report.assets_detected -gt 5) { $Success } else { $Warning })
        Write-Host "WebSocket Frames:      $($report.websocket_frames)" -ForegroundColor $(if ($report.websocket_frames -gt 100) { $Success } else { $Warning })
        Write-Host "Errors:                $($report.errors)" -ForegroundColor $(if ($report.errors -eq 0) { $Success } else { $Warning })
        Write-Host ""
        
        if ($report.signals_detected -gt 0) {
            Write-Host "Signals/Minute:        $([Math]::Round(($report.signals_detected / $report.duration) * 60, 1))" -ForegroundColor $Success
        }
        
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor $Info
        Write-Host ""
        
        # Overall status
        if ($report.signals_detected -gt 5 -and $report.assets_detected -gt 5 -and $report.errors -eq 0) {
            Write-Host "✅ BOT SYSTEM: FULLY OPERATIONAL" -ForegroundColor $Success
            Write-Host ""
            Write-Host "The bot is generating signals successfully!" -ForegroundColor $Success
        }
        elseif ($report.signals_detected -gt 0) {
            Write-Host "⚠️  BOT SYSTEM: PARTIALLY OPERATIONAL" -ForegroundColor $Warning
            Write-Host ""
            Write-Host "Signals are being generated but may be limited." -ForegroundColor $Warning
        }
        else {
            Write-Host "⚠️  BOT SYSTEM: NOT GENERATING SIGNALS" -ForegroundColor $Warning
            Write-Host ""
            Write-Host "Troubleshooting:" -ForegroundColor $Info
            Write-Host "   1. Ensure Chrome is running: chrome.exe --remote-debugging-port=9222" -ForegroundColor $Warning
            Write-Host "   2. Keep Quotex visible in browser" -ForegroundColor $Warning
            Write-Host "   3. Check bot logs: Get-Content bot_output.log -Wait" -ForegroundColor $Warning
            Write-Host "   4. Verify internet connection" -ForegroundColor $Warning
        }
    }
    else {
        Write-Host "⚠️  No validation report found" -ForegroundColor $Warning
    }
}

function Show-NextSteps {
    Write-Header "NEXT STEPS & QUICK COMMANDS"
    
    Write-Host "📋 TO CONTINUE MONITORING:" -ForegroundColor $Info
    Write-Host ""
    Write-Host "  View real-time bot output:" -ForegroundColor $Info
    Write-Host "    Get-Content bot_output.log -Wait" -ForegroundColor $Warning
    Write-Host ""
    Write-Host "  Open web dashboard:" -ForegroundColor $Info
    Write-Host "    Start-Process 'http://localhost:5000'" -ForegroundColor $Warning
    Write-Host ""
    Write-Host "  Stop bot:" -ForegroundColor $Info
    Write-Host "    Stop-Process -Name python -Force" -ForegroundColor $Warning
    Write-Host ""
}

# ═════════════════════════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═════════════════════════════════════════════════════════════════════════════════

Write-Header "🤖 COMPLETE BOT TESTING & VERIFICATION FRAMEWORK"

# Step 1: Pre-flight checks
Write-Step "PRE-FLIGHT CHECKS" 1

if (-not $SkipDependencyCheck) {
    if (-not (Test-Dependencies)) {
        Write-Host "⚠️  Dependency check failed" -ForegroundColor $Warning
        Write-Host ""
        $continue = Read-Host "Continue anyway? (y/n)"
        if ($continue -ne 'y') {
            exit 1
        }
    }
}

Test-Configuration | Out-Null
$chromeRunning = Test-ChromeRunning

Write-Host ""

if (-not $chromeRunning) {
    Write-Host "⚠️  Chrome Remote Debug not detected" -ForegroundColor $Warning
    Write-Host ""
    $startChrome = Read-Host "Start Chrome now with remote debug? (y/n)"
    if ($startChrome -eq 'y') {
        Write-Host "🚀 Starting Chrome..." -ForegroundColor $Info
        Start-Process "chrome.exe" -ArgumentList "--remote-debugging-port=9222"
        Write-Host "   Waiting for Chrome to initialize..." -ForegroundColor $Info
        Start-Sleep -Seconds 5
    }
}

# Step 2: System diagnostics
Write-Step "SYSTEM DIAGNOSTICS" 2
Run-SystemTest

# Step 3: Start bot
Write-Step "BOT STARTUP" 3

if (-not $SkipBotStart) {
    $startBot = Read-Host "Start bot for signal monitoring? (y/n)"
    if ($startBot -eq 'y') {
        Start-Bot
        
        # Step 4: Monitor signals
        Write-Step "SIGNAL MONITORING" 4
        Monitor-Signals
    }
}

# Step 5: Show results
Write-Step "RESULTS ANALYSIS" 5
Show-Results

# Step 6: Next steps
Show-NextSteps

Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor $Info
Write-Host "Testing framework completed" -ForegroundColor $Success
Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor $Info
Write-Host ""