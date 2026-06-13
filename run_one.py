#!/usr/bin/env python3
"""Quick strategy runner."""
import yaml, subprocess, sys, time, os, re, json

CONFIG = "data/config/config.yaml"
RF = "data/config/results2.json"

def run_one(idx):
    with open(CONFIG) as f:
        cfg = yaml.safe_load(f)
    
    for i, s in enumerate(cfg["strategies"]):
        s["enabled"] = (i == idx)
    
    with open(CONFIG, "w") as f:
        yaml.dump(cfg, f, default_flow_style=False, sort_keys=False, width=1000)
    
    name = cfg["strategies"][idx]["name"]
    print(f"\n=== S{idx+1}: {name} ===", flush=True)
    
    subprocess.run("podman-compose down 2>/dev/null", shell=True, capture_output=True)
    subprocess.run("rm -f data/reports/backtest_report*", shell=True, capture_output=True)
    subprocess.run("MT5_MODE=tester podman-compose up -d 2>/dev/null", shell=True, capture_output=True)
    
    deadline = time.time() + 300
    while time.time() < deadline:
        r = subprocess.run("podman logs mt5 2>&1 | tail -3", shell=True, capture_output=True, text=True)
        if "Tester run complete" in r.stdout:
            time.sleep(2)
            break
        time.sleep(5)
    else:
        print(f"  TIMEOUT", flush=True)
        return {"name": name, "error": "timeout"}
    
    r = subprocess.run("python3 tools/parse_report.py data/reports/backtest_report.htm --human",
                       shell=True, capture_output=True, text=True)
    out = r.stdout + r.stderr
    
    m = {"name": name}
    try:
        m["profit_factor"] = float(re.search(r"Profit Factor\s+([\d.]+)", out).group(1))
        m["total_trades"] = int(re.search(r"Total Trades\s+(\d+)", out).group(1))
        m["win_rate"] = float(re.search(r"Profit Trades.*\(([\d.]+)%\)", out).group(1))
        m["net_profit"] = float(re.search(r"Total Net Profit\s+([-\d.]+)", out).group(1))
        dd_match = re.search(r"Balance Drawdown Maximal.*\(([\d.]+)%\)", out)
        m["max_dd"] = float(dd_match.group(1)) if dd_match else 0
    except Exception as e:
        m["parse_error"] = str(e)
    
    print(f"  PF={m.get('profit_factor',0):.2f} WR={m.get('win_rate',0):.1f}% T={m.get('total_trades',0)} DD={m.get('max_dd',0):.1f}%", flush=True)
    return m

def main():
    with open(CONFIG) as f:
        cfg = yaml.safe_load(f)
    results = {}
    if os.path.exists(RF):
        with open(RF) as f:
            results = json.load(f)
    start = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    end = int(sys.argv[2]) if len(sys.argv) > 2 else len(cfg["strategies"])
    for i in range(start, end):
        if str(i) in results:
            r = results[str(i)]
            print(f"\nS{i+1} {r['name']} (cached): PF={r.get('profit_factor')} WR={r.get('win_rate')}% T={r.get('total_trades')} DD={r.get('max_dd')}%", flush=True)
            continue
        r = run_one(i)
        results[str(i)] = r
        with open(RF, "w") as f:
            json.dump(results, f, indent=2, default=str)
    print("\n=== SUMMARY ===")
    for i in range(len(cfg["strategies"])):
        r = results.get(str(i), {})
        if r:
            print(f"S{i+1} {r['name']}: PF={r.get('profit_factor','?')} WR={r.get('win_rate','?')}% T={r.get('total_trades','?')} DD={r.get('max_dd','?')}%")

if __name__ == "__main__":
    main()