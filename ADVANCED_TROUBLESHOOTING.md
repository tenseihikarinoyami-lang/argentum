# 🔧 GUÍA AVANZADA DE TROUBLESHOOTING

## Diagnóstico Completo del Sistema

Este documento proporciona soluciones para problemas complejos y raros.

---

## 1️⃣ PROBLEMAS DE CONEXIÓN CDP

### Problema: "Failed to connect over CDP"

**Root Cause Analysis**:
```
Error: Target page, context or browser has been closed
Port 9222 unreachable
WSEndpoint connection timeout
```

**Solución Paso a Paso**:

```powershell
# Paso 1: Limpiar procesos Chrome existentes
Get-Process chrome -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

# Paso 2: Limpiar carpetas de sesión
Remove-Item "C:\Users\usuario\AppData\Local\Google\Chrome\User Data\Default" -Recurse -Force
Remove-Item "C:\Users\usuario\AppData\Local\Google\Chrome\User Data\First Run" -Recurse -Force

# Paso 3: Iniciar Chrome con opciones de debugging limpias
$chrome = "C:\Program Files\Google\Chrome\Application\chrome.exe"
& $chrome `
  --remote-debugging-port=9222 `
  --user-data-dir="C:\temp\chrome_debug" `
  --disable-extensions `
  --no-first-run `
  --disable-sync `
  --disable-translate `
  --disable-default-apps `
  https://quotex.com
```

**Verificación**:
```powershell
# Confirmar puerto abierto
netstat -ano | findstr :9222
# Debe mostrar: TCP    0.0.0.0:9222    LISTENING

# Conectar manualmente con curl
curl -s http://localhost:9222/json | ConvertFrom-Json
# Debe devolver lista de páginas abiertas
```

---

## 2️⃣ PROBLEMAS DE DATOS

### Problema: "Constant Simulated Data Warnings"

**Diagnóstico**:
```powershell
# Ver qué método está fallando
Get-Content logs/trading_bot_*.log | Select-String "PLAN"

# Típica salida problemática:
# [DATOS] PLAN B: Intentando getBars...
# [DATOS] PLAN C: Intentando JS Objects...
# [DATOS] PLAN D: Escaneando memoria...
# [ALERTA] ¡¡¡USANDO DATOS SIMULADOS!
```

**Causas Posibles**:
1. Chart no está cargado en el navegador
2. Broker cambió estructura de API
3. Datos bloqueados por CORS
4. Cookie/session expirada

**Soluciones**:

```powershell
# Opción 1: Cargar manualmente chart en Chrome
# 1. Abrir https://quotex.com en Chrome
# 2. Loguearse
# 3. Navegar a EUR/USD
# 4. Dejar el gráfico abierto
# 5. Ejecutar bot

# Opción 2: Aumentar timeouts
# Editar broker_capture.py línea ~288:
# await iframe_locator.wait_for(state="attached", timeout=5000)  # 5s en lugar de 1s

# Opción 3: Usar External API como fallback
# Verificar que Alpha Vantage está disponible:
$url = "https://www.alphavantage.co/query?function=FX_INTRADAY&from_symbol=EUR&to_symbol=USD&interval=1min&apikey=demo"
Invoke-RestMethod -Uri $url
```

### Problema: "Empty DataFrame from Market Data Service"

**Verificación**:
```python
# Ejecutar directamente en Python
from market_data_service import MarketDataService
mds = MarketDataService()

# Chequear inicialización
print(mds.interceptor.candles_cache)
print(mds.ws_listener.data_buffer)

# Si está vacío, investigar:
# 1. ¿Se llamó a initialize(page)?
# 2. ¿La página está conectada?
# 3. ¿Hay tráfico de red en el broker?
```

**Solución**:
```python
# Forzar reinicialización
mds.cache_ttl = 1  # TTL bajo para testing
mds.interceptor.candles_cache.clear()
mds.ws_listener.data_buffer.clear()

# Esperar un ciclo completo (45 segundos) para recolectar datos
```

---

## 3️⃣ PROBLEMAS DE RENDIMIENTO

### Problema: "Bot runs slowly / High CPU usage"

**Diagnóstico**:
```powershell
# Monitoreo en vivo
$timer = 0
while ($true) {
    $cpu = (Get-Process python | Measure-Object -Property CPU -Sum).Sum
    $mem = (Get-Process python | Measure-Object -Property WS -Sum).Sum
    Write-Host "CPU: $($cpu)% | RAM: $([math]::Round($mem/1MB,2))MB"
    Start-Sleep -Seconds 1
}
```

**Causas Comunes**:
1. Demasiados activos en config.json
2. Timeframes muy bajos (< 1 minuto)
3. ML reentrenando cada ciclo
4. Memory scan ejecutándose constantemente

**Soluciones**:

```json
// config.json optimizado
{
  "assets": ["EUR/USD", "GBP/USD", "USD/JPY"],  // Reducir a 3-5
  "timeframes": [5],  // Usar solo 1 timeframe
  "cycle_sleep_seconds": 60,  // Aumentar espera
  "ml_settings": {
    "retrain_every_n_signals": 200  // Menos reentrenamiento
  }
}
```

---

## 4️⃣ PROBLEMAS DE NOTIFICACIONES

### Problema: "Telegram notifications not working"

**Verificación**:
```powershell
# Verificar credenciales en .env
Get-Content .env | findstr "TELEGRAM"

# Validar token manualmente
$token = "YOUR_TOKEN_HERE"
$chatId = "YOUR_CHAT_ID_HERE"
$url = "https://api.telegram.org/bot$token/sendMessage"
$body = @{chat_id=$chatId; text="Test"}

Invoke-RestMethod -Uri $url -Method Post -Body $body
```

**Problema**: Token inválido

```powershell
# Obtener nuevo token
# 1. Abrir Telegram
# 2. Contactar @BotFather
# 3. Crear nuevo bot: /newbot
# 4. Copiar token
# 5. Actualizar .env

# Verificar Chat ID
# 1. Contactar @userinfobot
# 2. Ver ID mostrado
# 3. Actualizar .env
```

**Problema**: Firewall bloqueando salida

```powershell
# Probar conectividad
$null = Invoke-WebRequest -Uri "https://api.telegram.org/bot1/test" -ErrorAction SilentlyContinue
if ($?) {
    Write-Host "Telegram accesible"
} else {
    Write-Host "Firewall bloqueando Telegram"
    # Abrir puerto 443 en firewall Windows
}
```

---

## 5️⃣ PROBLEMAS DE BASE DE DATOS

### Problema: "Database locked or corrupted"

**Síntomas**:
```
sqlite3.OperationalError: database is locked
sqlite3.DatabaseError: file is not a database
```

**Solución**:

```powershell
# Hacer backup
Copy-Item "trading_signals.db" "trading_signals.db.backup"

# Verificar integridad
sqlite3 trading_signals.db "PRAGMA integrity_check;"

# Si dice "ok", base de datos está bien
# Si dice "error", eliminar y reconstruir

# Eliminar y reconstruir
Remove-Item trading_signals.db
# Bot la recreará automáticamente en siguiente ciclo
```

---

## 6️⃣ PROBLEMAS DE ML MODEL

### Problema: "ML model fails to train"

**Diagnóstico**:
```powershell
# Verificar logs
Get-Content logs/trading_bot_*.log | Select-String "ML"

# Buscar específicamente errores
Get-Content logs/trading_bot_*.log | Select-String "ERROR.*ML"
```

**Soluciones**:

```python
# En Python REPL
from ml_model import MLTradingModel
from database import TradingDatabase

db = TradingDatabase()
ml = MLTradingModel({})

# Verificar datos de entrenamiento
stats = db.get_statistics()
print(f"Señales totales: {stats['total']}")  # Debe ser >= 50 para entrenamiento

# Entrenar manualmente si es necesario
success = ml.train(db, initial_training=True)
print(f"Entrenamiento: {'Exitoso' if success else 'Fallido'}")
```

### Problema: "ML predictions too similar / not varied"

**Causa**: Modelo no bien entrenado

**Solución**:
```json
{
  "ml_settings": {
    "training_window": 1000,  // Aumentar ventana
    "learning_rate": 0.1,     // Aumentar tasa de aprendizaje
    "min_confidence": 0.5     // Bajar confianza inicial
  }
}
```

---

## 7️⃣ PROBLEMAS DE ANTI-BOT DETECTION

### Problema: "Broker is blocking/slowing down"

**Señales**:
```
- Respuestas lentas (>10 segundos)
- Conexión rechazada ocasionalmente
- Datos incompletos o parciales
```

