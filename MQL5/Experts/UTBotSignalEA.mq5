//+------------------------------------------------------------------+
//|                                                  UTBotSignalEA.mq5 |
//|                              UT Bot Alerts - ATR Trailing Stop     |
//|                              EA version - auto-starts via config   |
//+------------------------------------------------------------------+
#property copyright "MT5-Docker"
#property version   "1.00"

//--- Input parameters
input int      ATR_Period    = 10;        // ATR Period
input double   ATR_Mult      = 2.0;       // ATR Multiplier
input int      WriteInterval = 5;         // File write interval (seconds)
input string   OutputFile    = "ut_bot_signals.csv"; // Output file name

//--- ATR handle
int atr_handle;

//--- Trail stop arrays (ring buffer of last N bars)
double TrailStop[];
double Direction[];
int    calc_bars = 0;

//--- Signal tracking
datetime last_buy_signal_time  = 0;
double   last_buy_signal_price = 0;
datetime last_sell_signal_time = 0;
double   last_sell_signal_price = 0;
int      bars_since_signal = 0;
int      consecutive_bull = 0;
int      consecutive_bear = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   atr_handle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
   if(atr_handle == INVALID_HANDLE)
   {
      Print("Failed to create ATR handle");
      return(INIT_FAILED);
   }

   EventSetTimer(WriteInterval);
   Print("UTBotSignalEA started on ", _Symbol, " ", EnumToString(Period()),
         " ATR(", ATR_Period, ") x", DoubleToString(ATR_Mult, 1));

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   if(atr_handle != INVALID_HANDLE)
      IndicatorRelease(atr_handle);
   Print("UTBotSignalEA stopped");
}

//+------------------------------------------------------------------+
void OnTick()
{
   Calculate();
}

//+------------------------------------------------------------------+
void OnTimer()
{
   Calculate();
   WriteSignalFile();
}

//+------------------------------------------------------------------+
void Calculate()
{
   int total = Bars(_Symbol, PERIOD_CURRENT);
   if(total < ATR_Period + 2) return;

   //--- Get all close prices
   double close[];
   ArraySetAsSeries(close, false);
   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, total, close) <= 0) return;

   //--- Get ATR values
   double atr[];
   ArraySetAsSeries(atr, false);
   if(CopyBuffer(atr_handle, 0, 0, total, atr) <= 0) return;

   //--- Get bar times for signal tracking
   datetime time[];
   ArraySetAsSeries(time, false);
   if(CopyTime(_Symbol, PERIOD_CURRENT, 0, total, time) <= 0) return;

   //--- Resize arrays if needed
   if(ArraySize(TrailStop) != total)
   {
      ArrayResize(TrailStop, total);
      ArrayResize(Direction, total);
      calc_bars = 0; // Force full recalculation
   }

   //--- Calculate starting point
   int start;
   if(calc_bars == 0)
   {
      for(int i = 0; i < ATR_Period && i < total; i++)
      {
         TrailStop[i] = close[i];
         Direction[i] = 1;
      }
      if(ATR_Period < total)
      {
         TrailStop[ATR_Period] = close[ATR_Period];
         Direction[ATR_Period] = 1;
      }
      start = ATR_Period + 1;
   }
   else
   {
      start = calc_bars - 1;
   }

   //--- Main calculation loop
   for(int i = start; i < total; i++)
   {
      double nLoss = ATR_Mult * atr[i];
      double prev_stop = TrailStop[i - 1];
      double prev_dir  = Direction[i - 1];

      double new_stop;

      if(close[i] > prev_stop)
      {
         new_stop = close[i] - nLoss;
         if(prev_dir > 0)
            new_stop = MathMax(new_stop, prev_stop);
         Direction[i] = 1;
      }
      else
      {
         new_stop = close[i] + nLoss;
         if(prev_dir < 0)
            new_stop = MathMin(new_stop, prev_stop);
         Direction[i] = -1;
      }

      TrailStop[i] = new_stop;

      //--- Detect signal flips
      if(Direction[i] > 0 && prev_dir < 0)
      {
         last_buy_signal_time  = time[i];
         last_buy_signal_price = close[i];
         consecutive_bull = 1;
         consecutive_bear = 0;
         bars_since_signal = 0;
      }
      else if(Direction[i] < 0 && prev_dir > 0)
      {
         last_sell_signal_time  = time[i];
         last_sell_signal_price = close[i];
         consecutive_bear = 1;
         consecutive_bull = 0;
         bars_since_signal = 0;
      }
      else
      {
         bars_since_signal++;
         if(Direction[i] > 0) consecutive_bull++;
         else                  consecutive_bear++;
      }
   }

   calc_bars = total;
}

