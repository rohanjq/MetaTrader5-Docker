# Strategy Development Results

## Configuration
- **Symbol**: BTCUSDT (M1)
- **Initial Deposit**: $10,000
- **Leverage**: 1:100
- **Risk per trade**: 5%
- **RR ratio**: 1.5 (final)
- **Mode**: Long-only buy signals, all short entries disabled via `sell=""`

## Test Periods
- **Solo tests**: 2026.06.08 – 2026.06.13 (5 days)
- **Combined test**: 2026.04.13 – 2026.06.13 (2 months)

---

## Strategy Details

All strategies use the same core formula: UTBot H1 bias BULLISH + VWAP M5 price below + EMA200 M15 price above + ADX M15 trending. The differentiating signal is the **entry trigger**.

### S1: RSI2 + ADX (best solo performer)
- **Signal**: `rsi2_M5.zone in OS,EXTREME_OS` confirms oversold
- **5-day solo**: PF 1.84, Win 68.42%, Long Win 75%, 19 trades, +3221
- **SL/RR**: 400:400 (RR 1.0)
- **2-month combined**: PF 0.82, 98 trades, -1012 (dropped due to poor scaling)

### S2: RSI14 + ADX
- **Signal**: `rsi14_M15.zone in OS,NEUTRAL` for wider oversold detection
- **5-day solo**: PF 1.55, Win 58.82%, Long Win 66.67%, 17 trades, +1969
- **SL/RR**: 500:500 (RR 1.0)
- **2-month combined**: PF 0.38, 90 trades, -7333 (dropped)

### S3: Stochastic + RSI Combo (best combined performer) ★
- **Signal**: `stoch_M15.zone in OS,NEUTRAL` stochastic oversold
- **5-day solo**: PF 1.34, Win 55.56%, Long Win 63.64%, 18 trades
- **SL/RR**: 500:750 (RR 1.5)
- **2-month combined (RR 1.5)**: 120 trades, +8643, PF 1.22

### S4: Bollinger Band Reenter + VWAP (consistent performer) ★
- **Signal**: `bb_M15.reenter_below==TRUE` price reenters lower BB
- **5-day solo**: PF 17.81, Win 75%, 4 trades, +1486
- **SL/RR**: 500:750 (RR 1.5)
- **2-month combined (RR 1.5)**: 21 trades, +2080, PF 1.48

### S5: Donchian Wick + ADX (dropped)
- **Signal**: `dc_M15.lower_wick_rej==TRUE` lower wick rejection
- **5-day solo**: 1 trade, -500 (insufficient signals)
- Dropped due to very low trade frequency

---

## Final Combined Result (S3 + S4, RR = 1.5)

| Metric | Value |
|---|---|
| **Total Net Profit** | **+$10,723** |
| **Profit Factor** | **1.22** |
| **Total Trades** | 141 |
| **Win Rate** | 45.39% |
| **Max Drawdown** | 35.45% |
| **Sharpe Ratio** | 2.87 |
| **Recovery Factor** | 1.94 |
| **Avg Trade Duration** | 5h 19m |

### Per-Strategy Breakdown

| Strategy | Trades | Wins | Win% | PnL |
|---|---|---|---|---|
| S3 (stoch_rsi_combo) | 120 | 54 | 45% | +8643 |
| S4 (bb_reenter_vwap) | 21 | 10 | 48% | +2080 |

---

## Key Insights

1. **RR 1.5 is critical** — Going from RR 1.0 to 1.5 turned S3 from -2137 to +8643 over 2 months. The wider TP absorbs the <50% win rate.

2. **S3 (stochastic) + S4 (BB reenter) complementary** — S3 provides high frequency (120 trades), S4 provides high-quality filters (21 trades with better PF). Together they produce 141 trades over 2 months.

3. **Strategy-specific SL/RR works** — Using per-strategy SL (400-500 points) matches BTC volatility. RR 1.5 means TP = 600-750 points.

4. **RSI2-based strategies (S1, S2) don't scale** — They work on the 5-day window but degrade over 2 months because they overtrade in ranging markets.

5. **DC wick and candle patterns insufficient** — In the 5-day sample, these generated too few signals (<5 trades) with poor win rates. Need longer lookback.

---

## Files Modified

- `Metatrader/gen_inputs.py:72-76` — Added `UseLocal=1`, `UseRemote=0`, `UseCloud=0` lines
- `Metatrader/tester.ini:18-20` — Same additions to static template
- `Metatrader/start.sh:303-314` — Changed config.yaml sync from copy-once to copy-if-newer

## Active Config (config.yaml)

```yaml
strategies:
  - name: s3_stoch_rsi_combo
    enabled: true
    sl: 500.0
    rr: 1.5
    buy: "stoch_M15.zone in OS,NEUTRAL|utbot_H1.bias==BULLISH|vwap_M5.price_vs==BELOW|ema200_M15.price_vs==ABOVE|adx_M15.strength in STRONG_TREND,TRENDING"
    sell: ""
  - name: s4_bb_reenter_vwap
    enabled: true
    sl: 500.0
    rr: 1.5
    buy: "bb_M15.reenter_below==TRUE|utbot_H1.bias==BULLISH|vwap_M5.price_vs==BELOW|ema200_M15.price_vs==ABOVE"
    sell: ""
```