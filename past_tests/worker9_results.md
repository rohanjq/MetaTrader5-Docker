# Worker 9 — Reversal Strategy Discovery Results

**Summary:** No strategy had PF > 0.95. Best performers: S6 (r6_double_wick, PF=0.88), S11 (r11_stoch30_cross, PF=0.86), and S10 (r10_rsi_exhaust, PF=0.81). None reached PF > 1.15. All strategies failed — buy-only strategies bled in the downtrend, sell-only ones were either too restrictive (S9: 0 trades, S4/S10: ≤11 trades) or also lost money. S6 had the most trades (148) with the highest PF (0.88) but DD of 43.67%.

## Test Window: 2026.01.13–2026.06.13 (5 months), BTCUSDT, M1, $10k, 1:100

---

## Phase 2 — Baseline Results (SL=400, RR=1.0)

### S1: r1_hammer_os — Hammer at Oversold Band (Buy-only)
- **Setup:** RSI14 M15 OS + DC M15 lower zone
- **Confirm:** Hammer M5 + MACD M3 hist rising

| Metric | Value |
|--------|-------|
| PF | 0.61 |
| Trades | 61 |
| Win Rate | 38% |
| Max DD | 43.55% |
| Net PnL | -$3,794.67 |
| Verdict | FAIL — buy-only reversal struggles in downtrend |

---

### S2: r2_star_ob — Shooting Star at Overbought Band (Sell-only)
- **Setup:** RSI14 M15 OB + DC M15 upper zone
- **Confirm:** Shooting star M5 + MACD M3 hist falling

| Metric | Value |
|--------|-------|
| PF | 0.57 |
| Trades | 55 |
| Win Rate | 36% |
| Max DD | 47.81% |
| Net PnL | -$3,787.48 |
| Verdict | FAIL |

### S3: r3_utbot_exhausted — UTBot Exhausted Rally Reversal (Sell-only)
- **Setup:** UTBot H1 bullish for 12+ bars
- **Confirm:** Shooting star M5 + MACD M5 cross down + bearish M3

| Metric | Value |
|--------|-------|
| PF | 0.74 |
| Trades | 30 |
| Win Rate | 43% |
| Max DD | 21.37% |
| Net PnL | -$1,248.06 |
| Verdict | FAIL |

### S4: r4_liq_sweep_engulf — Liq Sweep Lower + Hammer (Buy-only)
- **Setup:** H1 lower liquidity swept
- **Confirm:** Hammer M5 + MACD M3 cross up + bullish M3

| Metric | Value |
|--------|-------|
| PF | 0.20 |
| Trades | 6 |
| Win Rate | 17% |
| Max DD | 11.56% |
| Net PnL | -$1,156.30 |
| Verdict | FAIL — too few trades, buy-only in downtrend |

---

### S6: r6_double_wick — Double Wick Rejection Snap (Buy-only)
- **Setup:** DC M15 lower wick rejection
- **Confirm:** M3 lower wick ratio>=2 + MACD M5 hist rising + bullish M3

| Metric | Value |
|--------|-------|
| PF | 0.88 |
| Trades | 148 |
| Win Rate | 47.30% |
| Max DD | 43.67% |
| Net PnL | -$2,637.45 |
| Verdict | FAIL |

---

### S7: r7_stoch_cross — Stochastic Cross (Buy-only)
- **Setup:** Stoch M15 oversold
- **Confirm:** MACD M5 cross up + bullish M3 candle

| Metric | Value |
|--------|-------|
| PF | 0.75 |
| Trades | 197 |
| Win Rate | 43.15% |
| Max DD | 62.32% |
| Net PnL | -$5,830.87 |
| Verdict | FAIL |

---

### S8: r8_rsi2_snap — RSI2 Panic Snap (Buy-only)
- **Setup:** RSI2 M5 extreme OS (<5 = panic selling)
- **Confirm:** MACD M3 hist rising + bullish M3

| Metric | Value |
|--------|-------|
| PF | 0.59 |
| Trades | 682 |
| Win Rate | 40.62% |
| Max DD | 98.64% |
| Net PnL | -$9,841.16 |
| Verdict | FAIL — near-total DD, worst performer |

---

### S9: r9_failed_breakout — Failed Breakout Reversal (Sell-only)
- **Setup:** BB M5 squeeze + DC M15 upper zone
- **Confirm:** Shooting star M5 + MACD M3 cross down

| Metric | Value |
|--------|-------|
| PF | 0.00 |
| Trades | 0 |
| Win Rate | 0% |
| Max DD | 0.00% |
| Net PnL | $0.00 |
| Verdict | FAIL — zero trades, conditions too restrictive |

