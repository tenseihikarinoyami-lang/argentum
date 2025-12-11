# ============================================================================
# Chrome Ready Check - Verifica que Chrome esté disponible
# ============================================================================
# Uso: powershell -ExecutionPolicy Bypass -File check_chrome_ready.ps1
# ============================================================================

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "🔍 Verificando estado de Chrome" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""

# Verificar si Chrome está corriendo
$chromeRunning = Get-Process chrome -ErrorAction SilentlyContinue
if ($chromeRunning) {
    Write-Host "✅ Chrome está corriendo" -ForegroundColor Green
} else {
    Write-Host "❌ Chrome NO está corriendo" -ForegroundColor Red
    Write-Host ""
    Write-Host "Para iniciar Chrome en modo debugging:" -ForegroundColor Yellow
    Write-Host "  chrome.exe --remote-debugging-port=9222" -ForegroundColor White
    Write-Host ""
    exit 1
}

# Verificar si puerto 9222 está disponible
Write-Host ""
Write-Host "Verificando puerto 9222..." -ForegroundColor Gray

$port9222 = $null
try {
    $port9222 = Get-NetTCPConnection -LocalPort 9222 -ErrorAction SilentlyContinue
    if ($port9222) {
        Write-Host "✅ Puerto 9222 está DISPONIBLE (Chrome en modo debugging)" -ForegroundColor Green
    }
} catch { }

if (-not $port9222) {
    Write-Host "❌ Puerto 9222 NO está disponible" -ForegroundColor Red
    Write-Host ""
    Write-Host "Cierra Chrome y reinicia con debugging:" -ForegroundColor Yellow
    Write-Host "  1. Presiona Ctrl+C en este script" -ForegroundColor White
    Write-Host "  2. Ejecuta: powershell -ExecutionPolicy Bypass -File run_bot_simple.ps1" -ForegroundColor White
    Write-Host ""
    exit 1
}

# Verificar conectividad a Chrome
Write-Host ""
Write-Host "Verificando conectividad a Chrome..." -ForegroundColor Gray

try {
    $response = Invoke-WebRequest -Uri "http://localhost:9222/json" -ErrorAction Stop
    Write-Host "✅ Chrome responde en http://localhost:9222" -ForegroundColor Green
    
    # Contar pestañas
    $json = $response.Content | ConvertFrom-Json
    Write-Host "   Pestañas abiertas: $($json.Count)" -ForegroundColor Gray
    
    # Verificar si está en Quotex
    $quotexTab = $json | Where-Object { $_.url -like "*quotex*" }
    if ($quotexTab) {
        Write-Host "   ✅ Quotex abierto en una pestaña" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Quotex NO está abierto" -ForegroundColor Yellow
        Write-Host "      Abre manualmente: https://quotex.com" -ForegroundColor Gray
    }
} catch {
    Write-Host "❌ Chrome no responde en http://localhost:9222" -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Green
Write-Host "✅ Chrome ESTÁ LISTO" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Ahora puedes iniciar el bot:" -ForegroundColor Cyan
Write-Host "  python main.py" -ForegroundColor White
Write-Host ""