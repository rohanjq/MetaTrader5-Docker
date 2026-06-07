#!/bin/bash

# Configuration variables
mt5file='/config/.wine/drive_c/Program Files/PXBT Trading MT5 Terminal/terminal64.exe'
WINEPREFIX='/config/.wine'
WINEDEBUG='-all'
wine_executable="wine"
mt5server_port="8001"
MT5_CMD_OPTIONS="${MT5_CMD_OPTIONS:-}"
MT5_LOGIN="${MT5_LOGIN:-}"
MT5_PASSWORD="${MT5_PASSWORD:-}"
MT5_SERVER="${MT5_SERVER:-}"
mono_url="https://dl.winehq.org/wine/wine-mono/10.3.0/wine-mono-10.3.0-x86.msi"
python_url="https://www.python.org/ftp/python/3.9.13/python-3.9.13-amd64.exe"
mt5setup_url="https://download.terminal.free/cdn/web/pxbt.trading.ltd/mt5/pxbttrading5setup.exe"

# Function to display a graphical message
show_message() {
    echo $1
}

# Function to check if a dependency is installed
check_dependency() {
    if ! command -v $1 &> /dev/null; then
        echo "$1 is not installed. Please install it to continue."
        exit 1
    fi
}

# Function to check if a Python package is installed
is_python_package_installed() {
    python3 -c "import pkg_resources; exit(not pkg_resources.require('$1'))" 2>/dev/null
    return $?
}

# Function to check if a Python package is installed in Wine
is_wine_python_package_installed() {
    $wine_executable python -c "import pkg_resources; exit(not pkg_resources.require('$1'))" 2>/dev/null
    return $?
}

# Check for necessary dependencies
check_dependency "curl"
check_dependency "$wine_executable"

# Install Mono if not present
if [ ! -e "/config/.wine/drive_c/windows/mono" ]; then
    show_message "[1/7] Downloading and installing Mono..."
    curl -o /tmp/mono.msi $mono_url
    WINEDLLOVERRIDES=mscoree=d $wine_executable msiexec /i /tmp/mono.msi /qn
    rm -f /tmp/mono.msi
    show_message "[1/7] Mono installed."
else
    show_message "[1/7] Mono is already installed."
fi

# Check if MetaTrader 5 is already installed
if [ -e "$mt5file" ]; then
    show_message "[2/7] File $mt5file already exists."
else
    show_message "[2/7] File $mt5file is not installed. Installing..."

    # Set Windows 10 mode in Wine and download and install MT5
    $wine_executable reg add "HKEY_CURRENT_USER\\Software\\Wine" /v Version /t REG_SZ /d "win10" /f
    show_message "[3/7] Downloading MT5 installer..."
    curl -o /tmp/mt5setup.exe $mt5setup_url
    show_message "[3/7] Installing MetaTrader 5..."
    $wine_executable /tmp/mt5setup.exe /auto
    sleep 30
    rm -f /tmp/mt5setup.exe
fi

# Recheck if MetaTrader 5 is installed
if [ ! -e "$mt5file" ]; then
    show_message "[4/7] File $mt5file is not installed. MT5 cannot be run."
fi


# Install Python in Wine if not present
if ! $wine_executable python --version 2>/dev/null; then
    show_message "[5/7] Installing Python in Wine..."
    curl -L $python_url -o /tmp/python-installer.exe
    $wine_executable /tmp/python-installer.exe /quiet InstallAllUsers=1 PrependPath=1
    rm /tmp/python-installer.exe
    show_message "[5/7] Python installed in Wine."
else
    show_message "[5/7] Python is already installed in Wine."
fi

# Upgrade pip and install required packages
show_message "[6/7] Installing Python libraries"
$wine_executable python -m pip install --upgrade --no-cache-dir pip
# Install MetaTrader5 library in Windows if not installed
show_message "[6/7] Installing MetaTrader5 library in Windows"
if ! is_wine_python_package_installed "MetaTrader5"; then
    $wine_executable python -m pip install --no-cache-dir "numpy<2" MetaTrader5
