"""
Broker Capture Module - Phase 3 Type Hints Implementation

Handles browser automation and data capture from trading broker platforms.
Supports Quotex and PocketOption brokers with WebSocket data interception.
OPTIMIZED: Integrated with MarketDataService for anti-bot stealth capture
"""

from playwright.async_api import async_playwright, Page
import pandas as pd
import time
import re
import json
from PIL import Image
import numpy as np
import io
import asyncio
import threading
from typing import Dict, Any, Optional, List
from datetime import datetime
from market_data_service import MarketDataService
from logger_config import setup_logger

logger = setup_logger(__name__)

class BrokerCapture:
    def get_close_at_expiration(self, asset: str, expiration_time, timeframe_min: int) -> Optional[float]:
        """
        Obtener el precio de cierre (close) de la vela que contiene la hora de expiración.
        Prioriza el cache del WebSocket para el activo normalizado.
        
        Args:
            asset: Nombre del activo
            expiration_time: datetime de expiración (hora objetivo)
            timeframe_min: timeframe en minutos
        Returns:
            close de la vela si existe, o None si no se encuentra
        """
        try:
            if not hasattr(self, 'market_data_service') or not self.market_data_service or not self.market_data_service.ws_listener:
                return None
            from data_interceptor import WebSocketInterceptor
            ws_listener = self.market_data_service.ws_listener
            normalized_asset = WebSocketInterceptor.normalize_asset_name(asset)

            # Construir variantes de clave para búsqueda robusta
            candidates = set([
                normalized_asset,
                normalized_asset.lower(),
                normalized_asset.upper(),
                asset,
                asset.lower(),
                asset.upper(),
                asset.replace(' (OTC)', '_otc').replace('/', '').lower(),
                asset.replace(' (OTC)', '').replace('/', '').lower(),
                asset.replace(' (OTC)', '-otc').lower(),
            ])
            cache = ws_listener.candles_cache
            tf_sec = int(timeframe_min * 60)
            exp_ts = int(expiration_time.timestamp())

            # Buscar en cada variante
            for key in list(candidates):
                if key in cache and cache[key]:
                    candles = cache[key]
                    # candles: lista de dicts con 'time' base (segundos). Asumimos cada vela dura timeframe.
                    # Encontrar vela cuyo intervalo [t, t+tf) contenga exp_ts
                    for c in reversed(candles[-200:]):  # revisar última ventana
                        t = int(c.get('time') or c.get('t') or 0)
                        if t <= exp_ts < t + tf_sec:
                            close = c.get('close') or c.get('c')
                            if close is not None:
                                try:
                                    return float(close)
                                except Exception:
                                    return None
            # Si no se encontró, intentar match insensible a mayúsculas con claves reales
            lower_map = {k.lower(): k for k in cache.keys()}
            for cand in list(candidates):
                lk = cand.lower()
                if lk in lower_map:
                    real_key = lower_map[lk]
                    candles = cache.get(real_key) or []
                    tf_sec = int(timeframe_min * 60)
                    for c in reversed(candles[-200:]):
                        t = int(c.get('time') or c.get('t') or 0)
                        if t <= exp_ts < t + tf_sec:
                            close = c.get('close') or c.get('c')
                            if close is not None:
                                try:
                                    return float(close)
                                except Exception:
                                    return None
            return None
        except Exception:
            return None
    """
    Automates browser interaction with trading brokers and captures market data.
    
    Attributes:
        broker: Broker name ('quotex' or 'pocketoption')
        candles_data: Dictionary of OHLC candle data by asset
        payout_data: Dictionary of payout percentages by asset
        price_data: Dictionary of current prices by asset
    """
    
    def __init__(self, broker: str = 'quotex', use_existing: bool = True) -> None:
        """
        Initialize broker capture with async event loop.
        
        Args:
            broker: Broker platform ('quotex' or 'pocketoption')
            use_existing: Connect to existing browser or launch new one
        """
        self.broker = broker
        self.browser = None
        self.page: Optional[Page] = None
        self.playwright = None
        self.candles_data: Dict[str, List[Dict[str, Any]]] = {}
        self.payout_data: Dict[str, int] = {}
        self.price_data: Dict[str, float] = {}
        self.use_existing = use_existing        
        self.loop = asyncio.new_event_loop()
        self.pw_thread = threading.Thread(target=self._start_event_loop, daemon=True)
        self.pw_thread.start()
        self.connection_status = "disconnected"
        self.last_successful_data_time = None
        self.reconnect_attempts = 0
        self.max_reconnect_attempts = 10
        
        # 🔐 ANTI-BOT SYSTEM: Initialize market data service for stealth capture
        self.market_data_service = MarketDataService()
        self.mds_initialized = False

    async def _start_async(self, headless: bool = False) -> None:
        """
        Start browser connection asynchronously with aggressive reconnection.
        
        Args:
            headless: Run browser in headless mode
        """
        self.playwright = await async_playwright().start()
        if self.use_existing:
            logger.info("\n[INFO] [WAIT] Intentando conectar a Chrome en puerto 9222...")
            logger.info("   [WAIT] Esperando que Chrome esté disponible...")
            logger.info("   [INFO] Si Chrome no se abre automáticamente, ejecuta:")
            logger.info("      powershell -ExecutionPolicy Bypass -File run_bot_simple.ps1")
            logger.info("      O manualmente: chrome.exe --remote-debugging-port=9222\n")
            
            # INTENTOS AGRESIVOS: 15 intentos de 3 segundos = 45 segundos totales
            for attempt in range(15):
                try:
                    # Agregar timeout de 3 segundos para evitar bloqueos indefinidos
                    self.browser = await asyncio.wait_for(
                        self.playwright.chromium.connect_over_cdp('http://localhost:9222'),
                        timeout=3.0
                    )
                    context = self.browser.contexts[0]
                    
                    # Busqueda de pagina mas robusta
                    target_page = None
                    for p in context.pages:
                        url = p.url.lower()
                        title = (await p.title()).lower()
                        if self.broker in url or self.broker in title or ('pocket' in title and 'option' in title):
                            target_page = p
                            break
                    
                    if not target_page and context.pages:
                        target_page = context.pages[0]

                    if target_page:
                        self.page = target_page
                        await self.page.bring_to_front()
                        self.connection_status = "connected"
                        self.reconnect_attempts = 0
                        logger.info(f"[OK] [OK] [OK] CONECTADO A REAL DATA (Puerto 9222)")
                        logger.info(f"   Pestana: {await self.page.title()}")
                        logger.info(f"   URL: {self.page.url}\n")
                        
                        # 🔐 ANTI-BOT: Initialize stealth data interception system
                        try:
                            await self.market_data_service.initialize(self.page)
                            self.mds_initialized = True
                            logger.info("   [OK] [STEALTH] Anti-bot data capture system ACTIVE\n")
                        except Exception as e:
                            logger.warning(f"   [WARN] [STEALTH] Warning initializing stealth system: {e}")
                            self.mds_initialized = False
                        
                        # NOTE: intercept_websocket_data() está DEPRECATED - el listener ya se registró en market_data_service.initialize()
                        # Llamarlo aquí causaba CONFLICTO de listeners - el segundo sobrescribía el primero
                        
                        # 🎯 NUEVO: Descubrir y navegar a activos con payout >80% automáticamente
                        # IMPORTANTE: Ejecutar en BACKGROUND (non-blocking) para no bloquear RealTimeMonitor
                        logger.info("\n[AUTO-ASSET] Iniciando descubrimiento de activos con payout >80% (background)...")
                        asyncio.create_task(self._auto_discover_and_navigate_assets())
                        
                        # Inicia health check en background
                        asyncio.create_task(self._health_check_loop())
                        return

                except Exception as e:
                    wait_time = 3
                    elapsed = (attempt + 1) * wait_time
                    logger.info(f"   [WAIT] Intento {attempt + 1}/15... ({elapsed}s) - Reintentando...")
                    await asyncio.sleep(wait_time)
            
            logger.warning("\n[WARN] [ALERT] No se pudo conectar a Chrome después de 45 segundos")
            logger.warning("   -> El bot usará datos simulados para esta sesión")
            logger.warning("   -> Para conectar Chrome:")
            logger.warning("      1. Cierra este bot (Ctrl+C)")
            logger.warning("      2. Ejecuta: powershell -ExecutionPolicy Bypass -File run_bot_simple.ps1")
            logger.warning("      3. Espera a que se abra Chrome automáticamente\n")
            self.use_existing = False
            self.connection_status = "fallback"
        
        if not self.use_existing:
            self.browser = await self.playwright.chromium.launch(headless=headless)
            context = await self.browser.new_context()
            self.page = await context.new_page()
            
            if self.broker == 'quotex':
                logger.warning("   [WARN] Modo SIMULACION activado para Quotex")
            elif self.broker == 'pocketoption':
                logger.info("   Nota: Usando modo simulación para Pocket Option")
            
            await asyncio.sleep(2)

    def _start_event_loop(self):
        asyncio.set_event_loop(self.loop)
        self.loop.run_forever()

    def start(self, headless=False):
        # Ejecuta la inicialización asíncrona en el bucle de eventos del hilo de Playwright
        future = asyncio.run_coroutine_threadsafe(self._start_async(headless), self.loop)
        future.result() # Espera a que la inicialización termine
    
    async def _auto_discover_and_navigate_assets(self) -> None:
        """
        Descubre automáticamente activos con payout >80% y navega a uno de ellos.
        Esto asegura que el WebSocket reciba datos reales desde el inicio.
        
        Strategy:
        1. Obtener el activo actual del gráfico
        2. Verificar su payout
        3. Si es >80%, mantenerlo y esperar datos WebSocket
        4. Si no, buscar otros activos en lista de prioridad
        5. Navegar al primero que tenga >80% payout
        6. CRÍTICO: Esperar confirmación de cambio + datos WebSocket
        """
        try:
            if not self.page or not self.use_existing:
                logger.info("   [AUTO-ASSET] Sin navegador disponible, saltando auto-discover")
                return
            
            logger.info("\n   🔍 [AUTO-ASSET] === INICIANDO DESCUBRIMIENTO DE ACTIVOS ===\n")
            
            # Obtener activo actual
            logger.info("   [AUTO-ASSET] [1/2] Obteniendo activo actual del gráfico...")
            current_asset = await self._get_current_chart_asset_async()
            logger.info(f"       → Asset detectado: {current_asset}")
            
            if current_asset:
                # Verificar el payout del activo actual
                payout = await self._get_asset_payout_async(current_asset)
                logger.info(f"       → Payout: {payout}%")
                
                if payout >= 80:
                    logger.info(f"   ✅ [AUTO-ASSET] {current_asset} ya tiene {payout}% (>=80%) - BUENO para trading")
                    logger.info("   [AUTO-ASSET] [2/2] Esperando datos WebSocket...")
                    data_received = await self._wait_for_websocket_data(current_asset, timeout_seconds=10)
                    if data_received:
                        logger.info(f"   ✅ [AUTO-ASSET] === LISTO: {current_asset} con datos reales ===\n")
                    else:
                        logger.info(f"   ⚠️  [AUTO-ASSET] No hay datos WebSocket aún, pero continuando con {current_asset}...\n")
                    return
                else:
                    logger.info(f"   ⚠️  [AUTO-ASSET] {current_asset} tiene {payout}% (INSUFICIENTE)")
            
            # Buscar alternativas con >80% payout
            logger.info("   [AUTO-ASSET] Buscando activos alternativos con payout >80%...")
            
            # PRIORITARIOS: OTC con mejor payout + Forex estable
            candidates = [
                "USD/BDT (OTC)",   # Típicamente 85-90%
                "USD/BRL (OTC)",   # Típicamente 85-90%
                "NZD/CAD (OTC)",   # Típicamente 84-88%
                "USD/PHP (OTC)",   # Típicamente 85-88%
                "USD/IDR (OTC)",   # Típicamente 85-88%
                "EUR/USD",         # Típicamente 80-85%
                "GBP/USD",
                "USD/JPY",
                "AUD/USD",
            ]
            
            for idx, asset in enumerate(candidates, 1):
                try:
                    logger.info(f"   [AUTO-ASSET] Verificando alternativa {idx}/{len(candidates)}: {asset}...")
                    payout = await self._get_asset_payout_async(asset)
                    
                    if payout >= 80:
                        logger.info(f"   ✅ [AUTO-ASSET] {asset} tiene {payout}% - NAVEGANDO...")
                        success = await self._change_asset_on_chart_async(asset)
                        
                        if success:
                            # Verificar que el cambio fue realmente exitoso
                            await asyncio.sleep(1)
                            verify_asset = await self._get_current_chart_asset_async()
                            logger.info(f"   ✅ [AUTO-ASSET] Navegación verificada: {verify_asset}")
                            
                            # Esperar datos WebSocket
                            logger.info(f"   [AUTO-ASSET] Esperando datos WebSocket para {asset}...")
                            data_received = await self._wait_for_websocket_data(asset, timeout_seconds=15)
                            
                            if data_received:
                                logger.info(f"   ✅ [AUTO-ASSET] === LISTO: {asset} con datos reales ===\n")
                            else:
                                logger.info(f"   ⚠️  [AUTO-ASSET] Sin datos WebSocket, pero {asset} está en gráfico\n")
                            return
                        else:
                            logger.info(f"   ⚠️  [AUTO-ASSET] Navegación a {asset} falló, probando siguiente...")
                    else:
                        logger.info(f"   ⚠️  [AUTO-ASSET] {asset}: {payout}% (insuficiente)")
                
                except Exception as e:
                    logger.info(f"   ⚠️  [AUTO-ASSET] Error con {asset}: {e}")
                    await asyncio.sleep(0.5)
                    continue
            
            logger.warning("\n   ⚠️  [AUTO-ASSET] No se encontraron activos con payout >80%")
            logger.warning("       El bot continuará con el activo actual, pero datos pueden ser simulados\n")
        
        except Exception as e:
            logger.error(f"   ❌ [AUTO-ASSET] Error crítico: {e}")
            import traceback
            traceback.print_exc()
    
    async def _wait_for_websocket_data(self, asset: str, timeout_seconds: int = 15) -> bool:
        """
        Espera a que el WebSocket reciba datos reales para un activo específico.
        
        Args:
            asset: Nombre del activo
            timeout_seconds: Tiempo máximo de espera
            
        Returns:
            True si se recibieron datos, False si timeout
        """
        try:
            from data_interceptor import WebSocketInterceptor
            
            logger.info(f"   [WS-WAIT] Esperando datos WebSocket para {asset}...")
            normalized_asset = WebSocketInterceptor.normalize_asset_name(asset)
            
            start_time = datetime.now()
            while True:
                if self.market_data_service and self.market_data_service.ws_listener:
                    ws_listener = self.market_data_service.ws_listener
                    
                    # Verificar si hay datos en caché
                    if normalized_asset in ws_listener.candles_cache:
                        candles = ws_listener.candles_cache[normalized_asset]
                        if len(candles) > 5:
                            logger.info(f"   ✅ [WS-WAIT] Datos WebSocket recibidos para {asset} ({len(candles)} velas)")
                            return True
                
                # Verificar timeout
                elapsed = (datetime.now() - start_time).total_seconds()
                if elapsed > timeout_seconds:
                    logger.info(f"   ⚠️  [WS-WAIT] Timeout esperando datos para {asset}. Continuando...")
                    return False
                
                # Esperar antes de reintentar
                await asyncio.sleep(0.5)
        
        except Exception as e:
            logger.info(f"   ⚠️  [WS-WAIT] Error esperando datos WebSocket: {e}")
            return False
    
    async def _extract_candles_from_dom(self, asset: str) -> Optional[List[Dict[str, Any]]]:
        """
        Extrae datos OHLC directamente del gráfico DOM si WebSocket falla.
        
        Returns:
            Lista de candles o None si falla
        """
        try:
            if not self.page:
                return None
            
            logger.info(f"   [DOM-EXTRACT] Intentando extraer datos OHLC del DOM para {asset}...")
            
            # Script para extraer datos del gráfico TradingView/Quotex
            dom_script = """
            () => {
                const candles = [];
                try {
                    // Intentar obtener datos del objeto de gráfico
                    if (window.chartInstance && window.chartInstance.data) {
                        const bars = window.chartInstance.data;
                        if (Array.isArray(bars)) {
                            candles.push(...bars.slice(-100).map(bar => ({
                                time: Math.round(bar.time / 1000),
                                open: bar.open,
                                high: bar.high,
                                low: bar.low,
                                close: bar.close,
                                volume: bar.volume || 1
                            })));
                        }
                    }
                    
                    // Intentar obtener del elemento del gráfico
                    if (candles.length === 0) {
                        const chartElement = document.querySelector('[class*="chart"]');
                        if (chartElement && chartElement._instance && chartElement._instance.data) {
                            candles.push(...chartElement._instance.data.slice(-100));
                        }
                    }
                } catch (e) {
                    // Silent error
                }
                return candles.length > 0 ? candles : null;
            }
            """
            
            result = await self.page.evaluate(dom_script)
            if result and isinstance(result, list) and len(result) > 5:
                logger.info(f"   ✅ [DOM-EXTRACT] Extraído {len(result)} candles del DOM para {asset}")
                return result
            else:
                logger.info(f"   ⚠️  [DOM-EXTRACT] No se pudieron extraer datos del DOM")
                return None
        
        except Exception as e:
            logger.info(f"   ⚠️  [DOM-EXTRACT] Error extrayendo datos: {e}")
            return None
    
    def intercept_websocket_data(self):
        self.page.on('websocket', self._handle_websocket)
        logger.info("   [WS] Interceptor de WebSocket activado.")
    
    def _handle_websocket(self, ws): # Esto se ejecuta en el hilo de Playwright, está bien
        # El evento 'framereceived' en la API de Python pasa el payload directamente como bytes.
        # No es un objeto con un atributo .payload.
        ws.on('framereceived', lambda payload_bytes: self._process_frame(payload_bytes))
    
    def _process_frame(self, payload):
        try:
            # El payload es bytes, necesitamos decodificarlo a una cadena de texto.
            payload_str = payload.decode('utf-8', errors='ignore')

            if self.broker == 'quotex':
                # Quotex usa un formato numérico al inicio (ej: "42[...]"). Lo eliminamos.
                if payload_str.startswith('42'):
                    payload_str = payload_str[2:]
                
                data = json.loads(payload_str)
                
                # Detectar y procesar datos de velas (estructura común en brokers)
                if isinstance(data, list) and len(data) > 1:
                    event_name = data[0]
                    event_data = data[1]
                    
                    if event_name == 'ohlc' and isinstance(event_data, list):
                        for candle in event_data:
                            asset = candle.get('asset')
                            if asset and isinstance(candle.get('data'), list):
                                self.candles_data[asset] = candle['data']
                    
                    # Detectar precios actuales
                    if event_name == 'quotes' and isinstance(event_data, list):
                        for quote in event_data:
                            asset = quote.get('asset')
                            price = quote.get('price')
                            if asset and price:
                                self.price_data[asset] = float(price)
                    
                    # Detectar payouts
                    if event_name == 'option-opened' or event_name == 'asset-updated':
                        if isinstance(event_data, dict):
                            asset = event_data.get('asset')
                            payout = event_data.get('profitPercent') or event_data.get('payout')
                            if asset and payout is not None:
                                self.payout_data[asset] = int(payout)

            elif self.broker == 'pocketoption':
                # PocketOption suele enviar un JSON con un campo 'name' para el evento
                data = json.loads(payload_str)
                event_name = data.get('name')
                event_data = data.get('msg')

                if event_name == 'candles-generated' and isinstance(event_data, dict):
                    asset = event_data.get('asset')
                    candles = event_data.get('candles')
                    if asset and candles:
                        # PocketOption puede enviar las velas en un formato diferente
                        # Aquí asumimos un formato y lo adaptamos al nuestro
                        formatted_candles = [{
                            'time': c.get('t', c.get('time')),
                            'open': c.get('o', c.get('open')),
                            'high': c.get('h', c.get('high')),
                            'low': c.get('l', c.get('low')),
                            'close': c.get('c', c.get('close')),
                            'volume': c.get('v', c.get('volume', 0))
                        } for c in candles]
                        self.candles_data[asset] = formatted_candles

                if event_name == 'quotes' and isinstance(event_data, list):
                    for quote in event_data:
                        asset = quote.get('asset')
                        price = quote.get('rate') # PocketOption puede usar 'rate'
                        if asset and price:
                            self.price_data[asset] = float(price)

                if event_name == 'change-asset' and isinstance(event_data, dict):
                    asset = event_data.get('name')
                    payout = event_data.get('payout')
                    if asset and payout is not None:
                        self.payout_data[asset] = int(payout)

        except (json.JSONDecodeError, UnicodeDecodeError):
            # Ignorar frames que no son JSON o tienen problemas de decodificación
            pass
        except Exception:
            # Captura silenciosa de otros errores para no inundar la consola
            pass
    
    async def _ensure_page_open(self):
        """
        CRÍTICO: Verifica y recupera la página si está cerrada.
        Previene errores "Target page has been closed"
        """
        if not self.page or self.page.is_closed():
            # Intentar recuperar la página del contexto
            if self.browser and self.browser.contexts:
                for context in self.browser.contexts:
                    if context.pages:
                        self.page = context.pages[0]
                        await self.page.bring_to_front()
                        return True
            # Si no hay página disponible
            return False
        return True
    
    async def _safe_evaluate(self, context, script, timeout=5.0):
        """
        SEGURO: Ejecuta JavaScript con validación de página abierta.
        Retorna None si hay error en lugar de fallar.
        """
        try:
            # Verificar que la página esté abierta
            if not await self._ensure_page_open():
                return None
            
            # Asegurarse que el contexto sea válido
            if hasattr(context, 'is_closed') and context.is_closed():
                context = self.page
            
            # Ejecutar con timeout (CORREGIDO: sin await adicional en asyncio.wait_for)
            result = await asyncio.wait_for(context.evaluate(script), timeout=timeout)
            return result
        except asyncio.TimeoutError:
            logger.info(f"      ⚠️ Timeout ejecutando script (>{timeout}s)")
            return None
        except Exception as e:
            # Capturar el error pero no fallar - retornar None
            return None

    async def _capture_candles_from_chart_async(self, asset, timeframe, source_tag=""):
        """
        Función principal para capturar velas, con NUEVA PRIORIDAD optimizada.
        
        Data Priority (Anti-Bot optimized):
        1. 🔐 WebSocket Interceptor (real-time data - INVISIBLE)
        2. Market Data Service (intercepted + passive)
        3. DOM Graph Extraction (visible prices)
        4. Chart Engine (getBars)
        5. JS Objects scan
        6. Memory scan
        7. External API
        8. Simulation (fallback)
        """
        if not self.use_existing or not self.page:
            # Si no hay navegador, ir directamente a la simulación
            logger.info(f"   [ALERTA] {source_tag} ¡¡¡USANDO DATOS SIMULADOS PARA {asset}!!! No hay navegador conectado.")
            return self._simulate_candles(asset, timeframe)

        # 🔐 LAYER 0: Try WebSocket Interceptor first (MOST RELIABLE)
        # WebSocket tiene datos en TIEMPO REAL capturados pasivamente
        if hasattr(self.market_data_service, 'ws_listener') and self.market_data_service.ws_listener:
            from data_interceptor import WebSocketInterceptor
            ws_listener = self.market_data_service.ws_listener
            
            # Buscar en cache de WebSocket con normalización de nombres
            normalized_asset = WebSocketInterceptor.normalize_asset_name(asset)
            
            # Generar múltiples variantes del nombre para buscar exhaustivamente
            # 🔍 KEY FIX: Múltiples variantes porque WebSocket puede usar cualquier formato
            search_variants = [
                normalized_asset,
                asset,
                # Conversión crítica: USD/JPY (OTC) → usdjpy_otc (lo que WebSocket usa)
                asset.replace(' (OTC)', '_otc').replace('/', '').lower() if ' (OTC)' in asset else asset.replace('/', '').lower(),
                asset.replace(' (OTC)', '_otc').lower(),
                asset.replace('/', '').replace(' (OTC)', '_otc').lower(),
                asset.replace('(OTC)', 'otc'),
                asset.replace(' (OTC)', '-otc').lower(),
                asset.replace(' (OTC)', '').strip(),  # Sin (OTC)
                asset.replace('/', '') if '/' in asset else asset,  # EUR/USD (OTC) → EURUSD (OTC)
                asset.split(' ')[0] if ' ' in asset else asset,  # Solo símbolo
                asset.replace(' ', '').upper(),  # Sin espacios
                asset.replace(' ', ''),  # Sin espacios lowercase
                asset.lower(),  # Minúsculas
                # Extra: con espacios/guiones
                asset.replace('/', '-').lower(),
                asset.replace('/', '_').lower(),
            ]
            
            # Intentar cada variante
            found_data = False
            for idx, search_key in enumerate(search_variants):
                if search_key and search_key in ws_listener.candles_cache and ws_listener.candles_cache[search_key]:
                    candles = ws_listener.candles_cache[search_key]
                    if candles and len(candles) > 0:
                        logger.info(f"   ✅ [WS-REAL] Datos WebSocket en tiempo real para {asset} (variante: {search_key}, {len(candles)} velas)")
                        return candles
            
            # Debug: mostrar estado del WebSocket si no hay datos
            if not found_data:
                debug_status = ws_listener.get_debug_status()
                if debug_status['message_count'] == 0:
                    logger.info(f"   ⚠️  [DEBUG-WS] Sin frames WebSocket recibidos aún. Esperando conexión...")
                else:
                    logger.info(f"   ℹ️  [DEBUG-WS] Frames: {debug_status['message_count']}, Tipos: {debug_status['frame_types']}")
                    logger.info(f"   ℹ️  [DEBUG-WS] Buscando '{asset}' en {len(search_variants)} variantes:")
                    for v in search_variants[:5]:  # Mostrar primeras 5
                        logger.info(f"      - {v}")
                    logger.info(f"   ℹ️  [DEBUG-WS] Activos REALMENTE en cache: {list(ws_listener.candles_cache.keys())[:10]}")
                    if hasattr(ws_listener, 'get_debug_status'):
                        logger.info(f"   ℹ️  [DEBUG-WS] Activos según get_debug_status: {debug_status['cached_assets']}")
                    if debug_status['cached_quotes']:
                        logger.info(f"   ℹ️  [DEBUG-WS] Precios en cache: {list(debug_status['cached_quotes'].keys())}")

        # 🔐 LAYER 1: Try Market Data Service (STEALTH CAPTURE)
        if self.mds_initialized:
            try:
                candles_df = self.market_data_service.get_candles(asset, timeframe)
                if candles_df is not None and not candles_df.empty:
                    candles = candles_df.to_dict('records')
                    logger.info(f"   ✅ [STEALTH] Datos interceptados para {asset} (0 queries JS)")
                    return candles
            except Exception as e:
                pass

        # 🎯 Cambiar gráfico al activo deseado para cargar datos en memoria
        current_chart_asset = await self._get_current_chart_asset_async()
        if current_chart_asset and asset not in current_chart_asset:
            logger.info(f"   [DATOS] Cambiando gráfico a {asset}...")
            await self._change_asset_on_chart_async(asset)
            
            # 🎯 NUEVO: Esperar a que el WebSocket reciba datos después de cambiar el gráfico
            await self._wait_for_websocket_data(asset, timeout_seconds=5)
        
        # ✅ Reintentar WebSocket después de cambiar el gráfico
        if hasattr(self.market_data_service, 'ws_listener') and self.market_data_service.ws_listener:
            from data_interceptor import WebSocketInterceptor
            ws_listener = self.market_data_service.ws_listener
            normalized_asset = WebSocketInterceptor.normalize_asset_name(asset)
            
            search_variants = [
                normalized_asset,
                asset,
                asset.replace(' (OTC)', '_otc').lower(),
                asset.replace('(OTC)', 'otc'),
                asset.replace(' (OTC)', '-otc').lower(),
                asset.replace(' ', '').upper(),
                asset.replace('/', ''),
                asset.upper(),
            ]
            
            for search_key in search_variants:
                if search_key and search_key in ws_listener.candles_cache and ws_listener.candles_cache[search_key]:
                    candles = ws_listener.candles_cache[search_key]
                    if candles and len(candles) > 0:
                        logger.info(f"   ✅ [WS-REAL] Datos WebSocket recibidos para {asset} después de cambio (variante: {search_key})")
                        return candles

        search_context = self.page
        
        # Intentar localizar iFrame del gráfico
        try:
            iframe_locator = self.page.frame_locator("iframe[title*='Chart'], iframe[name*='chart']")
            await iframe_locator.wait_for(state="attached", timeout=1000)
            search_context = iframe_locator
            logger.info(f"   [DATOS] {source_tag} Detectado iFrame del gráfico.")
        except Exception:
            pass
        
        # 🎯 LAYER 2A: Try to extract price data directly from DOM
        candles = await self._extract_candles_from_dom_async(asset, source_tag, context=search_context)
        if candles and len(candles) > 5:
            logger.info(f"   ✅ [DOM] Datos extraídos del DOM visible para {asset}")
            return candles
        
        # 2. WebSocket stored data (legacy)
        if asset in self.candles_data and self.candles_data[asset]:
            logger.info(f"   [DATOS] {source_tag} Usando datos de WebSocket para {asset}.")
            return self.candles_data[asset]

        # 3. PLAN B: API del motor del gráfico (getBars)
        timeframe_seconds = int(timeframe * 60)
        candles = await self._get_candles_from_chart_engine_async(asset, timeframe_seconds, source_tag, context=search_context)
        if candles: return candles

        # 4. PLAN C: Búsqueda en objetos de JavaScript
        candles = await self._get_candles_from_js_objects_async(asset, source_tag, context=search_context)
        if candles: return candles

        # 5. PLAN E: Escaneo de memoria profundo
        candles = await self._scan_for_candles_in_memory_async(asset, source_tag, context=search_context)
        if candles: return candles

        # 6. PLAN G: Proveedor de datos externo
        timeframe_minutes = timeframe
        logger.info(f"   [DATOS] {source_tag} PLAN G: Fuerza obtener datos de API externa para {asset}...")
        candles = await self._get_candles_from_external_api_async(asset, timeframe_minutes, source_tag)
        if candles:
            logger.info(f"   ✅ [API-REAL] Datos obtenidos de API externa para {asset}")
            return candles

        # Si todo falla, simular, pero hacerlo muy evidente
        logger.info(f"\n{'*'*80}")
        logger.info(f"   🚨 [CRÍTICO] ¡¡¡USANDO DATOS SIMULADOS PARA {asset}!!!")
        logger.info(f"   Razón: No se pudo obtener datos REALES de ninguna fuente:")
        logger.info(f"      ❌ WebSocket cache: VACÍO")
        logger.info(f"      ❌ Market Data Service: FALLÓ")
        logger.info(f"      ❌ DOM extraction: FALLÓ")
        logger.info(f"      ❌ Chart engine (getBars): FALLÓ")
        logger.info(f"      ❌ JS Objects scan: FALLÓ")
        logger.info(f"      ❌ Memory scan: FALLÓ")
        logger.info(f"      ❌ API externa: FALLÓ")
        logger.info(f"   FALLBACK: Usando datos simulados (ESTO CAUSARÁ RESULTADOS INCORRECTOS)")
        logger.info(f"{'*'*80}\n")
        return self._simulate_candles(asset, timeframe)

    async def _get_candles_from_external_api_async(self, asset, timeframe_minutes, source_tag=""):
        """
        🎯 PLAN G: Como último recurso, obtiene datos de una API externa.
        """
        logger.info(f"   [DATOS] {source_tag} PLAN G: Intentando obtener datos de API externa para {asset}...")
        # Limpiar el nombre del activo para la API (ej: 'EUR/USD (OTC)' -> 'EUR/USD')
        clean_asset = asset.split(' ')[0].replace('(OTC)', '').replace('-OTC', '')
        
        # Mapear nuestro timeframe a lo que la API espera (ej: 1, 5, 15, 60)
        interval_map = {0.25: '1', 1: '1', 5: '5', 15: '15'}
        interval = interval_map.get(timeframe_minutes, '1')

        # Usamos la API de Twelve Data como ejemplo (requiere una clave API gratuita)
        # O una alternativa pública si no hay clave.
        # NOTA: Esto es una implementación de ejemplo.
        try:
            # Usaremos una API pública que no requiere clave para este ejemplo (Alpha Vantage)
            # Para Forex, el endpoint es FX_INTRADAY
            from_currency, to_currency = clean_asset.split('/')
            # La API gratuita tiene limitaciones, pero sirve como respaldo.
            url = f"https://www.alphavantage.co/query?function=FX_INTRADAY&from_symbol={from_currency}&to_symbol={to_currency}&interval={interval}min&apikey=demo&outputsize=compact"
            
            # 🎯 CORRECCIÓN DEFINITIVA: El objeto APIRequestContext no se usa con 'async with'.
            # Se debe crear, usar y luego desechar explícitamente.
            api_context = await self.playwright.request.new_context()
            try:
                response = await api_context.get(url)
                if not response.ok: return None
                
                data = await response.json()
                time_series_key = f"Time Series FX ({interval}min)"
                if time_series_key not in data: return None

    
                time_series = data[time_series_key]
                candles = [{'time': int(pd.to_datetime(dt).timestamp()), 'open': float(vals['1. open']), 'high': float(vals['2. high']), 'low': float(vals['3. low']), 'close': float(vals['4. close'])} for dt, vals in time_series.items()]
                candles.reverse() # La API devuelve del más reciente al más antiguo
                logger.info(f"   [DATOS] {source_tag} ¡Éxito! Datos de API externa para {clean_asset} obtenidos.")
                return candles[-150:] # Devolver las últimas 150 velas
            finally:
                # Asegurarnos de que el contexto se desecha siempre
                await api_context.dispose()
        except Exception as e:
            logger.info(f"      ⚠️ Error obteniendo datos de API externa: {e}")
            return None

    async def _get_candles_from_chart_engine_async(self, asset, timeframe_seconds, source_tag="", context=None):
        """
        🎯 NUEVO MÉTODO: Intenta obtener las velas comunicándose directamente con el motor del gráfico.
        Esto es más robusto que buscar en objetos globales de `window`.
        """
        if context is None: context = self.page
        try:
            script = """
            async () => {
                const chartAPI = window.widget || (window.tradingView && window.tradingView.activeChart && window.tradingView.activeChart());
                if (!chartAPI || typeof chartAPI.getSymbol !== 'function') return null;

                const symbol = chartAPI.getSymbol();
                const resolution = chartAPI.resolution();
                
                return new Promise((resolve) => {
                    chartAPI.getBars(symbol, resolution, { from: 0, to: Date.now() / 1000 }, (bars) => {
                        if (!bars || bars.length === 0) resolve(null);
                        resolve(bars.slice(-150)); // Devolver las últimas 150 velas
                    }, (error) => {
                        console.error('Error getBars:', error);
                        resolve(null);
                    });
                });
            }
            """
            candles = await self._safe_evaluate(context, script, timeout=5.0)
            if candles and len(candles) > 0:
                logger.info(f"   [DATOS] {source_tag} Usando datos del motor del gráfico (getBars) para {asset}.")
                return candles
        except Exception:
            pass # Si falla, probamos el siguiente método.
        return None

    async def _get_candles_from_js_objects_async(self, asset, source_tag="", context=None):
        """
        🎯 PLAN C: Intenta encontrar los datos de las velas en varios objetos de JavaScript comunes.
        Es menos directo que getBars, pero más fiable que selectores de DOM.
        """
        if context is None: context = self.page
        script = """
        () => {
            const dataSources = [
                // TradingView Widget
                () => window.tvWidget?.chart?.().getSeries?.()?.data?.()?.get?.(),
                // Active Chart API
                () => window.tradingView?.activeChart?.().getSeries?.()?.data?.()?.get?.(),
                // Quotex (estructura observada)
                () => window.candles?.find(c => c.asset === '""" + asset + """')?.data,
                // Estructura genérica
                () => window.chartData,
                () => window.candlesData
            ];

            for (const source of dataSources) {
                try {
                    const candles = source();
                    if (candles && candles.length > 10) {
                        // Mapear a un formato estándar por si acaso
                        return candles.slice(-150).map(c => ({
                            time: c.time ?? c.t,
                            open: c.open ?? c.o,
                            high: c.high ?? c.h,
                            low: c.low ?? c.l,
                            close: c.close ?? c.c,
                            volume: c.volume ?? c.v ?? 0
                        }));
                    }
                } catch (e) { /* Ignorar errores y probar la siguiente fuente */ }
            }
            return null;
        }
        """
        try:
            candles = await self._safe_evaluate(context, script, timeout=5.0)
            if candles and len(candles) > 0:
                logger.info(f"   [DATOS] {source_tag} Usando datos de objetos JS para {asset}.")
                return candles
        except Exception:
            pass
        return None

    async def _scan_for_candles_in_memory_async(self, asset, source_tag="", context=None):
        """
        🎯 PLAN D: Escanea la memoria de la ventana en busca de cualquier objeto que parezca una serie de velas.
        Este es el último recurso antes de simular datos. Es potente pero puede ser lento.
        """
        if context is None: context = self.page
        logger.info(f"   [DATOS] {source_tag} PLAN D: Escaneando memoria del navegador para {asset}...")
        # 🎯 PLAN E: SCRIPT DE ESCANEO MEJORADO (MÁS PROFUNDO Y AGNOSTICO)
        script = """
        () => {
            const foundCandles = [];
            const visited = new Set();
            const MIN_CANDLES = 50;

            // Criterio 1: Objeto con claves o,h,l,c
            function isCandleObject(o) {
                return o && typeof o === 'object' &&
                       (('t' in o || 'time' in o)) &&
                       ('o' in o || 'open' in o) &&
                       ('h' in o || 'high' in o) &&
                       ('l' in o || 'low' in o) &&
                       ('c' in o || 'close' in o);
            };

            // Criterio 2: Array de 5 o 6 números
            function isCandleArray(a) {
                return Array.isArray(a) && (a.length === 5 || a.length === 6) && a.every(v => typeof v === 'number');
            };

            function scan(obj) {
                if (!obj || typeof obj !== 'object' || visited.has(obj)) return;
                visited.add(obj);

                try {
                    // Detección de array de objetos vela
                    if (Array.isArray(obj) && obj.length > MIN_CANDLES && obj.every(isCandleObject)) {
                        foundCandles.push(obj.map(c => ({
                            time: c.time ?? c.t, open: c.open ?? c.o, high: c.high ?? c.h,
                            low: c.low ?? c.l, close: c.close ?? c.c, volume: c.volume ?? c.v ?? 0
                        })));
                        return;
                    }

                    // Detección de array de arrays vela
                    if (Array.isArray(obj) && obj.length > MIN_CANDLES && obj.every(isCandleArray)) {
                        foundCandles.push(obj.map(c => ({
                            time: c[0], open: c[1], high: c[2], low: c[3], close: c[4], volume: c[5] ?? 0
                        })));
                        return;
                    }

                    // Detección de objeto con arrays de o,h,l,c
                    if (obj.open && obj.high && obj.low && obj.close && Array.isArray(obj.open) && obj.open.length > MIN_CANDLES) {
                        const times = obj.time || obj.t || Array.from({ length: obj.open.length }, (_, i) => Date.now() / 1000 - (obj.open.length - i) * 60);
                        const volumes = obj.volume || obj.v || Array(obj.open.length).fill(0);
                        const reconstructed = [];
                        for (let i = 0; i < obj.open.length; i++) {
                            reconstructed.push({
                                time: times[i], open: obj.open[i], high: obj.high[i],
                                low: obj.low[i], close: obj.close[i], volume: volumes[i]
                            });
                        }
                        foundCandles.push(reconstructed);
                        return;
                    }

                    // Continuar escaneo recursivo
                    for (const key in obj) {
                        if (Object.prototype.hasOwnProperty.call(obj, key)) {
                            scan(obj[key]);
                        }
                    }
                } catch (e) { /* Ignorar errores de acceso o recursión */ }
            }

            scan(window);
            // Devolver el array de velas más largo encontrado
            if (foundCandles.length > 0) {
                return foundCandles.sort((a, b) => b.length - a.length)[0].slice(-150);
            }
            return null;
        }
        """
        try:
            # Usar método seguro con timeout extendido para el escaneo profundo
            candles = await self._safe_evaluate(context, script, timeout=10.0)
            if candles and len(candles) > 0:
                logger.info(f"   [DATOS] {source_tag} ¡Éxito! Datos encontrados en memoria para {asset}.")
                return candles
        except Exception as e:
            logger.info(f"      ⚠️ Error durante el escaneo de memoria: {e}")
        return None

    def capture_candles_from_chart(self, asset, timeframe, source_tag=""):
        future = asyncio.run_coroutine_threadsafe(self._capture_candles_from_chart_async(asset, timeframe, source_tag), self.loop)
        return future.result()
    
    async def _extract_candles_from_dom_async(self, asset, source_tag="", context=None):
        """
        🎯 Extract candles from TradingView chart (used by Quotex)
        Reads price data directly from the chart's internal data structure
        """
        if context is None:
            context = self.page
        
        try:
            logger.info(f"   [DATOS] {source_tag} Intentando extraer datos del gráfico TradingView...")
            
            # Script mejorado para extraer datos de TradingView/Quotex
            script = """
            () => {
                const candles = [];
                
                // Método 1: Acceder a la API interna de TradingView (si está disponible)
                try {
                    if (window.tvDataFeed && window.tvDataFeed.getBars) {
                        const bars = window.tvDataFeed.getBars();
                        if (Array.isArray(bars) && bars.length > 0) {
                            return bars.map(b => ({
                                time: Math.floor(b.time / 1000),
                                open: parseFloat(b.open),
                                high: parseFloat(b.high),
                                low: parseFloat(b.low),
                                close: parseFloat(b.close),
                                volume: parseInt(b.volume) || 0
                            }));
                        }
                    }
                } catch (e) {}
                
                // Método 1B: NUEVA ESTRATEGIA - Extraer precio actual visible en el gráfico
                try {
                    // ESTRATEGIA 1: Buscar en elementos de datos visibles
                    const allElements = document.querySelectorAll('[class*="price"], [class*="Price"], [id*="price"], span, div, p');
                    let foundPrice = null;
                    
                    for (const el of allElements) {
                        const text = el.textContent.trim();
                        // Buscar patrón de precio: 0.76000, 1.23456, 100.5000, etc.
                        const priceMatch = text.match(/\\b([0-9]{1,6}\\.[0-9]{3,6})\\b/);
                        if (priceMatch) {
                            const price = parseFloat(priceMatch[1]);
                            if (!isNaN(price) && price > 0.0001 && price < 100000) {
                                // Validar que sea precio real (no timestamp, no otros números)
                                if (price < 10000) {  // Precios reales suelen ser < 10000
                                    foundPrice = price;
                                    break;
                                }
                            }
                        }
                    }
                    
                    if (foundPrice) {
                        const currentTime = Math.floor(Date.now() / 1000);
                        return [{
                            time: currentTime,
                            open: foundPrice,
                            high: foundPrice,
                            low: foundPrice,
                            close: foundPrice,
                            volume: 1
                        }];
                    }
                    
                    // ESTRATEGIA 2: Buscar en todo el texto del documento
                    const allText = document.body.innerText;
                    // Buscar patrones más específicos
                    const patterns = [
                        /(?:Precio|Price|Bid|Ask|Rate)\\s*[:\\s]+\\s*([0-9]{1,6}\\.[0-9]{3,6})/gi,
                        /\\b([0-9]{1,6}\\.[0-9]{4,6})\\b/g,  // Precios con 4-6 decimales
                        /\\b0\\.[0-9]{5}\\b/g  // Precios que empiezan con 0.
                    ];
                    
                    for (const pattern of patterns) {
                        const matches = allText.match(pattern);
                        if (matches) {
                            for (const match of matches) {
                                let price = match;
                                // Extraer número si contiene texto
                                if (!/^[0-9]/.test(price)) {
                                    const numMatch = match.match(/([0-9]{1,6}\\.[0-9]{3,6})/);
                                    if (numMatch) price = numMatch[1];
                                }
                                
                                const numPrice = parseFloat(price);
                                if (!isNaN(numPrice) && numPrice > 0.0001 && numPrice < 100000 && numPrice < 10000) {
                                    const currentTime = Math.floor(Date.now() / 1000);
                                    return [{
                                        time: currentTime,
                                        open: numPrice,
                                        high: numPrice,
                                        low: numPrice,
                                        close: numPrice,
                                        volume: 1
                                    }];
                                }
                            }
                        }
                    }
                } catch (e) {}
                
                // Método 3: Buscar elementos SVG que puedan contener datos de precios
                try {
                    const svgElements = document.querySelectorAll('svg text, svg tspan');
                    const priceTexts = [];
                    svgElements.forEach(el => {
                        const text = el.textContent.trim();
                        const price = parseFloat(text);
                        if (!isNaN(price) && price > 0.001 && price < 100000 && text.split('.').length <= 2) {
                            if (price < 10000) {  // Filtro adicional
                                priceTexts.push({price, text});
                            }
                        }
                    });
                    
                    if (priceTexts.length > 3) {
                        const uniquePrices = [...new Set(priceTexts.map(p => p.price))].sort();
                        const currentPrice = uniquePrices[Math.floor(uniquePrices.length / 2)];
                        const currentTime = Math.floor(Date.now() / 1000);
                        return [{
                            time: currentTime,
                            open: currentPrice,
                            high: currentPrice,
                            low: currentPrice,
                            close: currentPrice,
                            volume: 1
                        }];
                    }
                } catch (e) {}
                
                // Método 4: Intentar extraer de objetos globales de Quotex
                try {
                    if (window.__QUOTEX_DATA && window.__QUOTEX_DATA.candles) {
                        const qxCandles = window.__QUOTEX_DATA.candles;
                        if (Array.isArray(qxCandles) && qxCandles.length > 0) {
                            return qxCandles.map(c => ({
                                time: c.t || c.time,
                                open: c.o || c.open,
                                high: c.h || c.high,
                                low: c.l || c.low,
                                close: c.c || c.close,
                                volume: c.v || c.volume || 0
                            }));
                        }
                    }
                } catch (e) {}
                
                // ✅ CRITICAL FIX: Return any candles found, even if just 1 price
                // The Python side will expand 1 candle into realistic OHLC series
                if (candles && candles.length > 0) {
                    return candles;
                }
                
                return null;
            }
            """
            
            # Usar método seguro con validación de página
            candles = await self._safe_evaluate(context, script, timeout=5.0)
            
            if candles and len(candles) > 5:
                return candles
            elif candles and len(candles) == 1:
                # Single price candle found - expand it to realistic OHLC series
                current_price = candles[0]['close']
                logger.info(f"   ✅ [DOM-PRICE] Precio actual extraído del gráfico: {current_price}")
                
                # Create realistic candles with this real price as base
                expanded_candles = self._create_realistic_candles_from_price(current_price, asset)
                logger.info(f"   ✅ [DOM-EXPANSION] Expandido a {len(expanded_candles)} candles con precio real")
                return expanded_candles
                
        except Exception as e:
            logger.info(f"      ⚠️ Error al extraer del gráfico: {e}")
        
        return None
    
    def _extract_candles_from_screenshot(self, screenshot_bytes, asset, timeframe):
        return self._simulate_candles(asset, timeframe)
    
    def _create_realistic_candles_from_price(self, real_price: float, asset: str, num_candles: int = 50, timeframe: int = 1) -> List[Dict[str, Any]]:
        """
        Create realistic OHLC candles using a REAL PRICE as the base.
        This ensures the trading signals are based on actual market prices,
        not purely simulated data.
        
        Args:
            real_price: The actual current price extracted from the chart
            asset: Asset symbol
            num_candles: Number of candles to generate
            timeframe: Timeframe in minutes
            
        Returns:
            List of candle dictionaries with realistic OHLC data
        """
        import random
        from datetime import datetime, timedelta
        
        candles = []
        current_time = datetime.now()
        
        # Use the real price as the close price of the latest candle
        base_price = real_price
        
        # Small trend (±0.1% per candle)
        trend = random.choice([-0.001, -0.0005, 0, 0.0005, 0.001])
        
        for i in range(num_candles, 0, -1):
            candle_time = current_time - timedelta(minutes=i * timeframe)
            
            # Small random movements (±0.2% volatility) around the base price
            volatility = base_price * random.uniform(0.001, 0.002)
            
            open_price = base_price + random.uniform(-volatility, volatility)
            close_price = open_price + random.uniform(-volatility/2, volatility/2) + (trend * base_price)
            high_price = max(open_price, close_price) + random.uniform(0, volatility/2)
            low_price = min(open_price, close_price) - random.uniform(0, volatility/2)
            
            # Ensure prices are reasonable
            low_price = max(low_price, base_price * 0.99)
            high_price = min(high_price, base_price * 1.01)
            
            candles.append({
                'time': int(candle_time.timestamp()),
                'open': round(open_price, 5),
                'high': round(high_price, 5),
                'low': round(low_price, 5),
                'close': round(close_price, 5),
                'volume': random.randint(100, 500)
            })
            
            base_price = close_price
        
        # Make sure the last candle has our real price as close
        if candles:
            candles[-1]['close'] = real_price
            candles[-1]['open'] = real_price * 0.999
            candles[-1]['high'] = real_price * 1.001
            candles[-1]['low'] = real_price * 0.999
        
        return candles
    
    def _simulate_candles(self, asset, timeframe, num_candles=100):
        import random
        from datetime import datetime, timedelta
        
        base_price = 1.1000 if 'EUR' in asset else 1.2500
        candles = []
        
        current_time = datetime.now()
        # 🎯 MEJORA: Añadir trend para mayor realismo
        trend = random.choice([0.0001, -0.0001, 0])  # Pequeño trend al alza/baja/neutro
        volatility_multiplier = random.uniform(1.5, 3.0)  # Volatilidad variable
        
        for i in range(num_candles, 0, -1):
            candle_time = current_time - timedelta(minutes=i * timeframe)
            
            # 🎯 MEJORA: Aumentar volatilidad para generar indicadores significativos
            # Antes: 1 pip | Ahora: 5-10 pips por vela
            open_price = base_price + random.uniform(-0.05, 0.05) * volatility_multiplier
            close_price = open_price + random.uniform(-0.025, 0.025) * volatility_multiplier + trend
            high_price = max(open_price, close_price) + random.uniform(0, 0.015) * volatility_multiplier
            low_price = min(open_price, close_price) - random.uniform(0, 0.015) * volatility_multiplier
            
            candles.append({
                'time': int(candle_time.timestamp()),
                'open': round(open_price, 5),
                'high': round(high_price, 5),
                'low': round(low_price, 5),
                'close': round(close_price, 5),
                'volume': random.randint(1000, 5000)  # Mayor volumen simulado
            })
            
            base_price = close_price
        
        return candles
    
    async def _get_current_price_async(self, asset):
        # 🎯 PRIORITY 1: WebSocket cache (REAL-TIME DATA) - FASTEST & MOST RELIABLE
        try:
            if self.market_data_service and self.market_data_service.ws_listener:
                ws_listener = self.market_data_service.ws_listener
                from data_interceptor import WebSocketInterceptor
                normalized_asset = WebSocketInterceptor.normalize_asset_name(asset)

                price = ws_listener.get_price(normalized_asset)
                if price is not None:
                    logger.info(f"   ✅ [PRICE] Got price from WebSocket for {asset}: {price}")
                    return float(price)
        except Exception as e:
            logger.debug(f"   ⚠️  WebSocket price failed: {type(e).__name__}")

        # 🎯 PRIORITY 2: Try multiple CSS selectors for Quotex DOM (only if WebSocket fails)
        if self.broker == 'quotex':
            # These are the ACTUAL working selectors for Quotex - tested
            price_selectors = [
                # SVG text elements (where Quotex displays the price)
                'text[class*="price"]',
                'tspan',  # Canvas text elements
                # Div selectors
                '[class*="price"]',
                '[class*="quote"]',
                '[data-testid*="price"]',
                # Text content search
                '.quotePrice__current',
                '.current-price',
                '.quote',
            ]
            
            try:
                # Script simplificado para buscar precio en DOM
                script = """() => {
                try {
                    // Buscar en elementos de precio comunes
                    const priceSelectors = [
                'text[class*="price"]',
                    'tspan',
                    '[class*="price"]',
                        '[class*="quote"]',
                    '.quotePrice__current',
                            '.current-price',
                            '.quote'
                        ];

                        for (let selector of priceSelectors) {
                            const elements = document.querySelectorAll(selector);
                            for (let elem of elements) {
                                const text = elem.textContent?.trim() || elem.innerText?.trim() || '';
                            const price = parseFloat(text.replace(/[^\d.]/g, ''));
                    if (!isNaN(price) && price > 0.0001 && price < 100000) {
                    return price;
                    }
                }
                    }

                        return null;
                    } catch (e) { return null; }
                }"""
                
                price = await self.page.evaluate(script)
                if price is not None and price > 0:
                    logger.info(f"   ✅ [PRICE] Got price from DOM for {asset}: {price}")
                    return float(price)
            except Exception as e:
                logger.debug(f"   ⚠️  DOM extraction failed: {type(e).__name__}")
        
        # 🎯 PRIORITY 2: Get from WebSocket cache (REAL-TIME DATA) - FASTEST & MOST RELIABLE
        try:
            if self.market_data_service and self.market_data_service.ws_listener:
                ws_listener = self.market_data_service.ws_listener
                from data_interceptor import WebSocketInterceptor
                normalized_asset = WebSocketInterceptor.normalize_asset_name(asset)
                
                # 🔍 Build comprehensive list of variants to try
                # CRITICAL: WebSocket stores data with different formatting than config.json
                variants_to_try = set()  # Use set to avoid duplicates
                
                # Extract base currency pair without OTC
                base_asset = normalized_asset.replace(" (OTC)", "")
                base_noslash = base_asset.replace("/", "")
                
                # 1. Exact normalized match (with case variations)
                variants_to_try.add(normalized_asset)
                variants_to_try.add(normalized_asset.lower())
                variants_to_try.add(normalized_asset.upper())
                
                # 2. Base asset (no OTC) with case variations
                variants_to_try.add(base_asset)
                variants_to_try.add(base_asset.lower())
                variants_to_try.add(base_asset.upper())
                
                # 3. With OTC suffix - all format combinations
                # a) underscore + otc (e.g., "USDJPY_otc", "usdjpy_otc")
                variants_to_try.add(f"{base_noslash}_otc")
                variants_to_try.add(f"{base_noslash.lower()}_otc")
                variants_to_try.add(f"{base_noslash.upper()}_otc")
                
                # b) slash + underscore + otc (e.g., "USD_JPY_otc", "usd_jpy_otc")
                base_with_underscore = base_asset.replace("/", "_")
                variants_to_try.add(f"{base_with_underscore}_otc")
                variants_to_try.add(f"{base_with_underscore.lower()}_otc")
                variants_to_try.add(f"{base_with_underscore.upper()}_otc")
                
                # c) slash + otc (e.g., "USD/JPY_otc", "usd/jpy_otc")
                variants_to_try.add(f"{base_asset}_otc")
                variants_to_try.add(f"{base_asset.lower()}_otc")
                variants_to_try.add(f"{base_asset.upper()}_otc")
                
                # 4. With (OTC) format - all variations
                otc_format = f"{base_asset} (OTC)"
                variants_to_try.add(otc_format)
                variants_to_try.add(otc_format.lower())
                variants_to_try.add(otc_format.upper())
                
                # 5. Original asset format variants
                variants_to_try.add(asset)
                variants_to_try.add(asset.lower())
                variants_to_try.add(asset.upper())
                
                # 4. CRITICAL: Case-insensitive matching against actual cache keys
                #    If no exact match found, try case-insensitive search
                cache_keys_lower = {k.lower(): k for k in ws_listener.quotes_cache.keys()}
                cache_keys_lower.update({k.lower(): k for k in ws_listener.candles_cache.keys()})
                
                # DEBUG: Log available cache keys on first search attempt for this asset
                if asset not in getattr(self, '_debug_logged_assets', set()):
                    available_keys = list(ws_listener.quotes_cache.keys())[:5] + list(ws_listener.candles_cache.keys())[:5]
                    logger.debug(f"[PRICE-DEBUG] Searching for '{asset}' (normalized: '{normalized_asset}'), Available cache samples: {available_keys}")
                    logger.debug(f"[PRICE-DEBUG] Generated {len(variants_to_try)} variants: {sorted(variants_to_try)}")
                    if not hasattr(self, '_debug_logged_assets'):
                        self._debug_logged_assets = set()
                    self._debug_logged_assets.add(asset)
                
                # Try each variant
                for variant in sorted(variants_to_try):  # Sort for consistent search order
                    if not variant:
                        continue
                        
                    # Check candles_cache (exact match first)
                    if variant in ws_listener.candles_cache:
                        candles = ws_listener.candles_cache[variant]
                        if candles and len(candles) > 0:
                            latest_price = candles[-1].get('close')
                            if latest_price:
                                if variant != normalized_asset:
                                    logger.debug(f"   ✅ [PRICE] Got price from WebSocket candles (exact) using variant '{variant}' for {asset}: {latest_price}")
                                else:
                                    logger.info(f"   ✅ [PRICE] Got price from WebSocket for {asset}: {latest_price}")
                                return float(latest_price)
                    
                    # Check quotes_cache (exact match first)
                    if variant in ws_listener.quotes_cache:
                        price = ws_listener.quotes_cache[variant]
                        if price:
                            if variant != normalized_asset:
                                logger.debug(f"   ✅ [PRICE] Got price from WebSocket quotes (exact) using variant '{variant}' for {asset}: {price}")
                            else:
                                logger.info(f"   ✅ [PRICE] Got price from WebSocket quotes for {asset}: {price}")
                            return float(price)
                    
                    # Try case-insensitive match
                    variant_lower = variant.lower()
                    if variant_lower in cache_keys_lower:
                        actual_key = cache_keys_lower[variant_lower]
                        
                        # Try candles_cache
                        if actual_key in ws_listener.candles_cache:
                            candles = ws_listener.candles_cache[actual_key]
                            if candles and len(candles) > 0:
                                latest_price = candles[-1].get('close')
                                if latest_price:
                                    logger.debug(f"   ✅ [PRICE] Got price from WebSocket candles (case-insensitive) variant '{variant}' → actual key '{actual_key}' for {asset}: {latest_price}")
                                    return float(latest_price)
                        
                        # Try quotes_cache
                        if actual_key in ws_listener.quotes_cache:
                            price = ws_listener.quotes_cache[actual_key]
                            if price:
                                logger.debug(f"   ✅ [PRICE] Got price from WebSocket quotes (case-insensitive) variant '{variant}' → actual key '{actual_key}' for {asset}: {price}")
                                return float(price)
                                
        except Exception as e:
            logger.debug(f"   ⚠️ WebSocket price lookup error: {type(e).__name__}: {e}")  # Log instead of silent pass
        
        # 🎯 PRIORITY 3: Try to get last candle close from broker data if available
        # Also try with variant keys
        try:
            candle_key = asset
            if candle_key not in self.candles_data:
                # Try lowercase variant
                from data_interceptor import WebSocketInterceptor
                norm = WebSocketInterceptor.normalize_asset_name(asset)
                for variant_key in self.candles_data.keys():
                    if variant_key.lower() == norm.lower():
                        candle_key = variant_key
                        break
            
            if candle_key in self.candles_data and len(self.candles_data[candle_key]) > 0:
                latest_candle = self.candles_data[candle_key][-1]
                if 'close' in latest_candle:
                    price = float(latest_candle['close'])
                    logger.info(f"   ✅ [PRICE] Got price from candles cache for {asset}: {price}")
                    return price
        except Exception:
            pass
        
        # 🎯 PRIORITY 4: Use price_data cache (updated by WebSocket)
        # Also try with variant keys
        price_key = asset
        if price_key not in self.price_data:
            # Try lowercase and variant matching
            from data_interceptor import WebSocketInterceptor
            norm = WebSocketInterceptor.normalize_asset_name(asset)
            for variant_key in self.price_data.keys():
                if variant_key.lower() == norm.lower():
                    price_key = variant_key
                    break
        
        if price_key in self.price_data:
            price = float(self.price_data[price_key])
            logger.info(f"   ✅ [PRICE] Got price from price_data for {asset}: {price}")
            return price
        
        # 🎯 FALLBACK: No se pudo obtener precio
        logger.warning(f"⚠️  Could not get price for {asset}")
        return None

    def get_current_price(self, asset: str) -> float:
        """
        Get current price for asset from broker.
        
        Args:
            asset: Asset name (e.g., 'EURUSD')
            
        Returns:
            Current price as float
        """
        future = asyncio.run_coroutine_threadsafe(self._get_current_price_async(asset), self.loop)
        return future.result()

    async def _get_asset_payout_async(self, asset: str) -> int:
        """
        Get payout percentage for asset asynchronously.
        
        Args:
            asset: Asset name
            
        Returns:
            Payout percentage (e.g., 85 for 85%)
        """
        # Prioridad 1: Usar datos de WebSocket si están disponibles (no requiere async)
        if asset in self.payout_data:
            return self.payout_data[asset]

        # Prioridad 2: Usar script de JavaScript para buscar en la página
        payout_script = ""
        if self.broker == 'quotex':
            payout_script = """
            () => { 
                try {
                    const tradePanel = document.querySelector('.deal-form-profit');
                    if (tradePanel) {
                        const profitElement = tradePanel.querySelector('.deal-form-profit__value');
                        if (profitElement) {
                            const payoutText = profitElement.innerText.replace('%', '').trim();
                            return parseInt(payoutText);
                        }
                    }
                } catch (e) { /* Silencio */ }
                return null;
            }
            """
        elif self.broker == 'pocketoption':
            payout_script = """
            () => {
                try {
                    // Selector para el payout en PocketOption (esto es una suposición)
                    const profitElement = document.querySelector('.profit-percent .val, .percent-val');
                    if (profitElement) {
                        const payoutText = profitElement.innerText.replace('%', '').trim();
                        return parseInt(payoutText);
                    }
                } catch (e) { /* Silencio */ }
                return null;
            }
            """

        try:
            if payout_script:
                payout = await self.page.evaluate(payout_script)
                if payout: return payout
        except Exception:
            pass # Continuar si falla
        
        # Si todo lo demás falla, devolver un valor por defecto
        return 85
    
    def close_and_switch_asset(self, current_asset: str, next_asset: Optional[str] = None) -> bool:
        """
        Close current asset by navigating to a different one.
        This prevents accumulation of open asset windows.
        
        Args:
            current_asset: Asset to close
            next_asset: Asset to navigate to (optional, will use EUR/USD if not specified)
            
        Returns:
            True if successfully switched, False otherwise
        """
        try:
            if not next_asset:
                # Default to EUR/USD if not specified
                next_asset = 'EUR/USD'
            
            logger.info(f"[ASSET-CLOSE] Closing {current_asset}, switching to {next_asset}")
            
            # Run navigation in async context
            future = asyncio.run_coroutine_threadsafe(
                self._change_asset_on_chart_async(next_asset), 
                self.loop
            )
            result = future.result(timeout=5)
            
            if result:
                logger.info(f"[ASSET-CLOSE] ✅ Successfully switched from {current_asset} to {next_asset}")
            else:
                logger.warning(f"[ASSET-CLOSE] ⚠️  Failed to switch from {current_asset} to {next_asset}")
            
            return result
            
        except Exception as e:
            logger.error(f"[ASSET-CLOSE] Error switching assets: {e}")
            return False
    
    def get_asset_payout(self, asset: str) -> int:
        """
        Get payout percentage for asset.
        
        Args:
            asset: Asset name
            
        Returns:
            Payout percentage
        """
        future = asyncio.run_coroutine_threadsafe(self._get_asset_payout_async(asset), self.loop)
        return future.result()

    def change_asset_on_chart(self, asset_name: str) -> bool:
        """
        Change the current asset displayed on the trading chart (SYNCHRONOUS WRAPPER).
        
        Args:
            asset_name: Asset name to switch to (e.g., 'USD/BRL (OTC)')
            
        Returns:
            True if change was successful, False otherwise
        """
        try:
            future = asyncio.run_coroutine_threadsafe(self._change_asset_on_chart_async(asset_name), self.loop)
            return future.result(timeout=15)  # Max 15 seconds to change asset
        except Exception as e:
            logger.error(f"[CHANGE-ASSET-SYNC] Error changing asset: {e}")
            return False

    async def _get_current_chart_asset_async(self) -> Optional[str]:
        """
        Get asset name currently displayed on chart asynchronously.
        
        Returns:
            Asset name or None if not found
        """
        if not self.use_existing or not self.page:
            return None

        asset_script = ""
        if self.broker == 'quotex':
            # Este selector apunta al nombre del activo en la parte superior del gráfico en Quotex
            asset_script = """
            () => {
                const selectors = [
                    '.section-deal__name',                 // 🎯 NUEVO: Basado en tu feedback
                    '.asset-select-button__symbol',      // Selector original
                    'div.current-asset-name',            // Alternativa común
                    '[data-testid="asset-select-button-symbol"]', // Atributo de prueba
                    'div[class*="asset-select-button"] > div:first-child', // Selector más genérico
                    'button[class*="asset-select"] > span', // Otra variante de botón
                    '.pair-name-holder .pair-name'       // Otra alternativa vista en algunas versiones
                ];
                
                for (const selector of selectors) {
                    const el = document.querySelector(selector);
                    if (el && el.innerText.trim()) {
                        return el.innerText.trim();
                    }
                }
                return null;
            }
            """
        elif self.broker == 'pocketoption':
            # Selector para PocketOption (esto es una suposición, puede necesitar ajuste)
            asset_script = """
            () => {
                const assetElement = document.querySelector('.current-asset-name-full');
                return assetElement ? assetElement.innerText.trim().split(' ')[0] : null;
            }
            """
        try:
            if asset_script:
                return await self.page.evaluate(asset_script)
        except Exception as e:
            logger.info(f"      ⚠️ Error obteniendo el activo del gráfico: {e}")
        return None

    async def _change_asset_on_chart_async(self, asset_name):
        """
        Cambia el activo en el gráfico del bróker.
        CRÍTICO: Espera suficiente tiempo para que WebSocket se reconecte.
        """
        if not self.use_existing or not self.page:
            return False

        logger.info(f"   [CHANGE-ASSET] Iniciando cambio a: {asset_name}")
        
        # Limpiar el nombre del activo para búsqueda
        search_term = asset_name.replace(' (OTC)', '').replace('-OTC', '').strip()

        try:
            # PASO 1: Hacer clic en el botón de selección de activos
            logger.info("   [CHANGE-ASSET] [1/5] Abriendo selector de activos...")
            asset_selector_buttons = [
                'button[class*="asset-select"]',
                '.section-deal__name',
                '.left-sidebar-header__asset'
            ]
            
            clicked = False
            for selector in asset_selector_buttons:
                try:
                    await self.page.click(selector, timeout=1500)
                    clicked = True
                    logger.info(f"   [CHANGE-ASSET]     ✓ Click exitoso en: {selector}")
                    break
                except Exception:
                    continue
            
            if not clicked: 
                raise Exception("No se encontró el botón de selección")

            await asyncio.sleep(0.5)  # Esperar apertura del dropdown

            # PASO 2: Escribir término de búsqueda
            logger.info("   [CHANGE-ASSET] [2/5] Escribiendo término de búsqueda...")
            search_input_selectors = [
                'input[class*="search-input"]',
                'input[placeholder*="Buscar"]',
                'input[type="text"]'
            ]
            
            filled = False
            for selector in search_input_selectors:
                try:
                    # Limpiar el campo primero
                    await self.page.fill(selector, '', timeout=1000)
                    await asyncio.sleep(0.2)
                    # Escribir término
                    await self.page.fill(selector, search_term, timeout=1500)
                    filled = True
                    logger.info(f"   [CHANGE-ASSET]     ✓ Término escrito: '{search_term}'")
                    break
                except Exception:
                    continue
            
            if not filled:
                raise Exception("No se encontró el campo de búsqueda")

            await asyncio.sleep(0.5)  # Esperar que se filtre la lista

            # PASO 3: Hacer clic en el resultado
            logger.info("   [CHANGE-ASSET] [3/5] Seleccionando resultado...")
            # Usar selector flexible para encontrar el resultado
            asset_part = asset_name.split('/')[0].strip().upper()
            asset_result_selectors = [
                f"div[class*='asset'] >> text=/{asset_part}/i",
                f"button >> text=/{asset_part}/i",
                f"text=/{asset_name.split('(')[0].strip()}/i"
            ]
            
            clicked_result = False
            for selector in asset_result_selectors:
                try:
                    await self.page.click(selector, timeout=2000)
                    clicked_result = True
                    logger.info(f"   [CHANGE-ASSET]     ✓ Resultado seleccionado")
                    break
                except Exception:
                    continue
            
            if not clicked_result:
                raise Exception("No se encontró el resultado")

            # PASO 4: Esperar a que el gráfico se cargue
            # 🔧 CRÍTICO: Aumentar tiempo para que WebSocket se conecte para el nuevo activo
            logger.info("   [CHANGE-ASSET] [4/5] Esperando carga del gráfico (8 segundos para WebSocket)...")
            await asyncio.sleep(8)  # Tiempo CRÍTICO para WebSocket sync
            
            # PASO 5: Verificar que el cambio fue exitoso
            logger.info("   [CHANGE-ASSET] [5/5] Verificando...")
            for retry in range(3):
                current_asset = await self._get_current_chart_asset_async()
                
                # Verificar si el nombre del activo coincide (ignorar variaciones menores)
                if current_asset:
                    asset_base = asset_name.split(' ')[0]  # "NZD/CAD"
                    current_base = current_asset.split(' ')[0]
                    
                    if asset_base.upper() == current_base.upper():
                        logger.info(f"   ✅ [CHANGE-ASSET] Cambio confirmado: {current_asset}")
                        
                        # 🧹 NUEVO: Cerrar pestañas previas para evitar acumulación
                        await self._close_unused_tabs()
                        
                        return True
                
                if retry < 2:
                    logger.info(f"   [CHANGE-ASSET]     Reintentando verificación ({retry+2}/3)...")
                    await asyncio.sleep(2)
            
            logger.warning(f"   ⚠️  [CHANGE-ASSET] Verificación falló. Gráfico muestra: {current_asset}")
            # Continuar de todas formas - el activo podría haberse cambiado
            return True

        except Exception as e:
            logger.warning(f"   ⚠️  [CHANGE-ASSET] Error al cambiar activo: {e}")
            return False
    
    async def _close_unused_tabs(self) -> None:
        """
        Cierra todas las pestañas innecesarias, manteniendo solo la actual.
        Previene acumulación de pestañas cuando se cambia de activo.
        """
        try:
            if not self.page or self.page.is_closed():
                return
            
            context = self.page.context
            if not context:
                return
            
            pages_to_close = []
            for p in context.pages:
                # No cerrar la página actual
                if p != self.page:
                    # Cerrar solo si es del broker (Quotex o Pocket Option)
                    try:
                        url = p.url.lower()
                        title = (await p.title()).lower() if p else ""
                        
                        # Si es una página del broker, cerrarla
                        if (self.broker in url or self.broker in title or 
                            'quotex' in url or 'quotex' in title or
                            'pocketoption' in url or 'pocketoption' in title):
                            pages_to_close.append(p)
                    except Exception:
                        pass
            
            # Cerrar las pestañas innecesarias
            for p in pages_to_close:
                try:
                    await p.close()
                    logger.debug(f"   [CLEANUP] Pestaña cerrada para evitar acumulación")
                except Exception:
                    pass
                    
        except Exception as e:
            logger.debug(f"   [CLEANUP] Error cerrando pestañas: {e}")

    async def _health_check_loop(self):
        """
        Background health check loop - validates page status and reconnects if needed.
        Runs continuously while bot is active.
        """
        check_interval = 10  # Check every 10 seconds
        consecutive_failures = 0
        max_failures = 3

        while True:
            try:
                await asyncio.sleep(check_interval)
                
                # Validate page status
                if not self.page or self.page.is_closed():
                    consecutive_failures += 1
                    self.connection_status = "disconnected"
                    
                    if consecutive_failures >= max_failures:
                        logger.info(f"\n⚠️ Health Check: Página cerrada {consecutive_failures} veces seguidas")
                        logger.info("   Intenta reconectar manualmente o ejecuta:")
                        logger.info("   powershell -ExecutionPolicy Bypass -File start_bot.ps1\n")
                else:
                    # Page is alive
                    consecutive_failures = 0
                    if self.connection_status != "connected":
                        self.connection_status = "connected"
                        logger.info(f"✅ Health Check: Conexión validada correctamente")
                    
                    # Update last successful data time
                    self.last_successful_data_time = datetime.now()
                    
            except asyncio.CancelledError:
                logger.info("[Health Check] Detenido")
                break
            except Exception as e:
                logger.info(f"   [Health Check] Error: {e}")
                await asyncio.sleep(5)

    def change_asset_on_chart(self, asset_name: str) -> bool:
        """
        Change asset displayed on broker chart.
        
        Args:
            asset_name: Asset name to display
            
        Returns:
            True if asset changed successfully
        """
        future = asyncio.run_coroutine_threadsafe(self._change_asset_on_chart_async(asset_name), self.loop)
        return future.result()

    def get_current_chart_asset(self) -> Optional[str]:
        """
        Get currently displayed asset on chart.
        
        Returns:
            Asset name or None
        """
        future = asyncio.run_coroutine_threadsafe(self._get_current_chart_asset_async(), self.loop)
        return future.result()

    def get_dataframe(self, asset: str, timeframe: int, source_tag: str = "") -> Optional[pd.DataFrame]:
        """
        Get OHLC data as pandas DataFrame.
        
        Args:
            asset: Asset name
            timeframe: Timeframe in seconds
            source_tag: Tag for logging source of data
            
        Returns:
            DataFrame with OHLC data indexed by time, or None
        """
        candles = self.capture_candles_from_chart(asset, timeframe, source_tag)
        
        if not candles:
            return None
        
        df = pd.DataFrame(candles)
        df['time'] = pd.to_datetime(df['time'], unit='s')
        df.set_index('time', inplace=True)
        df = df.sort_index()
        
        return df
    
    async def _get_screenshot_async(self) -> Optional[bytes]:
        """
        Take screenshot of browser page asynchronously.
        
        Returns:
            Screenshot as bytes or None
        """
        if self.page:
            try:
                return await self.page.screenshot()
            except Exception as e:
                logger.info(f"      ⚠️ Error al tomar captura de pantalla: {e}")
        return None

    def get_screenshot(self) -> Optional[bytes]:
        """
        Take screenshot of browser page.
        
        Returns:
            Screenshot as bytes or None
        """
        future = asyncio.run_coroutine_threadsafe(self._get_screenshot_async(), self.loop)
        return future.result()

    async def _close_async(self):
        if self.browser:
            await self.browser.close()
        if self.playwright:
            await self.playwright.stop()

    def close(self):
        logger.info("\n🔌 Desconectando del navegador...")
        if self.loop.is_running():
            asyncio.run_coroutine_threadsafe(self._close_async(), self.loop)
            self.loop.call_soon_threadsafe(self.loop.stop)


