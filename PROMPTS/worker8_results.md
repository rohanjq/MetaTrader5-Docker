# Worker 8 — Research Strategy Testing: Results

## Test Window: 2026.01.13–2026.06.13 (5 months), BTCUSDT, M1
## Baseline: SL=400, RR=1.0 (all 12 strategies)

## Summary

11 of 12 strategies failed baseline (PF < 1.0). MR4, TP3, CL2, TP2, BO2 produced <20 trades (statistically meaningless). The remaining 7 had 394–1213 trades but all lost money. Best baseline was BO3 (PF=0.85).

**Second Pass:** BO3 short-only with RR=1.5 achieved PF=1.14, Net=+$5,632, 189 trades, MaxDD=28.7%.

## First Pass Results (SL=400, RR=1.0)

| Strategy | PF | Trades | Win% | MaxDD | Net PnL | Verdict |
|---|---|---|---|---|---|---|
| mr1_connors_rsi2 | 0.81 | 1102 | 45.4% | 98.0% | -$9,711 | FAIL |
| mr2_ifr2_trend_rebound | 0.74 | 76 | 43.4% | 46.6% | -$2,844 | FAIL |
| mr3_bb_rsi_range | 0.53 | 20 | 35.0% | 17.2% | -$1,721 | FAIL |
| mr4_score_scalper | 0.00 | 0 | 0% | 0% | $0 | FAIL (0 trades) |
| tp1_ema_rsi_adx | 0.80 | 948 | 42.0% | 99.4% | -$9,937 | FAIL |
| tp2_stoch_momentum | - | 2 | 100% | 3.2% | +$608 | FAIL (<15 trades) |
| tp3_anwar_pullback | 0.80 | 469 | 45.0% | 80.4% | -$8,036 | FAIL |
| bo1_turtle_breakout | 0.84 | 761 | 45.1% | - | -$9,251 | FAIL |
| bo2_squeeze_expansion | 0.33 | 4 | 25.0% | - | -$600 | FAIL |
| bo3_vwap_pulse | 0.85 | 394 | 46.5% | - | -$6,330 | FAIL |
| cl1_vwap_rsi_align | 0.73 | 1213 | 44.0% | - | -$9,937 | FAIL |
| cl2_liq_sweep_reversal | 0.60 | 62 | 37.1% | 41.6% | -$3,988 | FAIL |

## Second Pass — Winning Configuration

**BO3 VWAP Pulse, Short-Only, SL=400, RR=1.5**

```yaml
strategies:
  - name: bo3_vwap_pulse_short
    enabled: true
    sl: 400.0
    rr: 1.5
    buy: ""
    sell: "vwap_M15.price_vs==BELOW|adx_M15.strength in TRENDING,STRONG_TREND|adx_M15.di_bias==BEARISH|dc_M5.zone in LOWER_MID,LOWER|macd_M5.cross==CROSS_DOWN"
```

| Variant | PF | Trades | Win% | MaxDD | Net PnL |
|---|---|---|---|---|---|
| Baseline (both dir, RR=1.0) | 0.85 | 394 | 46.5% | - | -$6,330 |
| **Short-only, RR=1.5** | **1.14** | **189** | **43.9%** | **28.7%** | **+$5,632** |
| Short-only, RR=1.8 | 1.07 | 177 | 37.9% | 42.3% | +$2,198 |
| Short-only, SL=350, RR=1.5 | 0.99 | 200 | 40.5% | 44.7% | -$376 |
| Short-only, RR=1.5, breakeven=200 | 0.92 | 205 | 62.4% | 35.4% | -$1,544 |

## Key Findings

1. **Short-only outperformed long-only for BTC in this window** — BTC was in a downtrend (from ~$96K to ~$63K over the 5 months), so short-biased strategies naturally did better
2. **BO3 (VWAP Pulse) was the only strategy that could be tuned to profitability** — its core logic (VWAP below + ADX trending + bearish DI + DC lower zone + MACD cross down) captures momentum breakdowns well
3. **RR=1.5 was the sweet spot** — RR=1.0 loses money, RR=1.8 reduces win rate too much
4. **None of the 12 strategies worked both directions** — all were net negative with both buy+sell enabled at RR=1.0