# Worker 7 — Creative Filter Engineering: Rescue 10+ Strategies

## Context

We tested 15 strategies over a 6-month window (2026.01.13–2026.06.13). **All failed.** Only L1 (PF=1.08) and L2 (PF=1.07) barely broke even. The rest had PF 0.72–1.00 with catastrophic drawdowns.

The core issue: these strategies fire too often on false signals. The expressions are not selective enough over long periods. They need **additional creative filters** to cut the noise.

**Your mission:** Take each strategy, add 1-2 smart filters, and push PF above 1.15 on the 6-month window. We need **at least 10 strategies** that survive.

## Step 0: Read the Docs

```bash
cat ONBOARD.md              # How to run backtests
cat docs/ea.md              # FULL signal reference — read ALL of it carefully
cat docs/yaml-config.md     # Config format
cat past_tests/MASTER_STRATEGIES.md  # Original strategy list
cat past_tests/worker6_production_results.md  # 6-month failure data
```

## CRITICAL RULES

1. **Test ONE strategy at a time** — never combine strategies in a single backtest
2. **Use the 6-month window** (2026.01.13–2026.06.13)
3. **Use relaxed global settings** (see config template below)
4. **PF > 1.15 to keep, > 1.25 is good, > 1.5 is excellent**
5. **MaxDD < 40%** — anything above means the strategy blows up in bad regimes

## The 13 Strategies to Rescue

Below are all strategies with their **best parameters from 6-month testing**. Your job: add creative filters to each one to improve the PF. Do NOT change the core signal — only ADD conditions.

### L1: Sweep + Stoch (PF=1.08, 87 trades, DD=34%)
```yaml
- name: L1_sweep_stoch
  sl: 400.0
  rr: 1.5
  buy: "liq_M15.lower_swept==TRUE|stoch_M15.zone==OS|candle_M3.is_bullish==TRUE|ema200_M15.price_vs==ABOVE"
  sell: "liq_M15.upper_swept==TRUE|stoch_M15.zone==OB|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW"
```
Already net positive. Needs a small boost. Try adding ADX, round number proximity, or candle quality filter.

### L2: Sweep + Stoch + Est Trend (PF=1.07, 66 trades, DD=33%)
```yaml
- name: L2_sweep_stoch_trend
  sl: 400.0
  rr: 1.5
  buy: "liq_M15.lower_swept==TRUE|stoch_M15.zone==OS|candle_M3.is_bullish==TRUE|utbot_H1.bias==BULLISH|utbot_H1.bullish_since>=5|ema200_M15.price_vs==ABOVE"
  sell: "liq_M15.upper_swept==TRUE|stoch_M15.zone==OB|candle_M3.is_bearish==TRUE|utbot_H1.bias==BEARISH|utbot_H1.bearish_since>=5|ema200_M15.price_vs==BELOW"
```
Already 6 conditions. Adding more may reduce trade count too much. Try replacing `bullish_since>=5` with `>=3` to get more trades, or swap a weaker filter for a stronger one.

### L3: Triple Rejection — Sweep+BB (PF=1.00, 68 trades, DD=31%)
```yaml
- name: L3_triple_rejection
  sl: 400.0
  rr: 2.5
  buy: "liq_M15.lower_swept==TRUE|bb_M15.reenter_below==TRUE|candle_M3.is_bullish==TRUE|utbot_H1.bias==BULLISH"
  sell: "liq_M15.upper_swept==TRUE|bb_M15.reenter_above==TRUE|candle_M3.is_bearish==TRUE|utbot_H1.bias==BEARISH"
```
Breakeven at PF=1.00. Very close. One good filter could push it over. Try EMA200 alignment, candle body_pct for conviction, or stoch confirmation.

### R3: EMA Slope Sell (PF=0.92, 465 trades, DD=80%)
```yaml
- name: R3_ema_slope_sell
  sl: 300.0
  rr: 2.5
  buy: ""
  sell: "ema50_M15.slope==FALLING|ema50_M15.price_vs==ABOVE|candle_M3.is_bearish==TRUE|utbot_H1.bias==BEARISH"
```
Fires 465 times in 6 months — WAY too many. The core idea is solid (price above a falling EMA = fake rally). Needs much more filtering. Try: ADX trending, VWAP above, BB squeeze, candle pattern (SHOOTING_STAR or MARUBOZU).

