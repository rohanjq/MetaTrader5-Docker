# Best Strategies — Reference Sheet

Consolidated from all worker backtests. These are our top candidates for refinement.
Only strategies with PF >= 1.0 (or very close with clear improvement path) are listed.

**Test window:** 2026.04.13 – 2026.06.13 (2 months), BTCUSDT, M1 chart, $10k deposit, 1:100 leverage.

---

## Tier 0: High PF (Worker 4 Refinement, PF >= 1.5)

### Failed BB Breakout Sell (Worker 4) — HIGHEST PF EVER
```yaml
- name: failed_bb_sell
  sl: 350.0
  rr: 1.5
  sell: "bb_M15.reenter_above==TRUE|utbot_H1.bias==BEARISH|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW|adx_M15.strength in STRONG_TREND,TRENDING"
```
| PF | Win% | Trades | Net Profit |
|----|------|--------|------------|
| 3.34 | 60% | 10 | +$1,140 |

**Why it works:** BB false breakout above in a bearish trend. ADX filter is critical — removing it drops PF to 0.60. Low count but highest quality signal found.

### Stoch OS Tight (Worker 4)
```yaml
- name: stoch_os_tight
  sl: 350.0
  rr: 1.5
  buy: "stoch_M15.zone==OS|utbot_H1.bias==BULLISH|vwap_M5.price_vs==BELOW|ema200_M15.price_vs==ABOVE|adx_M15.strength in STRONG_TREND,TRENDING|candle_M3.is_bullish==TRUE"
  sell: "stoch_M15.zone==OB|utbot_H1.bias==BEARISH|vwap_M5.price_vs==ABOVE|ema200_M15.price_vs==BELOW|adx_M15.strength in STRONG_TREND,TRENDING|candle_M3.is_bearish==TRUE"
```
| PF | Win% | Trades | Net Profit |
|----|------|--------|------------|
| 2.69 | 50% | 6 | +$395 |

### RSI2 Extreme Buy (Worker 4)
```yaml
- name: rsi2_extreme_buy
  sl: 350.0
  rr: 2.0
  buy: "rsi2_M5.zone==EXTREME_OS|utbot_H1.bias==BULLISH|vwap_M5.price_vs==BELOW|ema200_M15.price_vs==ABOVE|candle_M3.is_bullish==TRUE"
```
| PF | Win% | Trades | Net Profit |
|----|------|--------|------------|
| 2.60 | 60% | 5 | +$581 |

### DC Lowzone ADX (Worker 4)
```yaml
- name: dc_lowzone_adx
  sl: 350.0
  rr: 2.0
  buy: "dc_M15.zone in LOWER,LOWER_MID|utbot_H1.bias==BULLISH|candle_M3.is_bullish==TRUE|ema200_M15.price_vs==ABOVE|adx_M15.strength in STRONG_TREND,TRENDING"
  sell: "dc_M15.zone in UPPER,UPPER_MID|utbot_H1.bias==BEARISH|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW|adx_M15.strength in STRONG_TREND,TRENDING"
```
| PF | Win% | Trades | Net Profit |
|----|------|--------|------------|
| 1.69 | 38.5% | 13 | +$305 |

---

## Tier 1: Profitable (PF >= 1.2)

### VWAP Trend (Worker 4) — BEST STANDALONE ALL-ROUNDER
```yaml
- name: vwap_trend
  sl: 350.0
  rr: 1.5
  buy: "vwap_M5.price_vs==BELOW|utbot_H1.bias==BULLISH|candle_M3.is_bullish==TRUE|ema200_M15.price_vs==ABOVE"
  sell: "vwap_M5.price_vs==ABOVE|utbot_H1.bias==BEARISH|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW"
```
| PF | Win% | Trades | Net Profit |
|----|------|--------|------------|
| 1.42 | 47.1% | 68 | +$1,295 |

**Improvement over Worker 1:** Same concept but SL 350 instead of 400 + added EMA200 filter pushed PF from 0.99 → 1.42.

### Stoch Combo Wide (Worker 4)
```yaml
- name: stoch_wide
  sl: 350.0
  rr: 1.5
  buy: "stoch_M15.zone in OS,NEUTRAL|utbot_H1.bias==BULLISH|vwap_M5.price_vs==BELOW|ema200_M15.price_vs==ABOVE|adx_M15.strength in STRONG_TREND,TRENDING|candle_M3.is_bullish==TRUE"
  sell: "stoch_M15.zone in OB,NEUTRAL|utbot_H1.bias==BEARISH|vwap_M5.price_vs==ABOVE|ema200_M15.price_vs==BELOW|adx_M15.strength in STRONG_TREND,TRENDING|candle_M3.is_bearish==TRUE"
```
| PF | Win% | Trades | Net Profit |
|----|------|--------|------------|
| 1.35 | 42.9% | 28 | +$659 |

