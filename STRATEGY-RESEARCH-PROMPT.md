# Strategy Research Task — Market Trap & Candle Pattern Strategies for BTCUSDT

## Your Mission

You are a quantitative trading strategy researcher. Your job is to design **10 unique, unconventional strategies** for BTCUSDT that catch **market traps** — situations where price fakes out in one direction then reverses hard. These are NOT standard textbook strategies. You must think like a predator reading the footprint of trapped traders.

**Do not** build strategies around generic "RSI oversold + trend filter" setups. Those are boring and everyone uses them. Instead, think about **what the candles themselves reveal** about trapped participants, failed breakouts, exhaustion moves, and reversal mechanics.

---

## Step 0: Read the Documentation

Before doing anything, read these files to understand the system:

```bash
cat ONBOARD.md          # How to run backtests — START HERE
cat docs/ea.md          # Full signal reference — ALL available signals
cat docs/yaml-config.md # How config.yaml works
cat DESIGN.md           # EA internals (how signals are computed)
```

You **must** understand the available signals before designing strategies. The EA uses an expression engine — strategies are just condition strings, no code changes needed.

---

## Step 1: Understand What You Have Available

The EA computes these signals on **11 timeframes** (M1 through W1) every new bar:

### Candle anatomy (your primary weapon)
```
candle_TF.type          → DOJI, MARUBOZU, HAMMER, SHOOTING_STAR, SPINNING_TOP, NORMAL
candle_TF.dir           → UP, DOWN, DOJI
candle_TF.is_bullish    → TRUE/FALSE
candle_TF.is_bearish    → TRUE/FALSE
candle_TF.upper_wick_ratio  → decimal (upper_wick / body — KEY for trap detection)
candle_TF.lower_wick_ratio  → decimal (lower_wick / body)
candle_TF.body_pct      → decimal (body as % of total range)
candle_TF.live_*        → same fields but for the RUNNING bar (updates every tick)
```

### Trend context
```
utbot_TF.bias           → BULLISH/BEARISH (ATR trailing stop direction)
utbot_TF.signal         → BUY/SELL/NONE (one-bar flash on direction flip)
utbot_TF.bullish_since  → integer (consecutive bars in current direction)
utbot_TF.bearish_since  → integer
```

### Channel position
```
dc_TF.zone              → UPPER/UPPER_MID/MIDDLE/LOWER_MID/LOWER (where price sits in Donchian channel)
dc_TF.upper_wick_rej    → TRUE/FALSE (wick pierced upper band but close retreated)
dc_TF.lower_wick_rej    → TRUE/FALSE
dc_TF.width             → decimal (channel width)
```

### Momentum / mean reversion
```
rsi2_TF.zone            → EXTREME_OB/OB/NEUTRAL/OS/EXTREME_OS
rsi2_TF.value           → decimal
rsi14_TF.zone           → OB/NEUTRAL/OS
stoch_TF.zone           → OB/OS/NEUTRAL
macd_TF.cross           → CROSS_UP/CROSS_DOWN/NONE
macd_TF.hist_dir        → RISING/FALLING
macd_TF.vs_zero         → ABOVE/BELOW
adx_TF.strength         → STRONG_TREND/TRENDING/WEAK_TREND/RANGING
adx_TF.di_bias          → BULLISH/BEARISH/NEUTRAL
bb_TF.squeeze           → TRUE/FALSE
bb_TF.reenter_below     → TRUE/FALSE (was below lower band, now back inside)
bb_TF.reenter_above     → TRUE/FALSE (was above upper band, now back inside)
```

### Trend structure
```
ema9_TF.price_vs / .slope / .value
ema21_TF.price_vs / .slope / .value
ema50_TF.price_vs / .slope / .value
ema200_TF.price_vs / .slope / .value    (ABOVE/BELOW, RISING/FALLING/FLAT)
vwap_TF.price_vs / .value              (ABOVE/BELOW session VWAP)
atr_TF.value                            (volatility)
```

### Expression syntax
```
condition1|condition2|condition3        ← ALL must be true (AND)
signal_key==VALUE                      ← equals
signal_key!=VALUE                      ← not equals
signal_key>=N / <=N / >N / <N         ← numeric comparison
signal_key in VAL1,VAL2               ← set membership
signal_key not_in VAL1,VAL2           ← set exclusion
```

### Timeframes available
`M1, M2, M3, M5, M10, M15, M30, H1, H4, D1, W1`

---

## Step 2: Strategy Design Philosophy — THINK ABOUT TRAPS

The core insight: **markets move by trapping traders on the wrong side, then reversing.** Your strategies should detect the fingerprint of a trap.

### What a trap looks like in candle data:

1. **Full-body marubozu in the wrong direction then reversal** — If a large M15 or H1 candle has no wicks (body_pct >= 80, i.e. MARUBOZU) going against the higher trend, it's often a liquidity grab. The next candle or two often reverse violently. The wickless candle means it smashed through stops — those stops are the fuel for reversal.

2. **Consecutive small-timeframe full-body reversals** — 2-3 consecutive M1 or M3 MARUBOZU candles in the opposite direction after a move = real reversal building. Not just a wick, but full committed bodies flipping direction.

3. **H1 candle complete reversal** — An H1 candle that opened bearish (or bullish) but by close is the opposite direction with a large body. Check this via H1 candle type + direction against the prior H1's direction.

4. **Wick rejection at extreme channel zones** — Not just any wick rejection, but one where the wick ratio is extreme (>= 3x body) at the edge of the Donchian channel. This means price tried hard to break out, got slapped back violently.

5. **Failed breakout / re-entry traps** — Price breaks above the upper Bollinger band (bb.reenter_above triggers) — this means it was above, now it's back inside = failed breakout = sell signal. Same with reenter_below for buys.

6. **Exhaustion after extended trend** — utbot bullish_since >= 10 (or more) + shooting star or doji = trend exhaustion. The long unbroken trend run itself is the setup.

7. **Divergence-like setups** — RSI extreme while price is making new highs/lows in the Donchian channel. Example: dc_zone == UPPER but rsi14 == OB — price at channel top AND momentum exhausted.

### What to search online for inspiration (be creative with searches):

- "market maker trap candle patterns crypto"
- "liquidity sweep reversal patterns BTC"
- "stop hunt candle signatures bitcoin"
- "institutional order flow candle footprint"
- "exhaustion candle pattern quantitative"
- "failed breakout reentry quantitative trading"
- "engulfing trap crypto intraday"
- "volume profile trap candle patterns"
- Do NOT just search "RSI strategy" or "MACD crossover strategy" — those are useless.

---

## Step 3: Backtest Workflow

### Edit config and run:

```bash
cd /root/MetaTrader5-Docker

# Edit the config — set your strategy, enable ONLY that one
nano data/config/config.yaml
```

### Config structure:

```yaml
backtest:
  symbol: BTCUSDT
  period: M1
  model: 1                # 1 = open prices (fast), use 0 for every-tick if needed
  from: "2026.04.13"      # 2 months back from today
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
  # ENABLE ONLY ONE AT A TIME FOR ISOLATED TESTING
  - name: your_strategy_name
    enabled: true
    sl: 500.0             # stop loss in dollars (price distance)
    rr: 1.5               # reward:risk ratio (TP = SL * RR)
    buy: "your_buy_expression"
    sell: "your_sell_expression"
```

### Run the backtest:

```bash
# Stop existing, clean old reports, run
podman-compose down
rm -f data/reports/backtest_report*
MT5_MODE=tester podman-compose up --build

# Wait for "Tester run complete" in output, then parse:
python3 tools/parse_report.py data/reports/backtest_report.htm --human --all
```

### What to look for in results:

- **Profit Factor > 1.3** — minimum to consider viable
- **Win Rate > 45%** — below this the RR ratio must compensate
- **Total Trades > 20** — too few = not enough data, strategy may be overfitting
- **Max Drawdown < 30%** — anything higher is too risky
- **Consecutive losses < 6** — long streaks signal the strategy is fundamentally broken

### If a strategy doesn't work:
- Try adjusting SL (tighter or wider) — 200, 300, 500, 800 are good starting points for BTC
- Try adjusting RR — 1.0, 1.25, 1.5, 2.0, 2.5
- Try **tight SL + high RR** combos (e.g. SL=200, RR=2.0) for sniper entries
- Try **wide SL + low RR** combos (e.g. SL=800, RR=1.0) for high win-rate setups
- Try enabling **breakeven** — set `breakeven_start` to ~50% of your TP distance so the SL moves to entry once price goes halfway in your favor. Example: if SL=500 and RR=1.5, TP=750, set `breakeven_start: 375.0`. This protects winners from reversing back to a loss.
- Try all permutations — SL/RR/breakeven combos can turn a losing strategy into a winner
- Try adding/removing one filter condition
- Try on a different entry timeframe (M3 vs M5 vs M15)
- If it consistently loses after 3-4 SL/RR/breakeven combos, DISCARD IT and move on.

