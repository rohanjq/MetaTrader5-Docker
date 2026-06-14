# Worker 4 — Liquidity Sweep Reversal Strategies

## Context

You previously tested ~50 strategy variations and found 10 profitable ones (see `past_tests/worker4_refinement_strategies.md`). Great work — those are saved.

Now we have a **brand new signal** in the EA: **Liquidity Sweep** (`liq_TF`). Your mission is to build and test strategies that exploit liquidity sweeps — the way market makers hunt stop-losses before reversing price.

## How Liquidity Sweeps Work — The Market Maker Playbook

### The Core Concept
Big players (market makers, institutions) need **liquidity** to fill large orders. They can't just buy 500 BTC at market price — there aren't enough sellers. So they **engineer liquidity** by triggering stop-losses of retail traders.

Here's the playbook:
1. **Price trends up** → retail traders place buy orders, with stop-losses just below recent swing lows
2. **Market maker pushes price down sharply** → sweeps below those swing lows, **triggering all the stop-losses** (stop-losses are sell orders = liquidity for the market maker to buy)
3. **Market maker fills their buy orders** using the triggered sell orders as counterparty
4. **Price reverses sharply upward** because the selling pressure was artificial

This is why you see "wicks" — price briefly pierces a key level but closes back inside. The wick IS the sweep. The close coming back IS the reversal.

### Why Swing Highs/Lows Are Liquidity Pools
- **Above swing highs:** Buy stop-losses from short sellers cluster here. Sweep above = trigger those stops = instant selling pressure → price falls back
- **Below swing lows:** Sell stop-losses from long traders cluster here. Sweep below = trigger those stops = instant buying pressure → price rebounds

### The Signal We Built

The EA uses **fractal swing detection** (strength=3): a swing high must be strictly higher than 3 bars on EACH side (7-bar pattern). This ensures:
- In a **monotonic trend**: no swings found → no false sweeps
- Only **significant, established levels** where orders actually cluster are considered
- Nearest valid swing is at **bar 5** (not bar 2), giving it real historical age

```
liq_TF.upper_swept  = TRUE/FALSE  — wick went ABOVE highest swing high, close came BACK BELOW
liq_TF.lower_swept  = TRUE/FALSE  — wick went BELOW lowest swing low, close came BACK ABOVE
liq_TF.upper_level  = price       — highest swing high in lookback window
liq_TF.lower_level  = price       — lowest swing low in lookback window
```

**Critical:** `upper_swept==TRUE` is a **SELL setup** (price went above to hunt stops, will reverse DOWN). `lower_swept==TRUE` is a **BUY setup** (price went below to hunt stops, will reverse UP).

Config parameter: `liq_lookback: 20` (default, number of bars to scan for swing points)

## Step 0: Read the Docs

```bash
cat ONBOARD.md              # How to run backtests
cat docs/ea.md              # FULL signal reference — read ALL of it
cat docs/yaml-config.md     # Config format
cat past_tests/BEST_STRATEGIES.md  # Previous results — MUST READ
```

## Your Mission

Build **10 liquidity sweep reversal strategies** (PF > 1.2). All strategies must use `liq_TF.upper_swept` or `liq_TF.lower_swept` as the PRIMARY signal, combined with various confirmation filters.

## Strategy Ideas — What To Test

### Category 1: Pure Sweep + Candle Confirmation
The simplest — sweep happened, confirm with candle pattern:

**Idea 1A: Lower Sweep + Bullish M3**
```
buy: "liq_M15.lower_swept==TRUE|candle_M3.is_bullish==TRUE"
```
Sweep below grabbed stop-losses, M3 candle confirms buyers stepped in. Start with this baseline to see if the raw signal has edge.

**Idea 1B: Upper Sweep + Bearish M3**
```
sell: "liq_M15.upper_swept==TRUE|candle_M3.is_bearish==TRUE"
```
Same logic, sell side. Sweep above grabbed shorts' stops, M3 confirms sellers took over.

