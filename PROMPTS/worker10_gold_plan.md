# Worker 10 — GOLD (XAUUSD) Ultra-Aggressive Scalping: Strategy Plan

## Context

This document contains **12 original aggressive XAUUSD scalping strategies** designed for:
- **Symbol:** XAUUSD (Gold vs USD)
- **Timeframe focus:** M1/M3/M5, with M15/H1 context gates
- **Trade lifecycle:** 1–5 minutes (fast TP/SL hits)
- **Style:** Ultra-aggressive scalping — high-frequency, tight risk, fast exits

All strategies are translated into our EA's expression grammar using only the available signal families documented in `docs/ea.md`.

---

## Design Principles

1. **Lean conditions:** Most entries use 3-5 conditions (avoid over-filtering)
2. **Wick/rejection heavy:** Candle behavior is the primary signal — wicks don't lie
3. **Short-TF trigger + one context gate:** M1/M3 for entry, M5/M15 for context
4. **Both directions wherever possible** (some setups are directional by nature)
5. **Session proxies:** ADX strength, BB squeeze, and trend-state filters act as session/volatility proxies

---

## Strategy Categories

| # | Category | Strategies | Count |
|---|----------|------------|-------|
| G1–G4 | Reversal-focused | Wick rejections, exhaustion reversals | 4 |
| G5–G8 | Continuation/Momentum | Trend-following scalp entries | 4 |
| G9–G12 | Hybrid (sweep + continuation) | Liquidity grab → reverse, squeeze breakouts | 4 |

---

## STRATEGY G1: Golden Wick Rejection Snap (Reversal)

**Concept:** Gold loves round numbers. When price tags a round level ($3,000, $3,050, $3,100, etc.) and leaves a massive wick on M1, that's trapped traders getting stopped out. Enter on the wick confirmation with RSI2 extreme to catch the snap-back.

**Rationale:** XAUUSD traders heavily use round numbers as psychological levels. Wick rejections at these levels have a high probability of a 1-2 dollar snap-back within 1-3 minutes.

**Category:** Reversal

```yaml
- name: g1_round_wick_snap
  enabled: true
  sl: 5.0
  rr: 1.0
  buy: "candle_M1.lower_wick_ratio>=3.0|candle_M1.is_bullish==TRUE|rsi2_M1.zone==EXTREME_OS|round_M1.dist_below<=1.5"
  sell: "candle_M1.upper_wick_ratio>=3.0|candle_M1.is_bearish==TRUE|rsi2_M1.zone==EXTREME_OB|round_M1.dist_above<=1.5"
```

**Conditions explained:**
- Massive lower/upper wick (3x body = clear rejection)
- Candle direction matches
- RSI2 extreme exhaustion (panic sellers/buyers flushed)
- Near a round number ($1.50 or less)

---

## STRATEGY G2: UT Bot Exhaustion Fade (Reversal)

**Concept:** When UT Bot has been in one direction for an extended run and price starts to reverse with a rejection candle, fade the exhaustion. This catches the end of mini-trends on M3.

**Rationale:** UT Bot `bullish_since` and `bearish_since` track consecutive bars in a trend. Extended runs (>5 bars on M3 = 15 minutes) often exhaust and reverse, especially with a wick rejection at a DC boundary.

**Category:** Reversal

```yaml
- name: g2_utbot_exhaust_fade
  enabled: true
  sl: 5.0
  rr: 1.0
  buy: "utbot_M3.bearish_since>=5|dc_M3.lower_wick_rej==TRUE|candle_M3.is_bullish==TRUE|candle_M3.lower_wick_ratio>=2.0"
  sell: "utbot_M3.bullish_since>=5|dc_M3.upper_wick_rej==TRUE|candle_M3.is_bearish==TRUE|candle_M3.upper_wick_ratio>=2.0"
```

**Conditions explained:**
- UT Bot exhausted: 5+ bars in one direction on M3
- Donchian Channel wick rejection confirms boundary touch
- Candle confirms rejection with 2x wick ratio

