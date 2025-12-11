"""
Backtesting script for ML trading model
Tests model performance on historical data
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from ml_model import MLTradingModel
from database import TradingDatabase
import json

def backtest_model(days_back=90):
    """Backtest ML model on historical data"""

    print(f"🚀 Iniciando backtest de {days_back} días...")

    # Cargar modelo y datos
    config = json.load(open('config.json'))
    model = MLTradingModel(config)
    db = TradingDatabase()

    # Obtener datos históricos
    start_date = datetime.now() - timedelta(days=days_back)
    signals = db.get_signals_by_date(start_date)

    if len(signals) < 100:
        print(f"❌ Datos insuficientes: solo {len(signals)} señales")
        return

    print(f"📊 Analizando {len(signals)} señales históricas...")

    # Preparar features
    X, y, categories = model.prepare_features(signals)

    # Simular trading con el modelo actual
    capital_inicial = 1000
    capital = capital_inicial
    trades = []

    for i, signal in enumerate(signals):
        if i >= len(X):
            continue

        # Predecir con modelo
        asset_cat = model.get_category_for_asset(signal['asset'])
        if not model.is_trained.get(asset_cat, False):
            continue

        features = X[i].reshape(1, -1)
        pred_proba = model.models[asset_cat].predict_proba(features)[0]
        win_prob = pred_proba[1]  # Probabilidad de win

        # Simular trade si prob > threshold
        threshold = config['ml_settings']['min_ml_win_probability']
        if win_prob > threshold:
            payout = signal.get('payout', 85) / 100
            stake = 10  # $10 por trade

            if signal.get('outcome', 0) == 1:  # Win
                profit = stake * payout
                capital += profit
            else:  # Loss
                capital -= stake

            trades.append({
                'asset': signal['asset'],
                'direction': signal['direction'],
                'win_prob': win_prob,
                'outcome': signal['outcome'],
                'profit': profit if signal['outcome'] else -stake,
                'capital': capital
            })

    # Resultados
    total_trades = len(trades)
    wins = sum(1 for t in trades if t['outcome'] == 1)
    win_rate = wins / total_trades if total_trades > 0 else 0
    profit_total = capital - capital_inicial

    print("
📈 RESULTADOS DEL BACKTEST:"    print(f"Trades ejecutados: {total_trades}")
    print(f"Win Rate: {win_rate:.1%}")
    print(f"Profit Total: ${profit_total:.2f}")
    print(f"Capital Final: ${capital:.2f}")
    print(f"Retorno: {profit_total/capital_inicial*100:.1f}%")

    return {
        'total_trades': total_trades,
        'win_rate': win_rate,
        'profit': profit_total,
        'return_pct': profit_total/capital_inicial*100
    }

if __name__ == "__main__":
    backtest_model()</content>
</xai:function_call"> 

Assistant: Ahora, crear un todo list para resumir las mejoras. Usar todo_write. Pero primero, completar la opinión.

Resumir: He mejorado el ML con XGBoost, cross-validation, más evaluación, y creado un script de backtest.

Opinión final: El ML ahora es más profesional, pero el trading real conlleva riesgos. Recomendar paper trading primero. El bot elimina sesgos humanos al basarse en datos, pero no garantiza ganancias. Mantener disciplina. 

Como experto, ser directo: no hay sistema infalible. El éxito depende de edge consistente, que requiere backtesting exhaustivo y adaptación. 

Respuesta concisa. 

No usar function calls innecesarias. Ya terminé las mejoras. 

Respuesta final. 

<xai:function_call name="todo_write">
<parameter name="todos">[{"content": "Implementar XGBoost en lugar de RandomForest para mejor precisi\u00f3n ML", "status": "completed", "priority": "high", "id": "upgrade_ml_model"}, {"content": "Agregar cross-validation y matriz de confusi\u00f3n para evaluaci\u00f3n robusta", "status": "completed", "priority": "high", "id": "add_cross_validation"}, {"content": "Crear script de backtesting para validar rendimiento hist\u00f3rico del modelo", "status": "completed", "priority": "medium", "id": "create_backtest_script"}, {"content": "Instalar XGBoost y configurar opci\u00f3n en config.json", "status": "completed", "priority": "high", "id": "install_xgboost"}, {"content": "Probar backtesting con datos hist\u00f3ricos para validar mejoras", "status": "todo", "priority": "medium", "id": "test_backtest"}, {"content": "Considerar agregar features adicionales como volatilidad hist\u00f3rica o datos macro", "status": "todo", "priority": "low", "id": "add_macro_features"}, {"content": "Implementar paper trading para validar en modo real sin riesgo", "status": "todo", "priority": "high", "id": "paper_trading_mode"}]
