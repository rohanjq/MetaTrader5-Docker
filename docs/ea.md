# MasterTrader EA — Signal & Expression Reference

MasterTrader is an expression-based multi-strategy EA. It contains zero hardcoded strategy logic — all strategies are defined as buy/sell expression strings evaluated at runtime.

## Architecture

```
Indicators (computed every new bar on each timeframe)
    ↓
Signal Registry (key-value store: "utbot_M3.bias" → "BULLISH")
    ↓
Expression Engine (evaluates "utbot_M3.bias==BULLISH|dc_M15.zone==UPPER")
    ↓
Trade Execution (lot sizing, SL/TP, order management)
```

## Timeframes

Signals are computed on **11 timeframes** simultaneously. Use the suffix `_TF` in signal keys:

| Suffix | Timeframe |
|---|---|
| `_M1` | 1 minute |
| `_M2` | 2 minutes |
| `_M3` | 3 minutes |
| `_M5` | 5 minutes |
| `_M10` | 10 minutes |
| `_M15` | 15 minutes |
| `_M30` | 30 minutes |
| `_H1` | 1 hour |
| `_H4` | 4 hours |
| `_D1` | Daily |
| `_W1` | Weekly |

**Example:** `utbot_M3.bias`, `dc_M15.zone`, `ema50_H1.slope`

---

## Indicators & Signal Keys

### UT Bot (ATR trailing stop crossover)

**Prefix:** `utbot_TF`

| Key | Values | Description |
|---|---|---|
| `.bias` | `BULLISH`, `BEARISH` | Current trend direction based on trailing stop |
| `.signal` | `BUY`, `SELL`, `NONE` | One-bar flash when direction changes |
| `.bullish_since` | integer (e.g. `5`) | Consecutive bars bias has been BULLISH (0 if bearish) |
| `.bearish_since` | integer (e.g. `3`) | Consecutive bars bias has been BEARISH (0 if bullish) |

**Parameters:** `utbot_period` (ATR period, default 10), `utbot_mult` (ATR multiplier, default 2.0)

**Examples:**
```
utbot_M3.bias==BULLISH            # M3 trend is bullish
utbot_M5.signal==BUY              # M5 just flipped to buy (one bar only)
utbot_M5.bullish_since>=2         # M5 has been bullish for 2+ bars
utbot_H1.bearish_since>=5         # H1 has been bearish for 5+ bars
```

### Donchian Channel

**Prefix:** `dc_TF`

| Key | Values | Description |
|---|---|---|
| `.zone` | `UPPER`, `UPPER_MID`, `MIDDLE`, `LOWER_MID`, `LOWER` | Price zone within channel |
| `.upper_wick_rej` | `TRUE`, `FALSE` | Candle touched upper band and wicked down (wick > body) |
| `.lower_wick_rej` | `TRUE`, `FALSE` | Candle touched lower band and wicked up (wick > body) |
| `.width` | decimal (e.g. `150.5`) | Channel width in price units |

**Parameter:** `dc_length` (lookback period, default 20)

**Zone thresholds** (based on `(close - lower) / width * 100`):

| Zone | Range |
|---|---|
| `UPPER` | 80–100% |
| `UPPER_MID` | 60–80% |
| `MIDDLE` | 40–60% |
| `LOWER_MID` | 20–40% |
| `LOWER` | 0–20% |

**Examples:**
```
dc_M15.lower_wick_rej==TRUE       # M15 candle rejected off lower DC band
dc_M15.zone==UPPER                # Price in top 20% of M15 DC
dc_M5.zone in LOWER,LOWER_MID    # Price in bottom 40% of M5 DC
dc_M15.zone in UPPER,UPPER_MID   # Price in top 40% of M15 DC
```

### EMA (9, 21, 50, 200)

**Prefix:** `ema{X}_TF` where X = `9`, `21`, `50`, `200`

| Key | Values | Description |
|---|---|---|
| `.price_vs` | `ABOVE`, `BELOW` | Close price vs EMA value |
| `.slope` | `RISING`, `FALLING`, `FLAT` | EMA direction (current vs 3 bars ago) |
| `.value` | decimal (e.g. `63250.5`) | Raw EMA value |

**Examples:**
```
ema50_M5.price_vs==BELOW          # Price below M5 EMA50
ema200_M15.price_vs==ABOVE        # Price above M15 EMA200
ema50_M15.slope==RISING           # M15 EMA50 trending up
ema9_M3.slope==FALLING            # M3 EMA9 trending down
```

### RSI (2, 14)

**Prefix:** `rsi{X}_TF` where X = `2`, `14`

