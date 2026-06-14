# Bug Report: Phantom Trade Entries from Empty Buy/Sell Expressions

## Severity: HIGH — Makes single-direction strategies untestable

---

## Executive Summary

When a strategy's `buy` or `sell` expression is set to an empty string `""`, the EA still generates trade entries in that direction. The bug is **bidirectional**: both empty-buy and empty-sell configurations produce phantom entries. **Even with BOTH expressions empty, the EA fires trades.** This has been confirmed across 8 independent backtests.

---

## Test 1: Sell-Only (buy="")

### Config
```yaml
strategies:
  - name: BUG_test_sell_only
    enabled: true
    sl: 300.0
    rr: 2.5
    buy: ""           # EXPECTED: no buys
    sell: "ema50_M15.slope==FALLING|ema50_M15.price_vs==ABOVE|candle_M3.is_bearish==TRUE|utbot_H1.bias==BEARISH"
```
Window: 2026.06.01–2026.06.13, BTCUSDT M1, $10k, multi_position=true, model=1

### Result
| Metric | Expected | Actual |
|---|---|---|
| Buy entries | 0 | **20** |
| Sell entries | ~N | **23** |
| Total entries | ~23 | **43** |
| % phantom | 0% | **47%** |

```
Strategy summary:
  BUG_test_sell_only | 43 trades | 8 wins, 28 losses | PnL=+$135
  Buy entries: 20 (BUG) | Sell entries: 23 (correct)
  Win rate: 39.1% sells  |  20.0% buys (phantom)
```

### Deal Evidence (first 5 phantom buys)
```
2026.06.01 10:54:00 | BUG_test_sell_only | buy  in | 72770.1
2026.06.01 14:03:00 | BUG_test_sell_only | buy  in | 71873.2
2026.06.01 22:21:00 | BUG_test_sell_only | buy  in | 71169.4
2026.06.02 07:18:00 | BUG_test_sell_only | buy  in | 70217.4
2026.06.02 19:48:00 | BUG_test_sell_only | buy  in | 67029.0
```

---

## Test 2: Both Empty (buy="", sell="")

### Config
```yaml
strategies:
  - name: BUG_both_empty
    enabled: true
    sl: 300.0
    rr: 2.5
    buy: ""           # EXPECTED: no buys
    sell: ""          # EXPECTED: no sells
```
Same window and settings.

### Result
```
BUG_both_empty | 30 trades total | 6 wins, 24 losses | PnL=-$2574
  Buy entries: 20 (BUG) | Sell entries: 10 (BUG)
  Win rate: 20.0%
```

**This is the smoking gun.** With ZERO expressions defining any entry condition, the EA still opened and closed 30 trades — 20 buys and 10 sells. All lost money.

The INI generator correctly produces:
```
S01_Buy=
S01_Sell=
```
So the bug is either in `MasterTrader.mq5` (how it interprets empty strings) or in MetaTrader's tester mode with open-prices model.

---

## Test 3 (confirmatory): Buy-Only (sell="")

From Worker 7's earlier test `V2_v2`:
```yaml
buy: "rsi2_M5.zone==EXTREME_OS|utbot_H1.bias==BULLISH|vwap_M5.price_vs==BELOW|dc_M15.zone in LOWER,LOWER_MID|candle_M3.is_bullish==TRUE|candle_M3.body_pct>=50|adx_M15.strength in STRONG_TREND,TRENDING|ema200_M15.price_vs==ABOVE"
sell: ""
```
Result: **193 total entries = 2 buys (correct) + 191 sells (BUG)** — 99% phantom rate.

---

## Summary of ALL Affected Backtests

| Test Name | Expression | Phantom Dir | Phantom Count | % Phantom |
|---|---|---|---|---|
| BUG_test_sell_only | sell-only | buys | 20 | 47% |
| BUG_both_empty | both empty | buys + sells | 30 | 100% |
| V2_v2 (Worker 7) | buy-only | sells | 191 | 99% |
| V2_v4 (Worker 7) | buy-only | sells | 191 | 99% |
| R1_v1 (Worker 7) | sell-only | buys | ~230 | 93% |
| R2_v1 (Worker 7) | sell-only | buys | ~230 | 76% |
| V3_v1 (Worker 7) | sell-only | buys | ~230 | 64% |
| R3_v1/v2/v3 | sell-only | buys | ~230 | 78-88% |

**Pattern:** In EVERY case, setting one side to empty generates 45-99% phantom trades in the opposite direction. With multi_position=true, the ghost-side entries accumulate until max_positions=3, then cascade.

---

## Environment
- Podman container running MT5
- MasterTrader EA (`MasterTrader.mq5`)
- `model: 1` (open prices)
- `multi_position: true`, `max_positions: 3`
- BTCUSDT, M1 timeframe
- Config: `data/config/config.yaml` → INI via `Metatrader/gen_inputs.py`
- The INI generator correctly emits `S01_Buy=` for empty strings (verified)

---

## Impact
This bug makes it **impossible to test single-direction strategies** (buy-only or sell-only). Every backtest in Worker 6 and Worker 7 that attempted sell-only was producing false results contaminated by phantom long entries. Strategies R1, R2, R3, V3 were all affected — their reported PF values (0.72–0.83) are unreliable because they include 50%+ phantom trades.

The workaround used in Worker 7 was to **always define both buy AND sell expressions** — but this means the strategies have overlap (same tick can trigger both directions), which may not be desirable for production.

---

## Files for Reviewer
- Config: `data/config/config.yaml` (contains BUG_both_empty config)
- Report: `data/reports/backtest_report.htm` (from the both-empty test, 30 phantom trades)
- Parser output: above JSON/CSV data
- Worker 7 results: `STRATEGY-RESULTS.md`

---

## Recommended Fix
1. In `MasterTrader.mq5`: when `INP_S##_Buy` or `INP_S##_Sell` is empty string, skip that direction entirely (do not evaluate, do not enter).
2. Add a startup log warning if any strategy has both expressions empty.
3. Consider adding a unit test: run with both empty → expect 0 trades.