---

## STRATEGY G3: VWAP Mean Reversion Scalp (Reversal)

**Concept:** Price extends too far from VWAP during NY/London session, then prints a rejection candle at a band extreme. Mean reversion back to VWAP is high-probability for 1-3 minute scalps.

**Rationale:** VWAP acts as a magnetic level during active sessions. When ADX is weak (no strong trend), extended moves from VWAP revert. This is adapted from the GoldBTC.ai VWAP mean reversion strategy.

**Category:** Reversal

```yaml
- name: g3_vwap_mean_revert
  enabled: true
  sl: 5.0
  rr: 1.0
  buy: "vwap_M5.price_vs==BELOW|adx_M5.strength in WEAK_TREND,RANGING|candle_M1.lower_wick_ratio>=2.0|candle_M1.is_bullish==TRUE|stoch_M1.zone==OS"
  sell: "vwap_M5.price_vs==ABOVE|adx_M5.strength in WEAK_TREND,RANGING|candle_M1.upper_wick_ratio>=2.0|candle_M1.is_bearish==TRUE|stoch_M1.zone==OB"
```

**Conditions explained:**
- Price extended from VWAP (above for shorts, below for longs)
- ADX weak/ranging = no strong trend to fight (mean reversion only works in ranges)
- Wick rejection confirms exhaustion
- Stochastic extreme confirms overextension

---

## STRATEGY G4: RSI2 Panic Snap (Reversal)

**Concept:** Pure RSI2 mean reversion — when RSI2 hits extreme levels (<5 or >95), the rubber band snaps back. Filter with a candle confirmation to avoid catching falling knives.

