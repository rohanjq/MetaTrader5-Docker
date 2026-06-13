# MetaTrader5-Docker

Docker container running MetaTrader 5 via Wine + KasmVNC on Linux, bundled with the **MasterTrader EA** — an expression-based multi-strategy trading engine.

## Quick Start

```bash
cp .env.example .env
# Edit .env: set MT5_LOGIN, MT5_PASSWORD, MT5_SERVER

# Live trading
MT5_MODE=live podman-compose up -d --build

# Backtesting
MT5_MODE=tester podman-compose up --build
```

Access MT5 via browser at `http://<host>:3000`.

## Documentation

| Doc | What's in it |
|---|---|
| [Docker & Infrastructure](docs/docker.md) | Container architecture, volumes, symlinks, env vars, startup steps, ports |
| [MasterTrader EA](docs/ea.md) | Signal reference, timeframes, expression syntax, strategy slots, all indicators |
| [YAML Config](docs/yaml-config.md) | config.yaml schema, gen_inputs.py converter, live vs backtest usage |
| [Report Parser](docs/parse_report.md) | parse_report.py usage, output fields, JSON/CSV/human formats |
| [EA Design](DESIGN.md) | Full EA technical design document |

## Repo Structure

```
├── Metatrader/
│   ├── MQL5/Experts/MasterTrader.mq5   # EA source
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
