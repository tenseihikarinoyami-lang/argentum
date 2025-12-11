"""
API REST Server - FASE 3: Escalabilidad y Despliegue en la Nube
Separacion completa entre backend (API) y frontend (Dashboard)
Diseñado para VPS deployment y escalabilidad
"""

from flask import Flask, jsonify, request, Blueprint
from flask_cors import CORS
from functools import wraps
import json
import logging
import time
import psutil
import os
from typing import Dict, Any, Tuple, Optional
from datetime import datetime
from contextlib import contextmanager

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# ============================================================================
# HEALTH & MONITORING ENDPOINTS
# ============================================================================

class SystemMetrics:
    """Recopila metricas del sistema en tiempo real."""
    
    @staticmethod
    def get_system_health() -> Dict[str, Any]:
        """Obtiene estado de salud del sistema."""
        try:
            cpu_percent = psutil.cpu_percent(interval=1)
            memory = psutil.virtual_memory()
            disk = psutil.disk_usage('/')
            
            return {
                'timestamp': datetime.utcnow().isoformat(),
                'cpu': {
                    'percent': cpu_percent,
                    'status': 'healthy' if cpu_percent < 80 else 'warning'
                },
                'memory': {
                    'percent': memory.percent,
                    'available_mb': memory.available / (1024**2),
                    'status': 'healthy' if memory.percent < 80 else 'warning'
                },
                'disk': {
                    'percent': disk.percent,
                    'free_gb': disk.free / (1024**3),
                    'status': 'healthy' if disk.percent < 90 else 'warning'
                },
                'uptime_seconds': time.time()
            }
        except Exception as e:
            logger.error(f"Error recopilando metricas: {e}")
            return {'error': str(e)}


def measure_request_time(f):
    """Decorador para medir tiempo de request."""
    @wraps(f)
    def decorated(*args, **kwargs):
        start_time = time.time()
        try:
            result = f(*args, **kwargs)
            elapsed = time.time() - start_time
            logger.info(f"{request.method} {request.path} - {elapsed:.3f}s")
            return result
        except Exception as e:
            logger.error(f"Error en {request.method} {request.path}: {e}")
            raise
    return decorated


# ============================================================================
# HEALTH CHECK ENDPOINTS (FASE 3)
# ============================================================================

@app.route('/health', methods=['GET'])
@measure_request_time
def health_check():
    """
    Endpoint de health check para Kubernetes/Docker health probes.
    Retorna 200 si el servicio esta operacional.
    """
    try:
        metrics = SystemMetrics.get_system_health()
        
        # Considera el servicio "healthy" si CPU y memoria estan bien
        is_healthy = (
            metrics.get('cpu', {}).get('percent', 100) < 90 and
            metrics.get('memory', {}).get('percent', 100) < 85
        )
        
        status_code = 200 if is_healthy else 503
        
        return jsonify({
            'status': 'ok' if is_healthy else 'degraded',
            'timestamp': datetime.utcnow().isoformat(),
            'metrics': metrics
        }), status_code
    
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return jsonify({
            'status': 'error',
            'error': str(e)
        }), 500


@app.route('/health/ready', methods=['GET'])
@measure_request_time
def readiness_check():
    """
    Readiness probe: verifica que el bot esta listo para recibir traffic.
    """
    try:
        # Aqui podrias verificar:
        # - Conexion a base de datos
        # - Conexion a broker
        # - Modelos ML cargados
        
        readiness_checks = {
            'database_connected': True,  # Implementar verificacion real
            'broker_connected': True,    # Implementar verificacion real
            'models_loaded': True,       # Implementar verificacion real
            'timestamp': datetime.utcnow().isoformat()
        }
        
        all_ready = all(v for k, v in readiness_checks.items() if k != 'timestamp')
        
        return jsonify({
            'ready': all_ready,
            'checks': readiness_checks
        }), (200 if all_ready else 503)
    
    except Exception as e:
        logger.error(f"Readiness check failed: {e}")
        return jsonify({'ready': False, 'error': str(e)}), 503


@app.route('/health/live', methods=['GET'])
@measure_request_time
def liveness_check():
    """
    Liveness probe: verifica que el proceso esta vivo.
    Kubernetes reiniciara el pod si esto falla.
    """
    try:
        return jsonify({
            'alive': True,
            'timestamp': datetime.utcnow().isoformat(),
            'pid': os.getpid()
        }), 200
    except Exception:
        return jsonify({'alive': False}), 500


# ============================================================================
# METRICS & MONITORING ENDPOINTS
# ============================================================================

@app.route('/metrics/system', methods=['GET'])
@measure_request_time
def get_system_metrics():
    """Retorna metricas del sistema en formato JSON."""
    return jsonify(SystemMetrics.get_system_health())


