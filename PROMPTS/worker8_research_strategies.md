# Research-Based Strategy Testing — BTCUSDT

## Context

Deep research produced 12 strategy ideas from open-source GitHub repos, TradingView scripts, and community strategies. Each has been translated into our EA's expression grammar. Your job is to test them **one at a time** and find the profitable ones.

## Step 0: Read the Docs

```bash
cat ONBOARD.md              # How to run backtests
cat docs/ea.md              # FULL signal reference — ALL available signals
cat docs/yaml-config.md     # Config format
```

## WORKFLOW — One Strategy at a Time

For each strategy below:

1. Put **only that one strategy** in `config.yaml` (all others disabled or removed)
2. Run the backtest
3. Record the result
4. Move to the next strategy

**Never combine strategies in a single run.** We need true standalone numbers.

### Config Template

Use this exact template for every test. Only change the strategy section:

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
  round_level: 500.0
  liq_lookback: 20

control:
  use_control_file: false
  write_status_file: false
  control_poll_sec: 5

strategies:
  - name: STRATEGY_NAME_HERE
    enabled: true
    sl: 400.0
    rr: 1.0
    buy: "..."
    sell: "..."
```

### Run Command

```bash
podman-compose down
rm -f data/reports/backtest_report*
MT5_MODE=tester podman-compose up --build
# Wait for "Tester run complete"
python3 tools/parse_report.py data/reports/backtest_report.htm --human --all
```

### First Pass: SL=400, RR=1.0

Test every strategy with **SL=400, RR=1.0** first. This is our baseline. Record the result and move on. Don't tune yet — just get baseline numbers for all 12.

### Second Pass: Fix Losers

After you have baselines for all 12, come back to the ones that lost (PF < 1.0) and try these fixes **in order**:

1. **Add a filter** — see "Filter Ideas" section below
2. **Try RR=1.5** — if win rate is low (<45%), higher RR may help
3. **Try SL=350** — tighter SL means smaller losses
4. **Try breakeven_start=200** — locks in breakeven on winners

Only try one change at a time. If a strategy is still losing after 3-4 attempts, mark it as failed and move on. Don't waste time — some strategies simply don't work on BTC.

### Minimum Viable Results

- **PF > 1.15** — below this, not profitable after real-world slippage
- **Trades > 15** — fewer = not statistically meaningful
- **MaxDD < 50%** — above this is too risky

---

## THE 12 STRATEGIES TO TEST

### MEAN REVERSION (4 strategies)

#### MR1: Connors RSI2 Pullback
*Source: Jesse trading bot RSI2 example*
Classic pullback: buy exhaustion inside an existing uptrend, sell exhaustion inside a downtrend.

```yaml
- name: mr1_connors_rsi2
  enabled: true
  sl: 400.0
  rr: 1.0
  buy: "ema200_H1.price_vs==ABOVE|ema200_H1.slope==RISING|rsi2_M15.zone in EXTREME_OS,OS|candle_M5.is_bullish==TRUE"
  sell: "ema200_H1.price_vs==BELOW|ema200_H1.slope==FALLING|rsi2_M15.zone in EXTREME_OB,OB|candle_M5.is_bearish==TRUE"
```

#### MR2: IFR2 Crypto Trend Rebound
*Source: Jesse IFR2 strategy — crypto-adapted RSI2*
Buy the dip in trend, not range reversion. Uses H4 trend gate + ADX strength + DC wick rejection as extra confirmation.

```yaml
- name: mr2_ifr2_trend_rebound
  enabled: true
  sl: 400.0
  rr: 1.0
  buy: "ema200_H4.price_vs==ABOVE|adx_H1.strength in TRENDING,STRONG_TREND|rsi2_M5.zone in EXTREME_OS,OS|dc_M5.lower_wick_rej==TRUE|candle_M5.is_bullish==TRUE"
  sell: "ema200_H4.price_vs==BELOW|adx_H1.strength in TRENDING,STRONG_TREND|rsi2_M5.zone in EXTREME_OB,OB|dc_M5.upper_wick_rej==TRUE|candle_M5.is_bearish==TRUE"
```

#### MR3: Bollinger RSI Range Reversion
*Source: NinjaTrader BTC mean reversion*
Only trades when market is NOT trending (ADX ranging/weak). Fades BB band touches with RSI confirmation. This is a pure range strategy — opposite of trend-following.

```yaml
- name: mr3_bb_rsi_range
  enabled: true
  sl: 400.0
  rr: 1.0
  buy: "adx_H1.strength in RANGING,WEAK_TREND|bb_M15.reenter_below==TRUE|rsi14_M15.zone==OS|candle_M5.is_bullish==TRUE"
  sell: "adx_H1.strength in RANGING,WEAK_TREND|bb_M15.reenter_above==TRUE|rsi14_M15.zone==OB|candle_M5.is_bearish==TRUE"
