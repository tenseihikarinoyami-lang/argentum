"""
Asset Analyzer Visual - Simulates manual user analysis of forex assets
Generates visual representation of asset searches and charts like a user would do manually
"""

import json
import os
from datetime import datetime
from typing import Dict, Any, Optional, List
from broker_capture import BrokerCapture
from logger_config import setup_logger

logger = setup_logger(__name__)


class AssetAnalyzerVisual:
    """Simulates manual user analysis - searches for assets and shows charts like a real user would."""
    
    def __init__(self, config_path: str = 'config.json'):
        """Initialize analyzer with config."""
        try:
            with open(config_path, 'r') as f:
                self.config = json.load(f)
            self.broker = BrokerCapture(broker=self.config['broker'])
            logger.info(f"✅ Asset Analyzer initialized for {self.config['broker']}")
        except Exception as e:
            logger.error(f"❌ Error initializing analyzer: {e}")
            raise
    
    def search_asset_manual(self, asset: str, timeframe: int = 1) -> Dict[str, Any]:
        """
        Simulate manual user search for an asset.
        
        Args:
            asset: Asset symbol (e.g., 'EUR/USD')
            timeframe: Timeframe in minutes
            
        Returns:
            Asset data with metadata
        """
        logger.info(f"\n{'='*70}")
        logger.info(f"🔍 [USER SEARCH] Searching for asset: {asset}")
        logger.info(f"⏱️  Timeframe: {timeframe} minute(s)")
        logger.info(f"⏰ Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        logger.info(f"{'='*70}")
        
        result = {
            'asset': asset,
            'timeframe': timeframe,
            'timestamp': datetime.now().isoformat(),
            'status': 'NOT_FOUND',
            'data': None,
            'price': None,
            'payout': None,
            'error': None
        }
        
        try:
            # Step 1: Get current price (like user would see on screen)
            logger.info(f"📍 [STEP 1] Fetching current price...")
            price = self.broker.get_current_price(asset)
            
            if price is None:
                logger.warning(f"⚠️  [STEP 1] Asset not found or price unavailable")
                result['error'] = 'Price not available'
                return result
            
            result['price'] = price
            logger.info(f"💰 Current price: {price}")
            
            # Step 2: Check payout (like user would see in UI)
            logger.info(f"📊 [STEP 2] Checking payout...")
            try:
                payout = self.broker.get_asset_payout(asset)
                result['payout'] = payout
                logger.info(f"💵 Payout: {payout}%" if payout else "⚠️  Payout: Not available")
            except:
                logger.warning(f"⚠️  Could not fetch payout")
            
            # Step 3: Get chart data (like user would view candlesticks)
            logger.info(f"📈 [STEP 3] Loading chart data ({timeframe}m bars)...")
            df = self.broker.get_dataframe(asset, timeframe, source_tag="[VISUAL-SEARCH]")
            
            if df is None or df.empty:
                logger.warning(f"⚠️  [STEP 3] No chart data available")
                result['error'] = 'Chart data unavailable'
                return result
            
            result['data'] = {
                'total_candles': len(df),
                'latest_candle': {
                    'open': float(df.iloc[-1]['open']) if 'open' in df.columns else None,
                    'high': float(df.iloc[-1]['high']) if 'high' in df.columns else None,
                    'low': float(df.iloc[-1]['low']) if 'low' in df.columns else None,
                    'close': float(df.iloc[-1]['close']) if 'close' in df.columns else None,
                    'volume': float(df.iloc[-1]['volume']) if 'volume' in df.columns else None,
                },
                'chart_preview': self._generate_ascii_chart(df)
            }
            
            logger.info(f"📊 Chart loaded: {len(df)} candles")
            logger.info(f"\n{result['data']['chart_preview']}")
            
            # Step 4: Display key levels (like user would analyze)
            logger.info(f"\n📌 [STEP 4] Analyzing key levels...")
            self._display_key_levels(df, asset, price)
            
            result['status'] = 'SUCCESS'
            logger.info(f"✅ [ANALYSIS COMPLETE] {asset} ready for trading")
            
        except Exception as e:
            logger.error(f"❌ Error analyzing asset: {e}")
            result['error'] = str(e)
            result['status'] = 'ERROR'
        
        return result
    
    def analyze_multiple_assets(self, assets: Optional[List[str]] = None, 
                               top_n: int = 10) -> Dict[str, Dict]:
        """
        Analyze multiple assets like a user scrolling through watchlist.
        
        Args:
            assets: List of assets to analyze (if None, uses config assets)
            top_n: If assets is None, analyze only top N assets
            
        Returns:
            Dictionary of analysis results
        """
        to_analyze = assets or self.config['assets'][:top_n]
        
        logger.info(f"\n{'='*70}")
        logger.info(f"👁️  [BATCH ANALYSIS] Analyzing {len(to_analyze)} assets...")
        logger.info(f"⏰ Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        logger.info(f"{'='*70}\n")
        
        results = {}
        successful = 0
        failed = 0
        
        for i, asset in enumerate(to_analyze, 1):
            logger.info(f"\n[{i}/{len(to_analyze)}] Analyzing {asset}...")
            result = self.search_asset_manual(asset, timeframe=1)
            results[asset] = result
            
            if result['status'] == 'SUCCESS':
                successful += 1
                logger.info(f"✅ {asset}: Price ${result['price']:.4f}")
            else:
                failed += 1
                logger.info(f"❌ {asset}: {result.get('error', 'Unknown error')}")
        
        logger.info(f"\n{'='*70}")
        logger.info(f"📊 [BATCH COMPLETE]")
        logger.info(f"✅ Successful: {successful}")
        logger.info(f"❌ Failed: {failed}")
        logger.info(f"{'='*70}\n")
        
        return results
    
    def _generate_ascii_chart(self, df) -> str:
        """Generate ASCII chart preview like user would see."""
        if df.empty or len(df) < 10:
            return "⚠️  Not enough data for chart"
        
        try:
            # Get last 20 candles
            recent = df.tail(20)
            
            # Get price range
            high = recent['high'].max()
            low = recent['low'].min()
            range_val = high - low
            
            if range_val == 0:
                return "⚠️  Chart unavailable (no price movement)"
            
            # Build ASCII chart
            chart = "📈 Chart Preview (last 20 candles):\n"
            chart += "┌" + "─" * 40 + "┐\n"
            
            for idx, row in recent.iterrows():
                close = row['close']
                high = row['high']
                low = row['low']
                
                # Normalize to 0-40 range
                close_pos = int((close - low) / (high - low) * 40) if (high - low) > 0 else 20
                close_pos = max(0, min(40, close_pos))
                
                # Draw candle
                candle = "│" + " " * close_pos + "●" + " " * (40 - close_pos) + "│"
                chart += candle + "\n"
            
            chart += "└" + "─" * 40 + "┘\n"
            
            return chart
        except Exception as e:
            return f"⚠️  Chart error: {str(e)}"
    
    def _display_key_levels(self, df, asset: str, current_price: float) -> None:
        """Display key support/resistance levels like user would analyze."""
        try:
            recent = df.tail(50)
            
            high_50 = recent['high'].max()
            low_50 = recent['low'].min()
            avg_50 = recent['close'].mean()
            
            logger.info(f"\n📌 [KEY LEVELS for {asset}]")
            logger.info(f"   Resistance (High):     {high_50:.4f}")
            logger.info(f"   Current Price:         {current_price:.4f}")
            logger.info(f"   Support (Low):         {low_50:.4f}")
            logger.info(f"   Average (50 candles):  {avg_50:.4f}")
            
            # Distance analysis
            dist_to_resistance = ((high_50 - current_price) / current_price) * 100
            dist_to_support = ((current_price - low_50) / current_price) * 100
            
            logger.info(f"\n   Distance to Resistance: {dist_to_resistance:+.2f}%")
            logger.info(f"   Distance to Support:    {dist_to_support:+.2f}%")
            
            # Trend assessment
            if current_price > avg_50:
                logger.info(f"   📈 Trend: ABOVE average (Bullish)")
            elif current_price < avg_50:
                logger.info(f"   📉 Trend: BELOW average (Bearish)")
            else:
                logger.info(f"   ➡️  Trend: AT average (Neutral)")
                
        except Exception as e:
            logger.warning(f"⚠️  Could not analyze key levels: {e}")
    
    def generate_html_report(self, results: Dict[str, Dict], 
                           output_file: str = 'asset_analysis_report.html') -> None:
        """Generate beautiful HTML report of analysis like user would see."""
        
        html = """<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Asset Analysis Report</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            padding: 30px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
        }
        
        h1 {
            color: #333;
            text-align: center;
            border-bottom: 3px solid #667eea;
            padding-bottom: 15px;
        }
        
        .timestamp {
            text-align: center;
            color: #666;
            margin-bottom: 20px;
            font-size: 14px;
        }
        
        .stats {
            display: grid;
            grid-template-columns: 1fr 1fr 1fr;
            gap: 20px;
            margin-bottom: 30px;
        }
        
        .stat-box {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 8px;
            text-align: center;
        }
        
        .stat-number {
            font-size: 32px;
            font-weight: bold;
            margin-bottom: 5px;
        }
        
        .stat-label {
            font-size: 14px;
            opacity: 0.9;
        }
        
        .assets-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 20px;
            margin-top: 30px;
        }
        
        .asset-card {
            background: #f8f9fa;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            padding: 20px;
            transition: all 0.3s ease;
        }
        
        .asset-card:hover {
            border-color: #667eea;
            box-shadow: 0 5px 15px rgba(102, 126, 234, 0.2);
        }
        
        .asset-card.success {
            border-left: 5px solid #28a745;
        }
        
        .asset-card.error {
            border-left: 5px solid #dc3545;
        }
        
        .asset-name {
            font-size: 18px;
            font-weight: bold;
            color: #333;
            margin-bottom: 10px;
        }
        
        .asset-price {
            font-size: 24px;
            color: #667eea;
            font-weight: bold;
            margin-bottom: 5px;
        }
        
        .asset-payout {
            color: #28a745;
            font-weight: bold;
            margin-bottom: 10px;
        }
        
        .asset-info {
            font-size: 12px;
            color: #666;
            margin-bottom: 8px;
        }
        
        .asset-status {
            display: inline-block;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: bold;
        }
        
        .status-success {
            background: #d4edda;
            color: #155724;
        }
        
        .status-error {
            background: #f8d7da;
            color: #721c24;
        }
        
        .footer {
            text-align: center;
            color: #999;
            font-size: 12px;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #e0e0e0;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>📊 Asset Analysis Report</h1>
        <div class="timestamp">Generated: """ + datetime.now().strftime('%Y-%m-%d %H:%M:%S') + """</div>
        
        <div class="stats">
"""
        
        # Count statistics
        total = len(results)
        successful = sum(1 for r in results.values() if r['status'] == 'SUCCESS')
        failed = sum(1 for r in results.values() if r['status'] != 'SUCCESS')
        
        html += f"""            <div class="stat-box">
                <div class="stat-number">{total}</div>
                <div class="stat-label">Total Assets Analyzed</div>
            </div>
            <div class="stat-box">
                <div class="stat-number">{successful}</div>
                <div class="stat-label">✅ Successful</div>
            </div>
            <div class="stat-box">
                <div class="stat-number">{failed}</div>
                <div class="stat-label">❌ Failed</div>
            </div>
        </div>
        
        <div class="assets-grid">
"""
        
        # Sort by status then by asset name
        sorted_results = sorted(results.items(), 
                              key=lambda x: (x[1]['status'] != 'SUCCESS', x[0]))
        
        for asset, result in sorted_results:
            status_class = 'success' if result['status'] == 'SUCCESS' else 'error'
            
            html += f"""            <div class="asset-card {status_class}">
                <div class="asset-name">{asset}</div>
"""
            
            if result['status'] == 'SUCCESS' and result['price']:
                html += f"""                <div class="asset-price">${result['price']:.4f}</div>
"""
                if result['payout']:
                    html += f"""                <div class="asset-payout">📈 Payout: {result['payout']}%</div>
"""
                if result['data']:
                    html += f"""                <div class="asset-info">📊 {result['data']['total_candles']} candles loaded</div>
"""
            else:
                html += f"""                <div class="asset-info" style="color: #dc3545;">❌ {result.get('error', 'Unknown error')}</div>
"""
            
            status_text = result['status'].replace('_', ' ')
            status_class_text = 'status-success' if result['status'] == 'SUCCESS' else 'status-error'
            html += f"""                <div class="asset-status {status_class_text}">{status_text}</div>
            </div>
"""
        
        html += """        </div>
        
        <div class="footer">
            <p>🤖 Automated Asset Analysis - Simulating Manual User Research</p>
            <p>Quotex Trading Bot v4.0</p>
        </div>
    </div>
</body>
</html>"""
        
        try:
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write(html)
            logger.info(f"✅ HTML report generated: {output_file}")
        except Exception as e:
            logger.error(f"❌ Error generating HTML report: {e}")


if __name__ == "__main__":
    # Example usage
    analyzer = AssetAnalyzerVisual()
    
    # Option 1: Analyze single asset
    logger.info("\n" + "="*70)
    logger.info("EXAMPLE 1: Single Asset Analysis (Manual Search)")
    logger.info("="*70)
    result = analyzer.search_asset_manual("EUR/USD", timeframe=1)
    
    # Option 2: Analyze multiple assets
    logger.info("\n" + "="*70)
    logger.info("EXAMPLE 2: Batch Analysis (Like Scrolling Watchlist)")
    logger.info("="*70)
    results = analyzer.analyze_multiple_assets(top_n=5)
    
    # Option 3: Generate HTML report
    analyzer.generate_html_report(results)