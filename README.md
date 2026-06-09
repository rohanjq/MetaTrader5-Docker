# MetaTrader5-Docker

Docker container that runs MetaTrader 5 via Wine + KasmVNC on Linux.

## Prerequisites

Both repos must be cloned as siblings:
```
repos/
├── mt5-trader/              ← trading system + EA source (MQL5/)
└── MetaTrader5-Docker/      ← this repo (Docker infrastructure)
```

## Quick Start

```bash
cp .env.example .env
# Edit .env: set MT5_LOGIN, MT5_PASSWORD, MT5_SERVER

podman compose up -d --build
# or: docker compose up -d --build

# Access MT5 via browser at http://<host>:3000
```

## What It Does

The container startup (`Metatrader/start.sh`) runs 7 steps:

1. Install Mono (Wine .NET runtime)
2. Install MetaTrader 5 terminal via Wine
3. Install Python 3.9 in Wine
4. Install Python packages (MetaTrader5, rpyc, numpy)
5. Configure MT5 (auto-login, expert settings)
6. Sync & compile MQL5 files (copies from `../mt5-trader/MQL5`)
7. Start MT5 terminal + rpyc bridge

## EA Source

The SignalMaster EA source lives in the **mt5-trader** repo at `MQL5/Experts/SignalMaster.mq5`.
The Dockerfile copies it at build time:
```dockerfile
COPY mt5-trader/MQL5 /Metatrader/MQL5
```

After editing the EA, rebuild: `podman compose up -d --build`

## Health Check Tools

```bash
# Check MT5 connection and account info
podman exec mt5 python3 tools/account_info.py

# Get symbol/ticker info
podman exec mt5 python3 tools/ticker_info.py
```

## Environment Variables

See `.env.example` for all settings. Key ones:

| Variable | Description |
|----------|-------------|
| `MT5_LOGIN` | MT5 account number |
| `MT5_PASSWORD` | MT5 account password |
| `MT5_SERVER` | Broker server name |
| `MT5_STARTUP_EA` | EA to auto-attach (default: `SignalMaster`) |
| `MT5_STARTUP_SYMBOL` | Chart symbol (default: `XAUUSD`) |
| `MT5_STARTUP_PERIOD` | Chart timeframe (default: `M1`) |
| `MT5_RPYC_PORT` | rpyc bridge port (default: `8001`) |

## Ports

| Port | Service |
|------|---------|
| 3000 | KasmVNC web UI (browser access to MT5) |
| 8001 | rpyc bridge (Python ↔ MT5 API) |

## Trading System

For the full trading system (strategies, backtesting, signals, expressions), see the companion repo: [mt5-trader](https://github.com/rohanjq/mt5-trader)
