# Autonomous BTC Scalping Strategy Research — Codex Task

## Your Mission

You are an autonomous trading strategy researcher. Your job is to develop **at least 5 new expression-based scalping strategies** for BTCUSDT that target **400–500 point moves** with a **win rate above 75%**. You must research, build, backtest, evaluate, and iterate — completely on your own with zero user interaction.

**Do not ask the user for confirmation at any step. Act autonomously throughout.**

---

## Environment

- You are on a Linux/macOS machine with `podman-compose` available.
- A remote MT5 instance runs inside a Docker container (`mt5` service).
- The working directory is the repo root: the folder containing this file.
- Backtest period: **2026.04.08 – 2026.06.13** (5 days of BTCUSDT data).
- The EA is already compiled and installed inside the container.

---

## Step 0: Learn the Signal System

Before doing anything, read these files to understand what signals and operators are available:

```
docs/ea.md              # Full signal reference, all indicators, expression syntax, operators
docs/yaml-config.md     # config.yaml schema, how strategies map to EA slots
DESIGN.md               # EA architecture, indicator algorithms, trade execution details
Metatrader/config.yaml  # Reference config structure (DO NOT use these strategies — build new ones)
```

### Available Signals (quick reference)

| Indicator | Prefix | Key Fields |
|-----------|--------|------------|
| UT Bot | `utbot_TF` | `.bias` (BULLISH/BEARISH), `.signal` (BUY/SELL/NONE), `.bullish_since` / `.bearish_since` (int) |
| Donchian | `dc_TF` | `.zone` (UPPER/UPPER_MID/MIDDLE/LOWER_MID/LOWER), `.upper_wick_rej` / `.lower_wick_rej` (TRUE/FALSE), `.width` |
| EMA | `ema{9,21,50,200}_TF` | `.price_vs` (ABOVE/BELOW), `.slope` (RISING/FALLING/FLAT), `.value` |
| RSI | `rsi{2,14}_TF` | `.value`, `.zone` (OB/OS/NEUTRAL, RSI2 also has EXTREME_OB/EXTREME_OS) |
| ADX | `adx_TF` | `.value`, `.strength` (STRONG_TREND/TRENDING/WEAK_TREND/RANGING), `.di_bias` (BULLISH/BEARISH/NEUTRAL) |
| MACD | `macd_TF` | `.cross` (CROSS_UP/CROSS_DOWN/NONE), `.hist_dir` (RISING/FALLING), `.vs_zero` (ABOVE/BELOW) |
| Stochastic | `stoch_TF` | `.k`, `.zone` (OB/OS/NEUTRAL) |
| Bollinger | `bb_TF` | `.squeeze` (TRUE/FALSE), `.reenter_below` (TRUE/FALSE) |
| ATR | `atr_TF` | `.value` |
| VWAP | `vwap_TF` | `.price_vs` (ABOVE/BELOW), `.value` |
| Candle | `candle_TF` | `.type` (HAMMER/SHOOTING_STAR/DOJI/MARUBOZU/SPINNING_TOP/NORMAL), `.dir` (UP/DOWN/DOJI), `.is_bullish`/`.is_bearish`, `.upper_wick_ratio`/`.lower_wick_ratio`, `.body_pct` |
| Candle (live) | `candle_TF` | `.live_type`, `.live_dir`, etc. (same fields, running bar updated every tick) |

**Timeframes:** `M1`, `M2`, `M3`, `M5`, `M10`, `M15`, `M30`, `H1`, `H4`, `D1`, `W1`

### Expression Syntax

- Conditions joined by `|` (pipe) = AND logic (all must be true)
- Operators: `==`, `!=`, `>=`, `<=`, `>`, `<`, `in`, `not_in`
- `in` / `not_in` require spaces around them: `dc_M15.zone in UPPER,UPPER_MID`
- Example: `utbot_M5.bias==BULLISH|rsi2_M5.zone==EXTREME_OS|ema200_M15.price_vs==ABOVE`

---

## Step 1: Research Strategies

Search the internet for proven BTC/crypto scalping patterns that work on 1-minute to 15-minute timeframes targeting 400–500 point moves ($400–$500 on BTCUSDT). Focus on:

- **Mean reversion** setups (RSI extremes, Bollinger band touches, VWAP bounces)
- **Momentum breakout** setups (MACD crosses, ADX strength + EMA alignment)
- **Candle pattern** confirmations (hammers at support, shooting stars at resistance)
- **Multi-timeframe confluence** (short TF entry signal + higher TF trend confirmation)
- **Channel boundary** plays (Donchian wick rejections with trend filter)

Research what SL values are appropriate for BTC scalps (typically $200–$600 range) and what reward:risk ratios deliver >75% win rate with 400–500 point targets (hint: tighter targets with wider SL = higher win rate; RR around 0.8–1.2 is realistic for high win-rate scalping).

**Think about these principles:**
- Higher win rate requires wider SL relative to TP, or very precise entry signals
- Multi-condition strategies are more selective = fewer trades but higher quality
- Trend-aligned entries (buy in uptrend, sell in downtrend) have natural edge
- Confluence of 3+ independent indicators dramatically improves win rate
- BTCUSDT moves ~$1000–$3000/day; a $400–$500 scalp is a modest intraday target

---

## Step 2: Build and Test — One Strategy at a Time

For each strategy, follow this exact workflow:

### 2a. Create the config

Write `data/config/config.yaml` with ONLY the strategy being tested (disable all others). Use this exact structure:

