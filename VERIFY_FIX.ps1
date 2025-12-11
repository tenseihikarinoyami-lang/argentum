# ✅ VERIFICATION SCRIPT - Confirma que los fixes están en lugar
# Este script verifica que las correcciones fueron aplicadas correctamente

Write-Host "=" -ForegroundColor Cyan -NoNewline; Write-Host "=" -ForegroundColor Cyan -NoNewline; Write-Host "=" -ForegroundColor Cyan
Write-Host "🔍 VERIFICACIÓN DE FIXES - Signal Generation" -ForegroundColor Cyan
Write-Host "=" -ForegroundColor Cyan -NoNewline; Write-Host "=" -ForegroundColor Cyan -NoNewline; Write-Host "=" -ForegroundColor Cyan
Write-Host ""

# Test 1: Verificar que broker_capture.py tiene la nueva lógica de obtención de precios
Write-Host "[1/4] Verificando broker_capture.py..." -ForegroundColor Yellow
$broker_file = Get-Content "c:\Users\usuario\Documents\2\broker_capture.py" | Select-String "PRIORITY 1: Get from WebSocket"
if ($broker_file) {
    Write-Host "      ✅ Fix #1 encontrado: Multi-priority price fetching" -ForegroundColor Green
} else {
    Write-Host "      ❌ Fix #1 NO encontrado" -ForegroundColor Red
}

# Test 2: Verificar close_and_switch_asset
Write-Host "[2/4] Verificando close_and_switch_asset()..." -ForegroundColor Yellow
$close_asset = Get-Content "c:\Users\usuario\Documents\2\broker_capture.py" | Select-String "def close_and_switch_asset"
if ($close_asset) {
    Write-Host "      ✅ Fix #2 encontrado: Asset closing function" -ForegroundColor Green
} else {
    Write-Host "      ❌ Fix #2 NO encontrado" -ForegroundColor Red
}

# Test 3: Verificar que main.py llama close_and_switch_asset
Write-Host "[3/4] Verificando integración en main.py..." -ForegroundColor Yellow
$main_close = Get-Content "c:\Users\usuario\Documents\2\main.py" | Select-String "close_and_switch_asset"
if ($main_close) {
    Write-Host "      ✅ Fix #3 encontrado: Close asset integration" -ForegroundColor Green
} else {
    Write-Host "      ❌ Fix #3 NO encontrado" -ForegroundColor Red
}

# Test 4: Verificar selectors CSS múltiples
Write-Host "[4/4] Verificando CSS selectors múltiples..." -ForegroundColor Yellow
$selectors = Get-Content "c:\Users\usuario\Documents\2\broker_capture.py" | Select-String "price_selectors = \["
if ($selectors) {
    Write-Host "      ✅ Fix #4 encontrado: Multiple CSS selectors" -ForegroundColor Green
} else {
    Write-Host "      ❌ Fix #4 NO encontrado" -ForegroundColor Red
}

Write-Host ""
Write-Host "=" -ForegroundColor Cyan -NoNewline; Write-Host "=" -ForegroundColor Cyan -NoNewline; Write-Host "=" -ForegroundColor Cyan
Write-Host "✅ VERIFICACIÓN COMPLETADA" -ForegroundColor Green
Write-Host "=" -ForegroundColor Cyan -NoNewline; Write-Host "=" -ForegroundColor Cyan -NoNewline; Write-Host "=" -ForegroundColor Cyan
Write-Host ""
Write-Host "🚀 PRÓXIMOS PASOS:" -ForegroundColor Yellow
Write-Host "   1. chrome.exe --remote-debugging-port=9222" -ForegroundColor White
Write-Host "   2. Navega a https://qxbroker.com/es/demo-trade" -ForegroundColor White
Write-Host "   3. python run_bot.py" -ForegroundColor White
Write-Host "   4. Espera 2-5 minutos" -ForegroundColor White
Write-Host "   5. Deberías ver: [REAL-TIME] Signal detected..." -ForegroundColor White
Write-Host ""