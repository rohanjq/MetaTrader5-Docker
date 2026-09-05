# Low-latency tick publisher

`ZeroLatencyTicks.mq5` is the default live-mode EA. It captures the chart symbol in `OnTick()` and immediately writes a fixed binary frame to the local Windows named pipe `\\.\pipe\mt5_ticks`. The bundled Wine-side bridge consumes that pipe and exposes it at `http://localhost:18080` for the generic [`ohlc`](https://github.com/rohanjq/ohlc) service.

The bridge starts before MT5, creates the named-pipe server, and buffers up to 100,000 ticks per symbol. A consumer reads ordered ticks from `GET /ticks?symbol=BTCUSDTp&since_cursor=0`; historical closed bars remain available from `GET /rates`.

## Runtime behavior

- The hot path calls `SymbolInfoTick`, writes one 144-byte frame, and flushes it immediately.
- Pipe connection and reconnection attempts occur in `OnTimer`, not `OnTick`.
- `OnTick` is the primary publisher. A deduplicated 10 ms timer check also
  covers Wine/startup charts that update their tick cache without dispatching
  an `OnTick` event.
- When no receiver is running, ticks are dropped instead of queued or blocking the terminal.
- There is no per-tick logging.
- Attach one EA per chart symbol. Set `MT5_STARTUP_SYMBOL` to choose the default symbol.
- The bridge assigns a strictly increasing receipt-time nanosecond cursor so
  multiple ticks with the same MT5 millisecond timestamp are not lost.

Named-pipe transfer removes network transport latency, but “zero latency” cannot be guaranteed: broker delivery, terminal event scheduling, Wine, and a slow pipe reader still contribute latency. MetaTrader also coalesces new-tick events when an `OnTick` handler is already executing.

## Wire protocol

Frames are little-endian and 144 bytes. The layout is:

| Offset | Type | Field |
|---:|---|---|
| 0 | `uint32` | Magic `0x5435544D` (`MT5T`) |
| 4 | `uint16` | Protocol version (`1`) |
| 6 | `uint16` | Frame size (`144`) |
| 8 | `uint64` | Sequence number |
| 16 | `int64` | Broker Unix time in milliseconds |
| 24 | `uint64` | Monotonic microseconds since EA start |
| 32 | `double` | Bid |
| 40 | `double` | Ask |
| 48 | `double` | Last price |
| 56 | `uint64` | Tick volume |
| 64 | `double` | Real volume |
| 72 | `uint32` | `MQL_TICK_FLAG_*` mask |
| 76 | `uint32` | FNV-1a hash of UTF-16 symbol code units |
| 80 | `uint16[32]` | Zero-terminated UTF-16LE symbol |

The frame’s `captured_us` value is useful for ordering and measuring time inside one EA run. Use `time_msc` for cross-process wall-clock timestamps.

## Configuration

The EA inputs are:

- `INP_PipeName`: defaults to `\\.\pipe\mt5_ticks`.
- `INP_ReconnectMs`: reconnect and fallback-poll interval, default and minimum 10 ms.

The container settings are `MT5_TICK_BRIDGE_ENABLED` (default `true`) and
`MT5_TICK_BRIDGE_PORT` (default `18080`). Configure the OHLC service with:

```dotenv
OHLC_SOURCE=mt5
OHLC_SYMBOLS=BTCUSDTp
OHLC_MT5_BRIDGE=http://host.docker.internal:18080
OHLC_MT5_POLL_INTERVAL=20ms
```

The OHLC engine updates its forming candle for every tick. At a timeframe
boundary it emits a closed candle; its one-second sweep also closes an idle M1
candle even when no new boundary tick arrives. The bridge's `/rates` endpoint
supports cold-start and periodic reconciliation of finalized candles.

To run the trading EA again, set this in `.env`:

```dotenv
MT5_STARTUP_EA=MasterTrader
MT5_STARTUP_PARAMETERS=
```

When the parameter variable is empty, startup generates and selects `MasterTrader.set` from `config.yaml` automatically.
