# MetaTrader5-Docker

Docker container running MetaTrader 5 via Wine + KasmVNC on Linux. Live mode starts the **ZeroLatencyTicks EA** by default; the bundled **MasterTrader EA** remains available for automated trading and backtesting.

## Quick Start

```bash
cp .env.example .env
# Edit .env: set MT5_LOGIN, MT5_PASSWORD, MT5_SERVER

# Live trading
podman-compose -f docker-compose.live.yaml up -d --build

# Backtesting
podman-compose -f docker-compose.tester.yaml up --build
```

The compose files create their bind-mount directories automatically. Rootless
Podman uses `keep-id`, so generated files remain owned by your WSL user. A
tracked preset is mounted by default; set `MT5_CONFIG_FILE` in `.env` only when
you want to use another YAML file.

Access MT5 via browser at `http://<host>:3000`.

When this repository is checked out beside `ohlc/` and `signals/`, manage the
whole local stack in dependency order with the common wrapper:

```bash
./stack.sh up --build   # MT5, then OHLC, then Signals
./stack.sh status
./stack.sh down         # reverse order
```

After images exist, `./stack.sh up` is sufficient. Override sibling locations
with `MT5_REPO_DIR`, `OHLC_REPO_DIR`, or `SIGNALS_REPO_DIR` if needed.

## Documentation

| Doc | What's in it |
|---|---|
| [Docker & Infrastructure](docs/docker.md) | Container architecture, volumes, symlinks, env vars, startup steps, ports |
| [MasterTrader EA](docs/ea.md) | Signal reference, timeframes, expression syntax, strategy slots, all indicators |
| [Low-latency ticks](docs/zero-latency-ticks.md) | Named-pipe endpoint and binary tick-frame protocol |
| [YAML Config](docs/yaml-config.md) | config.yaml schema, gen_inputs.py converter, live vs backtest usage |
| [Report Parser](docs/parse_report.md) | parse_report.py usage, output fields, JSON/CSV/human formats |
| [EA Design](DESIGN.md) | Full EA technical design document |

## Repo Structure

```
├── Metatrader/
│   ├── MQL5/Experts/MasterTrader.mq5   # EA source
│   ├── MQL5/Experts/ZeroLatencyTicks.mq5 # Default live tick publisher
│   ├── config.yaml                      # Default YAML config (bundled in image)
│   ├── gen_inputs.py                    # YAML → tester.ini converter
│   ├── tester.ini                       # Static fallback tester config
│   └── start.sh                         # Container startup script
├── tools/
│   ├── parse_report.py                  # Backtest HTML report parser
│   ├── account_info.py                  # Account health check via rpyc
│   └── ticker_info.py                   # Ticker info via rpyc
├── docs/                                # Documentation (see table above)
├── root/                                # KasmVNC autostart/menu config
├── Dockerfile
├── docker-compose.yaml
├── .env.example
└── commands.txt                         # VPS quick-reference commands
```