### V1: Stoch OS Tight (PF=0.92, 341 trades, DD=47%)
```yaml
- name: V1_stoch_os_tight
  sl: 350.0
  rr: 2.0
  buy: "stoch_M15.zone==OS|utbot_H1.bias==BULLISH|vwap_M5.price_vs==BELOW|ema200_M15.price_vs==ABOVE|adx_M15.strength in STRONG_TREND,TRENDING|candle_M3.is_bullish==TRUE"
  sell: "stoch_M15.zone==OB|utbot_H1.bias==BEARISH|vwap_M5.price_vs==ABOVE|ema200_M15.price_vs==BELOW|adx_M15.strength in STRONG_TREND,TRENDING|candle_M3.is_bearish==TRUE"
```
Already 6 conditions. 341 trades in 6 months. Problem is likely the stoch+NEUTRAL zone generating false signals. Try: `stoch_M15.k<=15` (numerically tighter) instead of zone==OS. Or add MACD histogram confirmation.

### V2: RSI2 Extreme Buy (PF=0.90, 375 trades, DD=65%)
```yaml
- name: V2_rsi2_extreme_buy
  sl: 350.0
  rr: 2.0
  buy: "rsi2_M5.zone==EXTREME_OS|utbot_H1.bias==BULLISH|vwap_M5.price_vs==BELOW|ema200_M15.price_vs==ABOVE|candle_M3.is_bullish==TRUE"
  sell: ""
```
375 trades buy-only. RSI2 extreme fires too often. Try: add `candle_M5.type!=DOJI` (no indecision), or `dc_M15.zone in LOWER,LOWER_MID` (only buy at channel bottom), or `adx_M15.strength in STRONG_TREND,TRENDING`.

### T1: VWAP Trend (PF=0.87, 1263 trades, DD=99%)
```yaml
- name: T1_vwap_trend
  sl: 350.0
  rr: 1.5
  buy: "vwap_M5.price_vs==BELOW|utbot_H1.bias==BULLISH|candle_M3.is_bullish==TRUE|ema200_M15.price_vs==ABOVE"
  sell: "vwap_M5.price_vs==ABOVE|utbot_H1.bias==BEARISH|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW"
```
1263 trades = fires every day multiple times. Way too broad. Needs 2-3 more filters. Try: ADX trending, `candle_M3.body_pct>=40` (only strong candles), `utbot_H1.bullish_since>=3`, round number proximity.

### T2: Stoch Combo Wide (PF=0.84, 865 trades, DD=90%)
```yaml
- name: T2_stoch_combo_wide
  sl: 350.0
  rr: 1.25
  buy: "stoch_M15.zone in OS,NEUTRAL|utbot_H1.bias==BULLISH|vwap_M5.price_vs==BELOW|ema200_M15.price_vs==ABOVE|adx_M15.strength in STRONG_TREND,TRENDING|candle_M3.is_bullish==TRUE"
  sell: "stoch_M15.zone in OB,NEUTRAL|utbot_H1.bias==BEARISH|vwap_M5.price_vs==ABOVE|ema200_M15.price_vs==BELOW|adx_M15.strength in STRONG_TREND,TRENDING|candle_M3.is_bearish==TRUE"
```
865 trades from `NEUTRAL` zone inclusion. Try removing NEUTRAL: use `stoch_M15.zone==OS` only. Or add DC zone filter, or candle body quality.

### T3: MACD Cross Trend (PF=0.83, 199 trades, DD=67%)
```yaml
- name: T3_macd_cross_trend
  sl: 350.0
  rr: 1.5
  buy: "macd_M15.cross==CROSS_UP|utbot_H1.bias==BULLISH|candle_M3.is_bullish==TRUE|ema200_M15.price_vs==ABOVE|adx_M15.strength in STRONG_TREND,TRENDING"
  sell: "macd_M15.cross==CROSS_DOWN|utbot_H1.bias==BEARISH|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW|adx_M15.strength in STRONG_TREND,TRENDING"
```
199 trades — moderate count. PF=0.83 means too many false crosses. Try: add `macd_M15.vs_zero==ABOVE` for buys (only cross up when already above zero = trend continuation, not counter-trend). Or add stoch zone filter.

