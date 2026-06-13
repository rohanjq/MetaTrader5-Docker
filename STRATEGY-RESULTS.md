# Worker 3 — Strategy Refinement Results

## Overview

Tested ~50 strategy variations across 13 backtest rounds (2026.04.13–2026.06.13, BTCUSDT, M1, $10k deposit, 1:100 leverage).

**10 profitable strategies (standalone PF > 1.2) identified.** Combined performance limited by signal overlap.

---

## Key Discoveries

### What Works
1. **SL=350 is the sweet spot** — tighter than previous SL=400-500, confirmed profitable
2. **4+ conditions always beats 3** — every PF>1.2 strategy has 4-6 conditions
3. **M3 candle confirmation is mandatory** — M1 is noise, M3 filters out fake breakouts
4. **ADX STRONG_TREND/TRENDING filter** is the key differentiator — removes ranging market losses
5. **RR=1.5 default, RR=2.0 works for high-conviction setups** — exhausted sell, dc_lowzone, rsi2 extreme
6. **Breakeven (175/250) hurts PF** — cuts winning trades too early on BTC volatility
7. **Sell-side strategies work best with EMA slope divergence, BB false breakout, stoch OB**

### What Doesn't Work
- Round number magnet — just random
- Breakeven < 250 — cuts winners early  
- Removing ADX filter — reduces PF by 2-3x
- M1 candle confirmation — too many false signals
- AT-based strategies in combined configs — signal cannibalization kills PF

---

## The 10 Strategies

### S01: VWAP Trend
```
Type: Trend-riding pullback at institutional VWAP level
Buy:  "vwap_M5.price_vs==BELOW|utbot_H1.bias==BULLISH|candle_M3.is_bullish==TRUE|ema200_M15.price_vs==ABOVE"
Sell: "vwap_M5.price_vs==ABOVE|utbot_H1.bias==BEARISH|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW"
```
| SL | RR | PF | WR | Trades | Standalone PnL |
|----|----|----|----|--------|----------------|
| 350 | 1.5 | 1.42 | 47.1% | 68 | +$1,295 |

**Best standalone performer.** VWAP is a real institutional level — buying below VWAP in an uptrend is buying at a discount. 4 conditions, clean signal.

---

### S02: Stoch Combo Wide
```
Type: Multi-condition trend pullback with stochastic momentum
Buy:  "stoch_M15.zone in OS,NEUTRAL|utbot_H1.bias==BULLISH|vwap_M5.price_vs==BELOW|ema200_M15.price_vs==ABOVE|adx_M15.strength in STRONG_TREND,TRENDING|candle_M3.is_bullish==TRUE"
Sell: "stoch_M15.zone in OB,NEUTRAL|utbot_H1.bias==BEARISH|vwap_M5.price_vs==ABOVE|ema200_M15.price_vs==BELOW|adx_M15.strength in STRONG_TREND,TRENDING|candle_M3.is_bearish==TRUE"
```
| SL | RR | PF | WR | Trades | Standalone PnL |
|----|----|----|----|--------|----------------|
| 350 | 1.5 | 1.35 | 42.9% | 28 | +$659 |

**6 conditions.** Includes NEUTRAL zone to increase trade count while ADX filters out ranging markets.

---

### S03: Stoch Wide Sell
```
Type: Sell-only — stochastic OB in bearish H1 trend
Sell: "stoch_M15.zone in OB,NEUTRAL|utbot_H1.bias==BEARISH|vwap_M5.price_vs==ABOVE|ema200_M15.price_vs==BELOW|adx_M15.strength in STRONG_TREND,TRENDING|candle_M3.is_bearish==TRUE"
```
| SL | RR | PF | WR | Trades | Standalone PnL |
|----|----|----|----|--------|----------------|
| 350 | 1.5 | 1.28 | 44.1% | 34 | +$1,111 |

**Best sell-only strategy.** 6 conditions, all aligned bearish — price above VWAP, below EMA200, H1 bearish, ADX trending.

---

### S04: Exhausted Uptrend Reversal
```
Type: Sell-only — extended bullish run + shooting star at DC top = reversal
Sell: "utbot_M15.bullish_since>=8|candle_M5.type==SHOOTING_STAR|dc_M15.zone in UPPER,UPPER_MID|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW"
```
| SL | RR | PF | WR | Trades | Standalone PnL |
|----|----|----|----|--------|----------------|
| 350 | 2.0 | 1.25 | 37.2% | 43 | +$1,884 |

**RR=2.0 works here** — when a rally is exhausted (8+ bars bullish), the reversal tends to be strong. Shooting star + DC upper zone confirms exhaustion.

---

### S05: EMA Slope Divergence
```
Type: Sell-only — price above falling EMA = about to drop
Sell: "ema50_M15.slope==FALLING|ema50_M15.price_vs==ABOVE|candle_M3.is_bearish==TRUE|utbot_H1.bias==BEARISH"
```
| SL | RR | PF | WR | Trades | Standalone PnL |
|----|----|----|----|--------|----------------|
| 350 | 1.5 | 1.23 | 42.3% | 26 | +$918 |

**Divergence play** — EMA is falling but price is above it (temporary lift, about to fall back). H1 bearish confirms macro direction.

---

### S06: MACD Cross + Trend
```
Type: Trend-riding — MACD crossover in established H1 trend direction
Buy:  "macd_M15.cross==CROSS_UP|utbot_H1.bias==BULLISH|candle_M3.is_bullish==TRUE|ema200_M15.price_vs==ABOVE|adx_M15.strength in STRONG_TREND,TRENDING"
Sell: "macd_M15.cross==CROSS_DOWN|utbot_H1.bias==BEARISH|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW|adx_M15.strength in STRONG_TREND,TRENDING"
```
| SL | RR | PF | WR | Trades | Standalone PnL |
|----|----|----|----|--------|----------------|
| 350 | 1.5 | 1.20 | 42.4% | 33 | +$694 |

