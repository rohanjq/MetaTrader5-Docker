#!/bin/bash
# ============================================================
# MetaTrader 5 Docker — Idempotent Startup Script
# Skips already-completed steps, caches downloads, auto-compiles EAs
# ============================================================
set -euo pipefail

# ---- Paths ------------------------------------------------
DATA_DIR="${MT5_DATA:-/data}"
DOWNLOADS_DIR="$DATA_DIR/downloads"
EXPERTS_DIR="$DATA_DIR/experts"
INDICATORS_DIR="$DATA_DIR/indicators"
SCRIPTS_DIR="$DATA_DIR/scripts"
SIGNALS_DIR="$DATA_DIR/signals"
LOGS_DIR="$DATA_DIR/logs"

export WINEPREFIX="${WINEPREFIX:-$DATA_DIR/wine}"
export WINEDEBUG="${WINEDEBUG:--all}"
export DISPLAY="${DISPLAY:-:1}"

# ---- MT5 settings (all overridable via env) ---------------
WINE="wine"
MT5_INSTALL_DIR_NAME="${MT5_INSTALL_DIR:-PXBT Trading MT5 Terminal}"
MT5_EXE="$WINEPREFIX/drive_c/Program Files/$MT5_INSTALL_DIR_NAME/terminal64.exe"
MT5_EDITOR="$WINEPREFIX/drive_c/Program Files/$MT5_INSTALL_DIR_NAME/MetaEditor64.exe"
MT5_MQL5_DIR="$WINEPREFIX/drive_c/Program Files/$MT5_INSTALL_DIR_NAME/MQL5"
MT5_CONFIG_DIR="$WINEPREFIX/drive_c/Program Files/$MT5_INSTALL_DIR_NAME/Config"
MT5_WIN_INSTALL="C:\\Program Files\\${MT5_INSTALL_DIR_NAME}"
MT5_WIN_CONFIG="${MT5_WIN_INSTALL}\\Config"
RPYC_PORT="${MT5_RPYC_PORT:-8001}"

MONO_URL="https://dl.winehq.org/wine/wine-mono/10.3.0/wine-mono-10.3.0-x86.msi"
PYTHON_URL="https://www.python.org/ftp/python/3.9.13/python-3.9.13-amd64.exe"
MT5_SETUP_URL="${MT5_SETUP_URL:-https://download.terminal.free/cdn/web/pxbt.trading.ltd/mt5/pxbttrading5setup.exe}"

MT5_LOGIN="${MT5_LOGIN:-}"
MT5_PASSWORD="${MT5_PASSWORD:-}"
MT5_SERVER="${MT5_SERVER:-}"
MT5_STARTUP_EA="${MT5_STARTUP_EA:-}"
MT5_STARTUP_SYMBOL="${MT5_STARTUP_SYMBOL:-BTCUSDT}"
MT5_STARTUP_PERIOD="${MT5_STARTUP_PERIOD:-M1}"
MT5_CMD_OPTIONS="${MT5_CMD_OPTIONS:-}"
MT5_MODE="${MT5_MODE:-live}"             # "live" or "tester"

# ---- Helpers ----------------------------------------------
log() { echo "[$(date '+%H:%M:%S')] $*"; }

wine_pkg_installed() {
    $WINE python -c "import pkg_resources; pkg_resources.require('$1')" 2>/dev/null
}

linux_pkg_installed() {
    python3 -c "import pkg_resources; pkg_resources.require('$1')" 2>/dev/null
}

download_if_missing() {
    local url="$1" dest="$2"
    if [ ! -f "$dest" ]; then
        log "  Downloading $(basename "$dest")..."
        curl -L -o "$dest" "$url"
    fi
}

# ============================================================
# Create data directories
# ============================================================
log "Creating data directories..."
mkdir -p "$DOWNLOADS_DIR" "$EXPERTS_DIR" "$INDICATORS_DIR" \
         "$SCRIPTS_DIR" "$SIGNALS_DIR" "$LOGS_DIR" \
         "$DATA_DIR/reports" "$DATA_DIR/config"

# ============================================================
# [1/7] Mono
# ============================================================
if [ -d "$WINEPREFIX/drive_c/windows/mono" ]; then
    log "[1/7] Mono already installed, skipping."
else
    log "[1/7] Installing Mono..."
    download_if_missing "$MONO_URL" "$DOWNLOADS_DIR/wine-mono.msi"
    WINEDLLOVERRIDES=mscoree=d $WINE msiexec /i "$DOWNLOADS_DIR/wine-mono.msi" /qn || true
    log "[1/7] Mono installed."