### P1: DC Lowzone ADX (PF=0.98, 673 trades, DD=92%)
```yaml
- name: P1_dc_lowzone_adx
  sl: 400.0
  rr: 2.5
  buy: "dc_M15.zone in LOWER,LOWER_MID|utbot_H1.bias==BULLISH|candle_M3.is_bullish==TRUE|ema200_M15.price_vs==ABOVE|adx_M15.strength in STRONG_TREND,TRENDING"
  sell: "dc_M15.zone in UPPER,UPPER_MID|utbot_H1.bias==BEARISH|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW|adx_M15.strength in STRONG_TREND,TRENDING"
```
673 trades, PF=0.98 — almost breakeven. Fires when price is at channel edge in trend. Try: add `dc_M15.lower_wick_rej==TRUE` (wick rejection confirms the bounce), or `candle_M3.type==HAMMER` for buys.

### R1: Failed BB Sell (PF=0.79, 282 trades, DD=81%)
```yaml
- name: R1_failed_bb_sell
  sl: 300.0
  rr: 2.5
  buy: ""
  sell: "bb_M15.reenter_above==TRUE|utbot_H1.bias==BEARISH|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW|adx_M15.strength in STRONG_TREND,TRENDING"
```
Was PF=3.34 on 2-month, crashed to 0.79 on 6-month. 282 trades = fires too much. `bb_M15.reenter_above` may be too loose. Try: add `candle_M5.type in SHOOTING_STAR,SPINNING_TOP` (rejection candle pattern), or `stoch_M15.zone==OB`.

### R2: Exhausted Sell (PF=0.83, 357 trades, DD=75%)
```yaml
- name: R2_exhausted_sell
  sl: 300.0
  rr: 2.0
  buy: ""
  sell: "utbot_M15.bullish_since>=8|candle_M5.type==SHOOTING_STAR|dc_M15.zone in UPPER,UPPER_MID|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW"
```
357 trades for a SHOOTING_STAR pattern is suspicious — maybe the `bullish_since>=8` threshold is too low over 6 months. Try: `bullish_since>=12` or add `stoch_M15.zone==OB` for double exhaustion confirmation.

### V3: Stoch Wide Sell (PF=0.72, 630 trades, DD=97%)
```yaml
- name: V3_stoch_wide_sell
  sl: 300.0
  rr: 1.5
  buy: ""
  sell: "stoch_M15.zone in OB,NEUTRAL|utbot_H1.bias==BEARISH|vwap_M5.price_vs==ABOVE|ema200_M15.price_vs==BELOW|adx_M15.strength in STRONG_TREND,TRENDING|candle_M3.is_bearish==TRUE"
```
630 trades, worst performer. NEUTRAL zone is the problem. Remove NEUTRAL and use `zone==OB` only. Or add a structural filter.

---

## Creative Filter Ideas

Here are filters that previous workers NEVER used. **Be creative and try these:**

### 1. Candle Body Quality (`candle_M3.body_pct`)
A strong directional candle has a body that fills most of its range. A candle with body_pct < 30% is indecisive garbage — wicks everywhere, no commitment.

```
candle_M3.body_pct>=50             # Only strong candles (body fills 50%+ of range)
candle_M3.body_pct>=60             # Even stricter — real conviction candles
candle_M5.body_pct>=40             # M5 bar must show commitment
```

**Why this could work:** Many false signals come from tiny, indecisive candles that happen to match conditions. Requiring body_pct >= 50 filters out the noise. This has NEVER been tested.

### 2. Candle Wick Ratios (`candle_M3.upper_wick_ratio`, `lower_wick_ratio`)
For a BUY signal, you want the candle to NOT have a big upper wick (that means rejection upward). For a SELL, you don't want a big lower wick.

```
candle_M3.upper_wick_ratio<=1.5    # Buy filter: upper wick is not huge (not being rejected up)
candle_M3.lower_wick_ratio<=1.5    # Sell filter: lower wick is not huge
candle_M5.lower_wick_ratio>=2.0    # Hammer: lower wick is 2x+ body = strong rejection
```

**Why this could work:** A buy candle with a massive upper wick means sellers are pushing back. Filtering those out removes false breakouts.

