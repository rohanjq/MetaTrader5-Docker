//+------------------------------------------------------------------+
//|                                                 UTBotSignals.mq5 |
//|                              UT Bot Alerts - ATR Trailing Stop   |
//|                              Writes signals to file for Python   |
//+------------------------------------------------------------------+
#property copyright "MT5-Docker"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   2

//--- Plot trailing stop line (bullish = green, bearish = red)
#property indicator_label1  "UT Trail Up"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLime
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "UT Trail Down"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Input parameters
input int      ATR_Period    = 10;        // ATR Period
input double   ATR_Mult      = 2.0;       // ATR Multiplier
input int      WriteInterval = 5;         // File write interval (seconds)
input string   OutputFile    = "ut_bot_signals.csv"; // Output file name

//--- Indicator buffers
double TrailUpBuffer[];
double TrailDownBuffer[];
double TrailStopBuffer[];   // Internal: actual trail stop value
double DirectionBuffer[];   // Internal: 1=bullish, -1=bearish

//--- ATR handle
int atr_handle;

//--- File write timer
datetime last_write_time = 0;

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
   SetIndexBuffer(0, TrailUpBuffer,   INDICATOR_DATA);
   SetIndexBuffer(1, TrailDownBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, TrailStopBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, DirectionBuffer, INDICATOR_CALCULATIONS);

   ArraySetAsSeries(TrailUpBuffer,   false);
   ArraySetAsSeries(TrailDownBuffer, false);
   ArraySetAsSeries(TrailStopBuffer, false);
   ArraySetAsSeries(DirectionBuffer, false);

   atr_handle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
   if(atr_handle == INVALID_HANDLE)
   {
      Print("Failed to create ATR handle");
      return(INIT_FAILED);
   }

   IndicatorSetString(INDICATOR_SHORTNAME, "UT Bot(" +
                      IntegerToString(ATR_Period) + "," +
                      DoubleToString(ATR_Mult, 1) + ")");

   EventSetTimer(WriteInterval);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   if(atr_handle != INVALID_HANDLE)
      IndicatorRelease(atr_handle);
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   //--- Get ATR values
   double atr[];
   ArraySetAsSeries(atr, false);

   if(CopyBuffer(atr_handle, 0, 0, rates_total, atr) <= 0)
      return(0);

   //--- Calculate starting point
   int start = (prev_calculated > 0) ? prev_calculated - 1 : ATR_Period;

   //--- Initialize first bar
   if(prev_calculated == 0)
   {
      for(int i = 0; i < ATR_Period && i < rates_total; i++)
      {
         TrailUpBuffer[i]   = EMPTY_VALUE;
         TrailDownBuffer[i] = EMPTY_VALUE;
         TrailStopBuffer[i] = close[i];
         DirectionBuffer[i] = 1;
      }
      if(ATR_Period < rates_total)
      {
         TrailStopBuffer[ATR_Period] = close[ATR_Period];
         DirectionBuffer[ATR_Period] = 1;
         TrailUpBuffer[ATR_Period]   = close[ATR_Period];
         TrailDownBuffer[ATR_Period] = EMPTY_VALUE;
      }
      start = ATR_Period + 1;
   }

   //--- Main calculation loop
   for(int i = start; i < rates_total; i++)
   {
      double nLoss = ATR_Mult * atr[i];
      double prev_stop = TrailStopBuffer[i - 1];
      double prev_dir  = DirectionBuffer[i - 1];

      double new_stop;

      if(close[i] > prev_stop)
      {
         // Price above trail -> bullish
         new_stop = close[i] - nLoss;
         if(prev_dir > 0)
            new_stop = MathMax(new_stop, prev_stop); // Ratchet up
         DirectionBuffer[i] = 1;
      }
      else
      {
         // Price below trail -> bearish
         new_stop = close[i] + nLoss;
         if(prev_dir < 0)
            new_stop = MathMin(new_stop, prev_stop); // Ratchet down
         DirectionBuffer[i] = -1;
      }

      TrailStopBuffer[i] = new_stop;

      //--- Set plot buffers
      if(DirectionBuffer[i] > 0)
      {
         TrailUpBuffer[i]   = new_stop;
         TrailDownBuffer[i] = EMPTY_VALUE;
      }
      else
      {
         TrailUpBuffer[i]   = EMPTY_VALUE;
         TrailDownBuffer[i] = new_stop;
      }

      //--- Detect signal flips
      if(DirectionBuffer[i] > 0 && prev_dir < 0)
      {
         // BUY signal
         last_buy_signal_time  = time[i];
         last_buy_signal_price = close[i];
         consecutive_bull = 1;
         consecutive_bear = 0;
         bars_since_signal = 0;
      }
      else if(DirectionBuffer[i] < 0 && prev_dir > 0)
      {
         // SELL signal
         last_sell_signal_time  = time[i];
         last_sell_signal_price = close[i];
         consecutive_bear = 1;
         consecutive_bull = 0;
         bars_since_signal = 0;
      }
      else
      {
         bars_since_signal++;
         if(DirectionBuffer[i] > 0) consecutive_bull++;
         else                       consecutive_bear++;
      }
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
void OnTimer()
{
   WriteSignalFile();
}

//+------------------------------------------------------------------+
void WriteSignalFile()
{
   int total = Bars(_Symbol, PERIOD_CURRENT);
   if(total < ATR_Period + 2) return;

   //--- Current bar data
   int last = total - 1;
   double atr_val[];
   if(CopyBuffer(atr_handle, 0, 0, 1, atr_val) <= 0) return;

   MqlRates rates[];
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, rates) <= 0) return;

   double cur_trail = TrailStopBuffer[last];
   double cur_dir   = DirectionBuffer[last];

   //--- Current tick
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;

   //--- Distance from trail stop
   double dist_from_trail = tick.bid - cur_trail;
   double dist_pct = (cur_trail != 0) ? (dist_from_trail / cur_trail) * 100.0 : 0;

   //--- Determine current signal state
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

   //--- Price move since last signal
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

   // Header
   FileWrite(handle,
      "key", "value");

   // Metadata
   FileWrite(handle, "symbol",           _Symbol);
   FileWrite(handle, "timeframe",        EnumToString(Period()));
   FileWrite(handle, "server_time",      TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS));
   FileWrite(handle, "local_time",       TimeToString(TimeLocal(), TIME_DATE | TIME_SECONDS));

   // Current price
   FileWrite(handle, "bid",              DoubleToString(tick.bid, _Digits));
   FileWrite(handle, "ask",              DoubleToString(tick.ask, _Digits));
   FileWrite(handle, "spread",           DoubleToString(tick.ask - tick.bid, _Digits));

   // Bar data
   FileWrite(handle, "bar_open",         DoubleToString(rates[0].open, _Digits));
   FileWrite(handle, "bar_high",         DoubleToString(rates[0].high, _Digits));
   FileWrite(handle, "bar_low",          DoubleToString(rates[0].low, _Digits));
   FileWrite(handle, "bar_close",        DoubleToString(rates[0].close, _Digits));
   FileWrite(handle, "bar_time",         TimeToString(rates[0].time, TIME_DATE | TIME_SECONDS));
   FileWrite(handle, "bar_volume",       IntegerToString(rates[0].tick_volume));

   // UT Bot values
   FileWrite(handle, "atr_value",        DoubleToString(atr_val[0], _Digits));
   FileWrite(handle, "atr_nloss",        DoubleToString(atr_val[0] * ATR_Mult, _Digits));
   FileWrite(handle, "trail_stop",       DoubleToString(cur_trail, _Digits));
   FileWrite(handle, "current_bias",     current_bias);
   FileWrite(handle, "dist_from_trail",  DoubleToString(dist_from_trail, _Digits));
   FileWrite(handle, "dist_from_trail_pct", DoubleToString(dist_pct, 4));

   // Signal info
   FileWrite(handle, "last_signal_type",  last_signal_type);
   FileWrite(handle, "last_signal_time",  (last_signal_time_val > 0) ? TimeToString(last_signal_time_val, TIME_DATE | TIME_SECONDS) : "NONE");
   FileWrite(handle, "last_signal_price", (last_signal_price_val > 0) ? DoubleToString(last_signal_price_val, _Digits) : "0");
   FileWrite(handle, "bars_since_signal", IntegerToString(bars_since_signal));
   FileWrite(handle, "move_since_signal", DoubleToString(move_since_signal, _Digits));

   // Streak info
   FileWrite(handle, "consecutive_bull_bars", IntegerToString(consecutive_bull));
   FileWrite(handle, "consecutive_bear_bars", IntegerToString(consecutive_bear));

   // Last buy/sell details
   FileWrite(handle, "last_buy_time",    (last_buy_signal_time > 0) ? TimeToString(last_buy_signal_time, TIME_DATE | TIME_SECONDS) : "NONE");
   FileWrite(handle, "last_buy_price",   DoubleToString(last_buy_signal_price, _Digits));
   FileWrite(handle, "last_sell_time",   (last_sell_signal_time > 0) ? TimeToString(last_sell_signal_time, TIME_DATE | TIME_SECONDS) : "NONE");
   FileWrite(handle, "last_sell_price",  DoubleToString(last_sell_signal_price, _Digits));

   FileClose(handle);
}
//+------------------------------------------------------------------+
