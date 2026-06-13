# Master Strategy List — All Profitable Strategies

All strategies tested across Workers 1-5 that achieved PF > 1.2 standalone.
**Test window:** 2026.04.13 – 2026.06.13 (2 months), BTCUSDT, M1 chart, $10k, 1:100 leverage.
Settings tested at: SL=350, no breakeven, single strategy per backtest.

---

## Liquidity Sweep Family (Worker 5)

| # | Name | Buy Expression | Sell Expression | SL | RR | PF | WR | Trades | PnL |
|---|------|---------------|----------------|----|----|----|----|--------|-----|
| L1 | Sweep + Stoch | `liq_M15.lower_swept==TRUE\|stoch_M15.zone==OS\|candle_M3.is_bullish==TRUE\|ema200_M15.price_vs==ABOVE` | `liq_M15.upper_swept==TRUE\|stoch_M15.zone==OB\|candle_M3.is_bearish==TRUE\|ema200_M15.price_vs==BELOW` | 350 | 2.0 | **2.00** | 50% | 28 | +$4,769 |
| L2 | Sweep + Stoch + Est Trend | `liq_M15.lower_swept==TRUE\|stoch_M15.zone==OS\|candle_M3.is_bullish==TRUE\|utbot_H1.bias==BULLISH\|utbot_H1.bullish_since>=5\|ema200_M15.price_vs==ABOVE` | mirror sell | 350 | 2.0 | **1.97** | 50% | 22 | +$3,566 |
| L3 | Triple Rejection (Sweep+BB) | `liq_M15.lower_swept==TRUE\|bb_M15.reenter_below==TRUE\|candle_M3.is_bullish==TRUE\|utbot_H1.bias==BULLISH` | mirror sell | 350 | 2.0 | **1.80** | 46% | 24 | +$3,104 |

## Trend/Momentum Family (Worker 4)

| # | Name | Buy Expression | Sell Expression | SL | RR | PF | WR | Trades | PnL |
|---|------|---------------|----------------|----|----|----|----|--------|-----|
| T1 | VWAP Trend | `vwap_M5.price_vs==BELOW\|utbot_H1.bias==BULLISH\|candle_M3.is_bullish==TRUE\|ema200_M15.price_vs==ABOVE` | mirror sell | 350 | 1.5 | **1.42** | 47% | 68 | +$1,295 |
| T2 | Stoch Combo Wide | `stoch_M15.zone in OS,NEUTRAL\|utbot_H1.bias==BULLISH\|vwap_M5.price_vs==BELOW\|ema200_M15.price_vs==ABOVE\|adx_M15.strength in STRONG_TREND,TRENDING\|candle_M3.is_bullish==TRUE` | mirror sell | 350 | 1.5 | **1.35** | 43% | 28 | +$659 |
| T3 | MACD Cross Trend | `macd_M15.cross==CROSS_UP\|utbot_H1.bias==BULLISH\|candle_M3.is_bullish==TRUE\|ema200_M15.price_vs==ABOVE\|adx_M15.strength in STRONG_TREND,TRENDING` | mirror sell | 350 | 1.5 | **1.20** | 42% | 33 | +$694 |

## Reversal/Trap Family (Worker 4)

| # | Name | Buy Expression | Sell Expression | SL | RR | PF | WR | Trades | PnL |
|---|------|---------------|----------------|----|----|----|----|--------|-----|
| R1 | Failed BB Sell | — | `bb_M15.reenter_above==TRUE\|utbot_H1.bias==BEARISH\|candle_M3.is_bearish==TRUE\|ema200_M15.price_vs==BELOW\|adx_M15.strength in STRONG_TREND,TRENDING` | 350 | 1.5 | **3.34** | 60% | 10 | +$1,140 |
| R2 | Exhausted Sell | — | `utbot_M15.bullish_since>=8\|candle_M5.type==SHOOTING_STAR\|dc_M15.zone in UPPER,UPPER_MID\|candle_M3.is_bearish==TRUE\|ema200_M15.price_vs==BELOW` | 350 | 2.0 | **1.25** | 37% | 43 | +$1,884 |
| R3 | EMA Slope Sell | — | `ema50_M15.slope==FALLING\|ema50_M15.price_vs==ABOVE\|candle_M3.is_bearish==TRUE\|utbot_H1.bias==BEARISH` | 350 | 1.5 | **1.23** | 42% | 26 | +$918 |

