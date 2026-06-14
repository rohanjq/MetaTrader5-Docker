# Onboarding: Running Backtests with MetaTrader5-Docker

This document explains how to develop and test trading strategies using the MT5 Docker container and the MasterTrader EA.

---

## Architecture Overview

```
config.yaml  →  gen_inputs.py  →  tester.ini  →  MT5 Strategy Tester  →  backtest_report.htm
```

| Component | Path | Purpose |
|---|---|---|
| Config | `config-tester.yaml` / `config-live.yaml` | **The only file you edit.** Defines strategies, dates, parameters. |
| Generator | `Metatrader/gen_inputs.py` | Converts YAML → MT5 `.ini` format at container startup. |
| EA | `Metatrader/MQL5/Experts/MasterTrader.mq5` | The expert advisor running inside MT5. |
| Parser | `tools/parse_report.py` | Reads MT5 HTML reports → JSON/CSV/human-readable. |

---

## Quick Start

### 1. Edit strategy config

```bash
# Create from a preset (or edit directly)
cp presets/7-best-tested.yaml config-tester.yaml
nano config-tester.yaml
```

Set `enabled: true` on the strategy(s) you want to test. All others must be `enabled: false`.

### 2. Run the backtest

```bash
cd /root/MetaTrader5-Docker

# Stop any existing container, clean reports, start fresh
podman-compose -f docker-compose.tester.yaml down
rm -f data/reports/backtest_report*

# Run tester mode
podman-compose -f docker-compose.tester.yaml up -d

# Wait for completion (1-30 seconds depending on date range)
while ! podman logs mt5 2>&1 | grep -q "Tester run complete"; do sleep 5; done
```

### 3. View results

```bash
# Summary stats
python3 tools/parse_report.py data/reports/backtest_report.htm --human

# Per-strategy breakdown
python3 tools/parse_report.py data/reports/backtest_report.htm --human --all

# Deals table (CSV)
python3 tools/parse_report.py data/reports/backtest_report.htm --csv --deals

# Everything as JSON
python3 tools/parse_report.py data/reports/backtest_report.htm --json --all -o results.json
```

---

## Config File Reference (`config.yaml`)

### Backtest section

```yaml
backtest:
  symbol: BTCUSDT          # trading symbol
  period: M1               # M1, M5, M15, M30, H1, H4, D1
  model: 1                 # 0=every tick, 1=open prices (fast), 2=1-min OHLC
  from: "2026.06.08"       # YYYY.MM.DD format
  to: "2026.06.13"
  deposit: 10000
  leverage: "1:100"
```

### Strategy slots (S01–S20)

Each strategy has 6 fields:

| Field | Type | Description |
|---|---|---|
| `name` | string | Display name (appears in report) |
| `enabled` | bool | `true` / `false` |
| `sl` | float | Stop loss in points (e.g., 500 = $5 on BTCUSDT) |
| `rr` | float | Reward:risk ratio (TP = SL * RR) |
| `buy` | string | Entry condition for buy (empty = no buy signals) |
| `sell` | string | Entry condition for sell (empty = no sell signals) |

**Example — both directions:**
```yaml
- name: stoch_reversal
  enabled: true
  sl: 500.0
  rr: 1.5
  buy:  "stoch_M15.zone==OS|utbot_H1.bias==BULLISH|ema200_M15.price_vs==ABOVE"
  sell: "stoch_M15.zone==OB|utbot_H1.bias==BEARISH|ema200_M15.price_vs==BELOW"
```

**Example — long only:**
```yaml
- name: bb_pullback
  enabled: true
  sl: 500.0
  rr: 1.5
  buy:  "bb_M15.reenter_below==TRUE|utbot_H1.bias==BULLISH|ema200_M15.price_vs==ABOVE"
  sell: ""
```

---

## Signal Reference

Entry conditions use the format: `indicator_timeframe.field operator value`

Conditions joined with `|` are AND-ed (all must be true). Operators: `==`, `!=`, `>`, `<`, `>=`, `<=`, `in`, `not_in`.

### Available signals

