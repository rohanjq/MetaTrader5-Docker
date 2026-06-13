#!/usr/bin/env python3
"""
Parse MT5 Strategy Tester HTML report → JSON, CSV, or human-readable.

Usage:
  python3 parse_report.py report.htm                   # JSON summary
  python3 parse_report.py report.htm --deals             # JSON deals only
  python3 parse_report.py report.htm --orders            # JSON orders only
  python3 parse_report.py report.htm --all               # JSON everything
  python3 parse_report.py report.htm --csv --deals       # CSV deals
  python3 parse_report.py report.htm --human             # quick human summary
  python3 parse_report.py report.htm --human --deals     # human deals + breakdown
  python3 parse_report.py report.htm --human --all       # human everything
  python3 parse_report.py report.htm -o results.json     # save to file
  python3 parse_report.py report.htm --csv --all -o out/  # CSV files to dir
"""
import argparse
import csv
import io
import json
import os
import re
import sys
from html.parser import HTMLParser


def read_html(path):
    """Read HTML file, handling UTF-16LE encoding from MT5."""
    raw = open(path, "rb").read()
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return raw.decode("utf-16")
    return raw.decode("utf-8")


def strip_tags(html):
    """Remove HTML tags and decode entities."""
    text = re.sub(r"<[^>]+>", "", html)
    text = text.replace("&nbsp;", " ").replace("&amp;", "&")
    text = text.replace("&lt;", "<").replace("&gt;", ">")
    return text.strip()


def clean_number(s):
    """Parse number strings like '13 536.77' or '-3 729.44' or '54.32%'."""
    s = s.strip()
    if not s:
        return s
    # Remove thin/non-breaking spaces used as thousand separators
    s = re.sub(r"[\s\u00a0]+", "", s)
    return s


def parse_table_rows(html, section_start, section_end=None):
    """Extract <tr> rows between two section markers.
    Returns list of (tr_attrs, inner_html) tuples."""
    start = html.find(section_start)
    if start == -1:
        return []
    if section_end:
        end = html.find(section_end, start + len(section_start))
        if end == -1:
            end = len(html)
    else:
        end = len(html)
    chunk = html[start:end]
    # Match both multiline (header) and single-line (data) rows
    return re.findall(r"<tr([^>]*)>(.*?)</tr>", chunk, re.DOTALL | re.IGNORECASE)


def parse_cells(row_html):
    """Extract cell text from a <tr> inner HTML."""
    cells = re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", row_html, re.DOTALL | re.IGNORECASE)
    return [strip_tags(c) for c in cells]


def parse_results(html):
    """Parse the Results summary section into a dict."""
    rows = parse_table_rows(html, "<b>Results</b>", "<b>Orders</b>")
    stats = {}
    for attrs, inner in rows:
        cells = parse_cells(inner)
        # Results section uses pairs: label, value, label, value, ...
        # Filter out empty cells and image cells
        cells = [c for c in cells if c and "img" not in c.lower()]
        i = 0
        while i < len(cells) - 1:
            key = cells[i].rstrip(":").strip()
            val = cells[i + 1].strip()
            if key and val:
                stats[key] = clean_number(val)
            i += 2
    return stats


def parse_deals(html):
    """Parse the Deals table into a list of dicts."""
    rows = parse_table_rows(html, "<b>Deals</b>")
    if not rows:
        return []

    columns = ["time", "deal", "symbol", "type", "direction", "volume",
                "price", "order", "commission", "swap", "profit", "balance", "comment"]
    deals = []
    for attrs, inner in rows:
        cells = parse_cells(inner)
        if len(cells) < 10:
            continue
        # Skip header row
        if any(c in ("Time", "Deal") for c in cells[:2]):
            continue
        entry = {}
        for j, col in enumerate(columns):
            entry[col] = cells[j].strip() if j < len(cells) else ""
        deals.append(entry)
    return deals


