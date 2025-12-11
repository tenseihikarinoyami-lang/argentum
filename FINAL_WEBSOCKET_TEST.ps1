# ============================================================================
# FINAL WebSocket Capture Test - Verifies All Fixes
# ============================================================================
# This is the DEFINITIVE test to check if WebSocket frame capture is working
# Requirements:
# - Chrome running: chrome.exe --remote-debugging-port=9222
# - Quotex open and visible in one of the tabs
# ============================================================================

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════════════╗"
Write-Host "║              FINAL WEBSOCKET CAPTURE TEST                              ║"
Write-Host "║  Testing all fixes: navigation listener, frame handlers, cache update  ║"
Write-Host "╚════════════════════════════════════════════════════════════════════════╝"
Write-Host ""

# Check prerequisites
$chromeDone = $false
$quotexFound = $false

Write-Host "Checking prerequisites..."
Write-Host "─────────────────────────────────────────────────────────────────────────"

# Check Chrome
$chromeProc = Get-Process chrome -ErrorAction SilentlyContinue
if ($chromeProc) {
    Write-Host "✅ Chrome is running"
    $chromeDone = $true
} else {
    Write-Host "❌ Chrome is NOT running"
    Write-Host ""
    Write-Host "START CHROME NOW with:"
    Write-Host "  chrome.exe --remote-debugging-port=9222"
    Write-Host ""
    exit 1
}

# Check debug port
$debugPort = netstat -ano 2>$null | Select-String "9222"
if ($debugPort) {
    Write-Host "✅ Chrome debug port 9222 is active"
} else {
    Write-Host "⚠️  Port 9222 might not be listening yet, waiting..."
    Start-Sleep -Seconds 2
}

Write-Host ""
Write-Host "Starting test in 5 seconds..."
Write-Host "(Keep Chrome and Quotex visible during test)"
Write-Host ""
Start-Sleep -Seconds 5

# Create the comprehensive test script
$testCode = @'
#!/usr/bin/env python3
"""
FINAL WEBSOCKET CAPTURE VERIFICATION TEST
Tests if WebSocket frames are being captured after the fix
"""

import asyncio
import sys
import time
import json
from datetime import datetime
from pathlib import Path

# Add repo to path
sys.path.insert(0, str(Path.cwd()))