| Signal path | Values | Description |
|---|---|---|
| `utbot_TF.bias` | `BULLISH`, `BEARISH` | UT Bot trend bias |
| `utbot_TF.signal` | `BUY`, `SELL` | UT Bot entry signal |
| `rsi2_TF.zone` | `EXTREME_OB`, `OB`, `NEUTRAL`, `OS`, `EXTREME_OS` | RSI(2) zone |
| `rsi14_TF.zone` | `OB`, `NEUTRAL`, `OS` | RSI(14) zone |
| `stoch_TF.zone` | `OB`, `NEUTRAL`, `OS` | Stochastic zone |
| `adx_TF.strength` | `STRONG_TREND`, `TRENDING`, `WEAK_TREND`, `RANGING` | ADX strength |
| `adx_TF.di_bias` | `BULLISH`, `BEARISH` | DI bias |
| `emaX_TF.price_vs` | `ABOVE`, `BELOW` | Price vs EMA (X = period) |
| `emaX_TF.slope` | `RISING`, `FALLING`, `FLAT` | EMA slope |
| `vwap_TF.price_vs` | `ABOVE`, `BELOW` | Price vs VWAP |
| `bb_TF.reenter_below` | `TRUE`, `FALSE` | Price re-enters lower band |
| `bb_TF.reenter_above` | `TRUE`, `FALSE` | Price re-enters upper band |
| `bb_TF.squeeze` | `TRUE`, `FALSE` | BB squeeze |
| `macd_TF.cross` | `CROSS_UP`, `CROSS_DOWN`, `NONE` | MACD signal cross |
| `macd_TF.hist_dir` | `RISING`, `FALLING` | MACD histogram direction |
| `macd_TF.vs_zero` | `ABOVE`, `BELOW` | MACD vs zero line |
| `dc_TF.zone` | `UPPER`, `UPPER_MID`, `MIDDLE`, `LOWER_MID`, `LOWER` | Donchian zone |
| `dc_TF.lower_wick_rej` | `TRUE`, `FALSE` | Lower wick rejection |
| `dc_TF.upper_wick_rej` | `TRUE`, `FALSE` | Upper wick rejection |
| `candle_TF.is_bullish` | `TRUE`, `FALSE` | Bullish candle |
| `candle_TF.is_bearish` | `TRUE`, `FALSE` | Bearish candle |
| `candle_TF.type` | `DOJI`, `MARUBOZU`, `HAMMER`, `SHOOTING_STAR`, `SPINNING_TOP`, `NORMAL` | Candle pattern |
| `round_TF.dist_above` | decimal | Distance in $ to next round level above |
| `round_TF.dist_below` | decimal | Distance in $ to next round level below |
| `round_TF.pct` | decimal (0-100) | Position within round range (0=lower, 100=upper) |
| `liq_TF.upper_swept` | `TRUE`, `FALSE` | Wick swept above swing high, close came back below |
| `liq_TF.lower_swept` | `TRUE`, `FALSE` | Wick swept below swing low, close came back above |
| `liq_TF.upper_level` | decimal | Highest swing high in lookback window |
| `liq_TF.lower_level` | decimal | Lowest swing low in lookback window |

**Timeframes (TF):** `M1`, `M2`, `M3`, `M5`, `M10`, `M15`, `M30`, `H1`, `H4`, `D1`

### Example conditions

```
# RSI oversold + uptrend
rsi2_M5.zone in OS,EXTREME_OS|utbot_H1.bias==BULLISH|vwap_M5.price_vs==BELOW

# BB pullback + trend filter
bb_M15.reenter_below==TRUE|utbot_H1.bias==BULLISH|ema200_M15.price_vs==ABOVE

# Stochastic OB + bearish bias (short)
stoch_M15.zone==OB|utbot_H1.bias==BEARISH|vwap_M5.price_vs==ABOVE|ema200_M15.price_vs==BELOW

# Candlestick + ADX trend
candle_M5.is_bullish==TRUE|adx_M15.strength in STRONG_TREND,TRENDING|ema200_M15.price_vs==ABOVE
```

---

## Running Multiple Strategies

To test all strategies simultaneously (combined backtest), enable the ones you want:

```yaml
strategies:
  - name: s1
    enabled: true     # ← enable
    ...
  - name: s2
    enabled: true     # ← enable
    ...
  - name: s3
    enabled: false    # ← skip
    ...
```

To test a single strategy in isolation, enable only that one and disable all others.

---

## Parse Report Output

### `--human` (summary stats)

Shows: Total Net Profit, Profit Factor, Total Trades, Win Rate, Max Drawdown, Sharpe, Average trade stats, per-direction breakdown.

### `--all` (full output)

Adds Deals table and By-Strategy breakdown showing per-strategy PnL, trade count, and win rate.

### `--csv` / `--json`

Machine-readable output. Combine with `-o <file>` to write to disk. With `--all --csv -o output_dir/` each section gets a separate CSV file.

---

## Files You Should Not Edit

- `Metatrader/gen_inputs.py` — YAML → INI converter (touch only if adding new input types)
- `Metatrader/start.sh` — Container startup script
- `Metatrader/tester.ini` — Static INI template (generated fresh from YAML at runtime)
- `Metatrader/MQL5/Experts/MasterTrader.mq5` — EA source code

---

## Common Issues

| Problem | Cause | Fix |
|---|---|---|
| No report generated | Backtest failed (market closed, login issue) | Check `podman logs mt5` for errors |
| Report has `[N]` suffixes | Cache/stale config | `podman-compose -f docker-compose.tester.yaml down && rm -f data/reports/backtest_report* && podman-compose -f docker-compose.tester.yaml up -d` |
| Zero trades | Entry conditions too strict | Loosen filters (add NEUTRAL to zones, remove ADX) |
| Too many losing trades | Entry conditions too loose | Tighten filters, increase RR ratio |
| Short trades appear with sell="" | Not a bug — confirmed guard works | Check that another strategy isn't enabled with sell signals |

---

## Build/Rebuild

Only needed when changing EA code or start.sh:

```bash
podman-compose build
```

For config-only changes, just restart the container — no rebuild required.

---

## Container Commands

```bash
podman-compose -f docker-compose.tester.yaml down                     # stop container
podman-compose -f docker-compose.tester.yaml up -d    # start in tester mode
MT5_MODE=live podman-compose up -d      # start in live trading mode
podman logs mt5                         # view logs
podman exec -it mt5 bash                # shell into container
```