```

#### MR4: Score-Based Scalper Stack
*Source: msolomos BTC scalping bot*
Confluence of 6 indicators simulating a weighted-score bot. Very strict — needs VWAP + MACD cross + stoch zone + RSI level + ADX bias + BB reenter all at once.

```yaml
- name: mr4_score_scalper
  enabled: true
  sl: 400.0
  rr: 1.0
  buy: "vwap_M5.price_vs==ABOVE|macd_M5.cross==CROSS_UP|stoch_M5.zone==OS|rsi14_M5.value<45|adx_M15.di_bias==BULLISH|bb_M5.reenter_below==TRUE"
  sell: "vwap_M5.price_vs==BELOW|macd_M5.cross==CROSS_DOWN|stoch_M5.zone==OB|rsi14_M5.value>55|adx_M15.di_bias==BEARISH|bb_M5.reenter_above==TRUE"
```

---

### TREND & PULLBACK (3 strategies)

#### TP1: EMA RSI ADX Trend Confirmation
*Source: TradingView EMA Cross RSI ADX V2*
Trend follower: price above both EMA9 and EMA21, EMA slope rising, RSI confirming momentum, ADX confirming trend strength.

```yaml
- name: tp1_ema_rsi_adx
  enabled: true
  sl: 400.0
  rr: 1.0
  buy: "ema9_M15.price_vs==ABOVE|ema21_M15.price_vs==ABOVE|ema9_M15.slope==RISING|rsi14_M15.value>55|adx_H1.strength in TRENDING,STRONG_TREND|adx_H1.di_bias==BULLISH"
  sell: "ema9_M15.price_vs==BELOW|ema21_M15.price_vs==BELOW|ema9_M15.slope==FALLING|rsi14_M15.value<45|adx_H1.strength in TRENDING,STRONG_TREND|adx_H1.di_bias==BEARISH"
```

#### TP2: Stochastic Momentum + EMA Filter
*Source: TradingView BTC Stoch RSI Pine strategy*
Momentum recovery from oversold in an EMA-supported trend.

```yaml
- name: tp2_stoch_momentum
  enabled: true
  sl: 400.0
  rr: 1.0
  buy: "ema9_H1.price_vs==ABOVE|ema50_H1.slope==RISING|stoch_M30.zone==OS|macd_M30.hist_dir==RISING|candle_M15.is_bullish==TRUE"
  sell: "ema9_H1.price_vs==BELOW|ema50_H1.slope==FALLING|stoch_M30.zone==OB|macd_M30.hist_dir==FALLING|candle_M15.is_bearish==TRUE"
```

#### TP3: Anwar Higher-TF Pullback Rider
*Source: TradingView Anwar BTC Trend Strategy V2*
Conservative multi-TF pullback: H4 + H1 trend agreement, price pulls back to DC lower-mid/middle zone, then bullish candle confirms resumption. Designed for fewer but cleaner signals.

```yaml
- name: tp3_anwar_pullback
  enabled: true
  sl: 400.0
  rr: 1.0
  buy: "ema50_H1.price_vs==ABOVE|ema200_H4.price_vs==ABOVE|adx_H1.strength in TRENDING,STRONG_TREND|dc_M15.zone in LOWER_MID,MIDDLE|candle_M15.is_bullish==TRUE"
  sell: "ema50_H1.price_vs==BELOW|ema200_H4.price_vs==BELOW|adx_H1.strength in TRENDING,STRONG_TREND|dc_M15.zone in UPPER_MID,MIDDLE|candle_M15.is_bearish==TRUE"
```

---

### BREAKOUT & EXPANSION (3 strategies)

#### BO1: Turtle-Style Donchian Breakout
*Source: Jesse Turtle Rules implementation*
Classic breakout: enter when price hits DC upper band in an uptrend. Low win rate, big winners. Best with higher RR.

```yaml
- name: bo1_turtle_breakout
  enabled: true
  sl: 400.0
  rr: 1.0
  buy: "ema200_H4.price_vs==ABOVE|dc_H1.zone==UPPER|adx_H1.strength in TRENDING,STRONG_TREND|macd_H1.vs_zero==ABOVE"
  sell: "ema200_H4.price_vs==BELOW|dc_H1.zone==LOWER|adx_H1.strength in TRENDING,STRONG_TREND|macd_H1.vs_zero==BELOW"
```

#### BO2: UT Bot MACD Squeeze Expansion
*Source: TradingView BTC Scalping Supertrend MACD Squeeze*
Catches momentum bursts: BB squeeze (compression) + MACD cross as the release trigger. Pure expansion play, not a pullback.

```yaml
- name: bo2_squeeze_expansion
  enabled: true
  sl: 400.0
  rr: 1.0
  buy: "utbot_M15.bias==BULLISH|bb_M3.squeeze==TRUE|macd_M3.cross==CROSS_UP|macd_M3.vs_zero==ABOVE|candle_M3.is_bullish==TRUE"
  sell: "utbot_M15.bias==BEARISH|bb_M3.squeeze==TRUE|macd_M3.cross==CROSS_DOWN|macd_M3.vs_zero==BELOW|candle_M3.is_bearish==TRUE"
