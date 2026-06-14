#!/usr/bin/env python3
"""
Worker 6 — Strategy Parameter Optimization
Single backtest runner + parser. Each call runs one test.
"""
import json, os, re, subprocess, sys, time, yaml
from pathlib import Path

PROJECT_DIR = Path("/root/MetaTrader5-Docker")
CONFIG_YAML = PROJECT_DIR / "data/config/config.yaml"
REPORT_DIR = PROJECT_DIR / "data/reports"
RESULTS_JSON = PROJECT_DIR / "data/config/worker6_results.json"

BASE_CFG = {
    "backtest": {"symbol":"BTCUSDT","period":"M1","model":1,
                  "from":"2026.01.13","to":"2026.06.13","deposit":10000,"leverage":"1:100"},
    "global": {"risk_pct":3.0,"sl":0,"rr":0,"magic":300,"multi_position":True,
               "max_positions":3,"max_daily_trades":50,"cooldown_sec":900,
               "reversal_cooldown":0,"max_consec_loss":0,"consec_loss_pause":0,"slippage":20},
    "trailing": {"breakeven_start":0.0,"trail_start":0.0,"trail_step":2.0},
    "indicators": {"utbot_period":10,"utbot_mult":2.0,"dc_length":20,"round_level":500.0,"liq_lookback":20},
    "control": {"use_control_file":False,"write_status_file":False,"control_poll_sec":5},
}

S = {
    "L1": {"name":"L1_sweep_stoch","fam":"sweep",
        "buy":"liq_M15.lower_swept==TRUE|stoch_M15.zone==OS|candle_M3.is_bullish==TRUE|ema200_M15.price_vs==ABOVE",
        "sell":"liq_M15.upper_swept==TRUE|stoch_M15.zone==OB|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW"},
    "L2": {"name":"L2_sweep_stoch_est","fam":"sweep",
        "buy":"liq_M15.lower_swept==TRUE|stoch_M15.zone==OS|candle_M3.is_bullish==TRUE|utbot_H1.bias==BULLISH|utbot_H1.bullish_since>=5|ema200_M15.price_vs==ABOVE",
        "sell":"liq_M15.upper_swept==TRUE|stoch_M15.zone==OB|candle_M3.is_bearish==TRUE|utbot_H1.bias==BEARISH|utbot_H1.bearish_since>=5|ema200_M15.price_vs==BELOW"},
    "L3": {"name":"L3_triple_rejection","fam":"sweep",
        "buy":"liq_M15.lower_swept==TRUE|bb_M15.reenter_below==TRUE|candle_M3.is_bullish==TRUE|utbot_H1.bias==BULLISH",
        "sell":"liq_M15.upper_swept==TRUE|bb_M15.reenter_above==TRUE|candle_M3.is_bearish==TRUE|utbot_H1.bias==BEARISH"},
    "T1": {"name":"T1_vwap_trend","fam":"trend",
        "buy":"vwap_M5.price_vs==BELOW|utbot_H1.bias==BULLISH|candle_M3.is_bullish==TRUE|ema200_M15.price_vs==ABOVE",
        "sell":"vwap_M5.price_vs==ABOVE|utbot_H1.bias==BEARISH|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW"},
    "T2": {"name":"T2_stoch_combo_wide","fam":"trend",
        "buy":"stoch_M15.zone in OS,NEUTRAL|utbot_H1.bias==BULLISH|vwap_M5.price_vs==BELOW|ema200_M15.price_vs==ABOVE|adx_M15.strength in STRONG_TREND,TRENDING|candle_M3.is_bullish==TRUE",
        "sell":"stoch_M15.zone in OB,NEUTRAL|utbot_H1.bias==BEARISH|vwap_M5.price_vs==ABOVE|ema200_M15.price_vs==BELOW|adx_M15.strength in STRONG_TREND,TRENDING|candle_M3.is_bearish==TRUE"},
    "T3": {"name":"T3_macd_cross_trend","fam":"trend",
        "buy":"macd_M15.cross==CROSS_UP|utbot_H1.bias==BULLISH|candle_M3.is_bullish==TRUE|ema200_M15.price_vs==ABOVE|adx_M15.strength in STRONG_TREND,TRENDING",
        "sell":"macd_M15.cross==CROSS_DOWN|utbot_H1.bias==BEARISH|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW|adx_M15.strength in STRONG_TREND,TRENDING"},
    "R1": {"name":"R1_failed_bb_sell","fam":"reversal",
        "buy":"",
        "sell":"bb_M15.reenter_above==TRUE|utbot_H1.bias==BEARISH|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW|adx_M15.strength in STRONG_TREND,TRENDING"},
    "R2": {"name":"R2_exhausted_sell","fam":"reversal",
        "buy":"",
        "sell":"utbot_M15.bullish_since>=8|candle_M5.type==SHOOTING_STAR|dc_M15.zone in UPPER,UPPER_MID|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW"},
    "R3": {"name":"R3_ema_slope_sell","fam":"reversal",
        "buy":"",
        "sell":"ema50_M15.slope==FALLING|ema50_M15.price_vs==ABOVE|candle_M3.is_bearish==TRUE|utbot_H1.bias==BEARISH"},
    "P1": {"name":"P1_dc_lowzone_adx","fam":"pullback",
        "buy":"dc_M15.zone in LOWER,LOWER_MID|utbot_H1.bias==BULLISH|candle_M3.is_bullish==TRUE|ema200_M15.price_vs==ABOVE|adx_M15.strength in STRONG_TREND,TRENDING",
        "sell":"dc_M15.zone in UPPER,UPPER_MID|utbot_H1.bias==BEARISH|candle_M3.is_bearish==TRUE|ema200_M15.price_vs==BELOW|adx_M15.strength in STRONG_TREND,TRENDING"},
    "V1": {"name":"V1_stoch_os_tight","fam":"validation",
        "buy":"stoch_M15.zone==OS|utbot_H1.bias==BULLISH|vwap_M5.price_vs==BELOW|ema200_M15.price_vs==ABOVE|adx_M15.strength in STRONG_TREND,TRENDING|candle_M3.is_bullish==TRUE",
        "sell":"stoch_M15.zone==OB|utbot_H1.bias==BEARISH|vwap_M5.price_vs==ABOVE|ema200_M15.price_vs==BELOW|adx_M15.strength in STRONG_TREND,TRENDING|candle_M3.is_bearish==TRUE"},
    "V2": {"name":"V2_rsi2_extreme_buy","fam":"validation",
        "buy":"rsi2_M5.zone==EXTREME_OS|utbot_H1.bias==BULLISH|vwap_M5.price_vs==BELOW|ema200_M15.price_vs==ABOVE|candle_M3.is_bullish==TRUE",
        "sell":""},
    "V3": {"name":"V3_stoch_wide_sell","fam":"validation",
        "buy":"",
        "sell":"stoch_M15.zone in OB,NEUTRAL|utbot_H1.bias==BEARISH|vwap_M5.price_vs==ABOVE|ema200_M15.price_vs==BELOW|adx_M15.strength in STRONG_TREND,TRENDING|candle_M3.is_bearish==TRUE"},
}