**Rationale:** RSI2 on M1 measures 2-bar momentum. Readings below 5 or above 95 represent panic. These extreme readings almost always revert within 1-3 bars. This is a well-known scalping tactic (Larry Connors' RSI2).

**Category:** Reversal

```yaml
- name: g4_rsi2_panic_snap
  enabled: true
  sl: 5.0
  rr: 1.0
  buy: "rsi2_M1.value<5|candle_M1.is_bullish==TRUE|candle_M1.body_pct>=40"
  sell: "rsi2_M1.value>95|candle_M1.is_bearish==TRUE|candle_M1.body_pct>=40"
```

**Conditions explained:**
- RSI2 <5 or >95 = extreme exhaustion
- Candle confirms direction shift (bullish for buy, bearish for sell)
- Body at least 40% of range (not a doji fakeout)

---

## STRATEGY G5: EMA 9/21 Crossover Momentum (Continuation)

**Concept:** Fast EMA crossover on M2 with trend confirmation from M5. When EMA9 crosses above EMA21 and price is above 200 EMA on M5, enter on the close of the crossover candle.

**Rationale:** EMA crossovers on short timeframes capture momentum entry points. The 9/21 combo on M2 is responsive enough for gold's volatility while the M5 200 EMA filter keeps you on the right side of the larger trend.

**Category:** Continuation

```yaml
- name: g5_ema_cross_momentum
  enabled: true
  sl: 5.0
  rr: 1.0
  buy: "ema9_M2.slope==RISING|ema21_M2.slope==RISING|ema200_M5.price_vs==ABOVE|adx_M5.strength in TRENDING,STRONG_TREND|macd_M5.hist_dir==RISING"
  sell: "ema9_M2.slope==FALLING|ema21_M2.slope==FALLING|ema200_M5.price_vs==BELOW|adx_M5.strength in TRENDING,STRONG_TREND|macd_M5.hist_dir==FALLING"
```

**Conditions explained:**
- Both EMAs sloping in trade direction (confirms momentum, not just a cross)
- M5 trend filter: price on correct side of 200 EMA
- ADX trending = trending market, good for continuation
- MACD histogram confirms momentum acceleration

---

## STRATEGY G6: MACD Histogram Acceleration (Continuation)

**Concept:** When MACD histogram is rising (accelerating momentum) and price is on the right side of 200 EMA, enter on a pullback candle that holds the trend. This is a momentum continuation scalp.

**Rationale:** MACD histogram direction shows the rate of change of momentum. Rising histogram + trend alignment = the trend is accelerating, not decelerating. Entry on a small pullback candle gets you in at a discount.

**Category:** Continuation

```yaml
- name: g6_macd_hist_accel
  enabled: true
  sl: 5.0
  rr: 1.0
  buy: "macd_M3.hist_dir==RISING|ema200_M5.price_vs==ABOVE|candle_M1.is_bullish==TRUE|candle_M1.body_pct>=50|utbot_M5.bias==BULLISH"
  sell: "macd_M3.hist_dir==FALLING|ema200_M5.price_vs==BELOW|candle_M1.is_bearish==TRUE|candle_M1.body_pct>=50|utbot_M5.bias==BEARISH"
```

**Conditions explained:**
- MACD histogram rising/falling on M3 (momentum acceleration)
- M5 trend context: 200 EMA direction
- M1 entry candle confirms direction with solid body
- UT Bot M5 confirms the medium-term bias

---

## STRATEGY G7: Stochastic Cross Momentum (Continuation)

**Concept:** When Stochastic crosses above 20 (from oversold, starting to rise) in an uptrend confirmed by EMA200, enter on the next bullish M1 candle. Classic momentum entry at the start of a mini-wave.

**Rationale:** Stochastic crossing above 20 in an uptrend is a textbook momentum continuation. On gold M1/M5, this happens frequently enough for scalping with good reliability when filtered by trend.

**Category:** Continuation

```yaml
- name: g7_stoch_momentum
  enabled: true
  sl: 5.0
  rr: 1.0
  buy: "stoch_M5.k>=20|stoch_M5.k<=45|ema200_M5.price_vs==ABOVE|macd_M5.hist_dir==RISING|candle_M1.is_bullish==TRUE"
  sell: "stoch_M5.k<=80|stoch_M5.k>=55|ema200_M5.price_vs==BELOW|macd_M5.hist_dir==FALLING|candle_M1.is_bearish==TRUE"
```

**Conditions explained:**
- Stoch %K between 20-45 (emerging from oversold, momentum building) for buys
- Stoch %K between 55-80 (emerging from overbought, momentum building) for sells
- M5 trend: 200 EMA direction
- MACD histogram confirms momentum direction
- M1 candle confirms immediate direction

---

## STRATEGY G8: BB Squeeze Breakout Scalp (Continuation)

**Concept:** When Bollinger Bands are in a squeeze (low volatility) and price breaks above/below the upper/lower band with a strong candle, enter in the breakout direction. This is a volatility expansion play.

**Rationale:** BB squeezes precede explosive moves. On M3 for gold, a squeeze resolution often produces a $3-8 move in the next 5-10 minutes. Entering on the first candle that re-enters above/below the band captures the start of the expansion.

**Category:** Continuation

```yaml
- name: g8_bb_squeeze_break
  enabled: true
  sl: 5.0
  rr: 1.0
  buy: "bb_M3.squeeze==TRUE|bb_M3.reenter_above==TRUE|candle_M3.body_pct>=60|candle_M3.is_bullish==TRUE|adx_M5.strength not_in RANGING"
  sell: "bb_M3.squeeze==TRUE|bb_M3.reenter_below==TRUE|candle_M3.body_pct>=60|candle_M3.is_bearish==TRUE|adx_M5.strength not_in RANGING"
```

**Conditions explained:**
- BB squeeze active (low volatility, expansion imminent)
- Price re-enters above/below the band (breakout confirmation)
- Strong candle body (>60%) confirms conviction
- ADX not ranging (breakout needs some trend context)

---

## STRATEGY G9: Liquidity Sweep Reversal (Hybrid)

**Concept:** Upper/lower liquidity is swept (stop hunt), followed by a reversal candle. This is the classic "stop hunt then reverse" pattern. Price sweeps stops above a swing high or below a swing low, then immediately reverses.

**Rationale:** Liquidity sweeps are one of the highest-probability patterns in gold. Market makers hunt stops before the real move. The sweep + reversal combo on M15 context with M3 entry confirmation is proven in SMC/ICT trading.

**Category:** Hybrid

```yaml
- name: g9_liq_sweep_reverse
  enabled: true
  sl: 5.0
  rr: 1.0
  buy: "liq_M15.lower_swept==TRUE|candle_M3.is_bullish==TRUE|candle_M3.body_pct>=50|ema200_M15.price_vs==ABOVE|macd_M3.hist_dir==RISING"
  sell: "liq_M15.upper_swept==TRUE|candle_M3.is_bearish==TRUE|candle_M3.body_pct>=50|ema200_M15.price_vs==BELOW|macd_M3.hist_dir==FALLING"
```

**Conditions explained:**
- Liquidity sweep detected on M15 (stop hunt confirmed)
- M3 entry candle bullish/bearish with solid body
- M15 200 EMA trend alignment (sweep must be in the direction of the larger trend)
- MACD M3 histogram confirms the reversal direction

---

## STRATEGY G10: DC Wick Rejection + Momentum Continuation (Hybrid)

**Concept:** Price approaches a DC boundary, leaves a wick rejection, then continues in the original trend direction. This is a "pullback to support/resistance" setup where the DC boundary acts as dynamic S/R.

**Rationale:** Donchian Channel boundaries are dynamic support/resistance. When price pulls back to the LOWER boundary in an uptrend and rejects, it's a high-probability continuation entry. The DC zone + trend filter keeps this tight.

**Category:** Hybrid

```yaml
- name: g10_dc_wick_continue
  enabled: true
  sl: 5.0
  rr: 1.0
  buy: "dc_M5.lower_wick_rej==TRUE|utbot_M5.bias==BULLISH|ema50_M5.price_vs==ABOVE|candle_M1.is_bullish==TRUE|candle_M1.body_pct>=50"
  sell: "dc_M5.upper_wick_rej==TRUE|utbot_M5.bias==BEARISH|ema50_M5.price_vs==BELOW|candle_M1.is_bearish==TRUE|candle_M1.body_pct>=50"
```

**Conditions explained:**
- DC M5 wick rejection at lower (buy) or upper (sell) boundary
- UT Bot confirms medium-term bias
- EMA50 confirms trend direction
- M1 entry candle confirms rejection with solid body

---

## STRATEGY G11: UTBot Signal + RSI Confirmation Hybrid (Hybrid)

**Concept:** UT Bot fires a fresh BUY/SELL signal (not just bias, but a one-bar flash), confirmed by RSI14 zone and candle direction. This catches the exact moment of trend change or continuation with momentum confirmation.

**Rationale:** UT Bot `.signal` is a one-bar flash that only fires at signal bars. It's rarer than `.bias` but more precise. Combining it with RSI zone (not extreme, but directional) and candle confirmation creates a high-conviction hybrid entry.

**Category:** Hybrid

```yaml
- name: g11_utbot_signal_rsi
  enabled: true
  sl: 5.0
  rr: 1.0
  buy: "utbot_M3.signal==BUY|rsi14_M5.value>=40|rsi14_M5.value<=60|candle_M1.is_bullish==TRUE|adx_M5.strength not_in RANGING"
  sell: "utbot_M3.signal==SELL|rsi14_M5.value>=40|rsi14_M5.value<=60|candle_M1.is_bearish==TRUE|adx_M5.strength not_in RANGING"
```

**Conditions explained:**
- UT Bot fresh BUY/SELL signal on M3 (rare, high-precision)
- RSI14 between 40-60 (neutral zone, room to run — not overbought/oversold)
- M1 candle confirms direction
- ADX not ranging (trend context)

---

## STRATEGY G12: Round Number Bounce + Candle Direction (Hybrid)

**Concept:** Price is near a round number, the M5 trend is established, and an M1 candle bounces off the round number in the trend direction. This combines the psychological magnet of round numbers with trend continuation.

**Rationale:** Gold has massive round-number respect. Bounces at $50/$100 levels are common. This strategy waits for price to be near a round level AND align with the trend, then enters on the bounce confirmation candle.

**Category:** Hybrid

```yaml
- name: g12_round_bounce_trend
  enabled: true
  sl: 5.0
  rr: 1.0
  buy: "round_M5.dist_below<=2.0|utbot_M5.bias==BULLISH|candle_M1.is_bullish==TRUE|candle_M1.lower_wick_ratio>=1.5|ema200_M15.price_vs==ABOVE"
  sell: "round_M5.dist_above<=2.0|utbot_M5.bias==BEARISH|candle_M1.is_bearish==TRUE|candle_M1.upper_wick_ratio>=1.5|ema200_M15.price_vs==BELOW"
```

**Conditions explained:**
- Price within $2 of a round number on M5
- UT Bot confirms trend bias (bouncing off support in uptrend = buy)
- M1 candle has a wick (rejection) in the bounce direction
- M15 200 EMA confirms larger trend (optional but high-value filter)

---

## Summary Table

| ID | Name | Category | Conditions | Direction | SL | RR |
|----|------|----------|------------|-----------|----|----|
| G1 | Golden Wick Rejection Snap | Reversal | 4 | Both | 5.0 | 1.0 |
| G2 | UT Bot Exhaustion Fade | Reversal | 4 | Both | 5.0 | 1.0 |
| G3 | VWAP Mean Reversion Scalp | Reversal | 5 | Both | 5.0 | 1.0 |
| G4 | RSI2 Panic Snap | Reversal | 3 | Both | 5.0 | 1.0 |
| G5 | EMA 9/21 Crossover Momentum | Continuation | 5 | Both | 5.0 | 1.0 |
| G6 | MACD Histogram Acceleration | Continuation | 5 | Both | 5.0 | 1.0 |
| G7 | Stochastic Cross Momentum | Continuation | 5 | Both | 5.0 | 1.0 |
| G8 | BB Squeeze Breakout Scalp | Continuation | 5 | Both | 5.0 | 1.0 |
| G9 | Liquidity Sweep Reversal | Hybrid | 5 | Both | 5.0 | 1.0 |
| G10 | DC Wick Rejection + Continuation | Hybrid | 5 | Both | 5.0 | 1.0 |
| G11 | UTBot Signal + RSI Hybrid | Hybrid | 5 | Both | 5.0 | 1.0 |
| G12 | Round Number Bounce + Trend | Hybrid | 5 | Both | 5.0 | 1.0 |

---

## Test Config Template (Full)

```yaml
backtest:
  symbol: XAUUSD
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
  magic: 700
  multi_position: false
  max_positions: 1
  max_daily_trades: 150
  cooldown_sec: 60
  reversal_cooldown: 60
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
  round_level: 5.0
  liq_lookback: 20

control:
  use_control_file: false
  write_status_file: false
  control_poll_sec: 5

strategies: []  # ONE strategy at a time
```

---

## SL/RR Rationale

- **SL=$5.0:** On XAUUSD at ~$3,000, $5 = ~0.17% move. On M1, this is 1-2 typical bars of range. Tight enough for scalping but not so tight that noise kills every trade.
- **RR=1.0:** 1:1 is baseline for ultra-aggressive scalping. High-frequency strategies need high win rate, not high RR. If a strategy shows promise, we can test RR=1.2 or RR=1.5 in optimization.
- **Cooldown=60s:** Very fast cooldown to allow frequent trades (target: 100+ trades in 5 months).
- **Max_Daily_Trades=150:** Allows up to ~1 trade per 10 minutes on average during active hours.

---

## Phase 1 Complete

> Phase 1 complete. Plan is ready in `PROMPTS/worker10_gold_plan.md`. Waiting for go-ahead for testing.