**Idea 1C: Sweep + Hammer/Shooting Star**
```
buy: "liq_M15.lower_swept==TRUE|candle_M5.type==HAMMER|candle_M3.is_bullish==TRUE"
sell: "liq_M15.upper_swept==TRUE|candle_M5.type==SHOOTING_STAR|candle_M3.is_bearish==TRUE"
```
Hammer after a lower sweep = the wick IS the sweep, and the hammer body = rejection. Very clean signal.

### Category 2: Sweep Against the Trend (Stop Hunt in Trend)
The highest-probability setup. Market maker sweeps against the prevailing trend, then price resumes the trend:

**Idea 2A: Lower Sweep in Uptrend (Smart Money Buy)**
```
buy: "liq_M15.lower_swept==TRUE|utbot_H1.bias==BULLISH|candle_M3.is_bullish==TRUE|ema200_M15.price_vs==ABOVE"
```
H1 trend is bullish. Market maker pushes price down briefly to grab long stops. Once stops are swept, price resumes up. This is the CLASSIC smart money entry.

**Idea 2B: Upper Sweep in Downtrend (Smart Money Sell)**
```
sell: "liq_M15.upper_swept==TRUE|utbot_H1.bias==BEARISH|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW"
```
Mirror of 2A for sells.

**Idea 2C: Sweep + Trend + ADX Filter**
```
buy: "liq_M15.lower_swept==TRUE|utbot_H1.bias==BULLISH|candle_M3.is_bullish==TRUE|ema200_M15.price_vs==ABOVE|adx_M15.strength in STRONG_TREND,TRENDING"
sell: "liq_M15.upper_swept==TRUE|utbot_H1.bias==BEARISH|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW|adx_M15.strength in STRONG_TREND,TRENDING"
```
Same as 2A/2B but add ADX filter — sweep during a TRENDING market is more significant (more orders to hunt).

**Idea 2D: Sweep + Established Trend (Since >= N)**
```
buy: "liq_M15.lower_swept==TRUE|utbot_H1.bias==BULLISH|utbot_H1.bullish_since>=5|candle_M3.is_bullish==TRUE"
sell: "liq_M15.upper_swept==TRUE|utbot_H1.bias==BEARISH|utbot_H1.bearish_since>=5|candle_M3.is_bearish==TRUE"
```
The trend must have been running for 5+ H1 bars. This means price made a real multi-hour move, then the sweep is a brief stop-hunt before continuation.

### Category 3: Sweep + Momentum/Oscillator Confirmation
After the sweep, confirm with momentum indicators that the reversal has conviction:

**Idea 3A: Sweep + RSI2 Extreme (Double Exhaustion)**
```
buy: "liq_M15.lower_swept==TRUE|rsi2_M5.zone in OS,EXTREME_OS|candle_M3.is_bullish==TRUE|utbot_H1.bias==BULLISH"
```
Sweep below = stops grabbed. RSI2 oversold = price is also technically exhausted. Double confirmation of reversal.

**Idea 3B: Sweep + Stoch Oversold**
```
buy: "liq_M15.lower_swept==TRUE|stoch_M15.zone==OS|candle_M3.is_bullish==TRUE|ema200_M15.price_vs==ABOVE"
sell: "liq_M15.upper_swept==TRUE|stoch_M15.zone==OB|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW"
```
Stochastic confirms the sweep bar pushed into oversold/overbought territory. When stoch turns from OS in an uptrend = strong buy.

**Idea 3C: Sweep + MACD Histogram Turning**
```
buy: "liq_M15.lower_swept==TRUE|macd_M15.hist_dir==RISING|candle_M3.is_bullish==TRUE|utbot_H1.bias==BULLISH"
sell: "liq_M15.upper_swept==TRUE|macd_M15.hist_dir==FALLING|candle_M3.is_bearish==TRUE|utbot_H1.bias==BEARISH"
```
MACD histogram turning = momentum shifting back to trend direction after the sweep.

### Category 4: Sweep + Level Confluence
Combine the sweep with other structural levels for high-conviction entries:

