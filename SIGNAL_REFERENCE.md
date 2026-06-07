# SignalMaster EA — Signal Reference for Trading System

## Overview

A single MQL5 Expert Advisor (`SignalMaster.mq5`) attached to one chart computes all indicators across all timeframes.
It writes one CSV per indicator+timeframe+symbol to the Common/Files directory, symlinked to `/data/signals/` on the host.

Files are updated every 5 seconds. Format: key-value CSV with `key,value` header row.

---

## File Naming Convention

```
<SYMBOL>_<indicator>_<timeframe>.csv
```

Examples: `BTCUSDT_utbot_M1.csv`, `BTCUSDT_dc_M15.csv`, `BTCUSDT_liqgrab_H1.csv`

---

## All Available Signal Files

### UT Bot ATR Trailing Stop (`utbot`)
```
BTCUSDT_utbot_M1.csv
BTCUSDT_utbot_M3.csv
BTCUSDT_utbot_M10.csv
BTCUSDT_utbot_M15.csv
BTCUSDT_utbot_M45.csv
```
Config per instance: `TF:ATR_Period:ATR_Mult` (default all `10:2.0`)

### Donchian Channels (`dc`)
```
BTCUSDT_dc_M1.csv
BTCUSDT_dc_M3.csv
BTCUSDT_dc_M5.csv
BTCUSDT_dc_M15.csv
BTCUSDT_dc_M45.csv
```
Config per instance: `TF:Length:Offset` (default all `20:0`)

### Liquidity Grab (`liqgrab`)
```
BTCUSDT_liqgrab_M3.csv
BTCUSDT_liqgrab_M5.csv
BTCUSDT_liqgrab_M15.csv
BTCUSDT_liqgrab_H1.csv
BTCUSDT_liqgrab_H4.csv
```
Config per instance: `TF:LookbackRange:BarsN:WickBodyRatio:CandlesBeforeBreakout:MAPeriod` (defaults `50:5:2.0:5:100`)

---

## Standard Header (every file)

```
key                 → description
symbol              → BTCUSDT
indicator           → utbot | dc | liqgrab
timeframe           → M1, M3, M5, M10, M15, M45, H1, H4
timeframe_minutes   → 1, 3, 5, 10, 15, 45, 60, 240
server_time         → 2026.06.07 07:30:30
bid                 → current bid price
ask                 → current ask price
spread              → ask - bid
```

---

## Running vs Closed Bars (every file)

Every file outputs TWO sets of OHLCV data:

- `running_*` = current candle still forming (values WILL change before close)
- `closed_*`  = last completed candle (confirmed, final)

```
running_bar_time    → timestamp of current forming bar
running_open        → open price
running_high        → high so far
running_low         → low so far
running_close       → current close (= latest tick)
running_volume      → tick volume so far

closed_bar_time     → timestamp of last completed bar
closed_open         → open price (final)
closed_high         → high price (final)
closed_low          → low price (final)
closed_close        → close price (final)
closed_volume       → total tick volume (final)
```

**Rule of thumb:**
- Use `closed_*` for confirmed trade signals (candle fully formed)
- Use `running_*` for early detection or monitoring (signal may flip before close)

---

## UT Bot Fields

Computes ATR trailing stop and direction. Detects bias flips (BUY/SELL signals).

```
running_atr              → ATR value on current bar
running_nloss            → ATR * multiplier (the trailing distance)
running_trail_stop       → trailing stop level (current bar)
running_bias             → BULLISH or BEARISH (current direction)
running_signal           → BUY (flipped bull), SELL (flipped bear), or NONE

closed_atr               → ATR value on last closed bar
closed_nloss             → ATR * multiplier
closed_trail_stop        → trailing stop level (confirmed)
closed_bias              → BULLISH or BEARISH (confirmed)
closed_signal            → BUY, SELL, or NONE (confirmed flip on closed candle)

consecutive_bull_bars    → count of consecutive bullish-direction bars
consecutive_bear_bars    → count of consecutive bearish-direction bars

cfg_atr_period           → ATR period used (e.g. 10)
cfg_atr_mult             → ATR multiplier used (e.g. 2.0)
```

**Signal logic:**
- `closed_signal=BUY` → direction flipped from BEARISH to BULLISH on the last closed candle
- `closed_signal=SELL` → direction flipped from BULLISH to BEARISH on the last closed candle
- `closed_signal=NONE` → no direction change, trend continues
- `closed_bias` → current confirmed trend direction

---

## Donchian Channel Fields

Computes upper/lower bands from highest high and lowest low over N bars.
Detects price zone, touches, breakouts, and wick rejections.

```
upper_band               → highest high over lookback period
lower_band               → lowest low over lookback period
mid_band                 → (upper + lower) / 2
channel_width            → upper - lower

running_price_zone       → UPPER | UPPER_MID | MIDDLE | LOWER_MID | LOWER
running_pct_in_channel   → 0-100 (where bid sits within the channel)
running_touched_upper    → TRUE if running bar high >= upper band
running_touched_lower    → TRUE if running bar low <= lower band
running_break_upper      → TRUE if running bar close > upper band
running_break_lower      → TRUE if running bar close < lower band

closed_price_zone        → same zones for closed bar
closed_pct_in_channel    → 0-100
closed_touched_upper     → TRUE/FALSE
closed_touched_lower     → TRUE/FALSE
closed_break_upper       → TRUE/FALSE (confirmed breakout above)
closed_break_lower       → TRUE/FALSE (confirmed breakout below)
closed_upper_wick_rej    → TRUE if wick touched upper but body closed below (bearish rejection)
closed_lower_wick_rej    → TRUE if wick touched lower but body closed above (bullish rejection)

cfg_length               → DC lookback length (e.g. 20)
cfg_offset               → DC offset (e.g. 0)
```

