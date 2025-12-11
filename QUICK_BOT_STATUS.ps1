# 🤖 QUICK BOT STATUS CHECK
# ==========================

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════════════════╗"
Write-Host "║                      🤖 BOT STATUS QUICK CHECK                            ║"
Write-Host "╚════════════════════════════════════════════════════════════════════════════╝"
Write-Host ""

# Check 1: Chrome
Write-Host "1️⃣  Checking Chrome..." -ForegroundColor Cyan
try {
    $chrome = Get-NetTCPConnection -LocalPort 9222 -ErrorAction SilentlyContinue
    if ($chrome) {
        Write-Host "   ✅ Chrome Remote Debug ACTIVE (Port 9222)" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Chrome Remote Debug NOT DETECTED" -ForegroundColor Yellow
        Write-Host "   💡 Start with: chrome.exe --remote-debugging-port=9222" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "   ⚠️  Could not check port 9222" -ForegroundColor Yellow
}

# Check 2: Python
Write-Host ""
Write-Host "2️⃣  Checking Python..." -ForegroundColor Cyan
$pythonVersion = python --version 2>&1
Write-Host "   ✅ $pythonVersion" -ForegroundColor Green

# Check 3: Dependencies
Write-Host ""
Write-Host "3️⃣  Checking Dependencies..." -ForegroundColor Cyan
$deps = @("playwright", "numpy", "requests", "psutil")
$allOk = $true
foreach ($dep in $deps) {
    $result = python -c "import $dep" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ $dep" -ForegroundColor Green
    } else {
        Write-Host "   ❌ $dep (Missing)" -ForegroundColor Red
        $allOk = $false
    }
}

# Check 4: Config
Write-Host ""
Write-Host "4️⃣  Checking Configuration..." -ForegroundColor Cyan
if (Test-Path "config.json") {
    Write-Host "   ✅ config.json exists" -ForegroundColor Green
    $config = Get-Content config.json | ConvertFrom-Json
    Write-Host "      • Assets: $($config.assets.Count)" -ForegroundColor Green
    Write-Host "      • Broker: $($config.broker)" -ForegroundColor Green
} else {
    Write-Host "   ❌ config.json NOT FOUND" -ForegroundColor Red
}

# Check 5: Bot files
Write-Host ""
Write-Host "5️⃣  Checking Bot Files..." -ForegroundColor Cyan
$files = @("run_bot.py", "signal_generator.py", "data_interceptor.py", "indicators.py")
foreach ($file in $files) {
    if (Test-Path $file) {
        Write-Host "   ✅ $file" -ForegroundColor Green
    } else {
        Write-Host "   ❌ $file (Missing)" -ForegroundColor Red
    }
}

# Check 6: System resources
Write-Host ""
Write-Host "6️⃣  Checking System Resources..." -ForegroundColor Cyan
$cpu = (Get-WmiObject win32_processor).LoadPercentage
$memory = (Get-WmiObject win32_operatingsystem).FreePhysicalMemory / 1024 / 1024
Write-Host "   • CPU: $cpu%" -ForegroundColor Green
Write-Host "   • Free RAM: $([Math]::Round($memory))MB" -ForegroundColor Green

# Final status
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════════════════"
Write-Host ""

if ($allOk) {
    Write-Host "✅ BOT STATUS: READY TO RUN" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Make sure Chrome is running:" -ForegroundColor Yellow
    Write-Host "     chrome.exe --remote-debugging-port=9222" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2. Start bot:" -ForegroundColor Yellow
    Write-Host "     python run_bot.py" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  3. Monitor signals:" -ForegroundColor Yellow
    Write-Host "     Get-Content bot_output.log -Wait" -ForegroundColor Gray
} else {
    Write-Host "⚠️  BOT STATUS: NEEDS ATTENTION" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Install missing dependencies:" -ForegroundColor Yellow
    Write-Host "  pip install playwright numpy requests psutil" -ForegroundColor Gray
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════════════════"
Write-Host ""