**Verificación Anti-Bot**:
```powershell
# Ver qué método está siendo usado
Get-Content logs/trading_bot_*.log | Select-String "STEALTH\|WebSocket\|Plan"

# Todos deben ser:
# ✅ [STEALTH] Datos interceptados para EUR/USD (0 queries JS)
# ✅ [DATOS] Usando datos de WebSocket para GBP/USD
# ❌ ¡¡¡USANDO DATOS SIMULADOS!!! (indica problema)
```

**Si broker está bloqueando**:

```python
# En broker_capture.py, aumentar delays
time.sleep(0.5)  # Entre requests
asyncio.sleep(1)  # Entre operaciones async

# Cambiar User-Agent
# En _start_async(), antes de conectar:
self.browser = await self.playwright.chromium.connect_over_cdp(
    'http://localhost:9222',
    extra_http_headers={
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0'
    }
)
```

---

## 8️⃣ RECUPERACIÓN DE EMERGENCIA

### Resetear Sistema Completo

```powershell
# 1. Detener bot (Ctrl+C en terminal)

# 2. Limpiar todo
Remove-Item "trading_signals.db"
Remove-Item "logs\*"
Get-Process chrome -ErrorAction SilentlyContinue | Stop-Process -Force

# 3. Limpiar cache Python
Remove-Item "__pycache__" -Recurse
Remove-Item ".pytest_cache" -Recurse
Remove-Item ".venv" -Recurse

# 4. Reinstalar ambiente
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt --force-reinstall

# 5. Reiniciar bot
python main.py
```

### Modo Seguro

```powershell
# Ejecutar con configuración mínima
$env:SAFE_MODE = "true"

# config.json
{
  "assets": ["EUR/USD"],      # Solo 1 activo
  "timeframes": [5],          # Solo 1 timeframe
  "cycle_sleep_seconds": 120  # Ciclos largos
}

# Ejecutar
python main.py
```

---

## 9️⃣ VERIFICACIÓN POST-FIX

Después de cualquier fix, ejecutar:

```powershell
# 1. Verificación del sistema
python verify_antibot_system.py

# 2. Test de conectividad
python -c "
from broker_capture import BrokerCapture
bc = BrokerCapture()
print('✅ BrokerCapture importable')
"

# 3. Test de base de datos
python -c "
from database import TradingDatabase
db = TradingDatabase()
stats = db.get_statistics()
print(f'✅ DB funcional: {stats}')
"

# 4. Test de ML
python -c "
from ml_model import MLTradingModel
ml = MLTradingModel({})
print(f'✅ ML Model funcional: trained={ml.is_trained}')
"
```

---

## 🔟 LOGS PARA DIAGNÓSTICO

### Estructura de Logs

```
logs/
├── trading_bot_20251020.log    # Log del día
├── trading_bot_20251021.log    # Siguiente día
└── debug_dump.txt              # Volcado de debug manual
```

### Análisis de Logs

```powershell
# Ver todos los errores
Select-String "ERROR" logs/trading_bot_*.log | Group-Object Line | Select-Object -First 10

# Ver patrón de datos
Select-String "DATOS\|STEALTH\|Plan" logs/trading_bot_*.log | Select-Object -Last 50

# Búsqueda de patrón específico
Select-String "\[STATS\]" logs/trading_bot_*.log | Select-Object -Last 1

# Exportar para análisis externo
Get-Content logs/trading_bot_*.log | Out-File "full_log_analysis.txt"
```

---

## 📋 CHECKLIST DE TROUBLESHOOTING

```
Antes de reportar un problema, verificar:

[ ] Python 3.8+ instalado (python --version)
[ ] Chrome con debugging habilitado (chrome --remote-debugging-port=9222)
[ ] Virtual environment activado (.venv\Scripts\Activate.ps1)
[ ] Dependencias instaladas (pip install -r requirements.txt)
[ ] config.json válido (sin errores de JSON)
[ ] .env configurado con credenciales
[ ] Puerto 5000 disponible (netstat -ano | findstr :5000)
[ ] Puerto 9222 abierto (netstat -ano | findstr :9222)
[ ] Permisos de archivo (carpeta logs/ escribible)
[ ] Espacio en disco (> 500MB libre)
[ ] Conexión a internet estable
[ ] Verificación del sistema pasada (python verify_antibot_system.py)
```

---

**¡Con esta guía deberías poder resolver prácticamente cualquier problema! 🚀**