fi

# ============================================================
# [2/7] MetaTrader 5
# ============================================================
if [ -e "$MT5_EXE" ]; then
    log "[2/7] MetaTrader 5 already installed, skipping."
else
    log "[2/7] Installing MetaTrader 5..."
    $WINE reg add "HKEY_CURRENT_USER\\Software\\Wine" /v Version /t REG_SZ /d "win10" /f || true
    download_if_missing "$MT5_SETUP_URL" "$DOWNLOADS_DIR/mt5setup.exe"
    $WINE "$DOWNLOADS_DIR/mt5setup.exe" /auto || true
    sleep 30
    if [ ! -e "$MT5_EXE" ]; then
        log "[2/7] ERROR: MT5 installation failed — $MT5_EXE not found"
        exit 1
    fi
    log "[2/7] MetaTrader 5 installed."
fi

# ============================================================
# [3/7] Python in Wine
# ============================================================
if $WINE python --version 2>/dev/null; then
    log "[3/7] Python already installed in Wine, skipping."
else
    log "[3/7] Installing Python in Wine..."
    download_if_missing "$PYTHON_URL" "$DOWNLOADS_DIR/python-installer.exe"
    $WINE "$DOWNLOADS_DIR/python-installer.exe" /quiet InstallAllUsers=1 PrependPath=1 || true
    log "[3/7] Python installed in Wine."
fi

# ============================================================
# [4/7] Python packages (Wine + Linux)
# ============================================================
log "[4/7] Checking Python packages..."

$WINE python -m pip install --upgrade --no-cache-dir pip 2>/dev/null || true

for pkg in "numpy<2" "MetaTrader5" "rpyc==5.3.1" "python-dateutil"; do
    # Use the first word before < or = as the import check name
    check_name="${pkg%%[<=]*}"
    if ! wine_pkg_installed "$check_name"; then
        log "  Installing $pkg in Wine..."
        $WINE python -m pip install --no-cache-dir "$pkg"
    fi
done

for pkg in "mt5linux" "pyxdg"; do
    check_name="${pkg%%[<=]*}"
    if ! linux_pkg_installed "$check_name"; then
        log "  Installing $pkg on Linux..."
        pip install --break-system-packages --no-cache-dir "$pkg"
    fi
done
# Force rpyc 5.3.1 after mt5linux (which pulls 5.2.3) to match Wine side
pip install --break-system-packages --no-cache-dir "rpyc==5.3.1" 2>/dev/null || true

log "[4/7] Python packages ready."

# ============================================================
# [5/7] MT5 config (auto_login.ini + common.ini)
# ============================================================
log "[5/7] Configuring MT5..."
mkdir -p "$MT5_CONFIG_DIR"

# common.ini — ensure expert/autotrading flags
touch "$MT5_CONFIG_DIR/common.ini"
for setting in ExpertEnabled=1 ExpertDllImport=1 ExpertAllowLive=1 AutoTrading=1; do
    key="${setting%%=*}"
    grep -q "$key" "$MT5_CONFIG_DIR/common.ini" || echo "$setting" >> "$MT5_CONFIG_DIR/common.ini"
done

# auto_login.ini — priority: /data/config/ override > env vars > existing
if [ -f "$DATA_DIR/config/auto_login.ini" ]; then
    log "[5/7] Using user-provided auto_login.ini from /data/config/"
    cp "$DATA_DIR/config/auto_login.ini" "$MT5_CONFIG_DIR/auto_login.ini"
elif [ -n "$MT5_LOGIN" ] && [ -n "$MT5_PASSWORD" ] && [ -n "$MT5_SERVER" ]; then
    log "[5/7] Writing auto_login.ini from environment variables..."
    cat > "$MT5_CONFIG_DIR/auto_login.ini" <<EOINI
[Common]
Login=$MT5_LOGIN
Password=$MT5_PASSWORD
Server=$MT5_SERVER

[Experts]
AllowLiveTrading=1
AllowDllImport=1
Enabled=1
Account=0
Profile=0
EOINI

    # Append [StartUp] section if a startup EA is configured
    if [ -n "$MT5_STARTUP_EA" ]; then
        cat >> "$MT5_CONFIG_DIR/auto_login.ini" <<EOSTART

[StartUp]
Expert=$MT5_STARTUP_EA
Symbol=$MT5_STARTUP_SYMBOL
Period=$MT5_STARTUP_PERIOD
EOSTART
    fi
else
    log "[5/7] No credentials provided, keeping existing config (if any)."
fi

