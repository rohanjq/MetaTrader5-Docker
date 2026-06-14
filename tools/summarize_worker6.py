#!/usr/bin/env python3
"""
Summarize worker6_results.json → STRATEGY-RESULTS.md + final portfolio config.
"""
import json, sys
from pathlib import Path

RESULTS = Path("/root/MetaTrader5-Docker/data/config/worker6_results.json")

STRAT_NAMES = {
    "L1":"Sweep+Stoch", "L2":"Sweep+Stoch+Trend", "L3":"Triple Rejection",
    "T1":"VWAP Trend", "T2":"Stoch Combo Wide", "T3":"MACD Cross Trend",
    "R1":"Failed BB Sell", "R2":"Exhausted Sell", "R3":"EMA Slope Sell",
    "P1":"DC Lowzone ADX",
    "V1":"Stoch OS Tight", "V2":"RSI2 Extreme Buy", "V3":"Stoch Wide Sell",
}
STRAT_FAMILIES = {
    "L1":"Sweep","L2":"Sweep","L3":"Sweep",
    "T1":"Trend","T2":"Trend","T3":"Trend",
    "R1":"Reversal","R2":"Reversal","R3":"Reversal",
    "P1":"Pullback",
    "V1":"Validate","V2":"Validate","V3":"Validate",
}

def load():
    if not RESULTS.exists():
        print("ERROR: No results file found. Run python3 tools/run_worker6.py first.")
        sys.exit(1)
    with open(RESULTS) as f:
        return json.load(f)

def main():
    data = load()

    # Group by strategy
    by_sid = {}
    for key, e in data.items():
        sid = e["sid"]
        if sid not in by_sid:
            by_sid[sid] = []
        by_sid[sid].append(e)

    # Find best per strategy
    best_per = {}
    for sid, entries in by_sid.items():
        entries.sort(key=lambda x: (x["pf"], x["trades"]), reverse=True)
        best = entries[0]
        best_per[sid] = {
            "best": best,
            "all": entries,
            "name": STRAT_NAMES.get(sid, sid),
            "family": STRAT_FAMILIES.get(sid, "?"),
        }

    lines = []

    lines.append("# Worker 6 — Strategy Results (6-Month Window: 2026.01.13–2026.06.13)")
    lines.append("")
    lines.append("Global settings: `multi_position=true`, `max_positions=3`, `cooldown_sec=900`, `reversal_cooldown=0`, `risk_pct=3%`")
    lines.append("")

    # All results table
    lines.append("## All Results")
    lines.append("")
    lines.append("| ID | Name | Family | SL | RR | Trail | PF | WR | Trades | MaxDD | PnL |")
    lines.append("|---|---|---|---|---|---|---|---|---|---|---|")
    for sid in sorted(best_per.keys()):
        for e in sorted(best_per[sid]["all"], key=lambda x: (x["pf"], x["trades"]), reverse=True):
            lines.append(f"| {sid} | {best_per[sid]['name']} | {best_per[sid]['family']} | {e['sl']} | {e['rr']} | {e['trail']} | {e['pf']:.2f} | {e['wr']:.0f}% | {e['trades']} | {e['maxdd']:.1f}% | ${e['pnl']:.0f} |")

    lines.append("")
    lines.append("## Best Parameters Per Strategy")
    lines.append("")
    lines.append("| ID | Name | SL | RR | Trail | PF | Trades | WR | MaxDD | PnL | Status |")
    lines.append("|---|---|---|---|---|---|---|---|---|---|---|")
    keep = []
    discard = []
    for sid in sorted(best_per.keys()):
        bp = best_per[sid]
        b = bp["best"]
        status = "KEEP" if b["pf"] >= 1.15 and b["trades"] >= 15 else "DISCARD"
        if status == "KEEP":
            keep.append(sid)
        else:
            discard.append(sid)
        lines.append(f"| {sid} | {bp['name']} | {b['sl']} | {b['rr']} | {b['trail']} | {b['pf']:.2f} | {b['trades']} | {b['wr']:.0f}% | {b['maxdd']:.1f}% | ${b['pnl']:.0f} | {status} |")

    lines.append("")
    lines.append("## Discard List (Failed 6-Month Criteria: PF < 1.15 or < 15 trades)")
    lines.append("")
    if discard:
        for sid in sorted(discard):
            b = best_per[sid]["best"]
            reason = []
            if b["pf"] < 1.15: reason.append(f"PF={b['pf']:.2f}")
            if b["trades"] < 15: reason.append(f"{b['trades']} trades")
            lines.append(f"- **{sid}** ({best_per[sid]['name']}): {', '.join(reason)}")
    else:
        lines.append("All strategies passed.")

    lines.append("")
    lines.append("## Summary")
    lines.append(f"- Strategies that survived: {len(keep)} ({', '.join(sorted(keep))})")
    lines.append(f"- Strategies discarded: {len(discard)} ({', '.join(sorted(discard))})")

    # Best non-overlapping portfolio
    lines.append("")
    lines.append("## Recommended Production Portfolio")
    lines.append("")
    lines.append("Non-overlapping strategy combos for production config:")
    lines.append("")
    lines.append("### Combo 1: L1 + T1 + R1 (Sweep + VWAP Trend + Failed BB Sell)")
    lines.append("### Combo 2: L3 + T1 + R2 (Triple Rejection + VWAP Trend + Exhausted Sell)")
    lines.append("### Combo 3: L1 + R1 + P1 (Sweep + Failed BB Sell + DC Pullback)")

    output = "\n".join(lines)
    print(output)

    # Write to file
    out_path = Path("/root/MetaTrader5-Docker/STRATEGY-RESULTS.md")
    out_path.write_text(output)
    print(f"\nSaved to: {out_path}")

if __name__ == "__main__":
    main()