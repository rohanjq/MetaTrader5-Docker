# Worker 6 — Production Readiness: Parameter Optimization & Final Portfolio

## Context

We have **15 profitable strategies** (PF > 1.2) from 5 rounds of backtesting. They are all documented in `past_tests/MASTER_STRATEGIES.md` — **read it first**.

All strategies were tested under conservative settings: `multi_position=false`, single strategy per run, `cooldown_sec=60`, `reversal_cooldown=60`, SL=350, 2-month window.

**Now it's time to finalize for production.** Your job is to:
1. Run each strategy with relaxed settings and parameter permutations
2. Test over a **6-month window** for statistical validity
3. Find the optimal SL, RR, and trailing stop for each strategy individually
4. Produce a final portfolio config ready for a demo account

## Step 0: Read Everything

```bash
cat ONBOARD.md                         # How to run backtests
cat docs/ea.md                         # FULL signal reference
cat docs/yaml-config.md                # Config format
cat past_tests/MASTER_STRATEGIES.md    # ALL 15 profitable strategies — MUST READ
```

## CRITICAL RULES

### 1. Test ONE Strategy at a Time
**Never put multiple strategies in the config for a single backtest run.** Strategy order affects results. Every PF number must come from a single-strategy backtest.

### 2. Use Relaxed Global Settings
For ALL your backtests, use these global settings:
```yaml
global:
  risk_pct: 3.0
  sl: 0            # per-strategy SL overrides this
  rr: 0            # per-strategy RR overrides this
  magic: 300
  multi_position: true       # ALLOW multiple positions
  max_positions: 3           # up to 3 at once
  max_daily_trades: 50
  cooldown_sec: 900          # 15 min between ANY trade
  reversal_cooldown: 0       # NO reversal cooldown
  max_consec_loss: 0         # OFF — let it trade
  consec_loss_pause: 0
  slippage: 20
```

**Why these settings:**
- `multi_position: true` — strategies should be able to fire even if another position is open
- `max_positions: 3` — cap at 3 concurrent positions for risk management
- `cooldown_sec: 900` — 15 min between trades from the SAME strategy (prevents the same signal firing every tick on the same bar). This is the only safety valve needed.
- `reversal_cooldown: 0` — disabled. If a sell signal fires right after a buy, let it. The strategies have enough filters.
- `max_consec_loss: 0` — disabled. We want to see the raw strategy performance.

### 3. Use 6-Month Window
```yaml
backtest:
  symbol: BTCUSDT
  period: M1
  model: 1
  from: "2026.01.13"
  to: "2026.06.13"
  deposit: 10000
  leverage: "1:100"
```
6 months captures multiple market regimes (trending, ranging, volatile, quiet). If a strategy is only profitable in one regime, we need to know.

## The 15 Strategies to Test

Here are ALL strategies to test. For each one, run the parameter permutations below.

### Liquidity Sweep Family
```
L1: Sweep + Stoch
  buy: "liq_M15.lower_swept==TRUE|stoch_M15.zone==OS|candle_M3.is_bullish==TRUE|ema200_M15.price_vs==ABOVE"
  sell: "liq_M15.upper_swept==TRUE|stoch_M15.zone==OB|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW"

L2: Sweep + Stoch + Est Trend
  buy: "liq_M15.lower_swept==TRUE|stoch_M15.zone==OS|candle_M3.is_bullish==TRUE|utbot_H1.bias==BULLISH|utbot_H1.bullish_since>=5|ema200_M15.price_vs==ABOVE"
  sell: mirror

L3: Triple Rejection (Sweep+BB)
  buy: "liq_M15.lower_swept==TRUE|bb_M15.reenter_below==TRUE|candle_M3.is_bullish==TRUE|utbot_H1.bias==BULLISH"
  sell: mirror
```

### Trend/Momentum Family
```
T1: VWAP Trend
  buy: "vwap_M5.price_vs==BELOW|utbot_H1.bias==BULLISH|candle_M3.is_bullish==TRUE|ema200_M15.price_vs==ABOVE"
  sell: mirror

T2: Stoch Combo Wide
  buy: "stoch_M15.zone in OS,NEUTRAL|utbot_H1.bias==BULLISH|vwap_M5.price_vs==BELOW|ema200_M15.price_vs==ABOVE|adx_M15.strength in STRONG_TREND,TRENDING|candle_M3.is_bullish==TRUE"
  sell: mirror

T3: MACD Cross Trend
  buy: "macd_M15.cross==CROSS_UP|utbot_H1.bias==BULLISH|candle_M3.is_bullish==TRUE|ema200_M15.price_vs==ABOVE|adx_M15.strength in STRONG_TREND,TRENDING"
  sell: mirror
```