**Idea 4A: Sweep + VWAP Discount**
```
buy: "liq_M15.lower_swept==TRUE|vwap_M5.price_vs==BELOW|candle_M3.is_bullish==TRUE|utbot_H1.bias==BULLISH"
sell: "liq_M15.upper_swept==TRUE|vwap_M5.price_vs==ABOVE|candle_M3.is_bearish==TRUE|utbot_H1.bias==BEARISH"
```
Sweep grabbed stops AND price is below VWAP (at a discount) = buying where institutions buy.

**Idea 4B: Sweep + DC Lower Zone (Double Level)**
```
buy: "liq_M15.lower_swept==TRUE|dc_M15.zone in LOWER,LOWER_MID|candle_M3.is_bullish==TRUE|utbot_H1.bias==BULLISH"
sell: "liq_M15.upper_swept==TRUE|dc_M15.zone in UPPER,UPPER_MID|candle_M3.is_bearish==TRUE|utbot_H1.bias==BEARISH"
```
Both the liquidity level AND the Donchian channel boundary were tested and rejected. Two structural levels = much stronger reversal.

**Idea 4C: Sweep + BB False Breakout (Triple Rejection)**
```
buy: "liq_M15.lower_swept==TRUE|bb_M15.reenter_below==TRUE|candle_M3.is_bullish==TRUE|utbot_H1.bias==BULLISH"
sell: "liq_M15.upper_swept==TRUE|bb_M15.reenter_above==TRUE|candle_M3.is_bearish==TRUE|utbot_H1.bias==BEARISH"
```
The ULTIMATE rejection signal: price swept below the liquidity level, poked outside the Bollinger Band, AND came back in. Triple confluence. Should be very rare but very powerful.

**Idea 4D: Sweep + Round Number**
```
buy: "liq_M15.lower_swept==TRUE|round_M15.pct<=30|candle_M3.is_bullish==TRUE|utbot_H1.bias==BULLISH"
sell: "liq_M15.upper_swept==TRUE|round_M15.pct>=70|candle_M3.is_bearish==TRUE|utbot_H1.bias==BEARISH"
```
Sweep happened near a psychological round number (lower 30% for buys, upper 30% for sells). Round numbers attract orders = more stops = bigger sweep = stronger reversal.

### Category 5: Multi-Timeframe Sweep Confirmation

**Idea 5A: H1 Sweep + M5 Confirmation**
```
buy: "liq_H1.lower_swept==TRUE|candle_M5.is_bullish==TRUE|utbot_H1.bias==BULLISH|ema200_M15.price_vs==ABOVE"
sell: "liq_H1.upper_swept==TRUE|candle_M5.is_bearish==TRUE|utbot_H1.bias==BEARISH|ema200_M15.price_vs==BELOW"
```
H1 sweep = bigger liquidity pool grabbed. M5 candle confirms the reversal. Fewer signals but higher quality.

**Idea 5B: M5 Sweep + M15 Trend**
```
buy: "liq_M5.lower_swept==TRUE|utbot_M15.bias==BULLISH|candle_M3.is_bullish==TRUE|adx_M15.strength in STRONG_TREND,TRENDING"
sell: "liq_M5.upper_swept==TRUE|utbot_M15.bias==BEARISH|candle_M3.is_bearish==TRUE|adx_M15.strength in STRONG_TREND,TRENDING"
```
Faster sweep detection on M5 (more signals) but trend confirmed on M15.

### Category 6: Sweep + EMA Slope Divergence (Trap Reversal)

**Idea 6A: Upper Sweep + EMA Slope Falling (Bull Trap Complete)**
```
sell: "liq_M15.upper_swept==TRUE|ema50_M15.slope==FALLING|candle_M3.is_bearish==TRUE|utbot_H1.bias==BEARISH"
```
Price swept above to grab shorts' stops, but EMA50 is actually falling = the rally was fake, it was a stop hunt. Price will resume downward.

