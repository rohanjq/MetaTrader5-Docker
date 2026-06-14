# Worker 6 — Complete Run Instructions

## Overview

Worker 6 runs parameter optimization for 15 profitable strategies over a 6-month window (2026.01.13–2026.06.13) with relaxed global settings. Each strategy is tested individually across multiple SL/RR combinations (Phase 1) and trailing stop variations (Phase 2).

## Pre-requisites

```bash
# Ensure we're in the right directory
cd /root/MetaTrader5-Docker

# Make sure PyYAML is available
pip3 install pyyaml -q
```

## Step 1: Clean Previous Results (optional)

If you want to start completely fresh:

```bash
rm -f data/config/worker6_results.json
```

If you want to resume from partial results (e.g., L1 already has 9 out of 10 runs done), leave the file as-is. The script automatically skips already-completed runs.

## Step 2: Run All 15 Strategies

```bash
python3 tools/run_worker6.py
```

This will take approximately 2-3 hours. Each backtest takes ~45-55 seconds, and there are about 135 total runs (9-13 per strategy).

### To run only specific strategies:

```bash
python3 tools/run_worker6.py L1 L2 T1
```

### Strategy IDs:

| ID | Name | Family | Runs |
|----|------|--------|------|
| L1 | sweep_stoch | sweep | 6 + 4 |
| L2 | sweep_stoch_est | sweep | 6 + 4 |
| L3 | triple_rejection | sweep | 6 + 4 |
| T1 | vwap_trend | trend | 9 + 4 |
| T2 | stoch_combo_wide | trend | 9 + 4 |
| T3 | macd_cross_trend | trend | 9 + 4 |
| R1 | failed_bb_sell | reversal | 6 + 4 |
| R2 | exhausted_sell | reversal | 6 + 4 |
| R3 | ema_slope_sell | reversal | 6 + 4 |
| P1 | dc_lowzone_adx | pullback | 6 + 4 |
| V1 | stoch_os_tight | validation | 4 + 4 |
| V2 | rsi2_extreme_buy | validation | 4 + 4 |
| V3 | stoch_wide_sell | validation | 4 + 4 |

## Step 3: Generate the Results Report

After all runs complete:

```bash
python3 tools/summarize_worker6.py
```

This does two things:
1. Prints a full results table to the terminal
2. Writes `STRATEGY-RESULTS.md` with all results and recommendations

## Step 4: Create Production Config (manual)

Based on the output from Step 3, manually edit `config.yaml` with the best non-overlapping strategies. Template:

```yaml
backtest:
  symbol: BTCUSDT
  period: M1
  model: 1
  from: "2026.01.13"
  to: "2026.06.13"
  deposit: 10000
  leverage: "1:100"

global:
  risk_pct: 3.0
  sl: 0
  rr: 0
  magic: 300
  multi_position: true
  max_positions: 3
  max_daily_trades: 50
  cooldown_sec: 900
  reversal_cooldown: 0
  max_consec_loss: 0
  consec_loss_pause: 0
  slippage: 20

trailing:
  breakeven_start: 0.0    # override per-strategy if needed
  trail_start: 0.0
  trail_step: 2.0

indicators:
  utbot_period: 10
  utbot_mult: 2.0
  dc_length: 20
  round_level: 500.0
  liq_lookback: 20

control:
  use_control_file: false
  write_status_file: false
  control_poll_sec: 5

strategies:
  - name: L1_sweep_stoch
    enabled: true
    sl: 400.0
    rr: 1.5
    buy: "liq_M15.lower_swept==TRUE|stoch_M15.zone==OS|candle_M3.is_bullish==TRUE|ema200_M15.price_vs==ABOVE"
    sell: "liq_M15.upper_swept==TRUE|stoch_M15.zone==OB|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW"

  - name: T1_vwap_trend
    enabled: true
    sl: 300.0
    rr: 1.0
    buy: "vwap_M5.price_vs==BELOW|utbot_H1.bias==BULLISH|candle_M3.is_bullish==TRUE|ema200_M15.price_vs==ABOVE"
    sell: "vwap_M5.price_vs==ABOVE|utbot_H1.bias==BEARISH|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW"

  - name: R1_failed_bb_sell
    enabled: true
    sl: 350.0
    rr: 1.5
    buy: ""
    sell: "bb_M15.reenter_above==TRUE|utbot_H1.bias==BEARISH|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW|adx_M15.strength in STRONG_TREND,TRENDING"
```

Note: Replace SL/RR values with the best values found from Step 3.

## Troubleshooting

### Container gets stuck

```bash
podman stop -t 5 mt5 2>/dev/null
podman rm -f mt5 2>/dev/null
```

Then run `python3 tools/run_worker6.py` again — it will resume.

### How results are saved

Every run saves to `data/config/worker6_results.json`. Example entry:

```json
{
  "L1_sl400_rr1.5_no_trail": {
    "sid": "L1",
    "name": "L1_sweep_stoch",
    "sl": 400,
    "rr": 1.5,
    "trail": "no_trail",
    "pf": 1.08,
    "wr": 42.53,
    "trades": 87,
    "maxdd": 34.42,
    "pnl": 1027.07
  }
}
```

### What each run does internally

1. Writes `config.yaml` with one strategy and test parameters
2. Runs `podman stop -t 5 mt5 && podman rm -f mt5`
3. Deletes old reports from `data/reports/`
4. Runs `MT5_MODE=tester podman-compose up -d`
5. Waits for `data/reports/backtest_report.htm` to appear and be non-empty
6. Parses the report with `python3 tools/parse_report.py --json --all`
7. Saves results to `data/config/worker6_results.json`

### SL/RR Grid per Family

```
sweep:    SL=350,400 × RR=1.5,2.0,2.5     = 6 runs Phase 1
trend:    SL=250,300,350 × RR=1.0,1.25,1.5 = 9 runs Phase 1
reversal: SL=300,350 × RR=1.5,2.0,2.5      = 6 runs Phase 1
pullback: SL=350,400 × RR=1.5,2.0,2.5      = 6 runs Phase 1
validation: SL=300,350 × RR=1.5,2.0        = 4 runs Phase 1
```

Phase 2 adds 4 trailing stop variations for the best SL/RR from Phase 1.

### Minimum Viable Results (6-month window)

- PF > 1.15
- Trades > 15
- MaxDD < 50%
- Strategies with < 15 trades over 6 months are discarded

### Key Files

| File | Purpose |
|------|---------|
| `tools/run_worker6.py` | The automation runner |
| `tools/summarize_worker6.py` | Post-run summary generator |
| `data/config/worker6_results.json` | Running results (skip completed) |
| `config.yaml` | Gets overwritten each run |
| `STRATEGY-RESULTS.md` | Final output (created by summarizer) |
| `past_tests/MASTER_STRATEGIES.md` | Reference: original 2-month results |