### Reversal/Trap Family
```
R1: Failed BB Sell (SELL ONLY)
  sell: "bb_M15.reenter_above==TRUE|utbot_H1.bias==BEARISH|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW|adx_M15.strength in STRONG_TREND,TRENDING"

R2: Exhausted Sell (SELL ONLY)
  sell: "utbot_M15.bullish_since>=8|candle_M5.type==SHOOTING_STAR|dc_M15.zone in UPPER,UPPER_MID|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW"

R3: EMA Slope Sell (SELL ONLY)
  sell: "ema50_M15.slope==FALLING|ema50_M15.price_vs==ABOVE|candle_M3.is_bearish==TRUE|utbot_H1.bias==BEARISH"
```

### Pullback Family
```
P1: DC Lowzone ADX
  buy: "dc_M15.zone in LOWER,LOWER_MID|utbot_H1.bias==BULLISH|candle_M3.is_bullish==TRUE|ema200_M15.price_vs==ABOVE|adx_M15.strength in STRONG_TREND,TRENDING"
  sell: mirror
```

### Low-Count (Validate over 6 months)
```
V1: Stoch OS Tight
  buy: "stoch_M15.zone==OS|utbot_H1.bias==BULLISH|vwap_M5.price_vs==BELOW|ema200_M15.price_vs==ABOVE|adx_M15.strength in STRONG_TREND,TRENDING|candle_M3.is_bullish==TRUE"
  sell: mirror

V2: RSI2 Extreme Buy (BUY ONLY)
  buy: "rsi2_M5.zone==EXTREME_OS|utbot_H1.bias==BULLISH|vwap_M5.price_vs==BELOW|ema200_M15.price_vs==ABOVE|candle_M3.is_bullish==TRUE"

V3: Stoch Wide Sell (SELL ONLY)
  sell: "stoch_M15.zone in OB,NEUTRAL|utbot_H1.bias==BEARISH|vwap_M5.price_vs==ABOVE|ema200_M15.price_vs==BELOW|adx_M15.strength in STRONG_TREND,TRENDING|candle_M3.is_bearish==TRUE"
```

## Parameter Permutations

For EACH of the 15 strategies, test these parameter combinations. You don't need to test every single permutation — use judgment. Start with the baseline, then try variations.

### SL Variations
| SL | When to use |
|----|-------------|
| 250 | Tight — for high-frequency strategies (T1, T2) |
| 300 | Medium-tight |
| 350 | Current baseline (proven) |
| 400 | Wider — for low-frequency reversal strategies (L1-L3, R1-R3) |
| 500 | Wide — only if nothing else works |

### RR Variations
| RR | When to use |
|----|-------------|
| 1.0 | High win-rate trend strategies (if WR > 55%) |
| 1.25 | Moderate |
| 1.5 | Current baseline for trend |
| 2.0 | Current baseline for reversals/sweeps |
| 2.5 | Aggressive — for very high-conviction setups (sweep + BB + stoch) |
| 3.0 | Ultra-aggressive — worth trying on L1, L3, R1 |

### Trailing Stop Variations
| breakeven_start | trail_start | trail_step | Description |
|-----------------|-------------|------------|-------------|
| 0 | 0 | 2 | No trailing (current baseline) |
| 200 | 0 | 2 | Move SL to entry after $200 profit |
| 0 | 250 | 50 | Start trailing after $250, trail $50 behind |
| 0 | 350 | 75 | Start trailing after $350 (1x SL), trail $75 behind |
| 0 | 500 | 100 | Start trailing after $500, trail $100 behind |
| 200 | 350 | 75 | Breakeven at $200 + trail at $350 |

Previous testing showed breakeven at 175 hurts PF, but that was with `trail_step=2` (too tight). Try wider trail steps ($50-100) — these let winning trades breathe while still protecting profits.

### Suggested Test Matrix Per Strategy

For each strategy, run approximately this sequence:

**Phase 1: Find best SL/RR (5-7 runs)**
1. SL=350, RR=1.5 (baseline)
2. SL=350, RR=2.0
3. SL=300, RR=1.5
4. SL=300, RR=2.0
5. SL=250, RR=1.5 (for high-frequency strategies only)
6. SL=400, RR=2.0 (for low-frequency strategies only)
7. Best SL, RR=2.5 or 3.0 (for sweep/reversal strategies)