def parse_orders(html):
    """Parse the Orders table into a list of dicts."""
    rows = parse_table_rows(html, "<b>Orders</b>", "<b>Deals</b>")
    if not rows:
        return []

    columns = ["open_time", "order", "symbol", "type", "volume",
                "price", "sl", "tp", "time", "state", "comment"]
    orders = []
    for attrs, inner in rows:
        cells = parse_cells(inner)
        if len(cells) < 8:
            continue
        if any(c in ("Open Time", "Order") for c in cells[:2]):
            continue
        entry = {}
        for j, col in enumerate(columns):
            entry[col] = cells[j].strip() if j < len(cells) else ""
        orders.append(entry)
    return orders


def enrich_deals(deals):
    """Add strategy name extracted from comment (MT|strategy_name)."""
    for d in deals:
        comment = d.get("comment", "")
        if comment.startswith("MT|"):
            d["strategy"] = comment[3:]
        elif comment.startswith("sl ") or comment.startswith("tp "):
            d["strategy"] = ""
        else:
            d["strategy"] = ""
    return deals


# -- Key metrics for --human output --
HUMAN_METRICS = [
    "Total Net Profit",
    "Profit Factor",
    "Total Trades",
    "Profit Trades (% of total)",
    "Loss Trades (% of total)",
    "Expected Payoff",
    "Sharpe Ratio",
    "Recovery Factor",
    "Balance Drawdown Maximal",
    "Equity Drawdown Maximal",
    "Largest profit trade",
    "Largest loss trade",
    "Average profit trade",
    "Average loss trade",
    "Maximum consecutive wins ($)",
    "Maximum consecutive losses ($)",
    "Average consecutive wins",
    "Average consecutive losses",
    "Short Trades (won %)",
    "Long Trades (won %)",
    "Minimal position holding time",
    "Maximal position holding time",
    "Average position holding time",
]


def write_human(data, dest):
    """Write a compact human-readable summary."""
    lines = []

    if "summary" in data:
        summary = data["summary"]
        lines.append("═══ BACKTEST SUMMARY ═══")
        lines.append("")
        for key in HUMAN_METRICS:
            val = summary.get(key)
            if val is not None:
                lines.append(f"  {key:<40s} {val}")

    if "deals" in data:
        deals = [d for d in data["deals"] if d.get("type") not in ("balance",)]
        if deals:
            lines.append("")
            lines.append("═══ DEALS ═══")
            lines.append(f"  {'Time':<22s} {'Type':<6s} {'Dir':<4s} {'Vol':>6s} {'Price':>12s} {'Profit':>10s} {'Strategy'}")
            lines.append("  " + "─" * 90)
            for d in deals:
                lines.append(
                    f"  {d['time']:<22s} {d['type']:<6s} {d['direction']:<4s} "
                    f"{d['volume']:>6s} {d['price']:>12s} {d['profit']:>10s} "
                    f"{d.get('strategy', '')}"
                )

        # Per-strategy breakdown
        entry_deals = [d for d in data["deals"]
                       if d.get("direction") == "in" and d.get("strategy")]
        if entry_deals:
            strat_stats = {}
            for d in entry_deals:
                s = d["strategy"]
                if s not in strat_stats:
                    strat_stats[s] = {"count": 0, "buy": 0, "sell": 0}
                strat_stats[s]["count"] += 1
                if d["type"] == "buy":
                    strat_stats[s]["buy"] += 1
                else:
                    strat_stats[s]["sell"] += 1

            lines.append("")
            lines.append("═══ BY STRATEGY ═══")
            lines.append(f"  {'Strategy':<40s} {'Trades':>6s} {'Buys':>6s} {'Sells':>6s}")
            lines.append("  " + "─" * 60)
            for s, st in sorted(strat_stats.items(), key=lambda x: -x[1]["count"]):
                lines.append(f"  {s:<40s} {st['count']:>6d} {st['buy']:>6d} {st['sell']:>6d}")

    if "orders" in data and data["orders"]:
        lines.append("")
        lines.append("═══ ORDERS ═══")
        lines.append(f"  {'Open Time':<22s} {'Type':<6s} {'Volume':>8s} {'Price':>12s} {'SL':>12s} {'TP':>12s} {'Comment'}")
        lines.append("  " + "─" * 95)
        for o in data["orders"]:
            lines.append(
                f"  {o['open_time']:<22s} {o['type']:<6s} {o['volume']:>8s} "
                f"{o['price']:>12s} {o['sl']:>12s} {o['tp']:>12s} {o['comment']}"
            )

    output = "\n".join(lines) + "\n"
    if dest:
        with open(dest, "w") as f:
            f.write(output)
        print(f"Written to {dest}", file=sys.stderr)
    else:
        print(output)


