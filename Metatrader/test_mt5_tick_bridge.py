import struct
import tempfile
import unittest

from Metatrader.mt5_tick_bridge import FRAME, MAGIC, VERSION, TickBuffer


def frame(seq: int, source_ms: int, bid: float) -> bytes:
    symbol = "BTCUSDTp".encode("utf-16le").ljust(64, b"\0")
    return FRAME.pack(
        MAGIC,
        VERSION,
        FRAME.size,
        seq,
        source_ms,
        123,
        bid,
        bid + 2,
        bid + 1,
        3,
        3.0,
        1,
        0,
        symbol,
    )


class TickBufferTest(unittest.TestCase):
    def test_journal_survives_restart_and_detects_invalid_cursor(self):
        with tempfile.TemporaryDirectory() as directory:
            path = directory + "/bridge.sqlite3"
            first = TickBuffer(path)
            first.append(frame(1, 1_700_000_000_001, 100))
            first.append(frame(2, 1_700_000_000_002, 101))
            initial = first.after("BTCUSDTp", 0)
            self.assertEqual([1, 2], [tick["seq"] for tick in initial["ticks"]])
            cursor = initial["ticks"][0]["cursor"]
            latest = initial["latest_cursor"]
            first.close()

            restored = TickBuffer(path)
            remaining = restored.after("BTCUSDTp", cursor)
            self.assertEqual([2], [tick["seq"] for tick in remaining["ticks"]])
            gap = restored.after("BTCUSDTp", latest + 1)
            self.assertTrue(gap["gap"])
            self.assertEqual(latest, gap["latest_cursor"])
            restored.close()


if __name__ == "__main__":
    unittest.main()