**Phase 2: Test trailing stop with best SL/RR (3-4 runs)**
1. Best SL/RR, no trailing (already have this from Phase 1)
2. Best SL/RR, trail_start=350 trail_step=75
3. Best SL/RR, trail_start=500 trail_step=100
4. Best SL/RR, breakeven=200 + trail_start=350 trail_step=75

**Pick the best variant for each strategy and record all results.**

Total: ~10 runs per strategy × 15 strategies = ~150 backtest runs. Skip runs that are clearly unnecessary (e.g., don't test SL=250 on a rare signal like R1 with 10 trades).

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
  breakeven_start: 0.0       # VARY THIS
  trail_start: 0.0           # VARY THIS
  trail_step: 2.0            # VARY THIS

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
    sl: 350.0                 # VARY THIS
    rr: 1.5                   # VARY THIS
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

## Combination Ideas to Explore

Beyond parameter tuning, also try these combination tweaks on promising strategies:

### 1. Timeframe Shifts
Some strategies use M15 signals. Try shifting to M30:
- `liq_M30.lower_swept==TRUE` instead of M15 (bigger swings, fewer signals)
- `stoch_M30.zone==OS` instead of M15
- `bb_M30.reenter_above==TRUE` instead of M15

### 2. Looser/Tighter Stoch Zones
- Current: `stoch_M15.zone==OS` (strict oversold)
- Try: `stoch_M15.zone in OS,NEUTRAL` (more trades, possibly lower PF)
- Try: `stoch_M15.k<=15` (numerically tighter than zone==OS)

### 3. EMA Filter Variations
- Current: `ema200_M15.price_vs==ABOVE`
- Try: `ema50_M15.price_vs==ABOVE` (faster, more responsive)
- Try: `ema200_H1.price_vs==ABOVE` (slower, higher timeframe confirmation)

### 4. UTBot Timeframe Variations
- Current: `utbot_H1.bias==BULLISH`
- Try: `utbot_H4.bias==BULLISH` (longer trend, fewer but higher quality)
- Try: `utbot_M15.bias==BULLISH` (shorter trend, more signals)

### 5. Combining Non-Overlapping Strategies
After finding the best parameters for each strategy individually, try running 2-3 strategies together that DON'T overlap:
- **Sweep family (L1/L2/L3)** rarely fires → combine with **high-frequency T1 (VWAP)**
- **Sell-only (R1/R2/R3)** can run alongside **buy-heavy strategies**
- Don't combine strategies that use similar signals (L1 and L2 overlap, T1 and T2 overlap)

Suggested non-overlapping combos to test as a FINAL step:
- `L1 + T1 + R1` (sweep reversal + VWAP trend + BB trap sell)
- `L3 + T1 + R2` (triple rejection + VWAP trend + exhausted sell)
- `L1 + R1 + P1` (sweep + BB trap sell + DC pullback)

## Minimum Viable Results (6-month window)

- **PF > 1.15** — 6-month window has more trades, so lower PF is still profitable
- **Trades > 30** — need statistical significance over 6 months
- **MaxDD < 35%** — risk control
- Strategies with < 15 trades over 6 months should be discarded regardless of PF

## Deliverable

### 1. Results Table
Write `STRATEGY-RESULTS.md` with a table for ALL strategies tested:

```
| Strategy | SL | RR | Trail | PF | WR | Trades | MaxDD | PnL | Notes |
```

### 2. Best Parameters Per Strategy
For each of the 15 strategies, document the **best parameter combination** found:
```yaml
- name: L1_sweep_stoch
  sl: ???
  rr: ???
  breakeven_start: ???
  trail_start: ???
  trail_step: ???
  6mo_pf: ???
  6mo_trades: ???
```

### 3. Final Production Config
Put your recommended production portfolio in `data/config/config.yaml`:
- Include **3-5 non-overlapping strategies** that work well together
- Use the best parameters found for each
- Use the relaxed global settings (multi_position=true, max_positions=3, cooldown=900)
- This config should be ready to deploy on a demo account

### 4. Discard List
List strategies that FAILED on the 6-month window (PF < 1.15 or < 15 trades). These were overfit to the 2-month window.

### 5. Summary
Write a brief summary:
- Which strategies survived the 6-month test
- Which parameters changed from the 2-month baseline
- Recommended portfolio for demo deployment
- Expected monthly return and drawdown based on 6-month backtest
