# Low-latency tick publisher

`ZeroLatencyTicks.mq5` is the default live-mode EA. It captures the chart symbol in `OnTick()` and immediately writes a fixed binary frame to the local Windows named pipe `\\.\pipe\mt5_ticks`.

The receiving application must create the named-pipe server before the EA connects. Because MT5 runs under Wine, a native Windows consumer launched in the same Wine prefix is the direct interoperability path. A Linux-native consumer needs a small Wine-side named-pipe-to-Unix-socket bridge. No network port is opened by this EA.

## Runtime behavior

- The hot path calls `SymbolInfoTick`, writes one 144-byte frame, and flushes it immediately.
- Pipe connection and reconnection attempts occur in `OnTimer`, not `OnTick`.
- `OnTick` is the primary publisher. A deduplicated 10 ms timer check also
  covers Wine/startup charts that update their tick cache without dispatching
  an `OnTick` event.
- When no receiver is running, ticks are dropped instead of queued or blocking the terminal.
- There is no per-tick logging.
- Attach one EA per chart symbol. Set `MT5_STARTUP_SYMBOL` to choose the default symbol.

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

To run the trading EA again, set this in `.env`:

```dotenv
MT5_STARTUP_EA=MasterTrader
MT5_STARTUP_PARAMETERS=
```

When the parameter variable is empty, startup generates and selects `MasterTrader.set` from `config.yaml` automatically.