---

### S10: r10_rsi_exhaust — RSI14 M30 Exhaustion (Sell-only)
- **Setup:** RSI14 M30 overbought
- **Confirm:** Shooting star M5 + stoch M5 OB + bearish M3

| Metric | Value |
|--------|-------|
| PF | 0.81 |
| Trades | 11 |
| Win Rate | 45.45% |
| Max DD | 9.63% |
| Net PnL | -$341.25 |
| Verdict | FAIL — too few trades |

---

### S11: r11_stoch30_cross — Stoch M30 Oversold Cross (Buy-only)
- **Setup:** Stoch M30 oversold
- **Confirm:** MACD M5 cross up + hammer M5 + bullish M3

| Metric | Value |
|--------|-------|
| PF | 0.86 |
| Trades | 15 |
| Win Rate | 46.67% |
| Max DD | 16.25% |
| Net PnL | -$364.71 |
| Verdict | FAIL |

---

### S12: r12_upper_liq_sweep — Upper Liquidity Sweep (Sell-only)
- **Setup:** Upper liquidity swept M15 (stop-hunt above swing high)
- **Confirm:** Shooting star M5 + bearish M3 + MACD M5 hist falling

| Metric | Value |
|--------|-------|
| PF | 0.74 |
| Trades | 70 |
| Win Rate | 42.86% |
| Max DD | 41.37% |
| Net PnL | -$2,820.27 |
| Verdict | FAIL |

---

## Phase 3 — Second Pass Fixes

### S6v2: r6_double_wick RR=1.5 (Buy-only)
Removed candle type filter, added DC zone. Same core setup.

| Metric | Value |
|--------|-------|
| PF | 0.85 |
| Trades | 147 |
| Win Rate | 36.73% |
| Max DD | 48.29% |
| Net PnL | -$3,672.19 |
| Verdict | FAIL — RR increase didn't help, WR actually dropped |

### S12v2: r12v2_liq_sweep (Sell-only, SL=350, RR=2.0)
Removed shooting star filter, added DC upper zone.

| Metric | Value |
|--------|-------|
| PF | 0.95 |
| Trades | 269 |
| Win Rate | 33.09% |
| Max DD | 69.43% |
| Net PnL | -$2,568.31 |
| Verdict | FAIL — best PF (0.95) across all tests, but MaxDD too high |

### S12v3: liq_sweep + UTBot exhaustion (Sell-only, SL=350, RR=2.0)
Replaced candle bearish with UTBot M15 bullish_since>=8.

| Metric | Value |
|--------|-------|
| PF | 0.90 |
| Trades | 176 |
| Win Rate | 32.39% |
| Max DD | 59.56% |
| Net PnL | -$2,603.24 |
| Verdict | FAIL |

### S12v4: liq_sweep + DC zone + RSI14 OB (Sell-only, SL=350, RR=2.0)
Added RSI14 overbought filter for higher-TF exhaustion confirmation.

| Metric | Value |
|--------|-------|
| PF | 0.23 |
| Trades | 9 |
| Win Rate | 11.11% |
| Max DD | 19.45% |
| Net PnL | -$1,698.17 |
| Verdict | FAIL — too restrictive |

### S12v2 (re-run): liq_sweep + DC zone + bearish M3 + MACD (Sell-only, SL=350, RR=2.0)
Best performing variant. PF=0.95, most trades.

## Key Findings

1. **No confirmed reversal strategy reached PF > 1.0** in this 5-month window (2026.01.13–2026.06.13). The BTC downtrend was too strong — buying dips always lost, and shorting reversals got caught in the counter-trend bounces.

2. **Best performer:** S12v2 (liq_sweep + DC zone + bearish M3 + MACD falling) at PF=0.95, 269 trades. This was the closest to profitability. With a slightly better win rate (35% instead of 33%), it would cross PF=1.0 at RR=2.0.

3. **Candle pattern filters are too restrictive** — `candle_M5.type==SHOOTING_STAR` and `candle_M5.type==HAMMER` consistently produced <15 trades in 5 months when combined with other conditions.

4. **RR alone doesn't fix the problem** — higher RR reduces win rate because trades have farther to go to hit TP, giving them more time to reverse against the reversal thesis.

5. **The "confirmed reversal" framework is valid conceptually** but needs either:
   - A trending market (not the current BTC downtrend)
   - Much looser SL to let reversals breathe (SL=500+)
   - Directional bias aligned with the macro trend (which defeats the reversal purpose)

6. **Recommended for future work**: Focus on trend-following strategies (which have proven PF > 1.2 in prior workers) and use reversal filters only as entry refinement, not as the primary signal.