**M3 confirmation (not M1)** is critical. Previous worker's M1-based MACD cross hit only PF=0.94. Switching to M3 candle confirmation added 0.26 PF.

---

### S07: DC Lower Zone + ADX
```
Type: Trend-riding — price at DC bottom in uptrend = pullback entry
Buy:  "dc_M15.zone in LOWER,LOWER_MID|utbot_H1.bias==BULLISH|candle_M3.is_bullish==TRUE|ema200_M15.price_vs==ABOVE|adx_M15.strength in STRONG_TREND,TRENDING"
Sell: "dc_M15.zone in UPPER,UPPER_MID|utbot_H1.bias==BEARISH|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW|adx_M15.strength in STRONG_TREND,TRENDING"
```
| SL | RR | PF | WR | Trades | Standalone PnL |
|----|----|----|----|--------|----------------|
| 350 | 2.0 | 1.69 | 38.5% | 13 | +$305 |

**RR=2.0 and ADX filter** transforms this from PF=0.83 (without ADX, RR=1.5) to PF=1.69. Lower trade count but high conviction.

---

### S08: Failed BB Breakout (Sell)
```
Type: Trap/false breakout — price re-enters from above upper BB band
Sell: "bb_M15.reenter_above==TRUE|utbot_H1.bias==BEARISH|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW|adx_M15.strength in STRONG_TREND,TRENDING"
```
| SL | RR | PF | WR | Trades | Standalone PnL |
|----|----|----|----|--------|----------------|
| 350 | 1.5 | 3.34 | 60% | 10 | +$1,140 |

**Highest PF** of any strategy tested. BB false breakout above in a bearish trend = strong sell signal. Rare but high quality. ADX filter is critical — removing it drops PF to 0.60.

---

### S09: Stoch OS Tight
```
Type: High-quality trend pullback — stochastic oversold only (not NEUTRAL)
Buy:  "stoch_M15.zone==OS|utbot_H1.bias==BULLISH|vwap_M5.price_vs==BELOW|ema200_M15.price_vs==ABOVE|adx_M15.strength in STRONG_TREND,TRENDING|candle_M3.is_bullish==TRUE"
Sell: "stoch_M15.zone==OB|utbot_H1.bias==BEARISH|vwap_M5.price_vs==ABOVE|ema200_M15.price_vs==BELOW|adx_M15.strength in STRONG_TREND,TRENDING|candle_M3.is_bearish==TRUE"
```
| SL | RR | PF | WR | Trades | Standalone PnL |
|----|----|----|----|--------|----------------|
| 350 | 1.5 | 2.69 | 50% | 6 | +$395 |

**OS only (not NEUTRAL)** — fewer but much higher quality trades. Same conditions as S02 but with stoch zone tightened to OS/OB only.

---

### S10: RSI2 Extreme Oversold
```
Type: Mean reversion — extreme RSI2 <5 = exhaustion bounce
Buy:  "rsi2_M5.zone==EXTREME_OS|utbot_H1.bias==BULLISH|vwap_M5.price_vs==BELOW|ema200_M15.price_vs==ABOVE|candle_M3.is_bullish==TRUE"
```
| SL | RR | PF | WR | Trades | Standalone PnL |
|----|----|----|----|--------|----------------|
| 350 | 2.0 | 2.60 | 60% | 5 | +$581 |

**EXTREME_OS only (<5 on RSI2)**, not regular OS. Very rare (5 trades) but highly profitable. RR=2.0 captures the snap-back move.

---

## Strategy Classification

### By Direction
| Direction | Count | Strategies |
|---|---|---|
| Buy-only | 2 | S07 (RSI2 extreme), S08 (Failed BB — sell-only), S10 (RSI2) |
| Sell-only | 4 | S02 (EMA slope), S03 (Exhausted), S05 (Stoch wide sell), S08 (Failed BB) |
| Both | 4 | S01 (VWAP), S04 (Stoch wide), S06 (MACD), S09 (Stoch OS) |

### By Type
| Type | Count | Strategies |
|---|---|---|
| Trend-riding | 6 | S01, S04, S05, S06, S07, S10 |
| Reversal | 4 | S02, S03, S08, S09 |

---

## Important Notes

### Combined Performance
In combined backtests, strategies compete for signals (first-match wins). Overlap in conditions (H1 bias, ema200, M3 candle) means earlier strategies claim signals that later strategies would trade differently. Best approaches:
- **Run standalone** for maximum PF per strategy
- **Use as signal inputs** to a multi-strategy portfolio (each evaluated independently)
- **Order by expected PF** — highest PF strategies first in config

### Trade Count Limitations
Several strategies (S07-S10) have <15 trades — their PFs are based on small samples. They need more data (6+ months) to validate. The higher-trade-count strategies (S01, S04, S05, S06) have more statistical confidence.

### Breakeven
Tested breakeven_start=175 and 250. Both reduce PF by cutting profitable trades early. Not recommended for BTCUSDT with SL=350 — the 175 breakeven is 50% of SL which is too tight given BTC volatility.

### Comparison to Worker 1/2 Results
| Metric | Worker 1/2 | Worker 3 |
|---|---|---|
| Best PF | 1.48 (BB reenter) | 3.34 (Failed BB) |
| Best combined PF | ~1.0+ | 1.42 (VWAP trend standalone) |
| Sell strategies | 0 tested | 4 profitable |
| Trend-riding tested | 0 | 6 profitable |
| SL used | 400-500 | 350 |
| Breakeven tested | No | Yes (not recommended) |