### Exhausted Uptrend Sell (Worker 4)
```yaml
- name: exhausted_sell
  sl: 350.0
  rr: 2.0
  sell: "utbot_M15.bullish_since>=8|candle_M5.type==SHOOTING_STAR|dc_M15.zone in UPPER,UPPER_MID|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW"
```
| PF | Win% | Trades | Net Profit |
|----|------|--------|------------|
| 1.25 | 37.2% | 43 | +$1,884 |

### BB Reenter + Trend (Worker 2)
```yaml
- name: bb_reenter_vwap
  sl: 500.0
  rr: 1.5
  buy: "bb_M15.reenter_below==TRUE|utbot_H1.bias==BULLISH|vwap_M5.price_vs==BELOW|ema200_M15.price_vs==ABOVE"
  sell: ""
```
| PF | Win% | Trades | MaxDD | Net Profit |
|----|------|--------|-------|------------|
| 1.48 | 48% | 21 | — | +$2,080 |

**Why it works:** Very selective signal — BB reenter_below is rare (price must have been below lower band then come back in). Combined with 4 trend filters = high quality entries. Low trade count = high signal quality.

**To try:** Add sell side with `bb_M15.reenter_above`. Try SL=350.

---

### Stoch + Trend Combo (Worker 2)
```yaml
- name: stoch_rsi_combo
  sl: 500.0
  rr: 1.5
  buy: "stoch_M15.zone in OS,NEUTRAL|utbot_H1.bias==BULLISH|vwap_M5.price_vs==BELOW|ema200_M15.price_vs==ABOVE|adx_M15.strength in STRONG_TREND,TRENDING"
  sell: ""
```
| PF | Win% | Trades | MaxDD | Net Profit |
|----|------|--------|-------|------------|
| 1.22 | 45% | 120 | 35% | +$8,643 |

**Why it works:** 5 conditions = deep filtering. ADX trending requirement avoids ranging markets. VWAP below = buying at a discount in an uptrend.

**To try:** Tighten SL to 350. Add sell side. Try breakeven.

---

## Tier 2: Near-Breakeven (PF 1.0–1.19), Refine-worthy

### DC Wick Trap (Worker 1) — Best Trap Strategy
```yaml
- name: dc_wick_trap
  sl: 400.0
  rr: 1.5
  buy: "dc_M15.lower_wick_rej==TRUE|utbot_H1.bias==BULLISH|candle_M3.is_bullish==TRUE"
  sell: "dc_M15.upper_wick_rej==TRUE|utbot_H1.bias==BEARISH|candle_M3.is_bearish==TRUE"
```
| PF | Win% | Trades | MaxDD | Net Profit |
|----|------|--------|-------|------------|
| 1.06 | 42% | 92 | 24% | ~breakeven |

**Why it's close:** The wick rejection signal is fundamentally strong — price probed the channel edge, got slapped back. Low drawdown (24%) is a very good sign. Needs more filtering to push PF above 1.2.

**To try:** Add VWAP/EMA200 filters (like worker 2 did). Try SL=350. Stack with ADX trending. Try breakeven.

---

### VWAP Trend (Worker 1)
```yaml
- name: vwap_trend
  sl: 400.0
  rr: 1.5
  buy: "vwap_M5.price_vs==BELOW|utbot_H1.bias==BULLISH|candle_M3.is_bullish==TRUE"
  sell: "vwap_M5.price_vs==ABOVE|utbot_H1.bias==BEARISH|candle_M3.is_bearish==TRUE"
```
| PF | Win% | Trades | MaxDD | Net Profit |
|----|------|--------|-------|------------|
| 0.99 | 40.5% | 252 | 42% | ~breakeven |

**Why it's close:** VWAP is a real institutional level. 252 trades means plenty of opportunities. Needs more filtering to reduce noise trades.

**To try:** Add EMA200 filter. Add ADX trending. Reduce to 4+ conditions. Try SL=350.

---

## Key Patterns Observed

1. **SL=350 is the sweet spot** — Worker 4 confirmed: tighter than 400-500 used by Workers 1/2, consistently profitable.

2. **4+ conditions always beats 3** — Every PF>1.2 strategy has 4-6 conditions. Each filter removes bad trades.

3. **M3 confirmation >> M1 confirmation** — M1 candles are noise. M3 gives enough time for a real move to start. Worker 4 proved: switching M1→M3 for MACD cross added +0.26 PF.

4. **ADX STRONG_TREND/TRENDING filter is the key differentiator** — Removes ranging market losses. Removing it drops PF by 2-3x.

5. **RR=1.5 default, RR=2.0 for high-conviction** — Exhausted reversals, DC lowzone, RSI2 extreme = use RR=2.0.

6. **Breakeven hurts PF** — Worker 4 tested 175 and 250 breakeven. Both cut profitable trades early on BTC volatility. Not recommended.

7. **Sell-side strategies work** — Worker 4 found 4 profitable sell-only strategies. EMA slope divergence, BB false breakout, stoch OB are the best sell setups.

8. **Low frequency = high quality** — Failed BB sell (10 trades, PF=3.34) beats VWAP trend (68 trades, PF=1.42). Rare signals are stronger.
