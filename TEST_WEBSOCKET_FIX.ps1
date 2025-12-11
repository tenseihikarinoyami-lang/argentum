# Test WebSocket capture after the fix
# This script runs the bot for 60 seconds with enhanced WebSocket debugging

$chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"

# Check if Chrome is running
$chromeProcess = Get-Process chrome -ErrorAction SilentlyContinue
if ($chromeProcess) {
    Write-Host "✅ Chrome is already running"
} else {
    Write-Host "Starting Chrome with remote debugging..."
    & $chromePath --remote-debugging-port=9222 | Out-Null &
    Start-Sleep -Seconds 3
}

# Open Quotex in a new tab
Write-Host "Opening Quotex..."
$wshell = New-Object -ComObject wscript.shell
$wshell.AppActivate("Chrome")
Start-Sleep -Seconds 1

# Run the bot with debugging
Write-Host ""
Write-Host "========================================================================"
Write-Host "Starting Bot with WebSocket Debugging"
Write-Host "========================================================================"
Write-Host ""

python run_bot.py 2>&1 | Tee-Object -FilePath "websocket_debug_output.log"

Write-Host ""
Write-Host "========================================================================"
Write-Host "Test Complete - Check websocket_debug_output.log for WebSocket status"
Write-Host "========================================================================"