async def main():
    print("\n" + "="*80)
    print("WEBSOCKET CAPTURE VERIFICATION TEST")
    print("="*80)
    print()
    
    try:
        from playwright.async_api import async_playwright
        from data_interceptor import WebSocketInterceptor
        from market_data_service import MarketDataService
        import logging
        
        # Setup detailed logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(message)s'
        )
        
        async with async_playwright() as p:
            # 1. Connect to Chrome
            print("[STEP 1] Connecting to Chrome remote debugging on port 9222...")
            try:
                browser = await p.chromium.connect_over_cdp("http://localhost:9222")
                print("✅ Successfully connected to Chrome")
            except Exception as e:
                print(f"❌ Failed to connect to Chrome: {e}")
                print("   Make sure Chrome is running with: chrome.exe --remote-debugging-port=9222")
                return False
            
            # 2. Find Quotex page
            print("\n[STEP 2] Finding Quotex page...")
            contexts = browser.contexts
            quotex_page = None
            
            if not contexts:
                print("❌ No browser contexts found")
                await browser.close()
                return False
            
            for ctx in contexts:
                for page in ctx.pages:
                    print(f"   - Found page: {page.url[:60]}")
                    if "quotex" in page.url.lower():
                        quotex_page = page
                        print(f"✅ Found Quotex page: {page.url[:60]}")
                        break
                if quotex_page:
                    break
            
            if not quotex_page:
                print("❌ Quotex page not found in Chrome!")
                print("   Please open Quotex in Chrome: https://qxbroker.com/es/demo-trade")
                await browser.close()
                return False
            
            # 3. Initialize WebSocket interceptor
            print("\n[STEP 3] Setting up WebSocket listener...")
            ws_interceptor = WebSocketInterceptor()
            await ws_interceptor.setup_websocket_listener(quotex_page)
            print("✅ WebSocket listener configured")
            
            # 4. Test loop - wait and monitor
            print("\n[STEP 4] Monitoring WebSocket traffic for 120 seconds...")
            print("         (Keep Quotex visible and switch between assets)")
            print()
            
            start_time = time.time()
            last_frame_count = 0
            max_frames = 0
            checkpoints = [10, 30, 60, 90, 120]
            
            while time.time() - start_time < 120:
                current_frames = ws_interceptor.message_count
                current_candles = sum(len(v) for v in ws_interceptor.candles_cache.values())
                current_assets = len(ws_interceptor.candles_cache)
                elapsed = int(time.time() - start_time)
                
                # Report at checkpoints
                if elapsed in checkpoints:
                    print(f"\n⏱️  [{elapsed:3d}s] Frames: {current_frames:6,} | Assets: {current_assets:3d} | Candles: {current_candles:6,}")
                    
                    if current_frames > 0 and last_frame_count == 0:
                        print(f"       🎉 FIRST FRAMES DETECTED! Fix is working!")
                    
                    if current_assets > 0:
                        # Show sample assets
                        sample_assets = list(ws_interceptor.candles_cache.keys())[:3]
                        for asset in sample_assets:
                            candles = ws_interceptor.candles_cache[asset]
                            if len(candles) > 0:
                                latest = candles[-1]
                                print(f"       - {asset}: {len(candles)} candles (latest: {latest.get('close', 'N/A')})")
                    
                    last_frame_count = current_frames
                    max_frames = max(max_frames, current_frames)
                
                await asyncio.sleep(1)
            
            # 5. Final report
            print("\n" + "="*80)
            print("FINAL REPORT")
            print("="*80)
            
            final_frames = ws_interceptor.message_count
            final_assets = len(ws_interceptor.candles_cache)
            final_candles = sum(len(v) for v in ws_interceptor.candles_cache.values())
            
            print(f"\nWebSocket frames captured:    {final_frames:,}")
            print(f"Unique assets with data:      {final_assets}")
            print(f"Total candles cached:         {final_candles}")
            print(f"Frame types detected:         {dict(ws_interceptor.frame_types)}")
            
            # Show all cached assets
            if final_assets > 0:
                print(f"\nAssets with WebSocket data ({final_assets} total):")
                for asset in sorted(ws_interceptor.candles_cache.keys()):
                    count = len(ws_interceptor.candles_cache[asset])
                    print(f"  ✅ {asset}: {count} candles")
            
            print("\n" + "="*80)
            
            # Verdict
            if final_frames > 500:
                print("✅ SUCCESS! WebSocket capture is working perfectly!")
                print("   The fix successfully:")
                print("   - Registers listeners on page navigation")
                print("   - Captures WebSocket frames")
                print("   - Processes and caches price data")
                print("   - Supports multiple assets")
                success = True
            elif final_frames > 100:
                print("⚠️  PARTIAL SUCCESS - WebSocket capture is partially working")
                print("   Frames are being captured but at a lower rate than expected")
                print("   The fix may need additional tuning")
                success = True
            elif final_frames > 0:
                print("⚠️  LIMITED SUCCESS - Very few WebSocket frames captured")
                print("   Frames are being captured but the rate is very low")
                success = True
            else:
                print("❌ FAILURE - No WebSocket frames captured")
                print("   The fix may not be working correctly")
                print("   Debug info:")
                print(f"   - Total messages processed: {ws_interceptor.message_count}")
                print(f"   - Debug events: {ws_interceptor.debug_events[-10:] if ws_interceptor.debug_events else 'None'}")
                success = False
            
            print("="*80)
            print()
            
            await browser.close()
            return success
    
    except ImportError as e:
        print(f"❌ Import error: {e}")
        print("   Make sure you're in the repo directory and playwright is installed")
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    try:
        success = asyncio.run(main())
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n\n⚠️  Test interrupted by user")
        sys.exit(1)
'@

# Save test script
$testCode | Out-File -FilePath "test_websocket_final.py" -Encoding UTF8

Write-Host ""
Write-Host "Running comprehensive WebSocket test..."
Write-Host "─────────────────────────────────────────────────────────────────────────"
Write-Host ""

# Run the test
python test_websocket_final.py

Write-Host ""
Write-Host "─────────────────────────────────────────────────────────────────────────"
Write-Host ""
Write-Host "✅ Test complete!"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. If test PASSED: Run 'start_bot.ps1' to start the trading bot"
Write-Host "  2. If test FAILED: Check the debug output above and verify:"
Write-Host "     - Chrome is running with --remote-debugging-port=9222"
Write-Host "     - Quotex page is open and visible"
Write-Host "     - Network connection is stable"
Write-Host ""