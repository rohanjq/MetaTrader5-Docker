from mt5linux import MetaTrader5

mt5 = MetaTrader5(host="127.0.0.1", port=8001)

if not mt5.initialize(path=r"C:\Program Files\PXBT Trading MT5 Terminal\terminal64.exe"):
    print("init failed:", mt5.last_error())
    quit()

symbol = "BTCUSD"
mt5.symbol_select(symbol, True)

info = mt5.symbol_info(symbol)
if info is None:
    print(f"Symbol {symbol} not found")
    mt5.shutdown()
    quit()

print(f"Symbol: {symbol}, Bid: {info.bid}, Ask: {info.ask}")

request = {
    "action": mt5.TRADE_ACTION_DEAL,
    "symbol": symbol,
    "volume": 0.001,
    "type": mt5.ORDER_TYPE_BUY,
    "price": info.ask,
    "deviation": 20,
    "magic": 100,
    "comment": "test buy",
    "type_time": mt5.ORDER_TIME_GTC,
    "type_filling": mt5.ORDER_FILLING_IOC,
}

result = mt5.order_send(request)
print(f"Order result: {result}")

mt5.shutdown()
