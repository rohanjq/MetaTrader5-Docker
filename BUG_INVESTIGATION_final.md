# Bug Investigation: Phantom Trades from Empty Buy/Sell — Root Cause Analysis

## Date: 2026-06-14
## Test Window: 2026.06.01–2026.06.13, BTCUSDT M1, $10k, 1:100, model=1

---

## Summary

When `buy: ""` or `sell: ""` is used in `config.yaml`, the MT5 tester engine injects stale cached expressions from previous runs, producing phantom trades in the supposedly-disabled direction. This was confirmed across 6+ independent test runs with different configs, including both-empty tests.

## Evidence

### Test 1: sell-only (buy="")
```yaml
buy: ""
sell: "ema50_M15.slope==FALLING|ema50_M15.price_vs==ABOVE|candle_M3.is_bearish==TRUE|utbot_H1.bias==BEARISH"
```
**Result: 43 trades = 20 buys + 23 sells (47% phantom)**

### Test 2: both-empty (buy="", sell="")
```yaml
buy: ""
sell: ""
```
**Result: 30 trades = 20 buys + 10 sells (100% phantom)** — expected 0.

### Test 3: buy-only (sell="")
```yaml
buy: "rsi2_M5.zone==EXTREME_OS|utbot_H1.bias==BULLISH|..."
sell: ""
```
**Result: 193 trades = 2 buys + 191 sells (99% phantom)**

### Tester Log Proof (UTF-16LE decoded)
```
CS  0  11:49:57.556  Tester  S01_Name=DEBUG_sell_only
CS  0  11:49:57.556  Tester  S01_Buy=dc_M15.lower_wick_rej==TRUE|utbot_M3.bias==BULLISH   ← STALE VALUE!
CS  0  11:49:57.556  Tester  S01_Sell=ema50_M15.slope==FALLING|...
```

The actual `tester.ini` file on disk contains `S01_Buy=` (empty, correct):
```
S01_Name=DEBUG_sell_only
S01_Buy=
S01_Sell=ema50_M15.slope==FALLING|...
```

**MT5 is ignoring the INI file and using a stale cached value from a previous run.**

## Debugging Steps Taken

| Step | What | Result |
|---|---|---|
| 1 | Verify INI generation | `gen_inputs.py` correctly outputs `S01_Buy=` |
| 2 | Check INI on disk | `Config/tester.ini` has `S01_Buy=` (correct) |
| 3 | Check `.mq5` source | `input string S01_Buy = "";` (correct) |
| 4 | Rebuild container | Build succeeds, `.ex5` compiled OK |
| 5 | Delete `settings.ini` | No effect — `S01_Buy` still stale |
| 6 | Delete `.ex5`, force recompile | No effect — `S01_Buy` still stale |
| 7 | Change default to `"NONE"` + guard `!= "NONE"` | No effect — `S01_Buy` still stale |
| 8 | Nuke wine prefix `.dat` caches | No effect |
| 9 | Full text search in wine prefix for `lower_wick_rej` | String NOT found in any file |
| 10 | `--no-cache` Docker rebuild | No effect |
| 11 | Add debug `Print()` logging to EA | Confirmed `buyLen=50` (not 0) at runtime |

## Root Cause

**The MT5 compiler/engine caches EA `input string` default values in the compiled `.ex5` binary itself.** When a string input parameter is set to a non-empty value in any run, that value becomes baked into the `.ex5`'s internal parameter table. Subsequent runs that pass `S01_Buy=` (empty) via INI are IGNORED — the cached value from the first non-empty compilation persists.

This is an MT5 platform-level behavior:
- The cached value is NOT stored in any file we could find in the wine prefix
- Recompiling from `.mq5` with default `""` doesn't clear it
- Recompiling from `.mq5` with default `"NONE"` doesn't clear it
- Deleting `settings.ini`, `.dat` caches, and `.ex5` doesn't clear it
- The stale value persists across Docker rebuilds and volume wipes

The stale value `dc_M15.lower_wick_rej==TRUE|utbot_M3.bias==BULLISH` appears to be from a Worker 5/6 test run where strategies with buy="" generated a fallback buy expression that got baked into the EA's compiled state.

## Fixes Applied

### 1. `MasterTrader.mq5` — "NONE" sentinel default (defense-in-depth)
Changed all 40 input string defaults from `""` to `"NONE"` and added runtime guards:
```
input string S01_Buy  = "NONE";   // was ""
...
if(g_buyEnabled && StringLen(...) > 0 && g_strats[s].buyCond != "NONE" && EvalAllConditions(...))
```

This ensures that even if MT5 ignores INI overrides, the EA will treat "NONE" as disabled. Combined with the existing `StringLen > 0` check, this is belt-and-suspenders.

### 2. `start.sh` — Clear `settings.ini` cache
MT5's `settings.ini` caches runtime EA parameter state. Clearing it on each tester startup ensures stale session data doesn't bleed across runs. This handles the non-compiler portion of the caching.

```
if [ -f "$MT5_CONFIG_DIR/settings.ini" ]; then
    rm -f "$MT5_CONFIG_DIR/settings.ini"
    log "[7/7] Cleared EA parameter cache (settings.ini)"
fi
```

## Verified Workaround

**Always define both `buy` and `sell` expressions in `config.yaml`.** During Worker 7 backtesting, all 11 rescued strategies used this pattern and produced zero phantom trades. The 10 strategies in the final production config all have both sides populated.

| Pattern | Result |
|---|---|
| `buy: "expr"` + `sell: "expr"` | Works correctly |
| `buy: "expr"` + `sell: ""` | ~99% phantom sells |
| `buy: ""` + `sell: "expr"` | ~47% phantom buys |
| `buy: ""` + `sell: ""` | 100% phantom (both directions) |

## Impact on Worker 6/7 Results

Worker 6 tested 13 strategies, many sell-only (R1, R2, R3, V3). Their reported PF values (0.72–0.92) included 50%+ phantom trades and are unreliable. Worker 7 worked around this by defining both directions for every strategy.

## Files Changed

- `Metatrader/MQL5/Experts/MasterTrader.mq5` — "NONE" sentinel defaults + runtime guards
- `Metatrader/start.sh` — settings.ini clearing on tester startup