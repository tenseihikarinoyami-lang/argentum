#Requires -Version 5.0

<#
.SYNOPSIS
    Verifies that the new Asset Cycling system is working correctly.
    Checks that bot is changing assets, receiving WebSocket data, and generating signals.

.DESCRIPTION
    This script performs 5 key verification checks:
    1. Chrome is running with remote debugging on port 9222
    2. Bot is starting (Python process running)
    3. Logs show "asset cycling mode" (new system active)
    4. Logs show asset changes (CHANGE-ASSET messages)
    5. Logs show signals being generated within 60 seconds

.EXAMPLE
    .\VERIFY_ASSET_CYCLING.ps1
#>

# Configuration
$botLogFile = "c:\Users\usuario\Documents\2\bot_output.log"
$pythonProcessName = "python"
$chromePort = 9222
$maxWaitSeconds = 90  # Maximum 90 seconds to see first signal
$checkIntervalSeconds = 2

Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "🔍 ASSET CYCLING SYSTEM VERIFICATION" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# CHECK 1: Chrome is running with remote debugging
Write-Host "[CHECK 1] Verifying Chrome remote debugging..." -ForegroundColor Yellow
$chromeProcess = Get-Process chrome -ErrorAction SilentlyContinue
if ($chromeProcess) {
    Write-Host "✅ Chrome is running" -ForegroundColor Green
    
    # Try to connect to remote debugging port
    try {
        $socket = New-Object Net.Sockets.TcpClient
        $asyncResult = $socket.BeginConnect("127.0.0.1", $chromePort, $null, $null)
        $asyncResult.AsyncWaitHandle.WaitOne(1000, $false) | Out-Null
        
        if ($socket.Connected) {
            Write-Host "✅ Chrome remote debugging on port $chromePort is ACTIVE" -ForegroundColor Green
            $socket.Close()
        } else {
            Write-Host "⚠️  Port $chromePort not responding - Chrome may not have debugging enabled" -ForegroundColor Yellow
            Write-Host "   Run: chrome.exe --remote-debugging-port=9222 https://qxbroker.com/es/demo-trade" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "⚠️  Could not connect to port $chromePort" -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ Chrome is NOT running" -ForegroundColor Red
    Write-Host "   Please start Chrome with: chrome.exe --remote-debugging-port=9222" -ForegroundColor Red
}
Write-Host ""

# CHECK 2: Bot process is running
Write-Host "[CHECK 2] Checking if bot is running..." -ForegroundColor Yellow
$pythonProcess = Get-Process python -ErrorAction SilentlyContinue
if ($pythonProcess) {
    Write-Host "✅ Python process is running (PID: $($pythonProcess[0].Id))" -ForegroundColor Green
} else {
    Write-Host "⚠️  No Python process detected - bot may not have started yet" -ForegroundColor Yellow
}
Write-Host ""

# CHECK 3: Logs show "asset cycling mode" (new system active)
Write-Host "[CHECK 3] Checking if Asset Cycling system is active..." -ForegroundColor Yellow
if (Test-Path $botLogFile) {
    $recentLogs = Get-Content $botLogFile -Tail 100
    if ($recentLogs -match "asset cycling mode") {
        Write-Host "✅ Asset Cycling system is ACTIVE" -ForegroundColor Green
        Write-Host "   Found: 'asset cycling mode'" -ForegroundColor Green
    } elseif ($recentLogs -match "STARTUP PHASE") {
        Write-Host "⚠️  Old system is running (STARTUP PHASE)" -ForegroundColor Yellow
        Write-Host "   Please update real_time_monitor.py with the new Asset Cycling code" -ForegroundColor Yellow
    } else {
        Write-Host "⚠️  Cannot determine system status" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️  Log file not found: $botLogFile" -ForegroundColor Yellow
}
Write-Host ""

# CHECK 4: Monitor for asset changes over next 60 seconds
Write-Host "[CHECK 4] Monitoring for asset changes (up to $maxWaitSeconds seconds)..." -ForegroundColor Yellow
Write-Host ""

$startTime = Get-Date
$assetsFound = @()
$signalsFound = @()
$lastLogLineCount = 0

while ((Get-Date) - $startTime -lt ([TimeSpan]::FromSeconds($maxWaitSeconds))) {
    if (Test-Path $botLogFile) {
        $allLogs = @(Get-Content $botLogFile)
        $currentLineCount = $allLogs.Count
        
        # Get only new lines since last check
        if ($currentLineCount -gt $lastLogLineCount) {
            $newLines = $allLogs[($lastLogLineCount)..($currentLineCount - 1)]
            
            # Check for asset changes
            $changeLines = $newLines | Select-String "Switching to:|Successfully changed to"
            if ($changeLines) {
                foreach ($line in $changeLines) {
                    if ($line -match "Switching to: (.+?)$") {
                        $asset = $matches[1].Trim()
                        if ($asset -notin $assetsFound) {
                            $assetsFound += $asset
                            Write-Host "  ✅ Asset change detected: $asset" -ForegroundColor Green
                        }
                    }
                }
            }
            
            # Check for signals
            $signalLines = $newLines | Select-String "\[SIGNAL\]|📱"
            if ($signalLines) {
                foreach ($line in $signalLines) {
                    $signalsFound += $line
                    Write-Host "  ✅ Signal detected!" -ForegroundColor Green
                    Write-Host "     $($line.Line)" -ForegroundColor Cyan
                }
            }
            
            $lastLogLineCount = $currentLineCount
        }
    }
    
    # Check if we have enough confirmations
    if ($assetsFound.Count -ge 2 -and $signalsFound.Count -ge 1) {
        Write-Host ""
        Write-Host "✅ SUCCESS: Asset cycling and signals are working!" -ForegroundColor Green
        break
    }
    
    Start-Sleep -Seconds $checkIntervalSeconds
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "📊 VERIFICATION SUMMARY" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

if ($assetsFound.Count -gt 0) {
    Write-Host "✅ Assets detected: $($assetsFound.Count)" -ForegroundColor Green
    foreach ($asset in $assetsFound) {
        Write-Host "   • $asset" -ForegroundColor Cyan
    }
} else {
    Write-Host "⚠️  No asset changes detected" -ForegroundColor Yellow
}
Write-Host ""

if ($signalsFound.Count -gt 0) {
    Write-Host "✅ Signals detected: $($signalsFound.Count)" -ForegroundColor Green
    foreach ($signal in $signalsFound) {
        Write-Host "   • $signal" -ForegroundColor Cyan
    }
} else {
    Write-Host "⚠️  No signals detected yet (may take up to 2 minutes)" -ForegroundColor Yellow
}
Write-Host ""

# Final recommendations
Write-Host "📋 RECOMMENDATIONS:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1️⃣  If Asset Cycling shows ACTIVE:" -ForegroundColor Green
Write-Host "   ✅ System is working correctly" -ForegroundColor Green
Write-Host "   ✅ Keep bot running to receive continuous signals" -ForegroundColor Green
Write-Host ""

Write-Host "2️⃣  If Asset Cycling shows OLD SYSTEM:" -ForegroundColor Yellow
Write-Host "   ⚠️  Update the code:" -ForegroundColor Yellow
Write-Host "      git pull" -ForegroundColor Cyan
Write-Host "      Restart bot" -ForegroundColor Cyan
Write-Host ""

Write-Host "3️⃣  If no signals appear after 2 minutes:" -ForegroundColor Yellow
Write-Host "   ⚠️  Check troubleshooting guide:" -ForegroundColor Yellow
Write-Host "      Get-Content ASSET_CYCLING_EXPLAINED.md | Select-String -Pattern 'Troubleshooting' -Context 0,20" -ForegroundColor Cyan
Write-Host ""

Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan