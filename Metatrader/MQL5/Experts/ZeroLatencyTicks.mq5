//+------------------------------------------------------------------+
//| ZeroLatencyTicks.mq5                                             |
//| Publishes every chart tick to a local Windows named pipe.        |
//+------------------------------------------------------------------+
#property copyright "mt5-ea"
#property version   "1.00"
#property strict
#property description "Low-latency binary tick publisher over a local named pipe"

input string INP_PipeName       = "\\\\.\\pipe\\mt5_ticks";
input int    INP_ReconnectMs    = 10;
input string INP_Symbols        = ""; // comma-separated; empty = chart symbol

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
int       g_last_connect_error = 0;
bool      g_logged_first_tick = false;
string    g_symbols[];
long      g_last_time_msc[];
double    g_last_bid[];
double    g_last_ask[];
double    g_last_last[];
double    g_last_volume_real[];
ulong     g_last_volume[];
uint      g_last_flags[];
int       g_chart_symbol_index = -1;

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
   {
      const int error = GetLastError();
      // A missing server is normal. Log only when the state changes so a bad
      // pipe path or permissions problem remains diagnosable without spam.
      if(error != g_last_connect_error)
         PrintFormat("ZeroLatencyTicks waiting for pipe: %s (error %d)",
                     INP_PipeName, error);
      g_last_connect_error = error;
      ResetLastError();
      return;
   }

   g_last_connect_error = 0;
   PrintFormat("ZeroLatencyTicks connected: %s", INP_PipeName);
}

int OnInit()
{
   g_frame.magic = TICK_MAGIC;
   g_frame.version = TICK_VERSION;
   g_frame.frame_size = (ushort)sizeof(g_frame);

   string configured = INP_Symbols;
   StringTrimLeft(configured);
   StringTrimRight(configured);
   if(configured == "")
   {
      ArrayResize(g_symbols, 1);
      g_symbols[0] = _Symbol;
   }
   else
   {
      string parsed[];
      const int parsed_count = StringSplit(configured, (ushort)',', parsed);
      ArrayResize(g_symbols, parsed_count + 1);
      int count = 0;
      for(int i = 0; i < parsed_count; ++i)
      {
         string symbol = parsed[i];
         StringTrimLeft(symbol);
         StringTrimRight(symbol);
         if(symbol == "")
            continue;
         g_symbols[count++] = symbol;
      }
      ArrayResize(g_symbols, count);
   }

   const int symbol_count = ArraySize(g_symbols);
   if(symbol_count == 0)
      return INIT_PARAMETERS_INCORRECT;
   ArrayResize(g_last_time_msc, symbol_count);
   ArrayResize(g_last_bid, symbol_count);
   ArrayResize(g_last_ask, symbol_count);
   ArrayResize(g_last_last, symbol_count);
   ArrayResize(g_last_volume, symbol_count);
   ArrayResize(g_last_volume_real, symbol_count);
   ArrayResize(g_last_flags, symbol_count);
   for(int i = 0; i < symbol_count; ++i)
   {
      g_last_time_msc[i] = -1;
      if(!SymbolSelect(g_symbols[i], true))
         PrintFormat("ZeroLatencyTicks cannot select symbol: %s error=%d",
                     g_symbols[i], GetLastError());
      if(g_symbols[i] == _Symbol)
         g_chart_symbol_index = i;
   }

   const int reconnect_ms = MathMax(INP_ReconnectMs, 10);
   if(!EventSetMillisecondTimer(reconnect_ms))
      return INIT_FAILED;

   ConnectPipe();
   PrintFormat("ZeroLatencyTicks ready: symbols=%s pipe=%s frame=%u bytes",
               INP_Symbols == "" ? _Symbol : INP_Symbols,
               INP_PipeName, sizeof(g_frame));
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
   for(int i = 0; i < ArraySize(g_symbols); ++i)
      PublishLatestTick(g_symbols[i], i);
}

void PublishLatestTick(const string symbol, const int index)
{
   if(g_pipe == INVALID_HANDLE)
      return;

   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick))
      return;

   // OnTick is the primary path. The 10 ms timer also calls this function as
   // a Wine/startup-chart fallback, but this identity check prevents repeats.
   if(tick.time_msc == g_last_time_msc[index] &&
      tick.bid == g_last_bid[index] && tick.ask == g_last_ask[index] &&
      tick.last == g_last_last[index] && tick.volume == g_last_volume[index] &&
      tick.volume_real == g_last_volume_real[index] &&
      tick.flags == g_last_flags[index])
      return;

   SetFrameSymbol(symbol);
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
   const int error = GetLastError();

   if(!g_logged_first_tick)
   {
      PrintFormat("ZeroLatencyTicks first tick: sequence=%I64u written=%u error=%d",
                  g_frame.sequence, written, error);
      g_logged_first_tick = true;
   }

   if(written != sizeof(g_frame) || error != 0)
   {
      PrintFormat("ZeroLatencyTicks pipe write failed: written=%u expected=%u error=%d",
                  written, sizeof(g_frame), error);
      DisconnectPipe();
      return;
   }

   // Mark a quote delivered only after the entire frame was accepted. A pipe
   // reconnect therefore re-sends the latest quote instead of losing it.
   g_last_time_msc[index] = tick.time_msc;
   g_last_bid[index] = tick.bid;
   g_last_ask[index] = tick.ask;
   g_last_last[index] = tick.last;
   g_last_volume[index] = tick.volume;
   g_last_volume_real[index] = tick.volume_real;
   g_last_flags[index] = tick.flags;
}

void OnTick()
{
   // Never attempt a connection here: opening a missing pipe belongs off the
   // latency-sensitive path and is handled by OnTimer().
   if(g_chart_symbol_index >= 0)
      PublishLatestTick(_Symbol, g_chart_symbol_index);
}