fi
# Install rpyc in Wine for the classic server
show_message "[6/7] Checking and installing rpyc library in Windows if necessary"
if ! is_wine_python_package_installed "rpyc"; then
    $wine_executable python -m pip install --no-cache-dir "rpyc==5.3.1"
fi

# Install python-dateutil if needed (datetime is built-in, but dateutil adds features)
if ! is_wine_python_package_installed "python-dateutil"; then
    show_message "[6/7] Installing python-dateutil library in Windows"
    $wine_executable python -m pip install --no-cache-dir python-dateutil
fi

# Configure MT5 for API access
mt5config_dir=$(dirname "$mt5file")/Config
mt5_win_config_dir='C:\Program Files\PXBT Trading MT5 Terminal\Config'
if [ -d "$mt5config_dir" ]; then
    show_message "[6/7] Configuring MT5 for API access..."
    # Create common.ini if it doesn't exist
    touch "$mt5config_dir/common.ini"
    # Ensure common.ini has required settings
    grep -q "ExpertEnabled" "$mt5config_dir/common.ini" || echo "ExpertEnabled=1" >> "$mt5config_dir/common.ini"
    grep -q "ExpertDllImport" "$mt5config_dir/common.ini" || echo "ExpertDllImport=1" >> "$mt5config_dir/common.ini"
    grep -q "ExpertAllowLive" "$mt5config_dir/common.ini" || echo "ExpertAllowLive=1" >> "$mt5config_dir/common.ini"
    grep -q "AutoTrading" "$mt5config_dir/common.ini" || echo "AutoTrading=1" >> "$mt5config_dir/common.ini"

    # Write account config if credentials are provided
    if [ -n "$MT5_LOGIN" ] && [ -n "$MT5_PASSWORD" ] && [ -n "$MT5_SERVER" ]; then
        show_message "[6/7] Writing account credentials to config..."
        cat > "$mt5config_dir/auto_login.ini" <<EOINI
[Common]
Login=$MT5_LOGIN
Password=$MT5_PASSWORD
Server=$MT5_SERVER
EnableAutoTrading=1
EnableDDE=0
EOINI
    fi
fi

# Now launch the terminal (after Python packages are installed)
if [ -e "$mt5file" ]; then
    show_message "[6/7] Launching MT5 terminal..."
    mt5_args="/portable"
    if [ -f "$mt5config_dir/auto_login.ini" ]; then
        mt5_args="$mt5_args /config:${mt5_win_config_dir}\\auto_login.ini"
    fi
    $wine_executable "$mt5file" $mt5_args $MT5_CMD_OPTIONS &
    sleep 20
    show_message "[6/7] MT5 terminal launched."
fi

# Install mt5linux library in Linux if not installed (client-side proxy)
show_message "[6/7] Checking and installing mt5linux library in Linux if necessary"
if ! is_python_package_installed "mt5linux"; then
    pip install --break-system-packages --no-cache-dir mt5linux "rpyc==5.3.1"
fi

# Install pyxdg library in Linux if not installed
show_message "[6/7] Checking and installing pyxdg library in Linux if necessary"
if ! is_python_package_installed "pyxdg"; then
    pip install --break-system-packages --no-cache-dir pyxdg
fi

# Start the rpyc ClassicServer under Wine Python so it can access MetaTrader5
show_message "[7/7] Starting the rpyc classic server via Wine Python..."
$wine_executable python.exe -c "
import rpyc
from rpyc.utils.server import ThreadedServer
server = ThreadedServer(rpyc.ClassicService, hostname='0.0.0.0', port=$mt5server_port)
server.start()
" &

# Give the server some time to start
sleep 5

# Check if the server is running
if ss -tuln | grep ":$mt5server_port" > /dev/null; then
    show_message "[7/7] The mt5linux server is running on port $mt5server_port."
else
    show_message "[7/7] Failed to start the mt5linux server on port $mt5server_port."
fi