| Key | Values | Description |
|---|---|---|
| `.value` | decimal (e.g. `35.50`) | Raw RSI value |
| `.zone` | see below | Zone classification |

**RSI-14 zones:**

| Zone | Range |
|---|---|
| `OB` | > 70 |
| `OS` | < 30 |
| `NEUTRAL` | 30–70 |

**RSI-2 zones** (more extreme thresholds for mean reversion):

| Zone | Range |
|---|---|
| `EXTREME_OB` | > 95 |
| `OB` | > 80 |
| `EXTREME_OS` | < 5 |
| `OS` | < 20 |
| `NEUTRAL` | 20–80 |

**Examples:**
```
rsi2_M5.zone==EXTREME_OS          # RSI(2) on M5 is extremely oversold (<5)
rsi14_M15.zone==OB                # RSI(14) on M15 is overbought (>70)
rsi14_H1.value>=60                # Raw RSI(14) on H1 is 60+
```

### ADX

**Prefix:** `adx_TF`

| Key | Values | Description |
|---|---|---|
| `.value` | decimal (e.g. `28.50`) | Raw ADX value |
| `.strength` | `STRONG_TREND`, `TRENDING`, `WEAK_TREND`, `RANGING` | Trend strength classification |
| `.di_bias` | `BULLISH`, `BEARISH`, `NEUTRAL` | DI+ vs DI- comparison |

**Strength thresholds:**

| Strength | ADX Range |
|---|---|
| `STRONG_TREND` | ≥ 40 |
| `TRENDING` | ≥ 25 |
| `WEAK_TREND` | ≥ 20 |
| `RANGING` | < 20 |

**Examples:**
```
adx_M15.strength in STRONG_TREND,TRENDING   # M15 is trending (ADX ≥ 25)
adx_H1.di_bias==BULLISH                     # H1 DI+ > DI-
adx_M15.strength==RANGING                   # Market is ranging
```

### MACD

**Prefix:** `macd_TF`

| Key | Values | Description |
|---|---|---|
| `.cross` | `CROSS_UP`, `CROSS_DOWN`, `NONE` | Signal line crossover (one-bar flash) |
| `.hist_dir` | `RISING`, `FALLING` | Histogram direction (expanding/contracting) |
| `.vs_zero` | `ABOVE`, `BELOW` | MACD line vs zero line |

**Examples:**
```
macd_M15.cross==CROSS_UP          # MACD just crossed above signal line
macd_H1.vs_zero==ABOVE            # MACD line is above zero
macd_M5.hist_dir==RISING          # Histogram expanding (momentum increasing)
```

### Stochastic

**Prefix:** `stoch_TF`

| Key | Values | Description |
|---|---|---|
| `.k` | decimal (e.g. `75.30`) | Raw %K value |
| `.zone` | `OB`, `OS`, `NEUTRAL` | Zone (>80 OB, <20 OS) |

**Examples:**
```
stoch_M15.zone==OS                # M15 stochastic oversold
stoch_H1.k>=50                    # H1 %K above 50
```

### Bollinger Bands

**Prefix:** `bb_TF`

| Key | Values | Description |
|---|---|---|
| `.squeeze` | `TRUE`, `FALSE` | Bandwidth contracted >25% vs previous bar |
| `.reenter_below` | `TRUE`, `FALSE` | Price was below lower band, now re-entered |

**Examples:**
```
bb_M15.squeeze==TRUE              # Bollinger squeeze on M15
bb_M5.reenter_below==TRUE         # Price re-entered from below lower band
```

### ATR

**Prefix:** `atr_TF`

| Key | Values | Description |
|---|---|---|
| `.value` | decimal (e.g. `25.30`) | Raw ATR value |

**Example:**
```
atr_M15.value>=20                 # M15 ATR is 20+ (sufficient volatility)
```

### VWAP (Session-based)

**Prefix:** `vwap_TF` (sub-daily timeframes only, D1/W1 not computed)

| Key | Values | Description |
|---|---|---|
| `.price_vs` | `ABOVE`, `BELOW` | Close price vs VWAP |
| `.value` | decimal (e.g. `63100.5`) | Raw VWAP value |

VWAP is calculated from midnight each day using tick volume.

**Examples:**
```
vwap_M1.price_vs==BELOW           # Price below session VWAP
vwap_M5.price_vs==ABOVE           # Price above session VWAP
```

### Round Number Proximity

**Prefix:** `round_TF`

Tracks distance to the nearest psychological round-number levels (configurable interval, default 500 for BTC — e.g. 65000, 65500, 66000).

