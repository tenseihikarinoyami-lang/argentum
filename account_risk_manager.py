"""
Account Risk Manager - Gestión de riesgo a nivel de cuenta

Funcionalidades:
- Monitoreo de drawdown diario y máximo
- Pausa automática si se excede límite
- Tracking de pérdidas consecutivas
- Health score de la cuenta
- Señales de alerta

Tipo: Crítico para Risk Management
Estado: Phase 5 Implementation
"""

from typing import Dict, Any, Optional, List
from datetime import datetime, timedelta
import logging
from logger_config import setup_logger

logger = setup_logger(__name__)


class AccountRiskManager:
    """
    Gestiona el riesgo a nivel de cuenta completa.
    
    Características:
    - Límites de drawdown diario y máximo
    - Pausa automática si se excede
    - Tracking de pérdidas consecutivas
    - Account health score
    - Alertas visuales
    """
    
    def __init__(
        self,
        initial_balance: float = 1000.0,
        max_daily_loss_pct: float = 0.05,      # -5% máximo pérdida diaria
        max_weekly_loss_pct: float = 0.10,     # -10% máximo pérdida semanal
        max_monthly_loss_pct: float = 0.20,    # -20% máximo pérdida mensual
        max_consecutive_losses: int = 5,       # Pausa después de 5 pérdidas
        max_loss_streak_value: float = None    # Pausa si pierde X dinero seguidas
    ):
        """
        Inicializa el AccountRiskManager.
        
        Args:
            initial_balance: Balance inicial
            max_daily_loss_pct: % máximo de pérdida diaria (-5%)
            max_weekly_loss_pct: % máximo de pérdida semanal (-10%)
            max_monthly_loss_pct: % máximo de pérdida mensual (-20%)
            max_consecutive_losses: Número máximo de pérdidas consecutivas
            max_loss_streak_value: Máxima pérdida acumulada en racha (en dinero)
        """
        self.initial_balance = initial_balance
        self.current_balance = initial_balance
        self.max_daily_loss_pct = max_daily_loss_pct
        self.max_weekly_loss_pct = max_weekly_loss_pct
        self.max_monthly_loss_pct = max_monthly_loss_pct
        self.max_consecutive_losses = max_consecutive_losses
        self.max_loss_streak_value = max_loss_streak_value or (initial_balance * 0.10)  # 10% default
        
        # Estado de trading
        self.trading_paused = False
        self.pause_reason = None
        self.pause_until = None
        
        # Tracking de trades
        self.today_trades: List[Dict[str, Any]] = []
        self.this_week_trades: List[Dict[str, Any]] = []
        self.this_month_trades: List[Dict[str, Any]] = []
        self.consecutive_losses_count = 0
        self.consecutive_losses_value = 0.0
        
        # Máximos históricos
        self.highest_balance = initial_balance
        self.max_drawdown_pct = 0.0
        self.max_drawdown_value = 0.0
        
        # Timestamps
        self.day_start = datetime.now()
        self.week_start = datetime.now()
        self.month_start = datetime.now()
        
        logger.info(
            f"AccountRiskManager initialized: "
            f"initial_balance=${initial_balance:.2f}, "
            f"daily_limit={max_daily_loss_pct*100:.1f}%, "
            f"consecutive_loss_limit={max_consecutive_losses}"
        )
    
    def record_trade(
        self,
        asset: str,
        direction: str,
        signal_confidence: float,
        result: str,  # 'win', 'loss', 'draw'
        profit_loss: float,
        trade_size: float
    ) -> Dict[str, Any]:
        """
        Registra un trade completado.
        
        Args:
            asset: Asset operado
            direction: CALL o PUT
            signal_confidence: Confianza de la señal (0-1)
            result: 'win', 'loss', 'draw'
            profit_loss: Ganancia o pérdida en dinero
            trade_size: Tamaño del trade
        
        Returns:
            Dict con análisis del trade y cambios en estado
        """
        timestamp = datetime.now()
        
        # Actualizar balance
        old_balance = self.current_balance
        self.current_balance += profit_loss
        
        # Crear registro de trade
        trade = {
            'timestamp': timestamp,
            'asset': asset,
            'direction': direction,
            'signal_confidence': signal_confidence,
            'result': result,
            'profit_loss': profit_loss,
            'trade_size': trade_size,
            'balance_before': old_balance,
            'balance_after': self.current_balance
        }
        
        # Agregar a listas
        self._clean_and_add_trade(trade)
        
        # Actualizar máximos
        if self.current_balance > self.highest_balance:
            self.highest_balance = self.current_balance
        
        # Calcular drawdown
        drawdown_value = self.highest_balance - self.current_balance
        drawdown_pct = (drawdown_value / self.initial_balance) if self.initial_balance > 0 else 0
        
        if drawdown_pct > self.max_drawdown_pct:
            self.max_drawdown_pct = drawdown_pct
            self.max_drawdown_value = drawdown_value
        
        # Actualizar contador de pérdidas consecutivas
        if result == 'loss':
            self.consecutive_losses_count += 1
            self.consecutive_losses_value += abs(profit_loss)
        else:
            self.consecutive_losses_count = 0
            self.consecutive_losses_value = 0.0
        
        # Análisis de riesgo
        analysis = self._analyze_risk()
        
        # Verificar si debe pausar
        if analysis['should_pause'] and not self.trading_paused:
            self.pause_trading(analysis['pause_reason'])
            analysis['pause_action'] = 'PAUSED'
        
        logger.info(
            f"Trade recorded: {asset} {direction} {result} "
            f"P&L: ${profit_loss:+.2f} | "
            f"Balance: ${old_balance:.2f} → ${self.current_balance:.2f} | "
            f"Health: {analysis['account_health']:.1f}%"
        )
        
        return {
            'trade': trade,
            'balance': self.current_balance,
            'profit_loss': profit_loss,
            'daily_loss': self._get_daily_loss(),
            'drawdown_pct': drawdown_pct * 100,
            'consecutive_losses': self.consecutive_losses_count,
            'risk_analysis': analysis,
            'trading_paused': self.trading_paused
        }
    
    def _clean_and_add_trade(self, trade: Dict[str, Any]) -> None:
        """
        Limpia trades antiguos y agrega nuevo trade a las listas.
        
        Args:
            trade: Trade a agregar
        """
        now = datetime.now()
        
        # Limpiar trades de hace más de 1 día
        self.today_trades = [t for t in self.today_trades 
                            if (now - t['timestamp']).days == 0]
        
        # Limpiar trades de hace más de 1 semana
        self.this_week_trades = [t for t in self.this_week_trades 
                                if (now - t['timestamp']).days < 7]
        
        # Limpiar trades de hace más de 1 mes
        self.this_month_trades = [t for t in self.this_month_trades 
                                 if (now - t['timestamp']).days < 30]
        
        # Agregar nuevo trade
        self.today_trades.append(trade)
        self.this_week_trades.append(trade)
        self.this_month_trades.append(trade)
        
        # Reset si pasó medianoche
        if (now - self.day_start).days > 0:
            self.day_start = now
    
    def _get_daily_loss(self) -> float:
        """
        Calcula la pérdida diaria actual.
        
        Returns:
            Pérdida como porcentaje (-2.5 = -2.5%)
        """
        if not self.today_trades:
            return 0.0
        
        daily_pnl = sum(t['profit_loss'] for t in self.today_trades)
        daily_loss_pct = (daily_pnl / self.initial_balance) * 100
        return daily_loss_pct
    
    def _analyze_risk(self) -> Dict[str, Any]:
        """
        Analiza el riesgo actual de la cuenta.
        
        Returns:
            Dict con métricas de riesgo y recomendaciones
        """
        daily_loss = self._get_daily_loss()
        weekly_loss = self._get_weekly_loss()
        monthly_loss = self._get_monthly_loss()
        
        # Account Health Score (0-100)
        health = 100.0
        pause_reason = None
        should_pause = False
        
        # Penalizar por daily loss
        daily_loss_abs = abs(daily_loss)
        if daily_loss_abs > (self.max_daily_loss_pct * 100 * 0.75):  # 75% del límite
            health -= (daily_loss_abs - (self.max_daily_loss_pct * 100 * 0.75)) * 5
        
        if daily_loss_abs > (self.max_daily_loss_pct * 100):
            should_pause = True
            pause_reason = f"Daily loss exceeded: {daily_loss:.1f}%"
            health = 0.0
        
        # Penalizar por pérdidas consecutivas
        if self.consecutive_losses_count > 0:
            consecutive_severity = (self.consecutive_losses_count / self.max_consecutive_losses)
            health -= consecutive_severity * 20
        
        if self.consecutive_losses_count >= self.max_consecutive_losses:
            should_pause = True
            pause_reason = f"Consecutive losses: {self.consecutive_losses_count}"
            health = 0.0
        
        # Penalizar por racha de pérdidas
        if self.consecutive_losses_value > self.max_loss_streak_value:
            should_pause = True
            pause_reason = f"Loss streak value exceeded: ${self.consecutive_losses_value:.2f}"
            health = 0.0
        
        # Penalizar por drawdown
        drawdown_pct = (self.max_drawdown_pct * 100)
        if drawdown_pct > 10:  # > 10% drawdown
            health -= min(30, drawdown_pct)
        
        # Asegurar que health esté entre 0-100
        health = max(0, min(100, health))
        
        return {
            'account_health': health,
            'daily_loss_pct': daily_loss,
            'weekly_loss_pct': weekly_loss,
            'monthly_loss_pct': monthly_loss,
            'consecutive_losses': self.consecutive_losses_count,
            'drawdown_pct': self.max_drawdown_pct * 100,
            'should_pause': should_pause,
            'pause_reason': pause_reason,
            'alerts': self._generate_alerts(daily_loss, health, self.consecutive_losses_count)
        }
    
    def _get_weekly_loss(self) -> float:
        """Calcula pérdida semanal."""
        if not self.this_week_trades:
            return 0.0
        weekly_pnl = sum(t['profit_loss'] for t in self.this_week_trades)
        return (weekly_pnl / self.initial_balance) * 100
    
    def _get_monthly_loss(self) -> float:
        """Calcula pérdida mensual."""
        if not self.this_month_trades:
            return 0.0
        monthly_pnl = sum(t['profit_loss'] for t in self.this_month_trades)
        return (monthly_pnl / self.initial_balance) * 100
    
    def _generate_alerts(
        self,
        daily_loss: float,
        health: float,
        consecutive_losses: int
    ) -> List[Dict[str, Any]]:
        """
        Genera alertas basadas en métricas de riesgo.
        
        Returns:
            Lista de alertas con nivel y mensaje
        """
        alerts = []
        
        # Alert por daily loss
        if abs(daily_loss) > self.max_daily_loss_pct * 100:
            alerts.append({
                'level': 'danger',
                'message': f'Daily loss exceeded: {daily_loss:.1f}% (limit: {self.max_daily_loss_pct*100:.1f}%)',
                'metric': 'daily_loss'
            })
        elif abs(daily_loss) > self.max_daily_loss_pct * 100 * 0.75:
            alerts.append({
                'level': 'warning',
                'message': f'Daily loss near limit: {daily_loss:.1f}%',
                'metric': 'daily_loss'
            })
        
        # Alert por health
        if health < 50:
            alerts.append({
                'level': 'danger',
                'message': f'Account health critical: {health:.1f}%',
                'metric': 'account_health'
            })
        elif health < 75:
            alerts.append({
                'level': 'warning',
                'message': f'Account health degraded: {health:.1f}%',
                'metric': 'account_health'
            })
        
        # Alert por pérdidas consecutivas
        if consecutive_losses >= self.max_consecutive_losses:
            alerts.append({
                'level': 'danger',
                'message': f'Max consecutive losses reached: {consecutive_losses}',
                'metric': 'consecutive_losses'
            })
        elif consecutive_losses >= 3:
            alerts.append({
                'level': 'warning',
                'message': f'Multiple consecutive losses: {consecutive_losses}',
                'metric': 'consecutive_losses'
            })
        
        return alerts
    
    def pause_trading(self, reason: str, duration_minutes: int = 60) -> None:
        """
        Pausa el trading.
        
        Args:
            reason: Razón de la pausa
            duration_minutes: Duración de la pausa (0 = indefinida hasta reset manual)
        """
        self.trading_paused = True
        self.pause_reason = reason
        if duration_minutes > 0:
            self.pause_until = datetime.now() + timedelta(minutes=duration_minutes)
        
        logger.warning(f"Trading PAUSED: {reason} (until: {self.pause_until})")
    
    def resume_trading(self) -> None:
        """Reanuda el trading."""
        self.trading_paused = False
        self.pause_reason = None
        self.pause_until = None
        logger.info("Trading RESUMED")
    
    def reset_daily(self) -> None:
        """Reset diario (llamar a medianoche)."""
        logger.info("Daily reset executed")
        self.today_trades = []
        self.day_start = datetime.now()
    
    def reset_weekly(self) -> None:
        """Reset semanal (llamar cada lunes a las 00:00)."""
        logger.info("Weekly reset executed")
        self.this_week_trades = []
        self.week_start = datetime.now()
    
    def reset_monthly(self) -> None:
        """Reset mensual (llamar el primer día del mes a las 00:00)."""
        logger.info("Monthly reset executed")
        self.this_month_trades = []
        self.month_start = datetime.now()
    
    def can_trade(self) -> bool:
        """
        Verifica si se puede operar.
        
        Returns:
            True si se puede operar, False si está pausado
        """
        if not self.trading_paused:
            return True
        
        # Si hay fecha de pausa, verificar si ya pasó
        if self.pause_until and datetime.now() > self.pause_until:
            self.resume_trading()
            return True
        
        return False
    
    def get_status(self) -> Dict[str, Any]:
        """
        Obtiene el estado completo de la cuenta.
        
        Returns:
            Dict con métricas y estado actual
        """
        analysis = self._analyze_risk()
        
        return {
            'current_balance': self.current_balance,
            'initial_balance': self.initial_balance,
            'profit_loss': self.current_balance - self.initial_balance,
            'profit_loss_pct': ((self.current_balance - self.initial_balance) / self.initial_balance) * 100,
            'max_balance': self.highest_balance,
            'daily_loss_pct': self._get_daily_loss(),
            'weekly_loss_pct': self._get_weekly_loss(),
            'monthly_loss_pct': self._get_monthly_loss(),
            'max_drawdown_pct': self.max_drawdown_pct * 100,
            'max_drawdown_value': self.max_drawdown_value,
            'consecutive_losses': self.consecutive_losses_count,
            'consecutive_losses_value': self.consecutive_losses_value,
            'account_health': analysis['account_health'],
            'trading_paused': self.trading_paused,
            'pause_reason': self.pause_reason,
            'pause_until': self.pause_until.isoformat() if self.pause_until else None,
            'alerts': analysis['alerts'],
            'total_trades_today': len(self.today_trades),
            'total_trades_week': len(self.this_week_trades),
            'total_trades_month': len(self.this_month_trades)
        }