### Breakeven usage in config:
```yaml
trailing:
  breakeven_start: 250.0   # Move SL to entry after $250 profit (0=off)
  trail_start: 0.0         # Can also try trailing (start after $X profit)
  trail_step: 2.0          # Trail distance in dollars
```
Set `breakeven_start` to roughly 40-60% of your expected TP distance. This is especially powerful for trap-catching strategies where the initial move in your favor is strong but may retrace.

---

## Step 4: Strategy Ideas to Explore

Here are **seed ideas** — develop, twist, and combine them. These are starting points, NOT final strategies:

### Idea A: Marubozu Trap Reversal
A wickless (MARUBOZU) candle on M15/H1 going AGAINST the higher timeframe trend, followed by a reversal candle on M3/M5 confirming direction change.
```
# Example sketch (sell direction — adjust for buys):
candle_M15.type==MARUBOZU|candle_M15.is_bullish==TRUE|utbot_H1.bias==BEARISH|candle_M3.is_bearish==TRUE
```
The logic: a full-body bullish candle into a bearish H1 trend = stop hunt/liquidity grab. The M3 bearish candle = reversal beginning.

### Idea B: Exhausted Trend Doji
Extended trend (many consecutive bars in one direction) terminated by indecision.
```
utbot_M15.bullish_since>=8|candle_M5.type==DOJI|dc_M15.zone==UPPER
```

### Idea C: Double Reversal Body (M1/M3 consecutive)
Two or more consecutive full-body candles on M1 or M3 flipping against the prior micro-trend.
```
candle_M3.type==MARUBOZU|candle_M3.is_bearish==TRUE|utbot_M3.bearish_since>=2|utbot_M15.bias==BEARISH
```

### Idea D: Extreme Wick Rejection
Wick ratio >= 3 (massive wick relative to body) at channel edges.
```
candle_M5.lower_wick_ratio>=3|dc_M15.zone in LOWER,LOWER_MID|utbot_H1.bias==BULLISH
```

### Idea E: Failed BB Breakout
Price broke above/below Bollinger Band and came back inside = failed breakout.
```
bb_M15.reenter_above==TRUE|utbot_H1.bias==BEARISH|candle_M3.is_bearish==TRUE
```

### Idea F: Shooting Star at Channel Top After Trend
Reversal candle pattern at exhaustion point.
```
candle_M15.type==SHOOTING_STAR|dc_M15.zone==UPPER|utbot_M15.bullish_since>=5
```

### Idea G: RSI Extreme + Channel Extreme Divergence
Momentum exhausted while at price extremes.
```
rsi2_M5.zone==EXTREME_OB|dc_M15.zone==UPPER|candle_M5.type!=MARUBOZU
```

### Idea H: MACD Histogram Divergence with Candle Confirmation
Momentum fading while price still pushing — combined with reversal candle.
```
macd_M15.hist_dir==FALLING|dc_M15.zone in UPPER,UPPER_MID|candle_M5.type==SHOOTING_STAR
```

### Idea I: Stochastic Extreme + Bollinger Squeeze Release
Tight bands + extreme stochastic = about to explode in the opposite direction.
```
bb_M15.squeeze==TRUE|stoch_M15.zone==OB|utbot_H1.bias==BEARISH
```

### Idea J: EMA Slope Divergence Trap
Price above EMA but EMA slope is falling (or vice versa) = momentum contradiction.
```
ema50_M15.price_vs==ABOVE|ema50_M15.slope==FALLING|candle_M5.is_bearish==TRUE|utbot_M5.signal==SELL
```

---

## Step 5: Iteration Process

For each strategy:

1. **Design** it based on a trap-catching hypothesis
2. **Write** the YAML config (enable ONLY that strategy)
3. **Backtest** over the full 2-month window (2026.04.13 to 2026.06.13)
4. **Parse** results: `python3 tools/parse_report.py data/reports/backtest_report.htm --human --all`
5. **Evaluate** against the criteria (Profit Factor, Win Rate, Drawdown, Trade Count)
6. **Tune** SL/RR if promising but not yet profitable (try 2-3 SL/RR combos max)
7. **Record** the final result (profitable or not) and move to the next
8. If it's garbage after 2-3 tuning attempts, dump it and try a different idea