| Key | Values | Description |
|---|---|---|
| `.dist_above` | decimal (e.g. `150.0`) | Distance in $ to the next round level above |
| `.dist_below` | decimal (e.g. `350.0`) | Distance in $ to the next round level below |
| `.pct` | decimal (e.g. `70.0`) | Position within the current round range (0=at lower, 100=at upper) |

**Parameter:** `round_level` (round number interval, default 500.0)

**Examples:**
```
round_M1.pct>=70                   # Price in upper 30% of round range (near next level above)
round_M1.dist_above<=100           # Within $100 of the next round level above
round_M5.pct<=30                   # Price near the bottom of the round range
```

### Liquidity Sweep

**Prefix:** `liq_TF`

Detects price sweeping past recent swing high/low pivot points — areas where resting orders (stop-losses) cluster. A sweep occurs when the wick pierces beyond the level but the close retreats back inside, indicating a "stop hunt" reversal.

| Key | Values | Description |
|---|---|---|
| `.upper_swept` | `TRUE`, `FALSE` | Closed bar wick went above the highest swing high but close came back below |
| `.lower_swept` | `TRUE`, `FALSE` | Closed bar wick went below the lowest swing low but close came back above |
| `.upper_level` | decimal (e.g. `65400.0`) | Highest swing high in lookback window (liquidity pool above) |
| `.lower_level` | decimal (e.g. `64200.0`) | Lowest swing low in lookback window (liquidity pool below) |

**Parameter:** `liq_lookback` (swing point scan window, default 20 bars)

**Examples:**
```
liq_M15.upper_swept==TRUE          # Liquidity above was grabbed on M15
liq_M15.upper_swept==TRUE|candle_M3.is_bullish==TRUE   # Upper sweep + M3 bullish confirmation
liq_H1.lower_swept==TRUE|ema9_M5.slope==UP             # H1 sweep below + M5 trend turning up
```

### Candle Patterns

**Prefix:** `candle_TF` (sub-daily timeframes only)

Computed for two bars:
- **Closed bar** (bar index 1): keys use `candle_TF.{field}` — updated on new bar
- **Running bar** (bar index 0): keys use `candle_TF.live_{field}` — updated every tick

| Key | Values | Description |
|---|---|---|
| `.type` | `HAMMER`, `SHOOTING_STAR`, `DOJI`, `MARUBOZU`, `SPINNING_TOP`, `NORMAL` | Candle pattern type |
| `.dir` | `UP`, `DOWN`, `DOJI` | Candle direction (close vs open) |
| `.is_bullish` | `TRUE`, `FALSE` | Close > Open |
| `.is_bearish` | `TRUE`, `FALSE` | Close < Open |
| `.upper_wick_ratio` | decimal (e.g. `2.50`) | Upper wick / body size |
| `.lower_wick_ratio` | decimal (e.g. `0.30`) | Lower wick / body size |
| `.body_pct` | decimal (e.g. `65.0`) | Body as % of total range |

**Candle type classification:**

| Type | Condition |
|---|---|
| `DOJI` | body < 10% of range |
| `MARUBOZU` | body ≥ 80% of range |
| `HAMMER` | lower wick ≥ 2× body, upper wick < body |
| `SHOOTING_STAR` | upper wick ≥ 2× body, lower wick < body |
| `SPINNING_TOP` | body < 40% and both wicks > 0.5× body |
| `NORMAL` | none of the above |

**Examples:**
```
candle_M3.type==HAMMER                     # Closed M3 bar is a hammer
candle_M5.type==SHOOTING_STAR              # Closed M5 bar is a shooting star
candle_M3.type==DOJI                       # Closed M3 bar is a doji
candle_M3.is_bearish==TRUE                 # Closed M3 bar is bearish
candle_M3.upper_wick_ratio>=2              # Upper wick is 2× body or more
candle_M3.live_type==HAMMER                # Running (live) M3 bar is a hammer
candle_M5.live_is_bullish==TRUE            # Running M5 bar is currently bullish
```

---

## Expression Syntax

Strategies are defined as expression strings. Each expression is a set of conditions joined by `|` (AND — all must be true).

### Format

```
condition1|condition2|condition3
```

Each condition: `signal_key OPERATOR value`

### Operators

| Operator | Example | Description |
|---|---|---|
| `==` | `utbot_M3.bias==BULLISH` | Equals |
| `!=` | `utbot_M3.bias!=BEARISH` | Not equals |
| `>=` | `utbot_M5.bullish_since>=2` | Greater or equal (numeric) |
| `<=` | `rsi14_M15.value<=30` | Less or equal (numeric) |
| `>` | `atr_M15.value>20` | Greater than (numeric) |
| `<` | `rsi2_M5.value<5` | Less than (numeric) |
| `in` | `dc_M15.zone in UPPER,UPPER_MID` | Value is one of (comma-separated) |
| `not_in` | `dc_M15.zone not_in LOWER` | Value is not one of |