# Ejemplo de uso
if __name__ == '__main__':
    # Crear manager
    manager = AccountRiskManager(initial_balance=10000)
    
    # Simular algunos trades
    print("=== Recording Trades ===")
    
    result1 = manager.record_trade(
        asset='EURUSD',
        direction='CALL',
        signal_confidence=0.75,
        result='win',
        profit_loss=150,
        trade_size=1000
    )
    print(f"Trade 1: +150 | Balance: ${result1['balance']:.2f} | Health: {result1['risk_analysis']['account_health']:.1f}%")
    
    result2 = manager.record_trade(
        asset='GBPUSD',
        direction='PUT',
        signal_confidence=0.68,
        result='loss',
        profit_loss=-100,
        trade_size=800
    )
    print(f"Trade 2: -100 | Balance: ${result2['balance']:.2f} | Health: {result2['risk_analysis']['account_health']:.1f}%")
    
    result3 = manager.record_trade(
        asset='USDJPY',
        direction='CALL',
        signal_confidence=0.62,
        result='loss',
        profit_loss=-120,
        trade_size=800
    )
    print(f"Trade 3: -120 | Consecutive losses: {result3['consecutive_losses']}")
    
    # Status final
    status = manager.get_status()
    print("\n=== Account Status ===")
    print(f"Balance: ${status['current_balance']:.2f}")
    print(f"Daily Loss: {status['daily_loss_pct']:.2f}%")
    print(f"Account Health: {status['account_health']:.1f}%")
    print(f"Trading Paused: {status['trading_paused']}")
    print(f"Alerts: {len(status['alerts'])}")
    for alert in status['alerts']:
        print(f"  - [{alert['level'].upper()}] {alert['message']}")