### SL/RR guidelines for BTCUSDT:
- **Tight scalp:** SL=200, RR=1.5-2.5 (small risk, needs precise entry)
- **Standard:** SL=300-400, RR=1.25-1.5 (balanced)
- **Wide:** SL=500-550, RR=1.0-1.25 (higher win rate, needs good filtering)
- **NEVER go above SL=550** — anything wider is too much risk for BTC
- Start with SL=350 RR=1.5 as baseline, then try tight (200) and wide (500)
- **Always try breakeven** on promising strategies — set `breakeven_start` to ~50% of TP

### Round number awareness (IMPORTANT for BTC):
BTC has strong psychological levels at **multiples of 500** (65000, 65500, 66000, etc.). Price gravitates toward these levels and often bounces off them. The EA provides `round_TF.*` signals for this:

```
round_M1.dist_above    → distance in $ to the next 500-multiple above
round_M1.dist_below    → distance in $ to the next 500-multiple below
round_M1.pct           → % position within the current 500-range (0=at lower, 100=at upper)
```

**Use these to:**
- **Filter entries** — if buy signal fires and `round_M1.pct>=80` (close to next round above), TP will likely get hit. But if `round_M1.pct<=20` (just above a round below), price already touched the round and may not have momentum.
- **Avoid bad SL/TP placement** — if your SL would land right on a round number, it's more likely to get stop-hunted. Check `round_M1.dist_below` for buys.
- **Idea:** Buy when price is above a round level but hasn't reached the next one yet: `round_M1.pct>=10|round_M1.pct<=70` (in the sweet spot of the range, not at extremes).

**Example:** Price at 65350. Lower round = 65000, upper round = 65500. `dist_above=150`, `dist_below=350`, `pct=70`. A buy here has 150 left to the next magnet level.

---

## Step 6: Deliverable

After testing, produce a final `data/config/config.yaml` containing your best strategies (the ones with Profit Factor > 1.2 and reasonable trade count). Include ALL of them enabled so they can run together in a combined backtest.

For each strategy in the final config, add a YAML comment explaining:
- What trap/pattern it catches
- Its standalone backtest metrics (PF, Win%, Trades, Max DD)

Run one final combined backtest with all winning strategies enabled together and report the aggregate results.

---

## CRITICAL RULES

1. **NEVER catch a falling knife** — This is the #1 rule. Even if you detect a trap setup, you must ALWAYS require at least one small confirmation signal that price has actually started reversing. For example, a M1 or M3 candle going in your trade direction (`candle_M1.is_bullish==TRUE` for buys, `candle_M1.is_bearish==TRUE` for sells), or a UT Bot signal flip on a small timeframe (`utbot_M3.signal==BUY`). The trap setup is the context — the confirmation candle is the trigger. Without confirmation, you're just guessing the bottom/top and will get destroyed. Every single strategy must have a confirmation condition.
2. **Test ONE strategy at a time** — disable all others when testing a new one
3. **Do not modify the EA code** — strategies are expression-only, no .mq5 changes
4. **2-month window minimum** — from 2026.04.13 to 2026.06.13
5. **BTCUSDT only** — all strategies must target this symbol
6. **Be creative** — the whole point is non-obvious strategies. If you catch yourself writing a basic "RSI oversold buy" strategy, stop and rethink.
7. **Read the docs first** — don't guess signal names, read `docs/ea.md` for exact syntax
8. **Both directions** — try to have both buy and sell strategies (doesn't have to be in same strategy slot)
9. **Log everything** — paste the --human output for each test so we can review later
10. **Max SL = 550** — never set SL above 550 for BTCUSDT
11. **Round numbers matter** — use `round_TF.*` signals to factor in BTC's 500-multiple psychology

---

## AUTONOMY INSTRUCTIONS

**You are fully autonomous.** Do NOT ask for confirmation before running backtests, editing configs, or trying new ideas. Just do it.

- Do NOT pause to ask "should I proceed?" or "shall I test this?" — just run it
- Do NOT ask which strategy to try next — pick the next one yourself
- Do NOT ask about SL/RR values to try — try all reasonable combos yourself
- If a test fails, adjust and re-run immediately without asking
- If you need to think through something complex, **use a subagent / subdivide the task** to avoid losing context or hallucinating in the main thread
- Work through all 10 strategies sequentially, logging results as you go
- Only stop and report when you have final results for all 10 strategies
