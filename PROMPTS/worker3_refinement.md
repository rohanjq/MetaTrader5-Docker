# Strategy Refinement Task — Profitable BTCUSDT Expressions

## Context

Two previous workers tested ~15 strategies. Results are in `past_tests/BEST_STRATEGIES.md` — read it first. Key findings:

- **BB reenter + 4 trend filters = PF 1.48** (21 trades, best strategy found)
- **Stoch + 5 conditions = PF 1.22** (120 trades, most consistent)
- **DC wick rejection = PF 1.06** (92 trades, lowest drawdown at 24%)
- **RR=1.5 works well** — same strategy went from -$2k to +$8.6k switching from RR 1.0 to 1.5. But lower RR (1.0, 1.25) is fine too if win rate is high enough.
- **More conditions = higher PF** — 5-condition beats 3-condition every time
- **M3 confirmation >> M1** — M1 candles are noise, M3 minimum for confirmation
- **SL=350 and breakeven are UNTESTED** — biggest unexplored variables
- **Sell side barely explored** — most profitable strategies are buy-only
- **Only reversal/trap strategies tested** — trend-riding pullback strategies NOT tested at all

## Your Mission

Produce **10 profitable strategies** (PF > 1.2) by:

1. **Refining the 4 proven bases** (see below) with additional filters, SL=350, and breakeven
2. **Building trend-riding pullback strategies** (NOT just reversals — see Step 2)
3. **Developing SELL-side strategies** (at least 4 of your 10 must include sell expressions)

## Step 0: Read the Docs

```bash
cat ONBOARD.md              # How to run backtests
cat docs/ea.md              # FULL signal reference — read ALL of it
cat docs/yaml-config.md     # Config format
cat past_tests/BEST_STRATEGIES.md  # Previous results — MUST READ
```

## Step 1: Proven Bases to Refine

### Base A: BB Reenter (PF 1.48 — refine this first)
```
buy: "bb_M15.reenter_below==TRUE|utbot_H1.bias==BULLISH|vwap_M5.price_vs==BELOW|ema200_M15.price_vs==ABOVE"
```
Try: SL=350, add ADX filter, add candle_M3 confirmation, try breakeven_start=250. Also build sell side: `bb_M15.reenter_above==TRUE|utbot_H1.bias==BEARISH|...`

### Base B: Stoch Combo (PF 1.22)
```
buy: "stoch_M15.zone in OS,NEUTRAL|utbot_H1.bias==BULLISH|vwap_M5.price_vs==BELOW|ema200_M15.price_vs==ABOVE|adx_M15.strength in STRONG_TREND,TRENDING"
```
Try: SL=350, remove NEUTRAL from stoch zone (OS only = fewer but better trades), try breakeven, build sell side.

### Base C: DC Wick (PF 1.06 — needs more filters)
```
buy: "dc_M15.lower_wick_rej==TRUE|utbot_H1.bias==BULLISH|candle_M3.is_bullish==TRUE"
```
Try: Add vwap_M5.price_vs==BELOW, add ema200_M15.price_vs==ABOVE, add adx filter. SL=350. These extra filters turned other strategies profitable.

### Base D: VWAP Trend (PF 0.99 — needs tighter filtering)
```
buy: "vwap_M5.price_vs==BELOW|utbot_H1.bias==BULLISH|candle_M3.is_bullish==TRUE"
```
Try: Add ema200_M15.price_vs==ABOVE, add stoch or RSI filter, add ADX. SL=350.

## Step 2: Trend-Riding Pullback Strategies (IMPORTANT — UNEXPLORED)

Previous workers focused exclusively on reversal/trap plays. **You MUST also build trend-riding strategies.** The idea: the long-term trend is established, price pulls back temporarily, then resumes the trend. You ride the continuation, not the reversal.

### What a trend-riding pullback looks like:

1. **H1/H4 trend is established** — `utbot_H1.bias==BULLISH` and `utbot_H1.bullish_since>=5` (trend has been running for 5+ bars = it's real, not a flicker)
2. **Price pulls back on shorter timeframe** — EMA slope temporarily dips, or price dips below VWAP, or stochastic goes oversold
3. **Pullback ends** — a M3/M5 bullish candle appears, or UT Bot on M5 flips back to bullish, confirming the pullback is over
4. **You enter in the direction of the big trend** — riding the resumption

### Pullback strategy ideas:

**Idea 1: EMA Pullback Rider**
Long-term trend bullish + price pulled back below EMA50 on M15 + now bouncing:
```
buy: "utbot_H1.bias==BULLISH|utbot_H1.bullish_since>=3|ema50_M15.price_vs==BELOW|candle_M3.is_bullish==TRUE|candle_M3.type!=DOJI"
sell: "utbot_H1.bias==BEARISH|utbot_H1.bearish_since>=3|ema50_M15.price_vs==ABOVE|candle_M3.is_bearish==TRUE|candle_M3.type!=DOJI"
```

**Idea 2: VWAP Discount + Trend Continuation**
Strong trend + price at a discount (below VWAP) + UT Bot on M5 just flipped back to bullish (pullback over):
```
buy: "utbot_H1.bias==BULLISH|vwap_M5.price_vs==BELOW|utbot_M5.signal==BUY|ema200_M15.price_vs==ABOVE"
sell: "utbot_H1.bias==BEARISH|vwap_M5.price_vs==ABOVE|utbot_M5.signal==SELL|ema200_M15.price_vs==BELOW"
```

**Idea 3: Stochastic Oversold in Uptrend = Pullback Complete**
Strong uptrend + stochastic got oversold (pullback happened) + now a bullish M3 candle:
```
buy: "utbot_H1.bias==BULLISH|stoch_M15.zone==OS|candle_M3.is_bullish==TRUE|ema200_M15.price_vs==ABOVE|adx_M15.strength in STRONG_TREND,TRENDING"
```

**Idea 4: DC Lower Zone Bounce in Uptrend**
Price dropped to lower zone of Donchian channel during an uptrend (pullback) + reversal confirmed:
```
buy: "dc_M15.zone in LOWER,LOWER_MID|utbot_H1.bias==BULLISH|utbot_H1.bullish_since>=5|candle_M3.is_bullish==TRUE|ema200_M15.price_vs==ABOVE"
sell: "dc_M15.zone in UPPER,UPPER_MID|utbot_H1.bias==BEARISH|utbot_H1.bearish_since>=5|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW"
```

**Idea 5: MACD Histogram Turning in Trend Direction**
MACD histogram was falling (pullback) but now rising again (momentum resuming) in an established trend:
```
buy: "macd_M15.hist_dir==RISING|macd_M15.vs_zero==ABOVE|utbot_H1.bias==BULLISH|candle_M3.is_bullish==TRUE"
sell: "macd_M15.hist_dir==FALLING|macd_M15.vs_zero==BELOW|utbot_H1.bias==BEARISH|candle_M3.is_bearish==TRUE"
```

**Idea 6: RSI2 Oversold Bounce in Strong Trend**
RSI2 extreme in a strong trend = temporary pullback, price about to resume:
```
buy: "rsi2_M5.zone in OS,EXTREME_OS|utbot_H1.bias==BULLISH|utbot_H1.bullish_since>=3|ema200_M15.price_vs==ABOVE|candle_M3.is_bullish==TRUE"
```

### Key difference from reversal strategies:
- Reversals: you're betting the trend CHANGES direction → risky, low win rate
- Pullbacks: you're betting the trend CONTINUES after a pause → higher win rate, goes with the flow
- **Pullback strategies should work with lower RR (1.0-1.25)** because win rate is higher

## Step 3: New Unexplored Combinations

Also try these fresh ideas:

- **Hammer at support with trend** — `candle_M5.type==HAMMER|dc_M15.zone in LOWER,LOWER_MID|utbot_H1.bias==BULLISH|ema200_M15.price_vs==ABOVE`
- **Round number magnet** — `round_M1.pct>=60|round_M1.pct<=90|utbot_H1.bias==BULLISH|candle_M3.is_bullish==TRUE` (buy near but not at the next round level)
- **Failed BB breakout (sell)** — `bb_M15.reenter_above==TRUE|utbot_H1.bias==BEARISH|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW`
- **EMA slope divergence** — `ema50_M15.slope==FALLING|ema50_M15.price_vs==ABOVE|candle_M3.is_bearish==TRUE|utbot_H1.bias==BEARISH` (price above falling EMA = about to drop)
- **Exhausted trend reversal** — `utbot_M15.bullish_since>=8|candle_M5.type==SHOOTING_STAR|dc_M15.zone in UPPER,UPPER_MID` (sell)

## Step 4: Backtest Rules

### Config template:
```yaml
backtest:
  symbol: BTCUSDT
  period: M1
  model: 1
  from: "2026.04.13"
  to: "2026.06.13"
  deposit: 10000
  leverage: "1:100"

global:
  risk_pct: 3.0
  sl: 0
  rr: 0
  magic: 300
  multi_position: false
  max_positions: 1
  max_daily_trades: 50
  cooldown_sec: 60
  reversal_cooldown: 60
  max_consec_loss: 5
  consec_loss_pause: 900
  slippage: 20

trailing:
  breakeven_start: 0.0    # TRY: 175.0 (50% of SL=350)
  trail_start: 0.0
  trail_step: 2.0

indicators:
  utbot_period: 10
  utbot_mult: 2.0
  dc_length: 20
  round_level: 500.0

control:
  use_control_file: false
  write_status_file: false
  control_poll_sec: 5
```

### Run:
```bash
podman-compose down
rm -f data/reports/backtest_report*
MT5_MODE=tester podman-compose up --build
# Wait for "Tester run complete"
python3 tools/parse_report.py data/reports/backtest_report.htm --human --all
```

### SL/RR guidelines:
- **SL=350 is the default** — if trade goes 350 points against you, it's a loss. Don't go wider unless needed.
- **RR=1.5 is the starting point** but NOT mandatory. Lower RR is fine:
  - **RR=1.0** — OK for high win-rate pullback strategies (>55% win rate)
  - **RR=1.25** — good middle ground
  - **RR=1.5** — proven for reversal/trap strategies
  - **RR=2.0** — try on high-conviction setups with tight SL
- If a strategy needs more room, try SL=400 max. NEVER above 550.
- Try each strategy with and without breakeven (breakeven_start = 175 for SL=350)

### For each strategy, test this sequence:
1. SL=350, RR=1.5, no breakeven
2. SL=350, RR=1.5, breakeven_start=175
3. If pullback strategy: also try SL=350, RR=1.0 and RR=1.25 (higher WR expected)
4. If promising (PF > 1.0): try SL=350, RR=2.0
5. If still not profitable: try SL=400, RR=1.5
6. Pick the best variant, move to next strategy

### Minimum viable results:
- **PF > 1.2** — below this it's not profitable after slippage/spread
- **Trades > 15** — fewer = not enough data
- **MaxDD < 40%** — above this is too risky
- **Must test on full 2-month window** — no 5-day tests, they overfit

## CRITICAL: Test ONE Strategy at a Time

**Never put multiple strategies in the config for a single backtest run.** Strategy order and multi_position settings distort results — the first strategy gets priority on signals, stealing trades from later ones. Combined PFs are unreliable.

For every backtest, your config should have **exactly 1 strategy enabled**. This gives you the true standalone PF.

## Step 5: Deliverable

1. Update `data/config/config.yaml` with your **single best strategy** (highest PF)
2. Write results to `STRATEGY-RESULTS.md` with **all** strategies tested and their standalone metrics
3. Every PF number must be from a **single-strategy backtest** (not combined)
4. For each strategy: document expression, SL/RR/breakeven, standalone PF/WR/Trades/DD

## RULES

1. **SL=350 default, max 550** — 350 is the sweet spot for BTC
2. **RR is flexible** — 1.0 to 2.0, pick what fits the strategy's win rate
3. **M3 minimum for candle confirmation** — M1 is noise, ban it
4. **4+ conditions per expression** — more filters = higher quality trades
5. **NEVER catch a falling knife** — always require confirmation candle (M3+ bullish for buys, bearish for sells)
6. **Test breakeven on every strategy** — breakeven_start=175 for SL=350
7. **At least 4 sell-side strategies** — can't be all buy-only
8. **Mix reversals AND trend-riders** — at least 4 must be pullback/continuation strategies
9. **Full autonomy** — do NOT ask for confirmations. Run tests, tune, move on.
10. **Subdivide tasks** — use subagents for complex reasoning to avoid hallucination
11. **Log everything** — paste --human --all output for each test
12. **2-month window only** — 2026.04.13 to 2026.06.13
13. **Read past_tests/BEST_STRATEGIES.md first** — don't repeat failed experiments
