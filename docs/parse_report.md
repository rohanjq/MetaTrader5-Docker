# parse_report.py

Parses MT5 Strategy Tester HTML reports into JSON, CSV, or human-readable output.

Located at: `tools/parse_report.py`

## Usage

```bash
# Format flags (pick one, default: --json)
python3 tools/parse_report.py report.htm              # JSON
python3 tools/parse_report.py report.htm --csv         # CSV
python3 tools/parse_report.py report.htm --human       # Human-readable

# Section flags (pick one, default: --summary)
python3 tools/parse_report.py report.htm --summary     # Summary stats only
python3 tools/parse_report.py report.htm --deals       # Deals table only
python3 tools/parse_report.py report.htm --orders      # Orders table only
python3 tools/parse_report.py report.htm --all         # All sections

# Combine freely
python3 tools/parse_report.py report.htm --human --all
python3 tools/parse_report.py report.htm --csv --deals -o deals.csv
python3 tools/parse_report.py report.htm --all -o results.json
python3 tools/parse_report.py report.htm --csv --all -o output_dir/
```

## Output: `--summary` (default)

Key-value dict of all backtest statistics. 46 metrics total.

| Field | Example | Description |
|---|---|---|
| `Total Net Profit` | `-3729.44` | Net P&L after all trades |
| `Gross Profit` | `13536.77` | Sum of all winning trades |
| `Gross Loss` | `-17266.21` | Sum of all losing trades |
| `Profit Factor` | `0.78` | Gross Profit / |Gross Loss| |
| `Expected Payoff` | `-90.96` | Average profit per trade |
| `Sharpe Ratio` | `-5.00` | Risk-adjusted return |
| `Recovery Factor` | `-0.47` | Net Profit / Max Drawdown |
| `Total Trades` | `41` | Number of round-trip trades |
| `Total Deals` | `82` | Individual deal executions |
| `Profit Trades (% of total)` | `17(41.46%)` | Winning trades count and % |
| `Loss Trades (% of total)` | `24(58.54%)` | Losing trades count and % |
| `Short Trades (won %)` | `17(41.18%)` | Short trades count and win % |
| `Long Trades (won %)` | `24(41.67%)` | Long trades count and win % |
| `Balance Drawdown Maximal` | `7211.80(54.32%)` | Max drawdown in $ and % |
| `Equity Drawdown Maximal` | `7979.36(58.13%)` | Max equity drawdown |
| `Balance Drawdown Absolute` | `3934.63` | Max balance drop from initial |
| `Largest profit trade` | `1095.98` | Best single trade |
| `Largest loss trade` | `-998.10` | Worst single trade |
| `Average profit trade` | `796.28` | Mean winning trade |
| `Average loss trade` | `-719.43` | Mean losing trade |
| `Maximum consecutive wins ($)` | `4(3875.17)` | Longest win streak (count and $) |
| `Maximum consecutive losses ($)` | `6(-4427.04)` | Longest loss streak |
| `Average consecutive wins` | `2` | Typical win streak length |
| `Average consecutive losses` | `2` | Typical loss streak length |
| `AHPR` | `0.9919(-0.81%)` | Arithmetic holding period return |
| `GHPR` | `0.9887(-1.13%)` | Geometric holding period return |
| `LR Correlation` | `-0.78` | Linear regression correlation |
| `LR Standard Error` | `1147.29` | Linear regression std error |
| `Z-Score` | `-0.13(10.34%)` | Serial correlation of wins/losses |
| `Margin Level` | `3376.01%` | Account margin level |
| `History Quality` | `100%` | Tick data quality |
| `Bars` | `7200` | Number of bars in test |
| `Ticks` | `28751` | Number of ticks processed |
| `Minimal position holding time` | `0:05:40` | Shortest trade duration |
| `Maximal position holding time` | `9:51:40` | Longest trade duration |
| `Average position holding time` | `1:40:53` | Mean trade duration |

## Output: `--deals`

Each deal (individual execution) as an object/row.

| Field | Example | Description |
|---|---|---|
| `time` | `2026.06.08 01:10:00` | Execution timestamp |
| `deal` | `2` | Deal ticket number |
| `symbol` | `BTCUSDT` | Traded symbol |
| `type` | `buy` | `buy`, `sell`, or `balance` |
| `direction` | `in` | `in` (open) or `out` (close) |
| `volume` | `2.14` | Lot size |
| `price` | `63281.0` | Execution price |
| `order` | `2` | Parent order ticket |
| `commission` | `0.00` | Commission charged |
| `swap` | `0.00` | Swap charged |
| `profit` | `0.00` | Realized P&L (0 on entry deals) |
| `balance` | `10000.00` | Account balance after deal |
| `comment` | `MT\|rsi2_mean_rev_full` | EA comment (strategy source) |
| `strategy` | `rsi2_mean_rev_full` | Extracted strategy name (from `MT\|` prefix) |

## Output: `--orders`

Each order placed by the EA.

| Field | Example | Description |
|---|---|---|
| `open_time` | `2026.06.08 01:10:00` | Order creation time |
| `order` | `2` | Order ticket |
| `symbol` | `BTCUSDT` | Symbol |
| `type` | `buy` | Order type |
| `volume` | `2.14 / 2.14` | Requested / filled volume |
| `price` | `0.0` | Order price (0 = market) |
| `sl` | `62931.0` | Stop loss level |
| `tp` | `63701.0` | Take profit level |
| `time` | `2026.06.08 01:10:00` | Fill time |
| `state` | `filled` | Order state |
| `comment` | `MT\|rsi2_mean_rev_full` | EA comment |

## Output: `--human`

Stripped-down summary showing only the important metrics, plus optional trades and per-strategy breakdown.

```
═══ BACKTEST SUMMARY ═══

  Total Net Profit                         -3729.44
  Profit Factor                            0.78
  Total Trades                             41
  ...

═══ BY STRATEGY ═══
  Strategy                                 Trades   Buys  Sells
  ────────────────────────────────────────────────────────────
  rsi2_mean_rev_full                           14     14      0
  shstar_m5_m15                                10      0     10
  ...
```

## Notes

- MT5 reports are UTF-16LE encoded; the parser handles this automatically.
- Number formatting (e.g. `13 536.77` with space separators) is cleaned automatically.
- The `strategy` field is derived from the EA comment format `MT|strategy_name`.
- When using `--csv -o directory/`, each section is written as a separate `.csv` file (`summary.csv`, `deals.csv`, `orders.csv`).
