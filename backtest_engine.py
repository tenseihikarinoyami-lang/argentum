"""
Advanced Backtesting Engine - Fase 2
Framework para simular estrategia sobre datos históricos.
Permite optimizar indicadores y pesos del ML ensemble.
"""

import logging
import json
from typing import Dict, List, Tuple, Any, Optional
from datetime import datetime, timedelta
import pandas as pd
import numpy as np
from dataclasses import dataclass, asdict
import pickle

logger = logging.getLogger(__name__)


@dataclass
class BacktestResult:
    """Resultado de una operación en el backtest."""
    trade_id: int
    asset: str
    direction: str
    entry_price: float
    entry_time: datetime
    exit_price: float
    exit_time: datetime
    timeframe: int
    confidence: float
    payout: float
    result: str  # 'win', 'loss', 'draw'
    profit_loss: float
    strategy_used: str


@dataclass
class BacktestStats:
    """Estadísticas agregadas del backtest."""
    total_trades: int
    wins: int
    losses: int
    draws: int
    win_rate: float
    total_profit: float
    total_loss: float
    net_profit: float
    profit_factor: float
    avg_win: float
    avg_loss: float
    max_consecutive_wins: int
    max_consecutive_losses: int
    sharpe_ratio: float
    max_drawdown: float


class BacktestEngine:
    """
    Motor de backtesting avanzado.
    
    Características:
    - Simula operaciones en datos históricos
    - Calcula estadísticas detalladas
    - Permite optimización de parámetros
    - Soporta múltiples assets y timeframes
    """
    
    def __init__(self, config: Dict[str, Any], ml_model, signal_generator):
        """
        Inicializa el motor de backtesting.
        
        Args:
            config: Configuración del bot
            ml_model: Instancia del modelo ML
            signal_generator: Generador de señales
        """
        self.config = config
        self.ml_model = ml_model
        self.signal_generator = signal_generator
        
        # Estado del backtest
        self.trades: List[BacktestResult] = []
        self.stats: Optional[BacktestStats] = None
        self.equity_curve: List[float] = []
        
        # Parámetros de comisiones y costos (CRÍTICO PARA REALISMO)
        self.commission_per_trade = 0.001  # 0.1% comisión por operación
        self.slippage_pips = 1.5  # Pips de slippage (entrada)
        self.spread_multiplier = 0.5  # Multiplicador del spread del broker
        
        logger.info("[BACKTEST] BacktestEngine inicializado")
    
    def run_backtest(
        self,
        asset: str,
        dataframe: pd.DataFrame,
        timeframe: int = 1,
        initial_capital: float = 1000.0,
        risk_per_trade: float = 0.01,
        payout: float = 0.85,
        commission_per_trade: Optional[float] = None,
        slippage_pips: Optional[float] = None,
        apply_realistic_costs: bool = True
    ) -> BacktestStats:
        """
        Ejecuta un backtest completo sobre datos históricos.
        
        Args:
            asset: Símbolo del activo
            dataframe: DataFrame con datos OHLCV históricos
            timeframe: Timeframe en minutos
            initial_capital: Capital inicial
            risk_per_trade: Riesgo por operación (fracción)
            payout: Payout del broker (ej 0.85 = 85%)
            commission_per_trade: Comisión por trade (default 0.1%)
            slippage_pips: Pips de slippage (default 1.5)
            apply_realistic_costs: Si True, aplica comisiones y slippage
            
        Returns:
            BacktestStats con resultados
        """
        # Usar comisiones personalizadas o las por defecto
        commission = commission_per_trade if commission_per_trade is not None else self.commission_per_trade
        slippage = slippage_pips if slippage_pips is not None else self.slippage_pips
        try:
            logger.info(f"[BACKTEST] Iniciando backtest para {asset} ({len(dataframe)} candles)")
            
            self.trades = []
            self.equity_curve = [initial_capital]
            current_capital = initial_capital
            
            # Iterar sobre datos históricos
            for i in range(20, len(dataframe)):  # Necesitamos 20 candles de histórico
                df_slice = dataframe.iloc[:i+1].copy()
                
                # Calcular indicadores para este punto
                from indicators_optimizer import IndicatorsOptimizer
                indicators_calc = IndicatorsOptimizer(self.config)
                indicators = indicators_calc.calculate_all_optimized(df_slice)
                
                if not indicators:
                    continue
                
                # Generar señal
                signal = self.signal_generator.generate_signal(
                    asset, indicators, is_otc=False, aggressive_mode=False
                )
                
                if not signal:
                    self.equity_curve.append(current_capital)
                    continue
                
                # Determinar si ejecutar
                min_confidence = self.config.get('ml_settings', {}).get('min_confidence', 0.60)
                if signal.get('confidence', 0) < min_confidence:
                    self.equity_curve.append(current_capital)
                    continue
                
                # Simular operación
                entry_price = df_slice.iloc[-1]['close']
                exit_idx = min(i + (timeframe * 3), len(dataframe) - 1)  # Timeframe * 3 candles
                exit_price = dataframe.iloc[exit_idx]['close']
                
                # CRÍTICO: Aplicar slippage realista a los precios
                if apply_realistic_costs:
                    # Slippage favorece al mercado en contra nuestra
                    # En CALL: entrada peor (sube slippage), salida peor (baja slippage)
                    # En PUT: entrada peor (baja slippage), salida peor (sube slippage)
                    pip_value = entry_price * 0.0001  # 1 pip
                    is_call = signal['direction'] == 'CALL'
                    
                    # Ajustar entrada por slippage
                    entry_price_adjusted = entry_price + (slippage * pip_value if is_call else -slippage * pip_value)
                    # Ajustar salida por slippage
                    exit_price_adjusted = exit_price - (slippage * pip_value if is_call else slippage * pip_value)
                else:
                    entry_price_adjusted = entry_price
                    exit_price_adjusted = exit_price
                
                # Calcular resultado
                is_call = signal['direction'] == 'CALL'
                won = (exit_price_adjusted > entry_price_adjusted) if is_call else (exit_price_adjusted < entry_price_adjusted)
                
                # Calcular P&L
                trade_amount = current_capital * risk_per_trade
                if won:
                    profit = trade_amount * payout
                    result = 'win'
                else:
                    profit = -trade_amount
                    result = 'loss'
                
                # CRÍTICO: Restar comisión en ganancia y pérdida
                if apply_realistic_costs:
                    commission_cost = trade_amount * commission
                    profit -= commission_cost
                    logger.debug(f"[BACKTEST] {asset} {result.upper()}: payout=${profit+commission_cost:.2f} - commission=${commission_cost:.2f} = ${profit:.2f}")
                
                # Registrar operación
                trade = BacktestResult(
                    trade_id=len(self.trades),
                    asset=asset,
                    direction=signal['direction'],
                    entry_price=entry_price,
                    entry_time=df_slice.index[-1],
                    exit_price=exit_price,
                    exit_time=dataframe.index[exit_idx],
                    timeframe=timeframe,
                    confidence=signal.get('confidence', 0),
                    payout=payout,
                    result=result,
                    profit_loss=profit,
                    strategy_used=signal.get('strategy', 'HYBRID')
                )
                
                self.trades.append(trade)
                current_capital += profit
                self.equity_curve.append(current_capital)
            
            # Calcular estadísticas
            self.stats = self._calculate_stats(initial_capital)
            
            logger.info(f"[BACKTEST] ✅ Backtest completado: {self.stats.total_trades} operaciones")
            logger.info(f"[BACKTEST] WinRate: {self.stats.win_rate*100:.1f}% | Net Profit: ${self.stats.net_profit:.2f}")
            
            return self.stats
            
        except Exception as e:
            logger.error(f"[BACKTEST] Error ejecutando backtest: {e}")
            raise
    
    def _calculate_stats(self, initial_capital: float) -> BacktestStats:
        """
        Calcula estadísticas detalladas del backtest.
        
        Args:
            initial_capital: Capital inicial
            
        Returns:
            BacktestStats con resultados
        """
        if not self.trades:
            return BacktestStats(
                total_trades=0, wins=0, losses=0, draws=0,
                win_rate=0, total_profit=0, total_loss=0,
                net_profit=0, profit_factor=0, avg_win=0, avg_loss=0,
                max_consecutive_wins=0, max_consecutive_losses=0,
                sharpe_ratio=0, max_drawdown=0
            )
        
        # Contar resultados
        wins = sum(1 for t in self.trades if t.result == 'win')
        losses = sum(1 for t in self.trades if t.result == 'loss')
        draws = sum(1 for t in self.trades if t.result == 'draw')
        
        # P&L
        total_profit = sum(t.profit_loss for t in self.trades if t.profit_loss > 0)
        total_loss = abs(sum(t.profit_loss for t in self.trades if t.profit_loss < 0))
        net_profit = total_profit - total_loss
        
        # Ratios
        win_rate = wins / len(self.trades) if self.trades else 0
        profit_factor = total_profit / total_loss if total_loss > 0 else 0
        avg_win = total_profit / wins if wins > 0 else 0
        avg_loss = total_loss / losses if losses > 0 else 0
        
        # Rachas consecutivas
        max_wins = 0
        max_losses = 0
        current_wins = 0
        current_losses = 0
        
        for trade in self.trades:
            if trade.result == 'win':
                current_wins += 1
                current_losses = 0
                max_wins = max(max_wins, current_wins)
            elif trade.result == 'loss':
                current_losses += 1
                current_wins = 0
                max_losses = max(max_losses, current_losses)
        
        # Sharpe Ratio
        if len(self.equity_curve) > 1:
            returns = np.diff(self.equity_curve) / self.equity_curve[:-1]
            sharpe_ratio = np.mean(returns) / np.std(returns) * np.sqrt(252) if np.std(returns) > 0 else 0
        else:
            sharpe_ratio = 0
        
        # Max Drawdown
        max_drawdown = self._calculate_max_drawdown()
        
        return BacktestStats(
            total_trades=len(self.trades),
            wins=wins,
            losses=losses,
            draws=draws,
            win_rate=win_rate,
            total_profit=total_profit,
            total_loss=total_loss,
            net_profit=net_profit,
            profit_factor=profit_factor,
            avg_win=avg_win,
            avg_loss=avg_loss,
            max_consecutive_wins=max_wins,
            max_consecutive_losses=max_losses,
            sharpe_ratio=sharpe_ratio,
            max_drawdown=max_drawdown
        )
    
    def _calculate_max_drawdown(self) -> float:
        """
        Calcula el máximo drawdown durante el backtest.
        
        Returns:
            float: Max drawdown como porcentaje
        """
        if not self.equity_curve or len(self.equity_curve) < 2:
            return 0
        
        max_equity = self.equity_curve[0]
        max_dd = 0
        
        for equity in self.equity_curve:
            if equity > max_equity:
                max_equity = equity
            dd = (max_equity - equity) / max_equity
            max_dd = max(max_dd, dd)
        
        return max_dd
    
    def get_results(self) -> Dict[str, Any]:
        """
        Obtiene resultados del backtest.
        
        Returns:
            Dict con todos los detalles
        """
        if not self.stats:
            return {}
        
        return {
            'stats': asdict(self.stats),
            'trades_count': len(self.trades),
            'equity_curve': self.equity_curve,
            'average_confidence': np.mean([t.confidence for t in self.trades]) if self.trades else 0
        }
    
    def optimize_parameters(
        self,
        asset: str,
        dataframe: pd.DataFrame,
        param_ranges: Dict[str, List[float]]
    ) -> Dict[str, Any]:
        """
        Optimiza parámetros usando grid search.
        
        Args:
            asset: Símbolo del activo
            dataframe: DataFrame histórico
            param_ranges: Rangos de parámetros a probar
            
        Returns:
            Dict con configuración óptima
        """
        logger.info("[BACKTEST-OPT] Iniciando optimización de parámetros...")
        
        best_stats = None
        best_params = None
        best_win_rate = 0
        
        # Grid search simple (puede mejorarse con Bayesian optimization)
        # Por ahora: variar min_confidence
        for min_conf in param_ranges.get('min_confidence', [0.60]):
            # Ajustar config temporalmente
            original_min_conf = self.config['ml_settings']['min_confidence']
            self.config['ml_settings']['min_confidence'] = min_conf
            
            try:
                stats = self.run_backtest(asset, dataframe)
                
                if stats.win_rate > best_win_rate:
                    best_win_rate = stats.win_rate
                    best_stats = stats
                    best_params = {'min_confidence': min_conf}
                
                logger.info(f"[BACKTEST-OPT] min_conf={min_conf}: WR={stats.win_rate*100:.1f}%")
            
            finally:
                self.config['ml_settings']['min_confidence'] = original_min_conf
        
        logger.info(f"[BACKTEST-OPT] ✅ Parámetros óptimos encontrados: {best_params}")
        
        return {
            'optimal_params': best_params,
            'best_stats': asdict(best_stats) if best_stats else None
        }


if __name__ == '__main__':
    print("✅ BacktestEngine module ready")