**Important:** `in` and `not_in` require spaces around them: `key in val1,val2`. Spaces after commas in the value list are allowed (e.g. `key in val1, val2` works — values are trimmed).

### Strategy Slots

The EA has 20 strategy slots (S01–S20). Each slot has:

| Field | Type | Description |
|---|---|---|
| `_On` | bool | Enable/disable this strategy |
| `_SL` | double | Stop loss in dollars (0 = use global default) |
| `_RR` | double | Reward:risk ratio (0 = use global default) |
| `_Buy` | string | Buy entry expression (empty = no buys) |
| `_Sell` | string | Sell entry expression (empty = no sells) |

### Trade Flow

On every tick:
1. Trailing stop management runs
2. On new bar: all indicators recomputed, signals stored in registry
3. Running candle updated every tick
4. Trading filters checked (cooldown, max positions, daily limit, consec losses)
5. Strategies evaluated in order (S01 first). **First match wins** — only one trade per tick.
6. Buy expression checked first, then sell expression

### Example Strategies

**DC wick rejection (mean reversion at channel boundaries):**
```yaml
buy:  "dc_M15.lower_wick_rej==TRUE|utbot_M3.bias==BULLISH"
sell: "dc_M15.upper_wick_rej==TRUE|utbot_M3.bias==BEARISH"
```

**RSI(2) extreme oversold bounce with trend confirmation:**
```yaml
buy:  "rsi2_M5.zone==EXTREME_OS|ema200_M15.price_vs==ABOVE|adx_M15.strength in STRONG_TREND,TRENDING|utbot_H1.bias==BULLISH"
sell: ""
```

**Shooting star reversal with higher timeframe confirmation:**
```yaml
buy:  ""
sell: "candle_M5.type==SHOOTING_STAR|utbot_M15.bias==BEARISH"
```

**Trend-following sell with multi-timeframe alignment:**
```yaml
buy:  ""
sell: "utbot_M2.signal==SELL|ema50_M5.price_vs==BELOW|utbot_M5.bullish_since>=2|vwap_M1.price_vs==BELOW"
```

---

## EA Input Parameters

### Global Risk

| Input | Type | Default | Description |
|---|---|---|---|
| `INP_RiskPct` | double | 3.0 | Risk % of equity per trade |
| `INP_GlobalSL` | double | 7.5 | Default SL in dollars (if strategy SL=0) |
| `INP_GlobalRR` | double | 1.0 | Default reward:risk (if strategy RR=0) |

### Trade Management

| Input | Type | Default | Description |
|---|---|---|---|
| `INP_Magic` | int | 300 | Magic number for order identification |
| `INP_MultiPosition` | bool | false | Allow multiple simultaneous positions |
| `INP_MaxPositions` | int | 1 | Max simultaneous positions (if multi enabled) |
| `INP_MaxDailyTrades` | int | 15 | Max trades per day |
| `INP_CooldownSec` | int | 300 | Minimum seconds between trades |
| `INP_ReversalCooldown` | int | 300 | Extra cooldown before reversing direction |
| `INP_MaxConsecLoss` | int | 3 | Pause trading after N consecutive losses (0=off) |
| `INP_ConsecLossPause` | int | 1800 | Pause seconds per consecutive loss |
| `INP_Slippage` | int | 20 | Max slippage in points |

### Trailing Stop

| Input | Type | Default | Description |
|---|---|---|---|
| `INP_BreakevenStart` | double | 0.0 | Move SL to entry after $X profit (0=off) |
| `INP_TrailStart` | double | 0.0 | Start trailing after $X profit (0=off) |
| `INP_TrailStep` | double | 2.0 | Trail distance in dollars |

### Indicator Parameters

| Input | Type | Default | Description |
|---|---|---|---|
| `INP_UTBot_Period` | int | 10 | UT Bot ATR period |
| `INP_UTBot_Mult` | double | 2.0 | UT Bot ATR multiplier |
| `INP_DC_Length` | int | 20 | Donchian Channel lookback period |
| `INP_RoundLevel` | double | 500.0 | Round number interval for proximity signals |
| `INP_LiqLookback` | int | 20 | Liquidity sweep swing point scan window |

### External Control

| Input | Type | Default | Description |
|---|---|---|---|
| `INP_UseControlFile` | bool | false | Read `ea_control.csv` for runtime control |
| `INP_WriteStatusFile` | bool | false | Write `ea_status.csv` with current state |
| `INP_ControlPollSec` | int | 5 | Poll interval for control file (seconds) |