log "[5/7] MT5 configured."

# ============================================================
# [6/7] Sync & compile MQL5 files (EAs, indicators, scripts)
# ============================================================
log "[6/7] Syncing MQL5 files..."

compile_mq5() {
    local dest_file="$1"
    local rel_path="${dest_file#$WINEPREFIX/drive_c/}"
    local win_path="C:\\$(echo "$rel_path" | sed 's|/|\\\\|g')"

    cat > /tmp/compile_mq5.bat <<EOBAT
"${MT5_WIN_INSTALL}\\MetaEditor64.exe" /compile:"${win_path}" /log
EOBAT
    $WINE cmd /c Z:\\tmp\\compile_mq5.bat 2>/dev/null || true
    sleep 2

    local ex5_file="${dest_file%.mq5}.ex5"
    if [ -f "$ex5_file" ]; then
        log "    compiled OK"
        return 0
    else
        log "    compile FAILED"
        return 1
    fi
}

sync_mql5_dir() {
    local src_dir="$1"
    local dest_dir="$2"
    local label="$3"

    # Skip if source dir is empty or missing
    if [ ! -d "$src_dir" ]; then return; fi
    local mq5_files=()
    while IFS= read -r -d '' f; do mq5_files+=("$f"); done < <(find "$src_dir" -maxdepth 1 -name '*.mq5' -print0 2>/dev/null)
    if [ ${#mq5_files[@]} -eq 0 ]; then return; fi

    mkdir -p "$dest_dir"

    for mq5_file in "${mq5_files[@]}"; do
        local filename
        filename=$(basename "$mq5_file")
        local dest_file="$dest_dir/$filename"

        if [ ! -f "$dest_file" ] || [ "$mq5_file" -nt "$dest_file" ]; then
            log "  Syncing $filename → $label"
            cp "$mq5_file" "$dest_file"

            if [ -e "$MT5_EDITOR" ]; then
                log "  Compiling $filename..."
                compile_mq5 "$dest_file" || true
            fi
        fi
    done
}

# Sync user-provided EAs from /data volumes
sync_mql5_dir "$EXPERTS_DIR"    "$MT5_MQL5_DIR/Experts"    "Experts"
sync_mql5_dir "$INDICATORS_DIR" "$MT5_MQL5_DIR/Indicators" "Indicators"
sync_mql5_dir "$SCRIPTS_DIR"    "$MT5_MQL5_DIR/Scripts"    "Scripts"

# Sync bundled EAs baked into the image at build time
sync_mql5_dir "/Metatrader/MQL5/Experts"    "$MT5_MQL5_DIR/Experts"    "Experts (bundled)"
sync_mql5_dir "/Metatrader/MQL5/Indicators" "$MT5_MQL5_DIR/Indicators" "Indicators (bundled)"

log "[6/7] MQL5 sync complete."

# ============================================================
# [6b] Symlink signals directory
# ============================================================
WINE_USER="${CUSTOM_USER:-abc}"
COMMON_FILES="$WINEPREFIX/drive_c/users/$WINE_USER/AppData/Roaming/MetaQuotes/Terminal/Common/Files"
mkdir -p "$(dirname "$COMMON_FILES")"

if [ -L "$COMMON_FILES" ]; then
    log "  Signals symlink already in place."
elif [ -d "$COMMON_FILES" ]; then
    # Preserve any existing signal files, then replace dir with symlink
    cp -a "$COMMON_FILES"/. "$SIGNALS_DIR/" 2>/dev/null || true
    rm -rf "$COMMON_FILES"
    ln -s "$SIGNALS_DIR" "$COMMON_FILES"
    log "  Signals directory migrated and symlinked."
else
    ln -s "$SIGNALS_DIR" "$COMMON_FILES"
    log "  Signals directory symlinked."
fi

# ============================================================
# [6c] Symlink logs to /data/logs for easy access
# ============================================================
MT5_MQL5_LOGS="$MT5_MQL5_DIR/logs"
MT5_TERMINAL_LOGS="$WINEPREFIX/drive_c/Program Files/$MT5_INSTALL_DIR_NAME/logs"
mkdir -p "$MT5_MQL5_LOGS"

# Always (re)create relative symlinks so they resolve on host too
ln -sfnr "$MT5_MQL5_LOGS" "$LOGS_DIR/experts"
log "  EA logs symlinked → /data/logs/experts/"
ln -sfnr "$MT5_TERMINAL_LOGS" "$LOGS_DIR/terminal"
log "  Terminal logs symlinked → /data/logs/terminal/"

# Symlink tester logs
MT5_TESTER_DIR="$WINEPREFIX/drive_c/Program Files/$MT5_INSTALL_DIR_NAME/Tester"
mkdir -p "$MT5_TESTER_DIR/logs"
ln -sfnr "$MT5_TESTER_DIR" "$LOGS_DIR/tester"
log "  Tester logs symlinked → /data/logs/tester/"

# Always sync bundled tester.ini → Config dir (for manual podman exec tests)
if [ -f "/Metatrader/tester.ini" ]; then
    cp "/Metatrader/tester.ini" "$DATA_DIR/config/tester.ini"
    cp "/Metatrader/tester.ini" "$MT5_CONFIG_DIR/tester.ini"
    log "  tester.ini synced from image → /data/config/ + Config/"
fi

# ============================================================
# [7/7] Launch MT5 terminal + rpyc server
# ============================================================
if [ -e "$MT5_EXE" ]; then
    cd "$(dirname "$MT5_EXE")"

    if [ "$MT5_MODE" = "tester" ]; then
        log "[7/7] === TESTER MODE ==="

        # Clean stale tester agent data from previous runs
        local tester_dir="$MT5_DIR/Tester"
        if [ -d "$tester_dir/Agent-127.0.0.1-3002/bases" ]; then
            rm -rf "$tester_dir/Agent-127.0.0.1-3002/bases"
            log "[7/7] Cleared stale agent bases cache"
        fi

        # Build single config: [Common] (auth) + [Tester] (testing)
        # Terminal authenticates, syncs, then auto-starts tester in same session
        # (matches desktop behavior where tester runs inside running terminal)
        _login=$(grep -i "^Login=" "$MT5_CONFIG_DIR/auto_login.ini" | head -1 | cut -d= -f2)
        _password=$(grep -i "^Password=" "$MT5_CONFIG_DIR/auto_login.ini" | head -1 | cut -d= -f2)
        _server=$(grep -i "^Server=" "$MT5_CONFIG_DIR/auto_login.ini" | head -1 | cut -d= -f2)
        {
            echo "[Common]"
            echo "Login=${_login}"
            echo "Password=${_password}"
            echo "Server=${_server}"
            echo "KeepPrivate=1"
            echo ""
        } > "$MT5_CONFIG_DIR/tester.ini"
        cat "$DATA_DIR/config/tester.ini" >> "$MT5_CONFIG_DIR/tester.ini"
        log "[7/7] tester.ini built: Login=${_login} Server=${_server}"

        log "[7/7] Launching MT5 with tester config (single session)..."
        mt5_args="/portable /config:${MT5_WIN_CONFIG}\\tester.ini"
        $WINE "$(basename "$MT5_EXE")" $mt5_args $MT5_CMD_OPTIONS &
        MT5_PID=$!

        # Wait for tester to finish (ShutdownTerminal=1 in ini)
        log "[7/7] Waiting for backtest to complete (PID $MT5_PID)..."
        wait $MT5_PID 2>/dev/null || true

        # Check for report
        if ls "$DATA_DIR/reports"/backtest_report* 1>/dev/null 2>&1; then
            log "[7/7] Backtest report saved to /data/reports/"
            ls -la "$DATA_DIR/reports"/backtest_report*
        else
            log "[7/7] WARNING: No report file found in /data/reports/"
        fi

        log "[7/7] Tester run complete."
    else
        log "[7/7] Launching MT5 terminal..."
        mt5_args="/portable"
        if [ -f "$MT5_CONFIG_DIR/auto_login.ini" ]; then
            mt5_args="$mt5_args /config:${MT5_WIN_CONFIG}\\auto_login.ini"
        fi

        $WINE "$(basename "$MT5_EXE")" $mt5_args $MT5_CMD_OPTIONS &
        sleep 20
        log "[7/7] MT5 terminal launched."
    fi
fi

# Only start rpyc in live mode
if [ "$MT5_MODE" != "tester" ]; then
    log "[7/7] Starting rpyc server on port $RPYC_PORT..."
    $WINE python.exe -c "
import rpyc
from rpyc.utils.server import ThreadedServer
server = ThreadedServer(rpyc.ClassicService, hostname='0.0.0.0', port=$RPYC_PORT)
server.start()
" &

    sleep 5
    if ss -tuln | grep -q ":$RPYC_PORT"; then
        log "[7/7] rpyc server running on port $RPYC_PORT"
    else
        log "[7/7] WARNING: rpyc server failed to start on port $RPYC_PORT"
    fi
fi

log "Startup complete."