def write_json(data, dest):
    """Write JSON output."""
    out = json.dumps(data, indent=2, ensure_ascii=False)
    if dest:
        with open(dest, "w") as f:
            f.write(out)
        print(f"Written to {dest}", file=sys.stderr)
    else:
        print(out)


def write_csv(data, dest):
    """Write CSV output — one file per section, or combined to stdout."""
    sections = {}

    # Summary as key-value CSV
    buf = io.StringIO()
    w = csv.writer(buf)
    w.writerow(["metric", "value"])
    for k, v in data["summary"].items():
        w.writerow([k, v])
    sections["summary"] = buf.getvalue()

    # Orders
    if "orders" in data and data["orders"]:
        buf = io.StringIO()
        cols = list(data["orders"][0].keys())
        w = csv.DictWriter(buf, fieldnames=cols)
        w.writeheader()
        w.writerows(data["orders"])
        sections["orders"] = buf.getvalue()

    # Deals
    if "deals" in data and data["deals"]:
        buf = io.StringIO()
        cols = list(data["deals"][0].keys())
        w = csv.DictWriter(buf, fieldnames=cols)
        w.writeheader()
        w.writerows(data["deals"])
        sections["deals"] = buf.getvalue()

    if dest and os.path.isdir(dest):
        for name, content in sections.items():
            if content:
                path = os.path.join(dest, f"{name}.csv")
                with open(path, "w") as f:
                    f.write(content)
                print(f"Written {path}", file=sys.stderr)
    elif dest:
        # Single file — write deals (most useful)
        with open(dest, "w") as f:
            f.write(sections.get("deals") or sections.get("orders") or "")
        print(f"Written to {dest}", file=sys.stderr)
    else:
        # stdout — print all sections
        for name, content in sections.items():
            if content:
                print(f"# === {name} ===")
                print(content)


def main():
    parser = argparse.ArgumentParser(description="Parse MT5 backtest HTML report → JSON/CSV/human")
    parser.add_argument("report", help="Path to backtest_report.htm")
    fmt = parser.add_mutually_exclusive_group()
    fmt.add_argument("--json", action="store_true", default=True, help="JSON output (default)")
    fmt.add_argument("--csv", action="store_true", help="CSV output")
    fmt.add_argument("--human", action="store_true", help="Human-readable summary")
    section = parser.add_mutually_exclusive_group()
    section.add_argument("--summary", action="store_true", help="Summary stats only (default)")
    section.add_argument("--deals", action="store_true", help="Deals table only")
    section.add_argument("--orders", action="store_true", help="Orders table only")
    section.add_argument("--all", action="store_true", help="All sections")
    parser.add_argument("-o", "--output", default=None, help="Output file or directory (for CSV)")
    args = parser.parse_args()

    # Default to summary if no section specified
    if not (args.deals or args.orders or args.all):
        args.summary = True

    html = read_html(args.report)

    # Build only what's needed
    data = {}
    if args.summary or args.all:
        data["summary"] = parse_results(html)
    if args.deals or args.all:
        data["deals"] = enrich_deals(parse_deals(html))
    if args.orders or args.all:
        data["orders"] = parse_orders(html)

    if args.human:
        write_human(data, args.output)
    elif args.csv:
        write_csv(data, args.output)
    else:
        write_json(data, args.output)


if __name__ == "__main__":
    main()
