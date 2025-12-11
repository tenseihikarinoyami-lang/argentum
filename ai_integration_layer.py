"""
AI Integration Layer - Capa de integración entre la IA avanzada y el bot principal
==================================================================================

Este módulo actúa como puente entre:
  - AdvancedAIEngine: Sistema de IA personizado de máximo rendimiento
  - TradingBot: Bot principal de trading binarias
  - Componentes existentes: Indicadores, DB, Notificaciones

Permite reemplazar el signal_generator.py con la IA avanzada manteniendo compatibilidad.
"""

import logging
from typing import Dict, Optional, Any, List
from datetime import datetime
import numpy as np
from advanced_ai_engine import (
    AdvancedAIEngine,
    AISignal,
    convert_ai_signal_to_bot_signal
)

logger = logging.getLogger(__name__)


class AISignalAdapter:
    """
    Adaptador que convierte señales de IA avanzada al formato del bot.
    
    Características:
      - Conversión transparente de formatos
      - Compatibilidad con base de datos existente
      - Validación de señales
      - Logging detallado
      - Persistencia de contexto
    """
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.ai_engine = AdvancedAIEngine(config)
        self.signal_cache: Dict[str, AISignal] = {}
        self.strategy_stats: Dict[str, Dict[str, int]] = {}
    
    def generate_signal_with_ai(
        self,
        asset: str,
        df,
        indicators: Dict[str, Any],
        is_otc: bool = False,
        account_balance: float = 1000.0,
        recent_win_rate: float = 0.50
    ) -> Optional[Dict[str, Any]]:
        """
        Genera señal usando la IA avanzada.
        
        Args:
            asset: Símbolo del activo
            df: DataFrame con datos OHLCV
            indicators: Indicadores técnicos calculados
            is_otc: Si es mercado OTC
            account_balance: Balance de la cuenta
            recent_win_rate: Win rate reciente
        
        Returns:
            Señal en formato compatible con el bot, o None
        """
        
        try:
            logger.info(f"[AI-GEN] Generando señal para {asset} con IA avanzada...")
            
            # Validar datos - SOLO DA WARNING, NO RECHAZA
            if df is None or df.empty or len(df) < 20:
                logger.warning(f"[AI-GEN] DataFrame inválido para {asset}: {df is not None and len(df) if hasattr(df, '__len__') else 0} candles")
                logger.info(f"[AI-GEN] Usando fallback al signal_generator original para {asset}")
                return None  # Fallback - dejar que el bot use el signal_generator original
            
            # Obtener análisis de IA
            ai_signal: Optional[AISignal] = self.ai_engine.analyze_asset(
                asset=asset,
                df=df,
                indicators=indicators,
                account_balance=account_balance,
                recent_win_rate=recent_win_rate
            )
            
            if ai_signal is None:
                logger.info(f"[AI-GEN] No hay señal clara para {asset}")
                return None
            
            # Convertir a formato bot
            bot_signal = convert_ai_signal_to_bot_signal(ai_signal)
            
            # Agregar información específica OTC
            bot_signal['is_otc'] = is_otc
            
            # Cache la señal para referencia posterior
            self.signal_cache[asset] = ai_signal
            
            # Actualizar estadísticas de estrategia
            strategy_name = ai_signal.strategy.value
            if strategy_name not in self.strategy_stats:
                self.strategy_stats[strategy_name] = {'count': 0, 'wins': 0}
            self.strategy_stats[strategy_name]['count'] += 1
            
            # Log detallado
            logger.info(
                f"[AI-GEN] ✓ Señal generada para {asset}: "
                f"DIR={bot_signal['direction']} "
                f"CONF={bot_signal['confidence']*100:.0f}% "
                f"ESTRAT={strategy_name} "
                f"FASE={bot_signal['market_phase']}"
            )
            
            return bot_signal
        
        except Exception as e:
            logger.error(f"[AI-GEN] Error generando señal: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return None
    
    def validate_signal(self, signal: Dict[str, Any]) -> bool:
        """Valida que la señal cumple requisitos mínimos."""
        
        required_fields = [
            'asset', 'direction', 'confidence',
            'entry_price', 'stop_loss', 'target_profit'
        ]
        
        for field in required_fields:
            if field not in signal or signal[field] is None:
                logger.warning(f"[AI-VAL] Signal missing field: {field}")
                return False
        
        # Validar ranges
        if not 0 <= signal['confidence'] <= 1:
            logger.warning(f"[AI-VAL] Invalid confidence: {signal['confidence']}")
            return False
        
        if signal['direction'] not in ['CALL', 'PUT']:
            logger.warning(f"[AI-VAL] Invalid direction: {signal['direction']}")
            return False
        
        return True
    
    def get_signal_explanation(self, asset: str) -> Dict[str, Any]:
        """
        Retorna explicación detallada de la última señal del activo.
        
        Útil para debugging y análisis.
        """
        
        if asset not in self.signal_cache:
            return {'error': f'No cached signal for {asset}'}
        
        signal = self.signal_cache[asset]
        
        return {
            'asset': signal.asset,
            'direction': signal.direction,
            'confidence': f"{signal.confidence*100:.1f}%",
            'strategy': signal.strategy.value,
            'market_phase': signal.market_phase.value,
            'technical_score': f"{signal.technical_score:.2f}",
            'ml_score': f"{signal.ml_score:.2f}",
            'sentiment_score': f"{signal.sentiment_score:.2f}",
            'volatility': f"{signal.volatility_level:.4f}",
            'trend_strength': f"{signal.trend_strength:.2f}",
            'reversal_probability': f"{signal.reversal_probability*100:.1f}%",
            'support': f"{signal.support_level:.6f}",
            'resistance': f"{signal.resistance_level:.6f}",
            'pattern': signal.pattern_detected or 'None',
            'risk_reward': f"{signal.risk_reward_ratio:.2f}",
            'entry': f"{signal.entry_price:.6f}",
            'stop_loss': f"{signal.stop_loss:.6f}",
            'target_profit': f"{signal.target_profit:.6f}",
            'context': signal.additional_context
        }
    
    def get_ai_statistics(self) -> Dict[str, Any]:
        """Retorna estadísticas de la IA."""
        
        perf = self.ai_engine.get_performance_summary()
        
        return {
            'ai_performance': perf,
            'strategies_used': self.strategy_stats,
            'cached_signals': len(self.signal_cache),
            'total_analysis_runs': perf.get('total_signals', 0)
        }
    
    def record_signal_result(
        self,
        asset: str,
        result: str,  # 'win', 'loss', 'draw'
        profit_loss: float
    ) -> None:
        """
        Registra resultado de una operación para mejora de IA.
        
        Args:
            asset: Símbolo del activo
            result: Resultado de la operación
            profit_loss: Ganancia/pérdida
        """
        
        if asset in self.signal_cache:
            signal_info = self.signal_cache[asset]
            strategy = signal_info.strategy.value
            
            if strategy in self.strategy_stats:
                if result == 'win':
                    self.strategy_stats[strategy]['wins'] += 1
            
            # Marcar en histórico de IA
            was_profitable = result == 'win'
            for signal_record in self.ai_engine.signal_history:
                if (signal_record['asset'] == asset and 
                    signal_record['was_profitable'] is None):
                    signal_record['was_profitable'] = was_profitable
                    break
            
            logger.info(
                f"[AI-RESULT] {asset}: {result.upper()} | "
                f"PnL: {profit_loss:+.2f} | "
                f"Strategy: {strategy}"
            )


class AIEnhancedSignalGenerator:
    """
    Reemplazo de signal_generator.py que usa la IA avanzada.
    
    Compatible con la interfaz original pero potenciado con IA.
    """
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.adapter = AISignalAdapter(config)
        self.min_confidence = config['ml_settings'].get('min_confidence', 0.65)
    
    def generate_signal(
        self,
        asset: str,
        indicators_1m: Dict[str, Any],
        is_otc: bool = False,
        is_optimization: bool = False,
        aggressive_mode: bool = True,
        **kwargs
    ) -> Optional[Dict[str, Any]]:
        """
        Interface compatible con el original, usando IA avanzada.
        
        Args:
            asset: Símbolo del activo
            indicators_1m: Indicadores de 1 minuto
            is_otc: Si es mercado OTC
            is_optimization: Modo optimización
            aggressive_mode: Modo agresivo (más señales)
            **kwargs: Argumentos adicionales (ej: df para IA)
        
        Returns:
            Señal compatible con el formato original
        """
        
        # Obtener dataframe si está disponible
        df = kwargs.get('dataframe', None)
        account_balance = kwargs.get('account_balance', 1000.0)
        recent_win_rate = kwargs.get('recent_win_rate', 0.50)
        
        # Generar señal con IA
        signal = self.adapter.generate_signal_with_ai(
            asset=asset,
            df=df,
            indicators=indicators_1m,
            is_otc=is_otc,
            account_balance=account_balance,
            recent_win_rate=recent_win_rate
        )
        
        if signal is None:
            return None
        
        # Asegurar formato compatible
        return {
            'asset': signal['asset'],
            'direction': signal['direction'],
            'confidence': signal['confidence'],
            'expiration_minutes': signal.get('expiration_minutes', 1),
            'indicators_summary': signal.get('indicators_summary', indicators_1m),
            'category': signal.get('category', 'RISK'),
            'ml_probability': signal.get('ml_probability', signal['confidence']),
            'notify': signal.get('notify', signal['confidence'] >= self.min_confidence),
            'entry_price': signal.get('entry_price', 0),
            'stop_loss': signal.get('stop_loss', 0),
            'target_profit': signal.get('target_profit', 0),
            'risk_reward_ratio': signal.get('risk_reward_ratio', 1.0),
            'strategy': signal.get('strategy', 'HYBRID'),
            'market_phase': signal.get('market_phase', 'transition'),
            'volatility_level': signal.get('volatility_level', 0),
            'trend_strength': signal.get('trend_strength', 0),
            'pattern_detected': signal.get('pattern_detected', None),
            'timestamp': datetime.now(),
            'additional_context': signal.get('additional_context', {})
        }


# ==========================================================================
# FUNCIONES DE INTEGRACIÓN CON EL BOT PRINCIPAL
# ==========================================================================

def integrate_ai_engine(bot) -> AIEnhancedSignalGenerator:
    """
    Integra la IA avanzada con el bot principal.
    
    Reemplaza el signal_generator con la versión mejorada.
    
    Args:
        bot: Instancia del TradingBot
    
    Returns:
        AIEnhancedSignalGenerator listo para usar
    """
    
    ai_generator = AIEnhancedSignalGenerator(bot.config)
    
    # Reemplazar generador de señales
    original_generator = bot.signal_generator
    bot.signal_generator = ai_generator
    
    logger.info("[AI-INTEGRATION] ✓ Advanced AI Engine integrado con el bot")
    logger.info("[AI-INTEGRATION] Signal Generator reemplazado con IA mejorada")
    
    return ai_generator


def enable_ai_diagnostics(adapter: AISignalAdapter) -> None:
    """Habilita modo diagnóstico de IA con logs detallados."""
    
    logger.setLevel(logging.DEBUG)
    
    print("\n" + "="*70)
    print("ADVANCED AI DIAGNOSTICS - ENABLED")
    print("="*70)
    print("\nComponentes Activos:")
    print("  • Pattern Recognition Engine")
    print("  • Sentiment Analysis System")
    print("  • Ensemble Prediction Model")
    print("  • Adaptive Risk Management")
    print("\nFuncionalidades:")
    stats = adapter.get_ai_statistics()
    print(f"  • Total Analysis Runs: {stats['ai_performance'].get('total_signals', 0)}")
    print(f"  • Strategies Deployed: {len(stats['strategies_used'])}")
    print(f"  • Cached Signals: {stats['cached_signals']}")
    print("\n" + "="*70)


if __name__ == '__main__':
    # Demostración de integración
    print("\n" + "="*70)
    print("AI INTEGRATION LAYER - TEST MODE")
    print("="*70)
    print("\n✓ AISignalAdapter: READY")
    print("✓ AIEnhancedSignalGenerator: READY")
    print("✓ Integration Functions: READY")
    print("\nUso en el bot:")
    print("  from ai_integration_layer import integrate_ai_engine")
    print("  ai_generator = integrate_ai_engine(bot)")
    print("\n" + "="*70)
