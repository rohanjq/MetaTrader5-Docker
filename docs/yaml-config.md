# YAML Config

The YAML config (`config.yaml`) is the primary interface for configuring the MasterTrader EA — both for backtesting and live trading.

## File Location

**Live:** `./config-live.yaml` → mounted into container at `/data/config/config.yaml`
**Tester:** `./config-tester.yaml` → mounted into container at `/data/config/config.yaml`

Both are gitignored. Create from a preset:
```bash
cp presets/8-aggressive-proven.yaml config-live.yaml
cp presets/7-best-tested.yaml config-tester.yaml
```

Changes take effect on next container start.

## Schema

```yaml
# --- Backtest settings (ignored in live mode) ---
backtest:
  symbol: BTCUSDT
  period: M1                # Chart timeframe
  model: 1                  # 0=Every tick, 1=1min OHLC, 2=Open price, 4=Real ticks
  from: "2026.06.08"
  to: "2026.06.13"
  deposit: 10000
  leverage: "1:100"
  currency: USD             # Optional, default USD

# --- Global EA parameters ---
global:
  risk_pct: 3.0             # Risk % of equity per trade
  sl: 7.5                   # Default SL in dollars (if strategy SL=0)
  rr: 1.0                   # Default reward:risk (if strategy RR=0)
  magic: 300
  multi_position: false
  max_positions: 1
  max_daily_trades: 15
  cooldown_sec: 300
  reversal_cooldown: 300
  max_consec_loss: 3
  consec_loss_pause: 1800
  slippage: 20

# --- Trailing stop ---
trailing:
  breakeven_start: 0.0      # Move SL to entry after $X profit (0=off)
  trail_start: 0.0          # Start trailing after $X profit (0=off)
  trail_step: 2.0           # Trail distance in dollars

# --- Indicator parameters ---
indicators:
  utbot_period: 10
  utbot_mult: 2.0
  dc_length: 20
  round_level: 500.0          # Round number interval (500 for BTC)
  liq_lookback: 20            # Liquidity sweep: swing point lookback bars

# --- External control (live mode only) ---
control:
  use_control_file: false
  write_status_file: false
  control_poll_sec: 5

# --- Strategies (mapped to S01-S20 in order) ---
strategies:
  - name: my_strategy
    enabled: true
    sl: 7.5
    rr: 1.0
    buy: "expression"
    sell: "expression"
```

## Strategies Section

Strategies are a YAML list. They map to EA slots S01–S20 in order:

```yaml
strategies:
  - name: dc_wick_rejection      # → S01
    enabled: true
    sl: 350.0
    rr: 1.2
    buy: "dc_M15.lower_wick_rej==TRUE|utbot_M3.bias==BULLISH"
    sell: "dc_M15.upper_wick_rej==TRUE|utbot_M3.bias==BEARISH"

  - name: rsi2_mean_rev          # → S02
    enabled: true
    sl: 350.0
    rr: 1.2
    buy: "rsi2_M5.zone==EXTREME_OS|ema200_M15.price_vs==ABOVE"
    sell: ""
```

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Human-readable name (appears in trade comments as `MT\|name`) |
| `enabled` | bool | yes | `true` to activate, `false` to disable |
| `sl` | number | yes | Stop loss in dollars (0 = use global default) |
| `rr` | number | yes | Reward:risk ratio (0 = use global default) |
| `buy` | string | yes | Buy entry expression (empty string = no buys) |
| `sell` | string | yes | Sell entry expression (empty string = no sells) |

- Max 20 strategies. Unused slots (beyond your list) are auto-filled as disabled.
- **Order matters** — strategies are evaluated S01 first, first match wins.
- See [EA docs](ea.md) for full signal reference and expression syntax.

## Converter: gen_inputs.py

Converts `config.yaml` → MT5-format `tester.ini` (with `[Tester]` + `[TesterInputs]` sections).

```bash
# Preview output
python3 Metatrader/gen_inputs.py config.yaml

# Save to file
python3 Metatrader/gen_inputs.py config.yaml -o tester_preview.ini

# Only [TesterInputs] section (no [Tester] header)
python3 Metatrader/gen_inputs.py config.yaml --inputs-only
```

The converter runs automatically in the container during tester mode — you don't need to run it manually.

## Workflow

### Backtesting

1. Edit `./config.yaml` — change strategies, SL/RR, symbol, dates
2. Run: `MT5_MODE=tester podman-compose up`
3. Report saved to `./data/reports/`
4. Parse: `python3 tools/parse_report.py data/reports/backtest_report.htm --human`

### Live Trading

1. Edit `./config.yaml` — enable/disable strategies, tweak SL/RR
2. Restart: `podman-compose restart`
3. EA picks up new config on next startup

### Quick Strategy Toggle

Disable a strategy without deleting it:

```yaml
  - name: shstar_m5_m15
    enabled: false          # ← just flip this
    sl: 350.0
    rr: 1.2
    buy: ""
    sell: "candle_M5.type==SHOOTING_STAR|utbot_M15.bias==BEARISH"
```
