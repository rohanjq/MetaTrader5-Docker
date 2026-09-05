//+------------------------------------------------------------------+
//| ZeroLatencyTicks.mq5                                             |
//| Publishes every chart tick to a local Windows named pipe.        |
//+------------------------------------------------------------------+
#property copyright "mt5-ea"
#property version   "1.00"
#property strict
#property description "Low-latency binary tick publisher over a local named pipe"

input string INP_PipeName       = "\\\\.\\pipe\\mt5_ticks";
input int    INP_ReconnectMs    = 100;

#define TICK_MAGIC        0x5435544D // "MT5T" when read as little-endian bytes
#define TICK_VERSION      1
#define TICK_SYMBOL_CHARS 32

// Fixed 144-byte, little-endian wire frame. All fields are naturally aligned,
// so MetaTrader and a normal 64-bit C/C++ consumer use the same layout.
struct TickFrame
{
   uint   magic;                         // 0
   ushort version;                       // 4
   ushort frame_size;                    // 6
   ulong  sequence;                      // 8
   long   time_msc;                      // 16: broker Unix epoch milliseconds
   ulong  captured_us;                   // 24: monotonic microseconds since EA start
   double bid;                           // 32
   double ask;                           // 40
   double last;                          // 48
   ulong  volume;                        // 56
   double volume_real;                   // 64
   uint   flags;                         // 72: MQL_TICK_FLAG_* bit mask
   uint   symbol_hash;                   // 76: FNV-1a of UTF-16 symbol code units
   ushort symbol[TICK_SYMBOL_CHARS];     // 80: zero-terminated UTF-16LE
};

int       g_pipe = INVALID_HANDLE;
ulong     g_sequence = 0;
TickFrame g_frame;

uint SymbolHash(const string value)
{
   uint hash = 2166136261;
   const int length = StringLen(value);

   for(int i = 0; i < length; ++i)
   {
      const uint code = StringGetCharacter(value, i);
      hash = (hash ^ (code & 0xFF)) * 16777619;
      hash = (hash ^ ((code >> 8) & 0xFF)) * 16777619;
   }
   return hash;
}

void SetFrameSymbol(const string value)
{
   for(int i = 0; i < TICK_SYMBOL_CHARS; ++i)
      g_frame.symbol[i] = 0;

   const int count = MathMin(StringLen(value), TICK_SYMBOL_CHARS - 1);
   for(int i = 0; i < count; ++i)
      g_frame.symbol[i] = (ushort)StringGetCharacter(value, i);

   g_frame.symbol_hash = SymbolHash(value);
}

void DisconnectPipe()
{
   if(g_pipe != INVALID_HANDLE)
   {
      FileClose(g_pipe);
      g_pipe = INVALID_HANDLE;
   }
}

void ConnectPipe()
{
   if(g_pipe != INVALID_HANDLE)
      return;

   ResetLastError();
   g_pipe = FileOpen(INP_PipeName, FILE_READ | FILE_WRITE | FILE_BIN);
   if(g_pipe == INVALID_HANDLE)
      ResetLastError(); // A consumer/server is not running yet; retry on the timer.
}

int OnInit()
{
   g_frame.magic = TICK_MAGIC;
   g_frame.version = TICK_VERSION;
   g_frame.frame_size = (ushort)sizeof(g_frame);
   SetFrameSymbol(_Symbol);

   const int reconnect_ms = MathMax(INP_ReconnectMs, 10);
   if(!EventSetMillisecondTimer(reconnect_ms))
      return INIT_FAILED;

   ConnectPipe();
   PrintFormat("ZeroLatencyTicks ready: symbol=%s pipe=%s frame=%u bytes",
               _Symbol, INP_PipeName, sizeof(g_frame));
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   DisconnectPipe();
}

void OnTimer()
{
   ConnectPipe();
}

void OnTick()
{
   // Never attempt a connection here: opening a missing pipe belongs off the
   // latency-sensitive path and is handled by OnTimer().
   if(g_pipe == INVALID_HANDLE)
      return;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;

   g_frame.sequence = ++g_sequence;
   g_frame.time_msc = tick.time_msc;
   g_frame.captured_us = GetMicrosecondCount();
   g_frame.bid = tick.bid;
   g_frame.ask = tick.ask;
   g_frame.last = tick.last;
   g_frame.volume = tick.volume;
   g_frame.volume_real = tick.volume_real;
   g_frame.flags = tick.flags;

   ResetLastError();
   const uint written = FileWriteStruct(g_pipe, g_frame);
   FileFlush(g_pipe); // Push this frame immediately; do not wait for file buffering.

   if(written != sizeof(g_frame) || GetLastError() != 0)
      DisconnectPipe();
}
