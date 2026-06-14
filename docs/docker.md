# Docker & Infrastructure

## Container Stack

- **Base image**: `ghcr.io/linuxserver/baseimage-kasmvnc:debianbookworm`
- **Wine**: winehq-stable (Debian Bookworm)
- **Python**: 3.x (Linux) + 3.9 (Wine, for MT5 API)
- **VNC**: KasmVNC on port 3000 (browser-based)
- **rpyc**: Python bridge on port 8001

## Ports

| Port | Service | Description |
|------|---------|-------------|
| 3000 | KasmVNC | Browser access to MT5 desktop |
| 8001 | rpyc | Python ↔ MT5 API bridge (live mode only) |

## Environment Variables

Set in `.env` (see `.env.example`):

| Variable | Default | Description |
|---|---|---|
| `MT5_LOGIN` | (required) | MT5 account number |
| `MT5_PASSWORD` | (required) | MT5 account password |
| `MT5_SERVER` | (required) | Broker server name |
| `MT5_MODE` | `live` | `live` or `tester` |
| `MT5_INSTALL_DIR` | `PXBT Trading MT5 Terminal` | MT5 install folder name |
| `MT5_SETUP_URL` | (pxbt default) | MT5 installer download URL |
| `MT5_STARTUP_EA` | (empty) | EA to auto-attach in live mode |
| `MT5_STARTUP_SYMBOL` | `XAUUSD` | Chart symbol for live mode |
| `MT5_STARTUP_PERIOD` | `M1` | Chart timeframe for live mode |
| `MT5_RPYC_PORT` | `8001` | rpyc bridge port |
| `MT5_CMD_OPTIONS` | (empty) | Extra terminal64.exe flags |
| `PUID` | `1000` | Container user ID |
| `PGID` | `1000` | Container group ID |
| `CUSTOM_USER` | `abc` | Container username |
| `PASSWORD` | (required) | KasmVNC password |

## Volumes

```yaml
volumes:
  - ./config:/config    # KasmVNC config (managed by linuxserver base)
  - ./data:/data        # All MT5 data, logs, reports, config
```

## `/data` Directory Structure

All persistent data lives under `./data/` on the host (mounted as `/data` in the container):

```
data/
├── wine/                    # Wine prefix (MT5 installation lives here)
├── config/
│   ├── auto_login.ini       # Generated from env vars (or user-provided)
│   ├── config.yaml          # YAML EA config (edit this for strategies)
│   └── tester.ini           # Static tester fallback config
├── downloads/               # Cached installers (Mono, Python, MT5)
├── experts/                 # User-provided .mq5 EA files (hot-synced)
├── indicators/              # User-provided .mq5 indicator files (hot-synced)
├── scripts/                 # User-provided .mq5 script files (hot-synced)
├── signals/                 # Common/Files (symlinked, for signal CSVs)
├── reports/                 # Backtest HTML reports + images
└── logs/
    ├── experts/             # → symlink to MT5 MQL5/logs (EA print output)
    ├── terminal/            # → symlink to MT5 terminal logs
    └── tester/              # → symlink to MT5 Tester directory
```

## Symlinks in `/data/logs`

The container creates symlinks so you can read MT5 internal logs directly from the host:

| Host path | Points to (inside Wine) | Content |
|---|---|---|
| `data/logs/experts/` | `wine/.../MQL5/logs/` | EA `Print()` output, one file per day |
| `data/logs/terminal/` | `wine/.../logs/` | Terminal connection/startup logs |
| `data/logs/tester/` | `wine/.../Tester/` | Strategy Tester logs and cache |
| `data/signals/` | Wine `Common/Files/` | Shared files between EAs (signal CSVs) |

## Startup Sequence

`Metatrader/start.sh` runs these steps (idempotent — skips completed steps):

| Step | What it does |
|---|---|
| 1/7 | Install Mono (Wine .NET runtime) |
| 2/7 | Install MetaTrader 5 terminal via Wine |
| 3/7 | Install Python 3.9 in Wine |
| 4/7 | Install Python packages (MetaTrader5, rpyc, numpy) in Wine + Linux |
| 5/7 | Write `auto_login.ini` from env vars, configure expert permissions |
| 6/7 | Sync `.mq5` files from `/data/experts` + bundled image → MT5, compile with MetaEditor |
| 6b | Symlink `Common/Files` → `/data/signals` |
| 6c | Symlink logs directories → `/data/logs` |
| 7/7 | Launch MT5 in live mode (+ rpyc server) or tester mode |

## Modes

### Live Mode (`MT5_MODE=live`)

```bash
podman-compose up -d
```

- Terminal starts, authenticates, optionally attaches EA to chart
- rpyc server starts on port 8001
- Access via browser at `http://<host>:3000`

### Tester Mode (`MT5_MODE=tester`)

```bash
podman-compose up   # (foreground recommended to see output)
```

1. Reads credentials from `auto_login.ini`
2. If `config.yaml` exists → runs `gen_inputs.py` to generate tester config
3. Otherwise falls back to static `tester.ini`
4. Launches MT5 Strategy Tester
5. Copies report to `data/reports/`
6. Terminal shuts down

**Weekend limitation:** Forex/metals backtests fail with error 10044 during market-closed hours (broker sends `CLOSEONLY`). Run during market hours (Sun 5pm – Fri 5pm ET) or use crypto symbols (BTCUSDT) which work 24/7.

## Hot-Syncing MQL5 Files

Drop `.mq5` files into these host directories — they'll be synced and compiled on next container start:

| Host path | Destination |
|---|---|
| `data/experts/*.mq5` | MT5 `MQL5/Experts/` |
| `data/indicators/*.mq5` | MT5 `MQL5/Indicators/` |
| `data/scripts/*.mq5` | MT5 `MQL5/Scripts/` |

Files bundled in the Docker image (`Metatrader/MQL5/`) are also synced on every start.

## Rebuilding

```bash
# Full rebuild (after EA changes or Dockerfile changes)
podman-compose down && podman-compose build --no-cache && podman-compose up -d

# Quick restart (config-only changes)
podman-compose restart
```

## Tools

Located in `tools/`:

| Tool | Description |
|---|---|
| `account_info.py` | Account health check via rpyc bridge |
| `ticker_info.py` | Ticker/symbol info via rpyc bridge |
| `parse_report.py` | Parse backtest HTML report → JSON/CSV ([docs](parse_report.md)) |