```

#### BO3: VWAP Pulse Breakout
*Source: TradingView VWAP Pulse Breakout*
Intraday breakout: VWAP direction + ADX strength + DI bias + DC position + MACD cross timing.

```yaml
- name: bo3_vwap_pulse
  enabled: true
  sl: 400.0
  rr: 1.0
  buy: "vwap_M15.price_vs==ABOVE|adx_M15.strength in TRENDING,STRONG_TREND|adx_M15.di_bias==BULLISH|dc_M5.zone in UPPER_MID,UPPER|macd_M5.cross==CROSS_UP"
  sell: "vwap_M15.price_vs==BELOW|adx_M15.strength in TRENDING,STRONG_TREND|adx_M15.di_bias==BEARISH|dc_M5.zone in LOWER_MID,LOWER|macd_M5.cross==CROSS_DOWN"
```

---

### CONFLUENCE & LIQUIDITY (2 strategies)

#### CL1: VWAP + Higher-TF RSI Alignment
*Source: TradingView VWAP Multi-Timeframe RSI Strategy*
Aligns session VWAP structure with H1 RSI momentum. Simple and directly portable.

```yaml
- name: cl1_vwap_rsi_align
  enabled: true
  sl: 400.0
  rr: 1.0
  buy: "vwap_M15.price_vs==ABOVE|rsi14_H1.value>50|rsi14_M15.zone==NEUTRAL|utbot_M15.bias==BULLISH|macd_M15.vs_zero==ABOVE"
  sell: "vwap_M15.price_vs==BELOW|rsi14_H1.value<50|rsi14_M15.zone==NEUTRAL|utbot_M15.bias==BEARISH|macd_M15.vs_zero==BELOW"
```

#### CL2: Liquidity Sweep Reversal
*Source: TradingView Liquidity Sweeper*
Stop-hunt reversal: price sweeps past swing highs/lows, collects liquidity, then snaps back. Only in the direction of H1 bias. Requires both liq sweep + DC wick rejection + specific candle type (hammer/shooting star).

```yaml
- name: cl2_liq_sweep_reversal
  enabled: true
  sl: 400.0
  rr: 1.0
  buy: "utbot_H1.bias==BULLISH|liq_M5.lower_swept==TRUE|dc_M5.lower_wick_rej==TRUE|candle_M5.type==HAMMER|candle_M5.is_bullish==TRUE"
  sell: "utbot_H1.bias==BEARISH|liq_M5.upper_swept==TRUE|dc_M5.upper_wick_rej==TRUE|candle_M5.type==SHOOTING_STAR|candle_M5.is_bearish==TRUE"
```

---

## Filter Ideas (for Second Pass)

If a strategy loses on baseline, try adding ONE of these filters:

| Filter | Expression | When to use |
|--------|------------|-------------|
| Higher-TF trend gate | `utbot_H1.bias==BULLISH` (buy) | Strategy trades against the trend too often |
| EMA200 regime | `ema200_M15.price_vs==ABOVE` (buy) | Too many trades in bear markets |
| ADX strength | `adx_H1.strength in TRENDING,STRONG_TREND` | Too many trades in choppy/ranging markets |
| Body quality | `candle_M5.body_pct>=50` | Too many doji/weak candle entries |
| Candle confirmation | `candle_M3.is_bullish==TRUE` (buy) | Entries without directional confirmation |
| VWAP discount | `vwap_M5.price_vs==BELOW` (buy) | Buying at premium instead of discount |
| DC zone | `dc_M15.zone in LOWER,LOWER_MID` (buy) | Not entering at support |

**Add only ONE filter at a time.** Test, record, then decide if another is needed.

---

## Deliverable

Create a results table like this after testing:

```
| Strategy | SL | RR | PF | Trades | WinRate | MaxDD | Verdict |
|----------|-----|-----|------|--------|---------|-------|---------|
| mr1_connors_rsi2 | 400 | 1.0 | 1.35 | 45 | 52% | 18% | PASS |
| mr2_ifr2_rebound | 400 | 1.0 | 0.85 | 32 | 38% | 35% | +filter |
| mr2_ifr2_rebound | 400 | 1.5 | 1.12 | 32 | 38% | 28% | PASS |
| mr3_bb_rsi_range | 400 | 1.0 | 0.72 | 18 | 33% | 42% | FAIL |
```

For each strategy paste the full `--human --all` output so we can verify.

After all 12 are tested, put your **single best strategy** in `config.yaml` with `enabled: true`.

## RULES

1. **ONE strategy per backtest** — never combine
2. **SL=400, RR=1.0 first** — baseline before any tuning
3. **Full 5-month window** — `from: "2026.01.13"` `to: "2026.06.13"` — no short windows
4. **Log everything** — paste `--human --all` output for every test
5. **Don't over-tune** — 3-4 attempts max per strategy, then move on
6. **Full autonomy** — do NOT ask for confirmations. Test, record, move to next.
