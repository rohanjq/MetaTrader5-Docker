#!/usr/bin/env python3
"""Expose ZeroLatencyTicks named-pipe frames to the generic OHLC engine."""

from __future__ import annotations

import argparse
import ctypes
import json
import struct
import threading
import time
from collections import defaultdict, deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

import MetaTrader5 as mt5


PIPE_NAME = r"\\.\pipe\mt5_ticks"
FRAME = struct.Struct("<IHHQqQdddQdII64s")
MAGIC = 0x5435544D
VERSION = 1
ERROR_BROKEN_PIPE = 109
ERROR_PIPE_CONNECTED = 535
MAX_TICKS_PER_SYMBOL = 100_000


class TickBuffer:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._ticks: dict[str, deque[dict]] = defaultdict(
            lambda: deque(maxlen=MAX_TICKS_PER_SYMBOL)
        )
        self._last_cursor = 0
        self.pipe_connected = False

    def set_connected(self, connected: bool) -> None:
        with self._lock:
            self.pipe_connected = connected

    def append(self, frame: bytes) -> None:
        values = FRAME.unpack(frame)
        magic, version, size, sequence, src_ms, captured_us = values[:6]
        if (magic, version, size) != (MAGIC, VERSION, FRAME.size):
            return

        bid, ask, last = values[6:9]
        volume, volume_real, flags = values[9:12]
        symbol = values[13].decode("utf-16le").split("\0", 1)[0]
        if not symbol:
            return

        with self._lock:
            # Wall-clock receipt nanoseconds are both a stable cursor and the
            # OHLC bucket timestamp. Preserve strict ordering on coarse clocks.
            cursor = max(time.time_ns(), self._last_cursor + 1)
            self._last_cursor = cursor
            self._ticks[symbol].append(
                {
                    "cursor": cursor,
                    "seq": sequence,
                    "time_ms": src_ms,
                    "recv_ns": cursor,
                    "captured_us": captured_us,
                    "bid": bid,
                    "ask": ask,
                    "last": last,
                    "volume": volume_real if volume_real > 0 else float(volume),
                    "flags": flags,
                }
            )

    def after(self, symbol: str, cursor: int, limit: int = 5000) -> list[dict]:
        with self._lock:
            return [t.copy() for t in self._ticks.get(symbol, ()) if t["cursor"] > cursor][
                :limit
            ]

    def status(self) -> dict:
        with self._lock:
            return {
                "status": "ok",
                "pipe_connected": self.pipe_connected,
                "latest_cursor": self._last_cursor,
                "symbols": {k: len(v) for k, v in self._ticks.items()},
            }


ticks = TickBuffer()
mt5_lock = threading.Lock()


def pipe_loop(pipe_name: str) -> None:
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.CreateNamedPipeW.argtypes = [
        ctypes.c_wchar_p,
        ctypes.c_uint32,
        ctypes.c_uint32,
        ctypes.c_uint32,
        ctypes.c_uint32,
        ctypes.c_uint32,
        ctypes.c_uint32,
        ctypes.c_void_p,
    ]
    kernel32.CreateNamedPipeW.restype = ctypes.c_void_p
    kernel32.ConnectNamedPipe.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
    kernel32.ConnectNamedPipe.restype = ctypes.c_int
    kernel32.ReadFile.argtypes = [
        ctypes.c_void_p,
        ctypes.c_void_p,
        ctypes.c_uint32,
        ctypes.POINTER(ctypes.c_uint32),
        ctypes.c_void_p,
    ]
    kernel32.ReadFile.restype = ctypes.c_int
    kernel32.DisconnectNamedPipe.argtypes = [ctypes.c_void_p]
    kernel32.CloseHandle.argtypes = [ctypes.c_void_p]
    invalid_handle = ctypes.c_void_p(-1).value

    while True:
        handle = kernel32.CreateNamedPipeW(
            pipe_name,
            0x00000003,  # PIPE_ACCESS_DUPLEX
            0x00000006,  # message type + message read mode + blocking
            1,
            65536,
            65536,
            0,
            None,
        )
        if handle == invalid_handle:
            print(f"tick pipe create failed: {ctypes.get_last_error()}", flush=True)
            time.sleep(1)
            continue

        try:
            if not kernel32.ConnectNamedPipe(handle, None):
                error = ctypes.get_last_error()
                if error != ERROR_PIPE_CONNECTED:
                    time.sleep(0.1)
                    continue
            ticks.set_connected(True)
            print(f"tick pipe connected: {pipe_name}", flush=True)

            while True:
                buf = ctypes.create_string_buffer(FRAME.size)
                read = ctypes.c_uint32()
                if not kernel32.ReadFile(handle, buf, FRAME.size, ctypes.byref(read), None):
                    error = ctypes.get_last_error()
                    if error != ERROR_BROKEN_PIPE:
                        print(f"tick pipe read failed: {error}", flush=True)
                    break
                if read.value != FRAME.size:
                    print(f"tick pipe short frame: {read.value}/{FRAME.size}", flush=True)
                    continue
                ticks.append(buf.raw)
        finally:
            ticks.set_connected(False)
            kernel32.DisconnectNamedPipe(handle)
            kernel32.CloseHandle(handle)


