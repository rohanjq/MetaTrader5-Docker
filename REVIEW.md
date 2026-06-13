# Code Review: MetaTrader5-Docker / MasterTrader EA

**Date:** 2026-06-13
**Reviewer:** Copilot
**Scope:** Full repo — EA source, docs, tools, infra, config

---

## Overall Assessment

Very solid redesign. Moving everything inside MT5 eliminates the entire class of bar-timing/fill-price issues that plagued the Python backtester. The architecture (signal registry → expression engine → trade execution) is clean. Documentation is thorough. A few real issues found.

---

## BUGS

### 1. `OnTrade()` comment matching is fragile — will misattribute trades

**File:** `Metatrader/MQL5/Experts/MasterTrader.mq5` (line ~480)

`StringFind(comment, g_strats[s].name)` is a substring search. Strategy `"dc_mid_hammer_2w_m15"` contains `"hammer_2w_m15"` as a substring, so a trade from S05 (`hammer_2w_m15`) would also match S09 (`dc_mid_hammer_2w_m15`) — but since S05 is checked first (lower index), it would steal the credit. However, if the order changes or new strategies are added, misattribution will happen silently.

**Fix** — match against the full comment format:
```cpp
if(comment == "MT|" + g_strats[s].name
   || StringFind(comment, "MT|" + g_strats[s].name) >= 0)
```
Or safer: extract the strategy name from the comment first, then do exact comparison.

### 2. VWAP stale values persist across sessions

When `ComputeVWAP` returns early (fewer than 2 bars after midnight), it doesn't clear the previous VWAP signals. Yesterday's end-of-day VWAP persists in the registry until the first complete bar of the new session. For strategies like S02/S03/S04/S08 that check `vwap_M1.price_vs`, this means the first minute after midnight uses a stale VWAP from the previous day.

**Fix** — set a default/neutral value before returning early:
```cpp
if(copied < 2) {
   SigSet(pfx + ".price_vs", "");  // will cause conditions to fail (safe)
   SigSet(pfx + ".value", "0");
   return;
}
```

### 3. Candle signals also persist when data isn't available

Same pattern as VWAP: if `ComputeCandleForBar` returns early (`o==0 && h==0 && l==0 && c==0`), the previous candle's signals remain. A hammer from a previous bar could linger in the registry and trigger a strategy on the wrong bar.

---

## SIGNAL COMPUTATION — VERIFIED CORRECT

- **UT Bot**: Trailing stop path-dependent build, direction, bias, signal flash, and bullish_since/bearish_since counting — all correct. The chronological array ordering matches the algorithm.
- **Donchian zones**: Percentile-based zone classification — correct.
- **Donchian wick rejection**: Includes the closed bar in the channel (so a bar making a new period-high trivially passes `h >= upper`). This is consistent with the Python system and standard rolling-window DC. The other strategy conditions (UTBot bias, VWAP, etc.) filter out false positives in practice.
- **EMA**: 5-bar buffer, slope comparison across 3 bars — correct.
- **RSI**: Zone thresholds for RSI(2) vs RSI(14) — correct.
- **ADX**: strength/di_bias with DI±1 dead zone — correct.
- **MACD**: Crossover detection comparing previous vs closed bar, histogram direction — correct.
- **Stochastic**: Standard zones — correct.
- **Bollinger Bands**: Bandwidth squeeze (75% threshold), reenter from below lower band — correct.
- **ATR**: Raw value from native handle — correct.
- **VWAP**: Session-from-midnight, tick volume weighted, excludes running bar — correct (aside from stale signal issue above).
- **Candle patterns**: Priority order (DOJI → MARUBOZU → HAMMER → SHOOTING_STAR → SPINNING_TOP → NORMAL), body_safe prevents div-by-zero — correct.
- **Expression engine**: Word operators parsed before symbol operators, longest-first for symbol operators, `in`/`not_in` with trim — correct.

---

## DESIGN FEEDBACK

### Good decisions

- Signal registry as flat key-value store — simple, debuggable, extensible
- Expression-driven strategies — no recompilation for strategy changes
- File I/O disabled by default for backtest speed
- Breakeven before trailing (one-time event, then trailing takes over)
- Running candle separate from closed candle via prefix parameter
- Per-strategy stats in `OnTrade` with summary on deinit
- Idempotent start.sh with cached downloads

