# Liq Sweep + UT Bot Reversal Strategy - XAUUSD M1 (Jun 14-16 2026)
## Test Date: 2026.06.16

## Core Concept
Multi-timeframe reversal: liquidity sweep on M1, trend alignment with UT Bot M10,
volatility bounded by ATR15 < 12, confirmed by M1 candle direction.

Entry conditions:
1. ATR(15m) < 12 — bounded volatility, not a mega-trend day
2. Liq sweep M1 — price wicks past swing high/low and closes back inside
3. UT Bot M10 aligned — bias matches trade direction (no ceiling on how long it's been bullish/bearish)
4. M1 candle confirms — bullish candle for buys, bearish for sells

## Results (Jun 14-16 2026, XAUUSD, 1% risk)

| Metric | Value |
|--------|-------|
| Total Net Profit | +527.38 |
| Profit Factor | 1.66 |
| Total Trades | 22 (~14/day) |
| Win Rate | 63.64% |
| Sharpe Ratio | 18.86 |
| Max DD (equity) | 3.76% |
| Avg trade duration | 44 min |

### Per-Strategy

| Strategy | Trades | Wins | Loss | Win% | PnL |
|---|---|---|---|---|---|
| liq_sweep_utbot_buy | 4 | 4 | 0 | 100% | +392 |
| liq_sweep_fresh_sell | 10 | 6 | 4 | 60% | +200 |
| liq_sweep_utbot_sell | 1 | 1 | 0 | 100% | +96 |
| liq_sweep_fresh_buy | 7 | 3 | 4 | 43% | -161 |

## Key Insight
The UT Bot without ceiling (just `bias==BULLISH`) outperforms the `bullish_since<=10` version
for buy signals. The "fresh" version (<=10) works better for sell signals.
This makes sense: on range days, established trends are more reliable for buys,
while fresher signals are better for sells.

## Files
- Config: `presets/gold/9-trend-scalp-atr-12.yaml` (updated)
- Report: `past_tests/scalp_range_20260616/`