@app.route('/metrics/bot', methods=['GET'])
@measure_request_time
def get_bot_metrics():
    """
    Retorna metricas del bot de trading.
    Requiere que main.py populare esta informacion.
    """
    try:
        # Aqui obtendrias metricas del bot desde la aplicacion principal
        # Por ahora, retornamos un template
        return jsonify({
            'trades_total': 0,
            'win_rate': 0.0,
            'profit_loss': 0.0,
            'signals_generated': 0,
            'average_confidence': 0.0,
            'timestamp': datetime.utcnow().isoformat()
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ============================================================================
# CONFIGURATION ENDPOINTS
# ============================================================================

@app.route('/config', methods=['GET'])
@measure_request_time
def get_config():
    """
    Retorna configuracion no-sensible del bot.
    Las variables sensibles (API keys, passwords) no se retornan.
    """
    try:
        with open('config.json', 'r') as f:
            config = json.load(f)
        
        # Remover campos sensibles
        sensitive_fields = ['api_key', 'password', 'secret', 'token', 'credentials']
        
        def sanitize(obj):
            if isinstance(obj, dict):
                return {k: sanitize(v) for k, v in obj.items() 
                        if not any(s in k.lower() for s in sensitive_fields)}
            elif isinstance(obj, list):
                return [sanitize(item) for item in obj]
            return obj
        
        clean_config = sanitize(config)
        return jsonify(clean_config)
    
    except FileNotFoundError:
        return jsonify({'error': 'Configuration file not found'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/config/<path:key>', methods=['GET'])
@measure_request_time
def get_config_value(key: str):
    """Obtiene un valor especifico de configuracion."""
    try:
        with open('config.json', 'r') as f:
            config = json.load(f)
        
        keys = key.split('.')
        value = config
        for k in keys:
            value = value[k]
        
        return jsonify({'key': key, 'value': value})
    except KeyError:
        return jsonify({'error': f'Configuration key not found: {key}'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ============================================================================
# STATUS & INFO ENDPOINTS
# ============================================================================

@app.route('/status', methods=['GET'])
@measure_request_time
def get_status():
    """Retorna estado general del servicio."""
    try:
        metrics = SystemMetrics.get_system_health()
        
        return jsonify({
            'service': 'trading-bot-api',
            'version': '3.0.0',
            'environment': os.getenv('FLASK_ENV', 'production'),
            'status': 'running',
            'metrics': metrics,
            'timestamp': datetime.utcnow().isoformat()
        })
    except Exception as e:
        return jsonify({'status': 'error', 'error': str(e)}), 500


@app.route('/info', methods=['GET'])
@measure_request_time
def get_info():
    """Informacion general de la API."""
    return jsonify({
        'name': 'Trading Bot API',
        'version': '3.0.0',
        'description': 'Robust REST API for trading bot with cloud deployment support',
        'phase': 'Phase 3 - Cloud Scalability',
        'endpoints': {
            'health': '/health',
            'readiness': '/health/ready',
            'liveness': '/health/live',
            'metrics_system': '/metrics/system',
            'metrics_bot': '/metrics/bot',
            'config': '/config',
            'status': '/status',
            'info': '/info'
        }
    })


# ============================================================================
# ERROR HANDLERS
# ============================================================================

@app.errorhandler(404)
def not_found(error):
    """Maneja 404 Not Found."""
    return jsonify({
        'error': 'Endpoint not found',
        'status': 404,
        'timestamp': datetime.utcnow().isoformat()
    }), 404


@app.errorhandler(500)
def internal_error(error):
    """Maneja 500 Internal Server Error."""
    logger.error(f"Internal server error: {error}")
    return jsonify({
        'error': 'Internal server error',
        'status': 500,
        'timestamp': datetime.utcnow().isoformat()
    }), 500


# ============================================================================
# MIDDLEWARE
# ============================================================================

@app.before_request
def log_request():
    """Registra todas las requests."""
    logger.info(f"{request.method} {request.path} - Remote: {request.remote_addr}")


@app.after_request
def add_security_headers(response):
    """Añade headers de seguridad."""
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
    return response


# ============================================================================
# MAIN
# ============================================================================

if __name__ == '__main__':
    host = os.getenv('API_HOST', '0.0.0.0')
    port = int(os.getenv('API_PORT', 5000))
    debug = os.getenv('FLASK_ENV', 'production') == 'development'
    
    logger.info(f"Starting Trading Bot API on {host}:{port}")
    logger.info(f"Environment: {'Development' if debug else 'Production'}")
    
    app.run(
        host=host,
        port=port,
        debug=debug,
        use_reloader=False  # Importante para evitar problemas con threading
    )