**Idea 6B: Lower Sweep + EMA Slope Rising (Bear Trap Complete)**
```
buy: "liq_M15.lower_swept==TRUE|ema50_M15.slope==RISING|candle_M3.is_bullish==TRUE|utbot_H1.bias==BULLISH"
```
Price swept below to grab longs' stops, but EMA50 is rising = the dip was fake. Resume upward.

## Lookback Variations

The `liq_lookback` parameter controls how many bars to scan for swing points. Test these:
- `liq_lookback: 15` — shorter window, more recent swings, more signals
- `liq_lookback: 20` — default, balanced
- `liq_lookback: 30` — longer window, catches bigger/older levels, fewer but stronger signals
- `liq_lookback: 40` — catches major historical levels only

For your best strategies, try at least 2 lookback values to see which gives better PF.

## Backtest Rules

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
  breakeven_start: 0.0
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
```

### Run:
```bash
podman-compose down
rm -f data/reports/backtest_report*
MT5_MODE=tester podman-compose up --build
# Wait for "Tester run complete"
python3 tools/parse_report.py data/reports/backtest_report.htm --human --all
```

### SL/RR/Breakeven guidelines:
- **SL=350** is the starting point (you proved this works)
- **RR=1.5** default. For sweep reversals, try **RR=2.0** — sweeps tend to produce big reversals
- **RR=2.5 or 3.0** worth testing on sweep + trend + ADX combos — the market maker reversal can be violent
- **Breakeven: don't use** (you proved it hurts PF on BTC with SL=350)
- If a strategy doesn't work at SL=350: try SL=300 (tight) and SL=400 (wider)

### Test sequence per strategy:
1. SL=350, RR=1.5, liq_lookback=20
2. SL=350, RR=2.0 (sweeps often produce bigger reversals)
3. If promising: try RR=2.5
4. Try liq_lookback=30 (bigger levels)
5. If still borderline: add one more filter condition
6. Pick best variant, move on

### Minimum viable:
- **PF > 1.2** — below this not profitable after costs
- **Trades > 10** — fewer = not enough data (sweep signals are inherently rare, so lower threshold ok)
- **Must test on full 2-month window** (2026.04.13 – 2026.06.13)

## CRITICAL: Test ONE Strategy at a Time

**Never put multiple strategies in the config for a single backtest run.** Strategy order and multi_position settings distort results — the first strategy in the list gets priority on signals, stealing trades from later strategies. This makes combined PFs unreliable.

For every backtest run, your config should have **exactly 1 strategy enabled**. All other strategy slots should be `enabled: false` or removed. This gives you the true standalone PF for that strategy.

```yaml
strategies:
  - name: test_this_one
    enabled: true
    sl: 350.0
    rr: 1.5
    buy: "liq_M15.lower_swept==TRUE|utbot_H1.bias==BULLISH|candle_M3.is_bullish==TRUE|ema200_M15.price_vs==ABOVE"
    sell: ""
```

Do NOT worry about combining strategies — that is a separate step done later. Your job is to find strategies that are profitable **individually**.

## Important: What NOT to Do

1. **Don't put multiple strategies in one backtest** — results will be wrong (see above)
2. **Don't test liq_M15.upper_swept for BUY** — that means price went above and came back = SELL signal, not buy. Upper sweep = sell setup, lower sweep = buy setup.
3. **Don't remove candle confirmation (M3)** — you proved M3 confirmation is mandatory in every profitable strategy
4. **Don't use breakeven** — you proved it hurts PF
5. **Don't use M1 candle confirmation** — you proved it's noise
6. **Don't test without trend filter** — sweep alone without trend context = random

## Deliverable

1. Update `config.yaml` with your **single best strategy** (highest PF)
2. Write results to `STRATEGY-RESULTS.md` with **all** strategies tested and their standalone metrics
3. For each strategy: document expression, SL/RR, standalone PF/WR/Trades, liq_lookback used
4. Every PF number must be from a **single-strategy backtest** (not combined)
5. Note which lookback values worked best
6. Rank by confidence: HIGH (>20 trades, PF>1.3), MEDIUM (10-20 trades, PF>1.2), LOW (<10 trades)
