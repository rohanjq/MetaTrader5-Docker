#!/usr/bin/env python3
"""
Parse MT5 Strategy Tester HTML report → JSON or CSV.

Usage:
  python3 parse_report.py backtest_report.htm                # JSON to stdout
  python3 parse_report.py backtest_report.htm --csv           # CSV to stdout
  python3 parse_report.py backtest_report.htm -o results.json # save to file
  python3 parse_report.py backtest_report.htm --csv -o out/   # CSV files to dir
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


def build_output(html):
    """Build full parsed output."""
    return {
        "summary": parse_results(html),
        "orders": parse_orders(html),
        "deals": enrich_deals(parse_deals(html)),
    }


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
    sections = {"summary": None, "orders": None, "deals": None}

    # Summary as key-value CSV
    buf = io.StringIO()
    w = csv.writer(buf)
    w.writerow(["metric", "value"])
    for k, v in data["summary"].items():
        w.writerow([k, v])
    sections["summary"] = buf.getvalue()

    # Orders
    if data["orders"]:
        buf = io.StringIO()
        cols = list(data["orders"][0].keys())
        w = csv.DictWriter(buf, fieldnames=cols)
        w.writeheader()
        w.writerows(data["orders"])
        sections["orders"] = buf.getvalue()

    # Deals
    if data["deals"]:
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
    parser = argparse.ArgumentParser(description="Parse MT5 backtest HTML report → JSON/CSV")
    parser.add_argument("report", help="Path to backtest_report.htm")
    parser.add_argument("--csv", action="store_true", help="Output CSV instead of JSON")
    parser.add_argument("-o", "--output", default=None, help="Output file or directory (for CSV)")
    args = parser.parse_args()

    html = read_html(args.report)
    data = build_output(html)

    if args.csv:
        write_csv(data, args.output)
    else:
        write_json(data, args.output)


if __name__ == "__main__":
    main()
