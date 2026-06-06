from mt5linux import MetaTrader5
import time

# Connect to the rpyc server running in the container
mt5 = MetaTrader5(host='localhost', port=8001)

# Initialize MT5 — add your PXBT credentials here
if not mt5.initialize(login=YOUR_LOGIN, password="YOUR_PASSWORD", server="YOUR_SERVER"):
    print(f"initialize() failed: {mt5.last_error()}")
    quit()

print(f"MT5 version: {mt5.version()}")
print(f"Terminal info: {mt5.terminal_info()}")

# Get gold ticker info
symbol = "XAUUSD"
info = mt5.symbol_info(symbol)
if info is None:
    print(f"Symbol {symbol} not found, trying to add it...")
    if not mt5.symbol_select(symbol, True):
        print(f"Failed to select {symbol}: {mt5.last_error()}")
        mt5.shutdown()
        quit()
    info = mt5.symbol_info(symbol)

print(f"\n--- {symbol} Info ---")
print(f"Bid: {info.bid}")
print(f"Ask: {info.ask}")
print(f"Spread: {info.spread}")
print(f"Point: {info.point}")

# Get last 5 ticks
ticks = mt5.copy_ticks_from(symbol, mt5.COPY_TICKS_ALL, 0, 5)
if ticks is not None and len(ticks) > 0:
    print(f"\nLast {len(ticks)} ticks:")
    for t in ticks:
        print(f"  time={t.time}, bid={t.bid}, ask={t.ask}")

mt5.shutdown()
print("\nDone.")