## Pullback Family (Worker 4)

| # | Name | Buy Expression | Sell Expression | SL | RR | PF | WR | Trades | PnL |
|---|------|---------------|----------------|----|----|----|----|--------|-----|
| P1 | DC Lowzone ADX | `dc_M15.zone in LOWER,LOWER_MID\|utbot_H1.bias==BULLISH\|candle_M3.is_bullish==TRUE\|ema200_M15.price_vs==ABOVE\|adx_M15.strength in STRONG_TREND,TRENDING` | mirror sell | 350 | 2.0 | **1.69** | 39% | 13 | +$305 |

## Low-Trade-Count / Needs Validation (>6 months test)

| # | Name | Buy Expression | Sell Expression | SL | RR | PF | WR | Trades | PnL |
|---|------|---------------|----------------|----|----|----|----|--------|-----|
| V1 | Stoch OS Tight | `stoch_M15.zone==OS\|utbot_H1.bias==BULLISH\|vwap_M5.price_vs==BELOW\|ema200_M15.price_vs==ABOVE\|adx_M15.strength in STRONG_TREND,TRENDING\|candle_M3.is_bullish==TRUE` | mirror sell | 350 | 1.5 | 2.69 | 50% | 6 | +$395 |
| V2 | RSI2 Extreme Buy | `rsi2_M5.zone==EXTREME_OS\|utbot_H1.bias==BULLISH\|vwap_M5.price_vs==BELOW\|ema200_M15.price_vs==ABOVE\|candle_M3.is_bullish==TRUE` | — | 350 | 2.0 | 2.60 | 60% | 5 | +$581 |
| V3 | Stoch Wide Sell | — | `stoch_M15.zone in OB,NEUTRAL\|utbot_H1.bias==BEARISH\|vwap_M5.price_vs==ABOVE\|ema200_M15.price_vs==BELOW\|adx_M15.strength in STRONG_TREND,TRENDING\|candle_M3.is_bearish==TRUE` | 350 | 1.5 | 1.28 | 44% | 34 | +$1,111 |

## Worker 2 (Older, SL=500 — needs retest at SL=350)

| # | Name | Buy Expression | SL | RR | PF | WR | Trades | PnL |
|---|------|---------------|----|----|----|----|--------|-----|
| O1 | BB Reenter + VWAP | `bb_M15.reenter_below==TRUE\|utbot_H1.bias==BULLISH\|vwap_M5.price_vs==BELOW\|ema200_M15.price_vs==ABOVE` | 500 | 1.5 | 1.48 | 48% | 21 | +$2,080 |
| O2 | Stoch RSI Combo | `stoch_M15.zone in OS,NEUTRAL\|utbot_H1.bias==BULLISH\|vwap_M5.price_vs==BELOW\|ema200_M15.price_vs==ABOVE\|adx_M15.strength in STRONG_TREND,TRENDING` | 500 | 1.5 | 1.22 | 45% | 120 | +$8,643 |

---

## Summary Stats

| Metric | Value |
|--------|-------|
| Total profitable strategies | 15 |
| Best PF (>20 trades) | 2.00 (L1: Sweep+Stoch) |
| Best PF (any) | 3.34 (R1: Failed BB Sell, 10 trades) |
| Most trades | 68 (T1: VWAP Trend) |
| Best sell-only | 3.34 (R1: Failed BB Sell) |
| SL sweet spot | 350 |
| RR sweet spot | 1.5 (trend), 2.0 (reversal/sweep) |
| Lookback sweet spot | 20 (liq_lookback) |

## Proven Rules

1. **SL=350** is the sweet spot for BTCUSDT
2. **4+ conditions minimum** — every PF>1.2 strategy has 4-6 conditions
3. **M3 candle confirmation mandatory** — M1 is noise
4. **ADX filter key for non-sweep strategies** — removes ranging market losses
5. **RR=2.0 for reversals/sweeps**, RR=1.5 for trend-riding
6. **Breakeven hurts PF** on BTC with SL=350
7. **Sell side generally outperforms** buy side for reversal strategies
8. **liq_lookback=20** is optimal