//+------------------------------------------------------------------+
void WriteSignalFile()
{
   int total = ArraySize(TrailStop);
   if(total < ATR_Period + 2 || calc_bars == 0) return;

   int last = total - 1;

   //--- ATR value
   double atr_val[];
   if(CopyBuffer(atr_handle, 0, 0, 1, atr_val) <= 0) return;

   //--- Current bar
   MqlRates rates[];
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, rates) <= 0) return;

   //--- Current tick
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;

   double cur_trail = TrailStop[last];
   double cur_dir   = Direction[last];

   //--- Distance from trail stop
   double dist_from_trail = tick.bid - cur_trail;
   double dist_pct = (cur_trail != 0) ? (dist_from_trail / cur_trail) * 100.0 : 0;

   string current_bias = (cur_dir > 0) ? "BULLISH" : "BEARISH";
   string last_signal_type = "";
   datetime last_signal_time_val = 0;
   double last_signal_price_val = 0;

   if(last_buy_signal_time > last_sell_signal_time)
   {
      last_signal_type = "BUY";
      last_signal_time_val = last_buy_signal_time;
      last_signal_price_val = last_buy_signal_price;
   }
   else if(last_sell_signal_time > 0)
   {
      last_signal_type = "SELL";
      last_signal_time_val = last_sell_signal_time;
      last_signal_price_val = last_sell_signal_price;
   }

   double move_since_signal = 0;
   if(last_signal_price_val > 0)
      move_since_signal = tick.bid - last_signal_price_val;

   //--- Write CSV
   int handle = FileOpen(OutputFile, FILE_WRITE | FILE_CSV | FILE_COMMON, ',');
   if(handle == INVALID_HANDLE)
   {
      Print("Failed to open file: ", OutputFile, " Error: ", GetLastError());
      return;
   }

   FileWrite(handle, "key", "value");

   FileWrite(handle, "symbol",              _Symbol);
   FileWrite(handle, "timeframe",           EnumToString(Period()));
   FileWrite(handle, "server_time",         TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS));
   FileWrite(handle, "local_time",          TimeToString(TimeLocal(), TIME_DATE | TIME_SECONDS));

   FileWrite(handle, "bid",                 DoubleToString(tick.bid, _Digits));
   FileWrite(handle, "ask",                 DoubleToString(tick.ask, _Digits));
   FileWrite(handle, "spread",              DoubleToString(tick.ask - tick.bid, _Digits));

   FileWrite(handle, "bar_open",            DoubleToString(rates[0].open, _Digits));
   FileWrite(handle, "bar_high",            DoubleToString(rates[0].high, _Digits));
   FileWrite(handle, "bar_low",             DoubleToString(rates[0].low, _Digits));
   FileWrite(handle, "bar_close",           DoubleToString(rates[0].close, _Digits));
   FileWrite(handle, "bar_time",            TimeToString(rates[0].time, TIME_DATE | TIME_SECONDS));
   FileWrite(handle, "bar_volume",          IntegerToString(rates[0].tick_volume));

   FileWrite(handle, "atr_value",           DoubleToString(atr_val[0], _Digits));
   FileWrite(handle, "atr_nloss",           DoubleToString(atr_val[0] * ATR_Mult, _Digits));
   FileWrite(handle, "trail_stop",          DoubleToString(cur_trail, _Digits));
   FileWrite(handle, "current_bias",        current_bias);
   FileWrite(handle, "dist_from_trail",     DoubleToString(dist_from_trail, _Digits));
   FileWrite(handle, "dist_from_trail_pct", DoubleToString(dist_pct, 4));

   FileWrite(handle, "last_signal_type",    last_signal_type);
   FileWrite(handle, "last_signal_time",    (last_signal_time_val > 0) ? TimeToString(last_signal_time_val, TIME_DATE | TIME_SECONDS) : "NONE");
   FileWrite(handle, "last_signal_price",   (last_signal_price_val > 0) ? DoubleToString(last_signal_price_val, _Digits) : "0");
   FileWrite(handle, "bars_since_signal",   IntegerToString(bars_since_signal));
   FileWrite(handle, "move_since_signal",   DoubleToString(move_since_signal, _Digits));

   FileWrite(handle, "consecutive_bull_bars", IntegerToString(consecutive_bull));
   FileWrite(handle, "consecutive_bear_bars", IntegerToString(consecutive_bear));

   FileWrite(handle, "last_buy_time",       (last_buy_signal_time > 0) ? TimeToString(last_buy_signal_time, TIME_DATE | TIME_SECONDS) : "NONE");
   FileWrite(handle, "last_buy_price",      DoubleToString(last_buy_signal_price, _Digits));
   FileWrite(handle, "last_sell_time",      (last_sell_signal_time > 0) ? TimeToString(last_sell_signal_time, TIME_DATE | TIME_SECONDS) : "NONE");
   FileWrite(handle, "last_sell_price",     DoubleToString(last_sell_signal_price, _Digits));

   FileClose(handle);
}
//+------------------------------------------------------------------+