### 3. Round Number Proximity (`round_M15.pct`)
BTC gravitates toward round numbers (65000, 65500, 66000). A buy signal that fires when price is at pct=85 (near the next round above) has its TP blocked by the round number. A buy at pct=15 (near a round number below) has a clear runway upward.

```
round_M15.pct<=40                  # Buy: price is in lower 40% of round range (room to run up)
round_M15.pct>=60                  # Sell: price is in upper 40% (room to run down)
round_M15.dist_above>=150          # Buy: at least $150 to next round number above (enough room for TP)
round_M15.dist_below>=150          # Sell: at least $150 to next round number below
```

**Why this could work:** If your TP is $525 (SL=350, RR=1.5) but the next round number is only $100 away, price will bounce off the round number and you'll lose. Ensuring enough distance to the next round number gives TPs room to be hit.

### 4. ATR Volatility Filter (`atr_M15.value`)
When ATR is very low, the market is dead — no momentum, no follow-through. Your SL=$350 might get hit by random noise. When ATR is very high, you're entering during chaos — also bad.

```
atr_M15.value>=15                  # Minimum volatility — market is actually moving
atr_M15.value<=80                  # Not insanely volatile — some order in the chaos
atr_H1.value>=50                   # H1 ATR confirms there's a real move happening
```

**Why this could work:** A strategy that fires during dead markets (Asian session, weekends) is throwing money away. ATR filter ensures there's actual momentum to ride.

### 5. Multi-Timeframe Candle Alignment
Check that not just M3, but also M5 or M10 is moving in your direction:

```
candle_M5.is_bullish==TRUE         # M5 also bullish (not just M3)
candle_M5.type!=DOJI               # M5 is NOT indecisive
candle_M10.is_bullish==TRUE        # Even M10 agrees
candle_M5.dir==UP                  # M5 direction is up
```

### 6. DC Channel Width (`dc_M15.width`)
When the Donchian channel is very narrow, the market is in a tight range. Breakout strategies work better when the channel is wide (trending). Mean reversion works better when it's narrow.

```
dc_M15.width>=200                  # Channel is wide enough — market is trending
dc_M15.width<=100                  # Channel is narrow — range-bound, good for mean reversion
```

## Your Creative Additions

The filters above are just starting points. **Think of your own combinations.** Some ideas to explore:

- Can you use `ema9` vs `ema21` cross as a filter? (e.g., `ema9_M15.value > ema21_M15.value` — not directly available but `ema9_M15.price_vs==ABOVE` combined with `ema21_M15.price_vs==ABOVE` gives similar info)
- What about `bb_M15.squeeze==TRUE` as a filter for breakout strategies?
- Can `macd_M15.hist_dir==RISING` be used as a momentum confirmation for buys?
- Does `utbot_M5.signal==BUY` (the flash signal, not the bias) work better than `candle_M3.is_bullish`?
- What about using D1 timeframe for macro direction? `utbot_D1.bias==BULLISH` as a mega-filter?

## Test Approach

For each strategy:
1. Start with the baseline expression and best SL/RR from above
2. Add ONE filter at a time — see if PF improves
3. If one filter works, try adding a second
4. If PF drops, remove that filter and try a different one
5. Record every variant tested with PF, WR, trades, DD

**Target:** ~5-8 filter variants per strategy × 13 strategies = ~65-100 backtests.

## Config Template

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

strategies:
  - name: test_strategy
    enabled: true
    sl: 400.0
    rr: 1.5
    buy: "<expression>"
    sell: "<expression>"
```

### Run:
```bash
podman-compose down
rm -f data/reports/backtest_report*
MT5_MODE=tester podman-compose up --build
# Wait for "Tester run complete"
python3 tools/parse_report.py data/reports/backtest_report.htm --human --all
```

## Deliverable

### 1. Results Table
Write `STRATEGY-RESULTS.md`:
```
| Strategy | Filter Added | SL | RR | PF | WR | Trades | MaxDD | PnL |
```

### 2. Best Version Per Strategy
For each of the 13 strategies, what was the best filter combination found? Document the full expression.

### 3. Final Config
Put your top 10+ strategies (PF > 1.15) in `config.yaml`, each with best parameters.

### 4. Summary
- How many strategies rescued (PF > 1.15)?
- Which filters had the most impact?
- Which strategies are hopeless (could not be rescued)?
