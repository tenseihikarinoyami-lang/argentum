Write-Host "TEST DE GENERACION DE SENALES" -ForegroundColor Cyan
Write-Host ""

# Limpiar log
if (Test-Path "bot_output.log") {
    Remove-Item "bot_output.log" -Force
}

Write-Host "Ejecutando bot durante 120 segundos..." -ForegroundColor Yellow
Write-Host ""

# Ejecutar bot
$process = Start-Process -FilePath python.exe -ArgumentList "run_bot.py" -RedirectStandardOutput "bot_output.log" -NoNewWindow -PassThru

# Esperar
Start-Sleep -Seconds 120

# Detener
Stop-Process -InputObject $process -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "ANALISIS DE RESULTADOS:" -ForegroundColor Cyan
Write-Host ""

# Leer log
$log = Get-Content "bot_output.log" -Raw

# Contar
$cycles = @($log | Select-String "\[CYCLE" -AllMatches).Matches.Count
$analysis = @($log | Select-String "\[ANALYSIS\]" -AllMatches).Matches.Count
$callbacks = @($log | Select-String "\[CALLBACK\]" -AllMatches).Matches.Count
$signals = @($log | Select-String "Signal detected" -AllMatches).Matches.Count

Write-Host "Ciclos: $cycles"
Write-Host "Analisis: $analysis"
Write-Host "Callbacks: $callbacks"
Write-Host "SENALES: $signals" -ForegroundColor Cyan

if ($signals -gt 0) {
    Write-Host ""
    Write-Host "EXITO! Se generaron senales" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "SIN SENALES. Ultimas lineas:" -ForegroundColor Red
    Get-Content "bot_output.log" | Select-String "ERROR" -Last 10
}