### Design considerations

| Topic | Note |
|-------|------|
| **Running candle cost** | Computed every tick on all sub-daily TFs but no strategy uses `live_*` fields. DESIGN.md acknowledges this. Easy win: scan strategy strings in `OnInit` and set a `g_needLiveCandle` flag. |
| **VWAP granularity varies by TF** | `vwap_M5` computes VWAP from M5 bars (coarser), while `vwap_M1` uses M1 bars. Standard session VWAP should use the finest granularity regardless of TF. All current strategies use `vwap_M1` so it's fine today, but could confuse future users. |
| **VWAP midnight anchor** | Uses server-time midnight. Forex sessions traditionally anchor at 5pm ET (New York close). If the broker's server time differs, the VWAP anchor won't match TradingView/etc. |
| **Signal registry never shrinks** | `SigSet` appends new keys, updates existing. If you ever change the TF set or indicator list, stale keys from previous indicators persist. Not a problem in current usage since indicators are fixed across the lifetime. |
| **Strategy priority coupling** | S01 always wins over S20. If two strategies fire simultaneously, you can't see the lower-priority signal was also valid. Consider logging when a strategy *would* have fired but was preempted (useful for tuning). |

---

## CONFIG / DOCUMENTATION ISSUES

### 1. YAML config vs EA defaults mismatch

The bundled `Metatrader/config.yaml` has `symbol: BTCUSDT` with `sl: 350.0`, `rr: 1.2`, while the EA's hardcoded input defaults are XAUUSD-tuned (`S01_SL=5.0`, `S02_SL=7.5`). DESIGN.md says "Target instrument: XAUUSD". This is confusing — someone running without YAML gets gold-tuned defaults, someone using YAML gets the Bitcoin config.

**Recommendation:** Either make the EA defaults match the YAML (with 0 → fall through to global), or add a comment in the YAML explaining it's tuned for BTCUSDT specifically.

### 2. ea.md `in` operator note is misleading

`docs/ea.md` says `"key in val1,val2" not "key in val1, val2"` — but the EA code trims each element after splitting on comma:
```cpp
StringTrimLeft(p); StringTrimRight(p);
```
So `val1, val2` with spaces DOES work. The docs are overly restrictive.

### 3. DESIGN.md strategy SL/RR don't match config.yaml

DESIGN.md lists S01 with `SL=5.0, RR=1.0` (EA defaults), but config.yaml has `sl: 350.0, rr: 1.2`. The doc should clarify these are the EA fallback defaults, not the recommended values for any specific instrument.

---

## TOOLS REVIEW

### parse_report.py

Well-written. Handles UTF-16LE, space-separated numbers, all three output formats. No issues.

### account_info.py / ticker_info.py

Functional but minimal:
- No argparse, hardcoded `localhost:8001`
- No error handling if rpyc connection fails (just crashes)
- These are fine as quick diagnostic scripts.

### gen_inputs.py

Clean. Uses `yaml.safe_load` (good for security). Strategy buy/sell lines are emitted WITHOUT the `||...||N` optimization suffix, which is correct (strings aren't optimizable). One minor issue: if a strategy's `buy` or `sell` expression contains `||`, it would be misinterpreted by MT5's tester format. No current strategies have this, but it's a theoretical concern.

---

## INFRA / SECURITY

- **rpyc ClassicService on port 8001** is unauthenticated and gives full RCE. Fine for local dev, dangerous if the container is exposed. Consider not exposing 8001 in docker-compose by default (or only bind to 127.0.0.1).
- **`seccomp=unconfined`** is required for Wine but weakens container isolation — expected and documented.
- **start.sh `|| true` pattern** — many error-swallowing for idempotency. This is intentional but could mask real failures (e.g., MetaEditor compile failure → continues silently).

---

## SUMMARY: WHAT TO FIX

| Priority | Issue | Fix |
|----------|-------|-----|
| **High** | OnTrade comment substring matching | Use exact match on `"MT\|" + name` |
| **Medium** | Stale VWAP/candle signals after session reset | Clear signals on early return |
| **Low** | DESIGN.md/config.yaml instrument mismatch | Update docs to clarify |
| **Low** | ea.md says `in` doesn't allow spaces after comma | Fix docs (code does trim) |
| **Optimization** | Running candle every tick unused | Add auto-detect flag |