**Price zones** (based on % position in channel):
- UPPER: >= 90%
- UPPER_MID: 70-89%
- MIDDLE: 31-69%
- LOWER_MID: 11-30%
- LOWER: <= 10%

---

## Liquidity Grab Fields

Implements Smart Money Concepts (SMC) liquidity grab detection.
Finds key support/resistance levels, detects wick rejections that sweep past those levels,
then looks for breakout confirmation + moving average trend alignment.

Based on: https://www.mql5.com/en/articles/16518

```
key_high                 → identified resistance level (highest high with rejection confirmation), or "NONE"
key_low                  → identified support level (lowest low with rejection confirmation), or "NONE"
dist_to_key_high         → current high - key_high (negative = below, positive = above)
dist_to_key_low          → current low - key_low (positive = above, negative = below)

rejection_up             → TRUE if a bullish liquidity grab detected (lower wick swept below key_low, body closed above)
rejection_up_bar         → how many bars ago the rejection occurred (-1 if none)
rejection_down           → TRUE if a bearish liquidity grab detected (upper wick swept above key_high, body closed below)
rejection_down_bar       → how many bars ago the rejection occurred (-1 if none)

breakout_up              → TRUE if price broke above a recent key high (bullish breakout after grab)
breakout_down             → TRUE if price broke below a recent key low (bearish breakout after grab)

ma_value                 → SMA value (trend filter)
ma_trend                 → ABOVE (bullish) or BELOW (bearish) — price relative to MA

liq_signal               → composite signal:
                            BUY  = rejection_up + breakout_up + price above MA
                            SELL = rejection_down + breakout_down + price below MA
                            NONE = conditions not met

cfg_lookback             → lookback range for key level search (e.g. 50)
cfg_barsN                → bars for rejection confirmation (e.g. 5)
cfg_wick_ratio           → minimum wick:body ratio for rejection (e.g. 2.0)
cfg_candles_bk           → candles to look back for recent rejections (e.g. 5)
cfg_ma_period            → MA period for trend filter (e.g. 100)
```

**How liquidity grab detection works:**
1. Find key level = highest high (or lowest low) that has price rejection (local peak/trough confirmed by surrounding bars)
2. Look for rejection candle = wick sweeps past the key level but body closes back on the other side, with wick >= `wick_ratio` * body size
3. Look for breakout = after the rejection, price breaks through the opposite key level
4. Filter by trend = price must be on the right side of the MA (above MA for buy, below for sell)
5. All 3 conditions met → composite signal fires

---

## How to Read Any Signal File (Generic Parser)

```python
import csv

def read_signal(filepath):
    """Read a signal CSV and return as dict."""
    signals = {}
    try:
        with open(filepath, 'r') as f:
            reader = csv.reader(f)
            next(reader)  # skip header row
            for row in reader:
                if len(row) >= 2:
                    signals[row[0].strip()] = row[1].strip()
    except (FileNotFoundError, StopIteration):
        pass
    return signals

# Example:
sig = read_signal("/data/signals/BTCUSDT_utbot_M1.csv")
print(sig.get("closed_bias"))     # "BULLISH"
print(sig.get("closed_signal"))   # "BUY" / "SELL" / "NONE"
print(sig.get("indicator"))       # "utbot"
print(sig.get("timeframe"))       # "M1"
```

The `indicator` field in every file tells you which set of fields to expect.
All files share the same standard header + bar fields, so a generic reader works for all.

---

## Example Trade Trigger Ideas

These combine multiple signals across indicators and timeframes:

1. **DC Low + UT Bot Confluence Buy**: DC M15 `closed_price_zone=LOWER` AND UT Bot M1 `closed_signal=BUY` AND UT Bot M45 `consecutive_bull_bars >= 5`

2. **DC Wick Rejection Buy**: DC M15 `closed_lower_wick_rej=TRUE` AND UT Bot M3 `closed_bias=BULLISH`

3. **UT Bot Multi-TF Alignment**: UT Bot M1 `closed_signal=BUY` AND UT Bot M15 `closed_bias=BULLISH` AND UT Bot M45 `closed_bias=BULLISH`

4. **Liquidity Grab + UT Bot**: LiqGrab M15 `liq_signal=BUY` AND UT Bot M1 `closed_bias=BULLISH`

5. **Liquidity Grab + DC Support**: LiqGrab H1 `rejection_up=TRUE` AND DC M15 `closed_price_zone=LOWER_MID` AND UT Bot M3 `closed_signal=BUY`

6. **DC Breakout + Trend Confirmation**: DC M15 `closed_break_upper=TRUE` AND LiqGrab H1 `ma_trend=ABOVE` AND UT Bot M15 `closed_bias=BULLISH`