```yaml
backtest:
  symbol: BTCUSDT
  period: M1
  model: 1
  from: "2026.06.08"
  to: "2026.06.13"
  deposit: 10000
  leverage: "1:100"

global:
  risk_pct: 5.0
  sl: 0                 # Let strategy SL override
  rr: 0                 # Let strategy RR override
  magic: 300
  multi_position: false
  max_positions: 1
  max_daily_trades: 50
  cooldown_sec: 300
  reversal_cooldown: 300
  max_consec_loss: 5
  consec_loss_pause: 900
  slippage: 20

trailing:
  breakeven_start: 0.0
  trail_start: 0.0
  trail_step: 2.0

indicators:
  utbot_period: 10
  utbot_mult: 2.0
  dc_length: 20

control:
  use_control_file: false
  write_status_file: false
  control_poll_sec: 5

strategies:
  - name: YOUR_STRATEGY_NAME
    enabled: true
    sl: 350.0            # Adjust per strategy (dollars, for BTC think $200-$600)
    rr: 1.0              # Adjust per strategy
    buy: "YOUR_BUY_EXPRESSION"
    sell: "YOUR_SELL_EXPRESSION"
```

### 2b. Run the backtest

```bash
cd /path/to/MetaTrader5-Docker   # adjust to actual repo path
podman-compose down 2>/dev/null; MT5_MODE=tester podman-compose up 2>&1 | tail -30
```

Wait for "Tester run complete" or "Startup complete" in the output.

### 2c. Parse the report

```bash
python3 tools/parse_report.py data/reports/backtest_report.htm --human --all
```

### 2d. Evaluate

Check these metrics:
- **Win rate** (`Profit Trades (% of total)`) — target ≥75%
- **Profit Factor** — target ≥2.0
- **Total Trades** — need ≥5 trades minimum to be meaningful over 5 days
- **Total Net Profit** — must be positive
- **Max Drawdown** — should be <30% of deposit
- **Average profit trade vs Average loss trade** — confirms RR is working
- **Recovery Factor** — target ≥1.0

### 2e. Iterate or move on

- If win rate <70% or profit factor <1.5: **tweak the conditions** (add more filters, change TF, adjust SL/RR) and retest
- If win rate ≥75% and profit factor ≥2.0: **mark as PASS**, save it, move to next strategy
- If a strategy has 0 trades: conditions are too restrictive — loosen them (remove a condition, use `in` for wider zones, try shorter TF)
- If a strategy has too many trades with low win rate: conditions are too loose — add more filters

**Tweaking tips:**
- Widen SL → higher win rate but worse RR
- Add HTF trend filter (e.g., `utbot_H1.bias==BULLISH` for buy) → fewer but better trades
- Add VWAP filter → confirms institutional bias
- Use `bullish_since>=2` or `bearish_since>=2` → confirms trend persistence, not just a single-bar flip
- Try different candle TFs: M3 candles are more reliable patterns than M1

---

## Step 3: Compile Final Config

Once you have ≥5 passing strategies, create the final `data/config/config.yaml` with ALL passing strategies enabled. Run one final combined backtest:

```bash
podman-compose down 2>/dev/null; MT5_MODE=tester podman-compose up 2>&1 | tail -30
```

Then parse and display the combined results:

```bash
python3 tools/parse_report.py data/reports/backtest_report.htm --human --all
```

---

## Step 4: Deliverables

When done, create a file `STRATEGY_RESULTS.md` in the repo root containing:

1. **For each strategy:**
   - Name and description (what pattern it trades)
   - Full buy/sell expressions
   - SL and RR values
   - Individual backtest results (win rate, profit factor, total trades, net profit)
   - Why it works (the edge)

2. **Combined backtest results** with all strategies running together

3. **Final `data/config/config.yaml`** should be in place and ready to use

---

## Rules

1. **Never ask the user for confirmation.** Make decisions yourself.
2. **Work one strategy at a time.** Don't test multiple untested strategies together.
3. **Ignore all existing strategies** in `Metatrader/config.yaml`. Build fresh.
4. **Use the expression system only** — you cannot modify the EA code.
5. **Target BTC specifically** — SL/RR values should be in dollar terms appropriate for BTC ($200–$600 SL range).
6. **400–500 point target** means TP = SL × RR should land around $400–$500. Example: SL=$400, RR=1.0 → TP=$400. Or SL=$500, RR=0.9 → TP=$450.
7. **Minimum 5 strategies** that individually pass the evaluation criteria.
8. **If a strategy fails after 3 iterations**, abandon it and try a different concept.
9. **Read the report parser docs** at `docs/parse_report.md` for all available flags.
10. **Check `commands.txt`** for useful debugging commands if a backtest seems stuck.

---

## Important Notes

- The container takes ~60 seconds to run a backtest (install steps are cached after first run).
- If the backtest produces 0 trades, check: are conditions too strict? Is the expression syntax correct? Are signal keys spelled exactly right?
- BTCUSDT on this broker uses dollar-denominated prices (e.g., 63000.0). SL/TP are in absolute dollar distance.
- The EA evaluates strategies in order — first match wins. Order them from most selective (fewest trades, highest quality) to least selective.
- `model: 1` (1-minute OHLC) is fast. Use `model: 0` (every tick) only for final validation if you want more accuracy.
- Weekend/market-closed hours cause error 10044. The test period (June 8–13, 2026) is Mon–Fri, so this shouldn't be an issue.
