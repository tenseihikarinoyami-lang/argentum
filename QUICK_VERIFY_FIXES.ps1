# ============================================================================
# QUICK VERIFICATION - Check if all WebSocket fixes are properly applied
# ============================================================================

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════════════╗"
Write-Host "║           QUICK VERIFICATION OF WEBSOCKET FIXES                        ║"
Write-Host "╚════════════════════════════════════════════════════════════════════════╝"
Write-Host ""

$allGood = $true
$fixedItems = 0
$totalChecks = 0

function Check-CodeFix {
    param(
        [string]$FilePath,
        [string]$SearchPattern,
        [string]$Description
    )
    
    $totalChecks++
    Write-Host "Checking: $Description"
    
    if (Test-Path $FilePath) {
        $content = Get-Content $FilePath -Raw
        if ($content -match $SearchPattern) {
            Write-Host "  ✅ FOUND - Fix is applied correctly" -ForegroundColor Green
            $script:fixedItems++
            return $true
        } else {
            Write-Host "  ❌ NOT FOUND - Fix may be missing" -ForegroundColor Red
            $script:allGood = $false
            return $false
        }
    } else {
        Write-Host "  ❌ FILE NOT FOUND: $FilePath" -ForegroundColor Red
        $script:allGood = $false
        return $false
    }
}

# Verification checks
Write-Host "Verifying critical code changes..."
Write-Host "─────────────────────────────────────────────────────────────────────────"
Write-Host ""

# Check 1: Navigation listener registration
Check-CodeFix `
    -FilePath "c:\Users\usuario\Documents\2\data_interceptor.py" `
    -SearchPattern "page\.on\('framenavigated'" `
    -Description "Navigation listener registration in setup_websocket_listener()"

Write-Host ""

# Check 2: Navigation handler method exists
Check-CodeFix `
    -FilePath "c:\Users\usuario\Documents\2\data_interceptor.py" `
    -SearchPattern "def _on_frame_navigated\(self, frame\)" `
    -Description "_on_frame_navigated() handler method implementation"

Write-Host ""

# Check 3: WebSocket listener re-registration
Check-CodeFix `
    -FilePath "c:\Users\usuario\Documents\2\data_interceptor.py" `
    -SearchPattern "frame\.page\.on\('websocket'" `
    -Description "WebSocket listener re-registration on navigation"

Write-Host ""

# Check 4: Frame received handler exists
Check-CodeFix `
    -FilePath "c:\Users\usuario\Documents\2\data_interceptor.py" `
    -SearchPattern "def _on_frame_received\(self, payload\)" `
    -Description "_on_frame_received() frame handler implementation"

Write-Host ""

# Check 5: Socket.io message processor
Check-CodeFix `
    -FilePath "c:\Users\usuario\Documents\2\data_interceptor.py" `
    -SearchPattern "def _process_socket_io_message\(self, data\)" `
    -Description "_process_socket_io_message() for parsing WebSocket frames"

Write-Host ""

# Additional checks
Write-Host "─────────────────────────────────────────────────────────────────────────"
Write-Host "Additional verification..."
Write-Host ""

# Check test files exist
if (Test-Path "c:\Users\usuario\Documents\2\FINAL_WEBSOCKET_TEST.ps1") {
    Write-Host "✅ FINAL_WEBSOCKET_TEST.ps1 exists" -ForegroundColor Green
    $fixedItems++
} else {
    Write-Host "❌ FINAL_WEBSOCKET_TEST.ps1 NOT FOUND" -ForegroundColor Red
    $allGood = $false
}
$totalChecks++

Write-Host ""

if (Test-Path "c:\Users\usuario\Documents\2\test_websocket_final.py") {
    Write-Host "✅ test_websocket_final.py exists" -ForegroundColor Green
    $fixedItems++
} else {
    Write-Host "ℹ️  test_websocket_final.py will be created when test runs" -ForegroundColor Yellow
}
$totalChecks++

Write-Host ""

# Summary
Write-Host "═════════════════════════════════════════════════════════════════════════"
Write-Host ""

if ($allGood) {
    Write-Host "✅ ALL CHECKS PASSED!" -ForegroundColor Green
    Write-Host ""
    Write-Host "WebSocket fixes verified: $fixedItems/$totalChecks"
    Write-Host ""
    Write-Host "The following fixes are in place:"
    Write-Host "  ✅ Navigation listener registration"
    Write-Host "  ✅ Automatic listener re-registration on page navigation"
    Write-Host "  ✅ Frame received handler"
    Write-Host "  ✅ Socket.io message processor"
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "  1. Ensure Chrome is running: chrome.exe --remote-debugging-port=9222"
    Write-Host "  2. Open Quotex: https://qxbroker.com/es/demo-trade"
    Write-Host "  3. Run test: powershell -ExecutionPolicy Bypass -File FINAL_WEBSOCKET_TEST.ps1"
    Write-Host ""
} else {
    Write-Host "❌ SOME CHECKS FAILED!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Fixes applied: $fixedItems/$totalChecks"
    Write-Host ""
    Write-Host "Please check the failed items above."
    Write-Host "The fixes may not be properly applied."
    Write-Host ""
}

Write-Host "═════════════════════════════════════════════════════════════════════════"
Write-Host ""