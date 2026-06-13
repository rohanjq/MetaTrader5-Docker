#!/usr/bin/env python3
"""Run a backtest with specified strategy configuration."""
import subprocess, sys, os, yaml, shutil, time

CONFIG_PATH = os.path.join(os.path.dirname(__file__), "..", "data", "config", "config.yaml")
REPORTS_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "reports")
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "test_results")

def load_config():
    with open(CONFIG_PATH) as f:
        return yaml.safe_load(f)

def save_config(cfg):
    with open(CONFIG_PATH, "w") as f:
        yaml.dump(cfg, f, default_flow_style=False, sort_keys=False)

def enable_strategy_only(strats, idx):
    """Enable only the strategy at given index, disable all others."""
    for i, s in enumerate(strats):
        s["enabled"] = (i == idx)

def run_backtest(label):
    subprocess.run(["podman-compose", "down"], cwd=os.path.join(os.path.dirname(__file__), ".."), capture_output=True)
    for f in os.listdir(REPORTS_DIR):
        if f.startswith("backtest_report"):
            os.remove(os.path.join(REPORTS_DIR, f))
    subprocess.run(["podman-compose", "up", "-d"], cwd=os.path.join(os.path.dirname(__file__), ".."),
                   env={**os.environ, "MT5_MODE": "tester"}, check=True)
    time.sleep(5)
    result = subprocess.run(["podman", "logs", "--tail", "15", "mt5"], capture_output=True, text=True)
    print(f"[{label}] {result.stdout.strip()}")
    time.sleep(20)

    report_file = os.path.join(REPORTS_DIR, "backtest_report.htm")
    if os.path.exists(report_file):
        dest = os.path.join(OUTPUT_DIR, f"{label}.htm")
        os.makedirs(OUTPUT_DIR, exist_ok=True)
        shutil.copy(report_file, dest)
        print(f"  Report saved to {dest}")

    result = subprocess.run(["python3", os.path.join(os.path.dirname(__file__), "parse_report.py"),
                             report_file, "--human"], capture_output=True, text=True)
    print(result.stdout)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: backtest.py <label> [strategy_index]")
        print("  label: label for result file")
        print("  strategy_index: 0-based index of strategy to enable solo (optional)")
        sys.exit(1)
    label = sys.argv[1]
    if len(sys.argv) >= 3:
        cfg = load_config()
        idx = int(sys.argv[2])
        enable_strategy_only(cfg["strategies"], idx)
        save_config(cfg)
        print(f"Enabled only strategy {idx}: {cfg['strategies'][idx]['name']}")
    run_backtest(label)