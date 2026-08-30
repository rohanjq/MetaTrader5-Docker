#!/usr/bin/env python3
"""Batch runner for Worker 10 gold scalping tests."""
import yaml, subprocess, time, re, sys, os, copy

CONFIG = "/root/MetaTrader5-Docker/config-tester.yaml"
REPORT_DIR = "/root/MetaTrader5-Docker/data-tester/reports"
RESULT_FILE = "/root/MetaTrader5-Docker/PROMPTS/worker10_gold_results.md"

def run_strategy(strategy):
    """Run a single strategy backtest and return results."""
    cfg = yaml.safe_load(open(CONFIG))
    for s in cfg["strategies"]:
        s["enabled"] = False
    strategy["enabled"] = True
    cfg["strategies"] = [strategy]
    with open(CONFIG, "w") as f:
        yaml.dump(cfg, f, default_flow_style=False, sort_keys=False, width=1000)
    subprocess.run("cp /root/MetaTrader5-Docker/config-tester.yaml /root/MetaTrader5-Docker/data-tester/config/config.yaml", shell=True, capture_output=True)
    subprocess.run("podman-compose -f docker-compose.tester.yaml down 2>/dev/null", shell=True, capture_output=True)
    subprocess.run("podman rm mt5-tester 2>/dev/null", shell=True, capture_output=True)
    subprocess.run("rm -f /root/MetaTrader5-Docker/data-tester/reports/backtest_report*", shell=True, capture_output=True)
    subprocess.run("podman-compose -f docker-compose.tester.yaml up -d 2>/dev/null", shell=True, capture_output=True)
    deadline = time.time() + 180
    while time.time() < deadline:
        r = subprocess.run("podman logs mt5-tester 2>&1 | tail -1", shell=True, capture_output=True, text=True)
        if "Tester run complete" in r.stdout:
            time.sleep(3)
            break
        time.sleep(5)
    else:
        return {"error": "timeout", "name": strategy["name"]}
    r = subprocess.run("python3 tools/parse_report.py data-tester/reports/backtest_report.htm --human", shell=True, capture_output=True, text=True)
    out = r.stdout + r.stderr
    m = {"name": strategy["name"]}
    try:
        m["profit_factor"] = float(re.search(r"Profit Factor\s+([\d.]+)", out).group(1))
        m["total_trades"] = int(re.search(r"Total Trades\s+(\d+)", out).group(1))
        m["win_rate"] = float(re.search(r"Profit Trades.*\(([\d.]+)%\)", out).group(1))
        m["net_profit"] = float(re.search(r"Total Net Profit\s+([-\d.]+)", out).group(1))
        dd_match = re.search(r"Balance Drawdown Maximal\s+[\d.]+\%\(([\d.]+)%\)", out)
        m["max_dd"] = float(dd_match.group(1)) if dd_match else 0
        m["avg_holding"] = re.search(r"Average position holding time\s+([\d:]+)", out).group(1)
    except Exception as e:
        m["parse_error"] = str(e)
        m["raw"] = out[:300]
    print(f"  {m['name']}: PF={m.get('profit_factor',0):.2f} WR={m.get('win_rate',0):.1f}% T={m.get('total_trades',0)} DD={m.get('max_dd',0):.1f}% PnL={m.get('net_profit',0):+.0f}", flush=True)
    return m

def append_result(name, pf, trades, wr, dd, pnl, hold, cat, verdict):
    with open(RESULT_FILE) as f:
        content = f.read()
    line = f"| {name} | {cat} | {pf:.2f} | {trades} | {wr:.1f}% | {dd:.1f}% | ${pnl:+.0f} | {verdict} | {hold} |\n"
    idx = content.find("## First Pass — Baseline Results")
    if idx >= 0:
        table_end = content.find("---", idx + 50)
        if table_end < 0:
            table_end = content.find("##", idx + 50)
        insert = content.find("|\n", idx)
        if insert >= 0:
            insert = content.find("\n", insert + 1)
            content = content[:insert+1] + line + content[insert+1:]
    with open(RESULT_FILE, "w") as f:
        f.write(content)

# Define all strategies to test
strategies = []

# G1: Round wick snap (relaxed)
strategies.append(dict(name="g1_round_wick_snap", enabled=True, sl=8.0, rr=1.5,
    buy="candle_M1.lower_wick_ratio>=2.0|candle_M1.is_bullish==TRUE|rsi2_M1.zone in EXTREME_OS,OS|round_M1.dist_below<=5.0",
    sell="candle_M1.upper_wick_ratio>=2.0|candle_M1.is_bearish==TRUE|rsi2_M1.zone in EXTREME_OB,OB|round_M1.dist_above<=5.0"))

# G2: UT Bot exhaustion (simpler)
strategies.append(dict(name="g2_utbot_exhaust", enabled=True, sl=8.0, rr=1.5,
    buy="utbot_M3.bearish_since>=5|candle_M3.is_bullish==TRUE",
    sell="utbot_M3.bullish_since>=5|candle_M3.is_bearish==TRUE"))

