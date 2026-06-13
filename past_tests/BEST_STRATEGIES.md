# Best Strategies — Reference Sheet

Consolidated from all worker backtests. These are our top candidates for refinement.
Only strategies with PF >= 1.0 (or very close with clear improvement path) are listed.

**Test window:** 2026.04.13 – 2026.06.13 (2 months), BTCUSDT, M1 chart, $10k deposit, 1:100 leverage.

---

## Tier 1: Profitable (PF >= 1.2)

### BB Reenter + Trend (Worker 2) — BEST OVERALL
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

1. **RR=1.5 is the sweet spot** — Worker 2 proved this: same strategy went from -$2,137 at RR=1.0 to +$8,643 at RR=1.5.

2. **More conditions = better PF** — 5-condition strategy (PF=1.22) beats 3-condition (PF=1.06). Each filter removes bad trades.

3. **M3 confirmation >> M1 confirmation** — M1 candles are noise. M3 gives enough time for a real move to start.

4. **Low frequency = high quality** — BB reenter (21 trades, PF=1.48) beats stoch (120 trades, PF=1.22). Rare signals are stronger.

5. **SL=350 untested** — Both workers used 400-500. 350 is the sweet spot theory (if trade goes 350 against you, it's likely a loss anyway). Needs testing.

6. **Breakeven untested** — Neither worker used breakeven. This is the biggest unexplored variable.

7. **Sell side weak** — Most profitable strategies are buy-only. Need to find good sell expressions independently.

8. **Long-only bias in this 2-month window** — BTC may have been in an uptrend. Need to be careful not to overfit to bullish conditions. Must develop sell-side strategies for balanced portfolio.
