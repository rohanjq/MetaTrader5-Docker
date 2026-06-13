#!/usr/bin/env python3
"""
Convert config.yaml → MT5 tester.ini (or just [TesterInputs] section).

Usage:
  python3 gen_inputs.py config.yaml                    # outputs tester.ini
  python3 gen_inputs.py config.yaml -o custom.ini      # custom output path
  python3 gen_inputs.py config.yaml --inputs-only      # just [TesterInputs]
"""
import sys
import argparse
try:
    import yaml
except ImportError:
    sys.exit("PyYAML required: pip install pyyaml")

MAX_STRATEGIES = 20


def fmt_val(val, opt_fmt=None):
    """Format a value for the ||...||N tester input line."""
    if isinstance(val, bool):
        return "true" if val else "false"
    if isinstance(val, float):
        return f"{val}"
    return str(val)


def opt_range(val):
    """Build the ||start||step||stop||N optimization range string."""
    if isinstance(val, bool):
        s = "true" if val else "false"
        return f"{s}||false||0||true||N"
    if isinstance(val, float):
        # step = val/10, stop = val*10 (reasonable defaults)
        step = abs(val) / 10 if val != 0 else 0.0
        stop = abs(val) * 10 if val != 0 else 0.0
        return f"{val}||{val}||{step:f}||{stop:f}||N"
    if isinstance(val, int):
        step = max(1, abs(val) // 10)
        stop = abs(val) * 10 if val != 0 else 0
        return f"{val}||{val}||{step}||{stop}||N"
    # string — no optimization range
    return str(val)


def emit_input(key, val):
    """Emit a single TesterInputs line: key=value||...||N"""
    return f"{key}={opt_range(val)}"


def generate_tester_section(cfg):
    """Generate [Tester] section from backtest config."""
    bt = cfg.get("backtest", {})
    lines = ["[Tester]"]
    lines.append("Expert=MasterTrader.ex5")
    lines.append(f"Symbol={bt.get('symbol', 'XAUUSD')}")
    lines.append(f"Period={bt.get('period', 'M1')}")
    lines.append("Optimization=0")
    lines.append(f"Model={bt.get('model', 1)}")
    lines.append(f"FromDate={bt.get('from', '2026.01.01')}")
    lines.append(f"ToDate={bt.get('to', '2026.12.31')}")
    lines.append("ForwardMode=0")
    lines.append(f"Deposit={bt.get('deposit', 10000)}")
    lines.append(f"Currency={bt.get('currency', 'USD')}")
    lines.append("ProfitInPips=0")
    lines.append(f"Leverage={bt.get('leverage', '1:100')}")
    lines.append("ExecutionMode=0")
    lines.append("OptimizationCriterion=0")
    lines.append("Visual=0")
    lines.append("ShutdownTerminal=1")
    lines.append("UseLocal=1")
    lines.append("UseRemote=0")
    lines.append("UseCloud=0")
    lines.append("ReplaceReport=1")
    lines.append(r"Report=reports\backtest_report")
    return lines


def generate_inputs_section(cfg):
    """Generate [TesterInputs] section from config."""
    g = cfg.get("global", {})
    t = cfg.get("trailing", {})
    ind = cfg.get("indicators", {})
    ctrl = cfg.get("control", {})
    strats = cfg.get("strategies", [])

    lines = ["[TesterInputs]"]

    # Global Risk
    lines.append("; === Global Risk ===")
    lines.append(emit_input("INP_RiskPct", g.get("risk_pct", 3.0)))
    lines.append(emit_input("INP_GlobalSL", g.get("sl", 7.5)))
    lines.append(emit_input("INP_GlobalRR", g.get("rr", 1.0)))

    # Trade Management
    lines.append("; === Trade Management ===")
    lines.append(emit_input("INP_Magic", g.get("magic", 300)))
    lines.append(emit_input("INP_MultiPosition", g.get("multi_position", False)))
    lines.append(emit_input("INP_MaxPositions", g.get("max_positions", 1)))
    lines.append(emit_input("INP_MaxDailyTrades", g.get("max_daily_trades", 15)))
    lines.append(emit_input("INP_CooldownSec", g.get("cooldown_sec", 300)))
    lines.append(emit_input("INP_ReversalCooldown", g.get("reversal_cooldown", 300)))
    lines.append(emit_input("INP_MaxConsecLoss", g.get("max_consec_loss", 3)))
    lines.append(emit_input("INP_ConsecLossPause", g.get("consec_loss_pause", 1800)))
    lines.append(emit_input("INP_Slippage", g.get("slippage", 20)))

    # Trailing Stop
    lines.append("; === Trailing Stop ===")
    lines.append(emit_input("INP_BreakevenStart", t.get("breakeven_start", 0.0)))
    lines.append(emit_input("INP_TrailStart", t.get("trail_start", 0.0)))
    lines.append(emit_input("INP_TrailStep", t.get("trail_step", 2.0)))

    # Indicators
    lines.append("; === Indicator Parameters ===")
    lines.append(emit_input("INP_UTBot_Period", ind.get("utbot_period", 10)))
    lines.append(emit_input("INP_UTBot_Mult", ind.get("utbot_mult", 2.0)))
    lines.append(emit_input("INP_DC_Length", ind.get("dc_length", 20)))

    # External Control
    lines.append("; === External Control ===")
    lines.append(emit_input("INP_UseControlFile", ctrl.get("use_control_file", False)))
    lines.append(emit_input("INP_WriteStatusFile", ctrl.get("write_status_file", False)))
    lines.append(emit_input("INP_ControlPollSec", ctrl.get("control_poll_sec", 5)))

    # Strategies
    for i in range(MAX_STRATEGIES):
        slot = f"S{i+1:02d}"
        if i < len(strats):
            s = strats[i]
            name = s.get("name", "custom")
            lines.append(f"; === {slot}: {name} ===")
            lines.append(emit_input(f"{slot}_On", s.get("enabled", False)))
            lines.append(emit_input(f"{slot}_SL", float(s.get("sl", 0.0))))
            lines.append(emit_input(f"{slot}_RR", float(s.get("rr", 0.0))))
            lines.append(f"{slot}_Buy={s.get('buy', '')}")
            lines.append(f"{slot}_Sell={s.get('sell', '')}")
        else:
            lines.append(f"; === {slot}: (empty) ===")
            lines.append(emit_input(f"{slot}_On", False))
            lines.append(emit_input(f"{slot}_SL", 0.0))
            lines.append(emit_input(f"{slot}_RR", 0.0))
            lines.append(f"{slot}_Buy=")
            lines.append(f"{slot}_Sell=")

    return lines


def main():
    parser = argparse.ArgumentParser(description="Convert config.yaml → MT5 tester.ini")
    parser.add_argument("config", help="Path to config.yaml")
    parser.add_argument("-o", "--output", default=None, help="Output file (default: stdout)")
    parser.add_argument("--inputs-only", action="store_true", help="Only output [TesterInputs] section")
    args = parser.parse_args()

    with open(args.config) as f:
        try:
            cfg = yaml.safe_load(f)
        except yaml.YAMLError as e:
            sys.exit(f"ERROR: Invalid YAML in {args.config}:\n{e}")
    if not isinstance(cfg, dict):
        sys.exit(f"ERROR: {args.config} does not contain a valid YAML config (got {type(cfg).__name__})")
    if "strategies" not in cfg and "global" not in cfg:
        sys.exit(f"ERROR: {args.config} missing 'strategies' or 'global' keys — is this a YAML config file?")

    lines = []
    if not args.inputs_only:
        lines.extend(generate_tester_section(cfg))
    lines.extend(generate_inputs_section(cfg))

    output = "\n".join(lines) + "\n"

    if args.output:
        with open(args.output, "w") as f:
            f.write(output)
        print(f"Written to {args.output}", file=sys.stderr)
    else:
        print(output, end="")


if __name__ == "__main__":
    main()