def grid(fam):
    if fam == "sweep":    return [(sl,rr) for sl in [350,400] for rr in [1.5,2.0,2.5]]
    if fam == "reversal": return [(sl,rr) for sl in [300,350] for rr in [1.5,2.0,2.5]]
    if fam == "trend":    return [(sl,rr) for sl in [250,300,350] for rr in [1.0,1.25,1.5]]
    if fam == "pullback": return [(sl,rr) for sl in [350,400] for rr in [1.5,2.0,2.5]]
    return [(sl,rr) for sl in [300,350] for rr in [1.5,2.0]]

TRAILS = [
    ("trail_350_75", 0, 350, 75),
    ("trail_500_100", 0, 500, 100),
    ("be200_tr350_75", 200, 350, 75),
    ("trail_250_50", 0, 250, 50),
]

def load_r():
    if RESULTS_JSON.exists():
        with open(RESULTS_JSON) as f: return json.load(f)
    return {}

def save_r(r):
    RESULTS_JSON.parent.mkdir(parents=True, exist_ok=True)
    with open(RESULTS_JSON,"w") as f: json.dump(r,f,indent=2)

def write_yaml(strat, sl, rr, be, ts, tstep):
    cfg = {
        "backtest": dict(BASE_CFG["backtest"]),
        "global": dict(BASE_CFG["global"]),
        "trailing": {"breakeven_start":float(be),"trail_start":float(ts),"trail_step":float(tstep)},
        "indicators": dict(BASE_CFG["indicators"]),
        "control": dict(BASE_CFG["control"]),
        "strategies": [{"name":strat["name"],"enabled":True,"sl":float(sl),"rr":float(rr),
                        "buy":strat["buy"],"sell":strat["sell"]}],
    }
    with open(CONFIG_YAML,"w") as f:
        yaml.dump(cfg,f,default_flow_style=False,sort_keys=False)

def run_bt():
    import shlex
    # Stop
    subprocess.run(["podman","stop","-t","5","mt5"], capture_output=True, timeout=15)
    subprocess.run(["podman","rm","-f","mt5"], capture_output=True, timeout=10)
    # Clean reports
    for f in REPORT_DIR.glob("backtest_report*"):
        try: f.unlink()
        except: pass
    # Start
    env = dict(os.environ)
    env["MT5_MODE"] = "tester"
    subprocess.run(["podman-compose","up","-d"], cwd=PROJECT_DIR,
                   capture_output=True, env=env, timeout=30)
    # Wait for report file to appear and be non-empty
    report_htm = REPORT_DIR / "backtest_report.htm"
    for i in range(48):
        time.sleep(5)
        if report_htm.exists() and report_htm.stat().st_size > 1000:
            return True
    return False

