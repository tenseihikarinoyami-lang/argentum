# BOT STATUS CHECK

Write-Host ""
Write-Host "========================================================================"
Write-Host "                    BOT STATUS QUICK CHECK                             "
Write-Host "========================================================================"
Write-Host ""

# Check 1: Chrome
Write-Host "1. Checking Chrome..." -ForegroundColor Cyan
try {
    $chrome = Get-NetTCPConnection -LocalPort 9222 -ErrorAction SilentlyContinue
    if ($chrome) {
        Write-Host "   OK: Chrome Remote Debug ACTIVE (Port 9222)" -ForegroundColor Green
    } else {
        Write-Host "   WARN: Chrome Remote Debug NOT DETECTED" -ForegroundColor Yellow
        Write-Host "   Hint: Start with: chrome.exe --remote-debugging-port=9222" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "   WARN: Could not check port 9222" -ForegroundColor Yellow
}

# Check 2: Python
Write-Host ""
Write-Host "2. Checking Python..." -ForegroundColor Cyan
$pythonVersion = python --version 2>&1
Write-Host "   OK: $pythonVersion" -ForegroundColor Green

# Check 3: Dependencies
Write-Host ""
Write-Host "3. Checking Dependencies..." -ForegroundColor Cyan
$deps = @("playwright", "numpy", "requests", "psutil")
$allOk = $true
foreach ($dep in $deps) {
    $result = python -c "import $dep" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   OK: $dep" -ForegroundColor Green
    } else {
        Write-Host "   FAIL: $dep (Missing)" -ForegroundColor Red
        $allOk = $false
    }
}

# Check 4: Config
Write-Host ""
Write-Host "4. Checking Configuration..." -ForegroundColor Cyan
if (Test-Path "config.json") {
    Write-Host "   OK: config.json exists" -ForegroundColor Green
    $config = Get-Content config.json | ConvertFrom-Json
    Write-Host "      Assets: $($config.assets.Count)" -ForegroundColor Green
} else {
    Write-Host "   FAIL: config.json NOT FOUND" -ForegroundColor Red
}

# Check 5: Bot files
Write-Host ""
Write-Host "5. Checking Bot Files..." -ForegroundColor Cyan
$files = @("run_bot.py", "signal_generator.py", "data_interceptor.py", "indicators.py")
foreach ($file in $files) {
    if (Test-Path $file) {
        Write-Host "   OK: $file" -ForegroundColor Green
    } else {
        Write-Host "   FAIL: $file (Missing)" -ForegroundColor Red
    }
}

# Final status
Write-Host ""
Write-Host "========================================================================"
Write-Host ""

if ($allOk) {
    Write-Host "STATUS: READY TO RUN" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Start Chrome with remote debug (if not already running):" -ForegroundColor Yellow
    Write-Host "   chrome.exe --remote-debugging-port=9222" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Start the bot:" -ForegroundColor Yellow
    Write-Host "   python run_bot.py" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. In another terminal, monitor signals:" -ForegroundColor Yellow
    Write-Host "   Get-Content bot_output.log -Wait" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host "STATUS: NEEDS ATTENTION" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Install missing dependencies:" -ForegroundColor Yellow
    Write-Host "   pip install playwright numpy requests psutil" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "========================================================================"
Write-Host ""