# G3: VWAP mean reversion
strategies.append(dict(name="g3_vwap_mean_revert", enabled=True, sl=8.0, rr=1.5,
    buy="vwap_M5.price_vs==BELOW|adx_M5.strength in WEAK_TREND,RANGING|candle_M1.is_bullish==TRUE",
    sell="vwap_M5.price_vs==ABOVE|adx_M5.strength in WEAK_TREND,RANGING|candle_M1.is_bearish==TRUE"))

# G4: RSI2 panic snap both dirs
strategies.append(dict(name="g4_rsi2_panic", enabled=True, sl=8.0, rr=1.5,
    buy="rsi2_M1.value<15|rsi2_M1.value>0|candle_M1.is_bullish==TRUE",
    sell="rsi2_M1.value>85|rsi2_M1.value<100|candle_M1.is_bearish==TRUE"))

# G4s: RSI2 short-only (already confirmed PF=1.11 at RR=2.0)
strategies.append(dict(name="g4s_rsi2_short", enabled=True, sl=8.0, rr=2.0,
    buy="",
    sell="rsi2_M1.value>85|rsi2_M1.value<100|candle_M1.is_bearish==TRUE"))

# G4b: RSI2 buy-only at RR=1.5
strategies.append(dict(name="g4b_rsi2_buy", enabled=True, sl=8.0, rr=1.5,
    buy="rsi2_M1.value<15|rsi2_M1.value>0|candle_M1.is_bullish==TRUE",
    sell=""))

# G5: EMA cross momentum
strategies.append(dict(name="g5_ema_cross", enabled=True, sl=8.0, rr=1.5,
    buy="ema9_M2.slope==RISING|ema21_M2.slope==RISING|ema200_M5.price_vs==ABOVE|adx_M5.strength in TRENDING,STRONG_TREND",
    sell="ema9_M2.slope==FALLING|ema21_M2.slope==FALLING|ema200_M5.price_vs==BELOW|adx_M5.strength in TRENDING,STRONG_TREND"))

# G6: MACD hist acceleration
strategies.append(dict(name="g6_macd_hist", enabled=True, sl=8.0, rr=1.5,
    buy="macd_M3.hist_dir==RISING|ema200_M5.price_vs==ABOVE|candle_M1.is_bullish==TRUE|utbot_M5.bias==BULLISH",
    sell="macd_M3.hist_dir==FALLING|ema200_M5.price_vs==BELOW|candle_M1.is_bearish==TRUE|utbot_M5.bias==BEARISH"))

# G7: Simple candle + ADX trend (simplified from stoch)
strategies.append(dict(name="g7_candle_adx", enabled=True, sl=8.0, rr=1.5,
    buy="candle_M1.is_bullish==TRUE|adx_M5.strength in TRENDING,STRONG_TREND|utbot_M5.bias==BULLISH",
    sell="candle_M1.is_bearish==TRUE|adx_M5.strength in TRENDING,STRONG_TREND|utbot_M5.bias==BEARISH"))

# G8: BB squeeze break (simplified)
strategies.append(dict(name="g8_bb_break", enabled=True, sl=8.0, rr=1.5,
    buy="bb_M3.reenter_above==TRUE|candle_M3.is_bullish==TRUE",
    sell="bb_M3.reenter_below==TRUE|candle_M3.is_bearish==TRUE"))

# G11: UTBot signal
strategies.append(dict(name="g11_utbot_signal", enabled=True, sl=8.0, rr=1.5,
    buy="utbot_M3.signal==BUY|candle_M1.is_bullish==TRUE",
    sell="utbot_M3.signal==SELL|candle_M1.is_bearish==TRUE"))

# G12: Round bounce (simplified)
strategies.append(dict(name="g12_round_bounce", enabled=True, sl=8.0, rr=1.5,
    buy="round_M5.dist_below<=5.0|candle_M1.is_bullish==TRUE",
    sell="round_M5.dist_above<=5.0|candle_M1.is_bearish==TRUE"))

if __name__ == "__main__":
    start_idx = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    end_idx = int(sys.argv[2]) if len(sys.argv) > 2 else len(strategies)
    results = []
    for i in range(start_idx, min(end_idx, len(strategies))):
        print(f"\n=== [{i+1}/{len(strategies)}] {strategies[i]['name']} ===", flush=True)
        r = run_strategy(strategies[i])
        results.append(r)
        if "error" not in r:
            append_result(r["name"], r.get("profit_factor",0), r.get("total_trades",0),
                         r.get("win_rate",0), r.get("max_dd",0), r.get("net_profit",0),
                         r.get("avg_holding","?"), strategies[i].get("name","?"),
                         "PASS" if r.get("profit_factor",0) > 1.15 and r.get("total_trades",0) > 30 and r.get("max_dd",0) < 35 else "FAIL")
        subprocess.run(["sleep", "2"])