# MetaTrader5-Docker

Docker container running MetaTrader 5 via Wine + KasmVNC on Linux. Includes the MasterTrader EA and automated backtesting support.

## Quick Start

```bash
cp .env.example .env
# Edit .env: set MT5_LOGIN, MT5_PASSWORD, MT5_SERVER

podman-compose up -d --build
# Access MT5 via browser at http://<host>:3000
```

## Modes

### Live Trading (default)
```bash
# .env: MT5_MODE=live
podman-compose up -d
```
Terminal starts, authenticates, attaches the EA to a chart, and begins live trading.

### Backtesting
```bash
# .env: MT5_MODE=tester
podman-compose down && podman-compose build --no-cache && podman-compose up
```
Terminal authenticates, runs the strategy tester with `Metatrader/tester.ini`, saves report to `/data/reports/`, then shuts down.

**Note:** Backtests for forex/metals (XAUUSD etc.) must run during market hours. Brokers set `SYMBOL_TRADE_MODE_CLOSEONLY` during weekends, which causes all trades to fail with error 10044. Crypto symbols (BTCUSDT) work 24/7.

## Startup Steps

The container startup (`Metatrader/start.sh`) runs 7 steps:

1. Install Mono (Wine .NET runtime)
2. Install MetaTrader 5 terminal via Wine
3. Install Python 3.9 in Wine
4. Install Python packages (MetaTrader5, rpyc, numpy)
5. Configure MT5 (auto-login, expert settings)
6. Sync & compile MQL5 files (EAs, indicators)
7. Launch MT5 terminal (live mode) or run backtest (tester mode)

## EA Source

The MasterTrader EA lives in `Metatrader/MQL5/Experts/MasterTrader.mq5`. See [DESIGN.md](DESIGN.md) for full documentation.

After editing the EA, rebuild: `podman-compose build --no-cache && podman-compose up -d`

## Environment Variables

See `.env.example` for all settings. Key ones:

| Variable | Description |
|----------|-------------|
| `MT5_LOGIN` | MT5 account number |
| `MT5_PASSWORD` | MT5 account password |
| `MT5_SERVER` | Broker server name |
| `MT5_MODE` | `live` (default) or `tester` (backtest) |
| `MT5_STARTUP_EA` | EA to auto-attach in live mode |
| `MT5_STARTUP_SYMBOL` | Chart symbol (default: `XAUUSD`) |
| `MT5_STARTUP_PERIOD` | Chart timeframe (default: `M1`) |
| `MT5_RPYC_PORT` | rpyc bridge port (default: `8001`) |

## Ports

| Port | Service |
|------|---------|
| 3000 | KasmVNC web UI (browser access to MT5) |
| 8001 | rpyc bridge (Python ↔ MT5 API) |

## Useful Commands

See [commands.txt](commands.txt) for VPS reference commands (log tails, mode switching, etc.).