def parse():
    f = REPORT_DIR / "backtest_report.htm"
    if not f.exists():
        return None
    r = subprocess.run(["python3", str(PROJECT_DIR/"tools/parse_report.py"),
                        str(f), "--json", "--all"],
                       capture_output=True, text=True, timeout=30)
    if r.returncode != 0:
        return None
    try: return json.loads(r.stdout)
    except: return None

def num(v):
    if isinstance(v,(int,float)): return float(v)
    if not isinstance(v,str): return 0.0
    m = re.search(r'\(([\d.]+)%\)',str(v))
    if m: return float(m.group(1))
    m = re.match(r'^([\d.-]+)',str(v).strip())
    if m: return float(m.group(1))
    return 0.0

def run_one(sid, sl, rr, be, ts, tstep, lbl):
    key = f"{sid}_sl{sl}_rr{rr}_{lbl}"
    r = load_r()
    if key in r:
        e = r[key]
        print(f"  [SKIP] {key} PF={e['pf']:.2f} T={e['trades']} PnL={e['pnl']:.0f}")
        return e

    print(f"  [RUN]  {key}", end=" ", flush=True)
    write_yaml(S[sid], sl, rr, be, ts, tstep)
    if not run_bt():
        print("TIMEOUT")
        return None
    d = parse()
    if not d or "summary" not in d:
        print("NODATA")
        return None
    s = d["summary"]
    e = {
        "sid":sid,"name":S[sid]["name"],"sl":sl,"rr":rr,"trail":lbl,
        "be":be,"ts":ts,"tstep":tstep,
        "pf":num(s.get("Profit Factor",0)),
        "wr":num(s.get("Profit Trades (% of total)",0)),
        "trades":int(num(s.get("Total Trades",0))),
        "maxdd":num(s.get("Balance Drawdown Relative",s.get("Balance Drawdown Maximal",0))),
        "pnl":num(s.get("Total Net Profit",0)),
    }
    r[key] = e
    save_r(r)
    print(f" PF={e['pf']:.2f} WR={e['wr']:.0f}% T={e['trades']} DD={e['maxdd']:.1f}% PnL=${e['pnl']:.0f}")
    return e

def run_strat(sid):
    st = S[sid]
    print(f"\n{'='*60}")
    print(f"{sid} {st['name']} [{st['fam']}]")
    print(f"{'='*60}")

    # Phase 1: SL/RR grid no trailing
    entries = []
    for sl,rr in grid(st["fam"]):
        e = run_one(sid, sl, rr, 0, 0, 2, "no_trail")
        if e: entries.append(e)

    if not entries:
        print(f"  SKIP {sid}: no results")
        return None

    entries.sort(key=lambda x: (x["pf"], x["trades"]), reverse=True)
    best = entries[0]
    print(f"  PH1 BEST: SL={best['sl']} RR={best['rr']} PF={best['pf']:.2f} T={best['trades']}")

    # Phase 2: Trail
    for lbl,be,ts,tstep in TRAILS:
        run_one(sid, best["sl"], best["rr"], be, ts, tstep, lbl)

    # Re-read best
    r = load_r()
    se = sorted([v for k,v in r.items() if v.get("sid")==sid], key=lambda x:(x["pf"],x["trades"]), reverse=True)
    fb = se[0]
    print(f"  FINAL: SL={fb['sl']} RR={fb['rr']} {fb['trail']} PF={fb['pf']:.2f} T={fb['trades']}")
    return fb

def main():
    ids = list(S.keys())
    if len(sys.argv) > 1:
        ids = [x for x in sys.argv[1:] if x in S]

    best = {}
    for sid in ids:
        b = run_strat(sid)
        if b: best[sid] = b

    print("\n" + "="*90)
    print(f"{'ID':<5} {'Name':<22} {'SL':<5} {'RR':<5} {'Trail':<18} {'PF':<7} {'T':<5} {'WR':<5} {'DD':<7} {'PnL':<10}")
    print("-"*90)
    for sid in sorted(best.keys()):
        b = best[sid]
        print(f"{sid:<5} {b['name']:<22} {b['sl']:<5} {b['rr']:<5} {b['trail']:<18} {b['pf']:<7.2f} {b['trades']:<5} {b['wr']:<5.0f}% {b['maxdd']:<7.1f}% ${b['pnl']:<10.0f}")

if __name__ == "__main__":
    main()