def ensure_mt5() -> None:
    if not mt5.initialize():
        raise RuntimeError(f"mt5.initialize failed: {mt5.last_error()}")


def timeframe_constant(value: str):
    return {
        "1m": mt5.TIMEFRAME_M1,
        "5m": mt5.TIMEFRAME_M5,
        "15m": mt5.TIMEFRAME_M15,
        "30m": mt5.TIMEFRAME_M30,
        "1h": mt5.TIMEFRAME_H1,
        "4h": mt5.TIMEFRAME_H4,
        "1d": mt5.TIMEFRAME_D1,
    }.get(value)


def historical_rates(symbol: str, tf: str, from_ms: int, to_ms: int) -> list[dict]:
    constant = timeframe_constant(tf)
    if constant is None:
        return []
    with mt5_lock:
        ensure_mt5()
        mt5.symbol_select(symbol, True)
        rates = mt5.copy_rates_range(symbol, constant, from_ms // 1000, to_ms // 1000)
    if rates is None:
        return []
    return [
        {
            "open_ms": int(r["time"]) * 1000,
            "open": float(r["open"]),
            "high": float(r["high"]),
            "low": float(r["low"]),
            "close": float(r["close"]),
            "volume": float(r["tick_volume"]),
        }
        for r in rates
    ]


class Handler(BaseHTTPRequestHandler):
    def send_json(self, code: int, payload: dict) -> None:
        body = json.dumps(payload, separators=(",", ":")).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802
        request = urlparse(self.path)
        query = parse_qs(request.query)
        try:
            if request.path == "/ticks":
                symbol = query.get("symbol", [""])[0]
                cursor = int(query.get("since_cursor", ["0"])[0])
                self.send_json(200, {"ticks": ticks.after(symbol, cursor)})
            elif request.path == "/rates":
                self.send_json(
                    200,
                    {
                        "bars": historical_rates(
                            query.get("symbol", [""])[0],
                            query.get("tf", ["1m"])[0],
                            int(query.get("from_ms", ["0"])[0]),
                            int(query.get("to_ms", ["0"])[0]),
                        )
                    },
                )
            elif request.path == "/healthz":
                self.send_json(200, ticks.status())
            else:
                self.send_json(404, {"error": "not found"})
        except Exception as exc:
            self.send_json(500, {"error": str(exc)})

    def log_message(self, *_args) -> None:
        pass


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--addr", default="0.0.0.0:18080")
    parser.add_argument("--pipe", default=PIPE_NAME)
    args = parser.parse_args()
    host, _, port = args.addr.rpartition(":")

    threading.Thread(target=pipe_loop, args=(args.pipe,), daemon=True).start()
    server = ThreadingHTTPServer((host, int(port)), Handler)
    print(f"MT5 tick bridge listening on {args.addr}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
