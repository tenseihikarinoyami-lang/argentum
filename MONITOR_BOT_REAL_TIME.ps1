#!/usr/bin/env powershell
<#
📊 MONITOR EN TIEMPO REAL - Muestra eventos clave mientras el bot se ejecuta
#>

param(
    [switch]$Prices,      # Mostrar solo precios
    [switch]$Signals,     # Mostrar solo señales
    [switch]$Indicators,  # Mostrar solo indicadores
    [switch]$Errors,      # Mostrar solo errores
    [switch]$WebSocket,   # Mostrar solo WebSocket
    [int]$RefreshMs = 500 # Frecuencia de refresco (ms)
)

Clear-Host

$green = @{ForegroundColor = "Green"}
$red = @{ForegroundColor = "Red"}
$yellow = @{ForegroundColor = "Yellow"}
$cyan = @{ForegroundColor = "Cyan"}

Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" @green
Write-Host "║                     📊 MONITOR BOT EN TIEMPO REAL                             ║" @green
Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" @green

Write-Host ""
Write-Host "Presiona CTRL+C para salir" @yellow
Write-Host ""

$lastLineCount = 0
$eventCount = @{
    "prices"      = 0
    "signals"     = 0
    "indicators"  = 0
    "errors"      = 0
    "websocket"   = 0
}

$displayFilter = "ALL"
if ($Prices)     { $displayFilter = "PRICES" }
if ($Signals)    { $displayFilter = "SIGNALS" }
if ($Indicators) { $displayFilter = "INDICATORS" }
if ($Errors)     { $displayFilter = "ERRORS" }
if ($WebSocket)  { $displayFilter = "WEBSOCKET" }

while ($true) {
    if (-not (Test-Path "bot_output.log")) {
        Write-Host "[⏳] Esperando bot_output.log..." -ForegroundColor Yellow
        Start-Sleep -Milliseconds $RefreshMs
        continue
    }
    
    $logs = Get-Content "bot_output.log" -ErrorAction SilentlyContinue
    $currentLineCount = @($logs).Count
    
    if ($currentLineCount -gt $lastLineCount) {
        # Nuevas líneas disponibles
        $newLines = @($logs)[($lastLineCount)..($currentLineCount-1)]
        $lastLineCount = $currentLineCount
        
        foreach ($line in $newLines) {
            # Categorizar línea
            $showLine = $false
            $color = @{}
            
            if ($line -match "ERROR") {
                $eventCount.errors++
                if ($displayFilter -in "ALL", "ERRORS") {
                    $showLine = $true
                    $color = @{ForegroundColor = "Red"}
                }
            }
            elseif ($line -match "\[PRICE\]|✅ \[PRICE\]") {
                $eventCount.prices++
                if ($displayFilter -in "ALL", "PRICES") {
                    $showLine = $true
                    $color = @{ForegroundColor = "Cyan"}
                }
            }
            elseif ($line -match "Signal detected|signal.*generated|\[SIGNAL\]") {
                $eventCount.signals++
                if ($displayFilter -in "ALL", "SIGNALS") {
                    $showLine = $true
                    $color = @{ForegroundColor = "Green"; BackgroundColor = "DarkGray"}
                }
            }
            elseif ($line -match "RSI|MACD|Bollinger|ADX|Stochastic|EMA|SMA") {
                $eventCount.indicators++
                if ($displayFilter -in "ALL", "INDICATORS") {
                    $showLine = $true
                    $color = @{ForegroundColor = "Magenta"}
                }
            }
            elseif ($line -match "\[WS-|\[FRAME|WebSocket|socket.*frame") {
                $eventCount.websocket++
                if ($displayFilter -in "ALL", "WEBSOCKET") {
                    $showLine = $true
                    $color = @{ForegroundColor = "Blue"}
                }
            }
            elseif ($displayFilter -eq "ALL" -and ($line -match "✅|⏳|🔍")) {
                $showLine = $true
                if ($line -match "✅") {
                    $color = @{ForegroundColor = "Green"}
                } elseif ($line -match "⏳") {
                    $color = @{ForegroundColor = "Yellow"}
                } else {
                    $color = @{ForegroundColor = "Cyan"}
                }
            }
            
            if ($showLine) {
                # Limitar a 200 caracteres y mostrar
                if ($line.Length -gt 200) {
                    $line = $line.Substring(0, 197) + "..."
                }
                Write-Host $line @color
            }
        }
    }
    
    # Actualizar header cada 10 segundos
    if ([Math]::Floor($lastLineCount / 20) % 2 -eq 0) {
        $statsLine = "📈 Eventos: Precios=$($eventCount.prices) | Señales=$($eventCount.signals) | Indicadores=$($eventCount.indicators) | WebSocket=$($eventCount.websocket) | Errores=$($eventCount.errors)"
        Write-Host "`r$statsLine" @cyan -NoNewline
    }
    
    Start-Sleep -Milliseconds $RefreshMs
}