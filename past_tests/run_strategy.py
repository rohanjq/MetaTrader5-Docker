#!/usr/bin/env python3
"""Run backtests for one strategy at a time, log results."""
import sys, os, subprocess, time, json, yaml

CONFIG = "data/config/config.yaml"
RESULTS_FILE = "data/config/strategy_results.json"

def run_backtest(strategy_idx):
    """Run backtest with only the given strategy enabled."""
    with open(CONFIG) as f:
        config = yaml.safe_load(f)
    
    # Disable all, enable only target
    for i, s in enumerate(config["strategies"]):
        s["enabled"] = (i == strategy_idx)
    
    with open(CONFIG, "w") as f:
        yaml.dump(config, f, default_flow_style=False, sort_keys=False)
    
    name = config["strategies"][strategy_idx]["name"]
    print(f"\n{'='*60}")
    print(f"Running strategy {strategy_idx+1}: {name}")
    print(f"{'='*60}")
    
    subprocess.run(["podman-compose", "down"], capture_output=True)
    subprocess.run(["rm", "-f"] + [f"data/reports/backtest_report{h}" for h in ["", "-hst.png", "-holding.png", "-mfemae.png", ".png", ".htm"]],
                   capture_output=True)
    
    result = subprocess.run(
        ["MT5_MODE=tester", "podman-compose", "up", "--build", "-d"],
        capture_output=True, text=True, shell=True
    )
    
    # Wait for completion
    timeout = 300
    start = time.time()
    while time.time() - start < timeout:
        r = subprocess.run(["podman", "logs", "mt5"], capture_output=True, text=True)
        if "Tester run complete" in r.stdout or "Tester run complete" in r.stderr:
            time.sleep(3)
            break
        time.sleep(5)
    else:
        print("TIMEOUT - backtest may have failed")
    
    # Parse results
    result = subprocess.run(
        ["python3", "tools/parse_report.py", "data/reports/backtest_report.htm", "--human", "--all"],
        capture_output=True, text=True
    )
    
    # Extract key metrics from human output
    out = result.stdout + result.stderr
    metrics = {}
    for line in out.split("\n"):
        line = line.strip()
        if "Total Net Profit" in line:
            metrics["net_profit"] = float(line.split()[-1])
        elif line.startswith("Profit Factor"):
            metrics["profit_factor"] = float(line.split()[-1])
        elif line.startswith("Total Trades"):
            metrics["total_trades"] = int(line.split()[-1])
        elif "Profit Trades (%" in line:
            parts = line.split("(")
            metrics["win_rate"] = float(parts[-1].rstrip("%)"))
        elif "Balance Drawdown Maximal" in line:
            parts = line.split("(")
            dd = parts[-1].rstrip("%)")
            if dd:
                metrics["max_dd"] = float(dd)
        elif "Maximum consecutive losses" in line:
            parts = line.split("(")
            metrics["max_consec_loss"] = int(parts[-1].split(")")[0])
    
    print(f"\nResults for {name}:")
    print(f"  PF={metrics.get('profit_factor','?')}  WR={metrics.get('win_rate','?')}%  Trades={metrics.get('total_trades','?')}  DD={metrics.get('max_dd','?')}%")
    
    # Full output for reference
    print("\nFull report:")
    print(out)
    
    return {"name": name, **metrics, "raw_output": out}

def main():
    with open(CONFIG) as f:
        config = yaml.safe_load(f)
    
    strategies = config["strategies"]
    
    # Load existing results
    results = {}
    if os.path.exists(RESULTS_FILE):
        with open(RESULTS_FILE) as f:
            results = json.load(f)
    
    if len(sys.argv) > 1:
        idx = int(sys.argv[1]) - 1
        r = run_backtest(idx)
        results[str(idx)] = r
        with open(RESULTS_FILE, "w") as f:
            json.dump(results, f, indent=2)
        return
    
    # Run all unrun
    for i in range(len(strategies)):
        if str(i) in results:
            print(f"Skipping S{i+1}: already tested")
            continue
        r = run_backtest(i)
        results[str(i)] = r
        with open(RESULTS_FILE, "w") as f:
            json.dump(results, f, indent=2)
    
    print("\n\n======= SUMMARY =======")
    for i in range(len(strategies)):
        r = results.get(str(i), {})
        print(f"S{i+1} {r.get('name','?')}: PF={r.get('profit_factor','?')} WR={r.get('win_rate','?')}% T={r.get('total_trades','?')} DD={r.get('max_dd','?')}%")

if __name__ == "__main__":
    main()