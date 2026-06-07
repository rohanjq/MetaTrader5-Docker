//+------------------------------------------------------------------+
//| SignalMaster.mq5 — Multi-indicator, multi-timeframe signal writer |
//| Attach to ANY chart. Writes one CSV per indicator+TF+symbol.      |
//| Output: <SYMBOL>_<indicator>_<TF>.csv in Common/Files (symlinked) |
//+------------------------------------------------------------------+
#property copyright "MT5-Docker"
#property version   "2.00"
#property strict

#define MAX_INST    10
#define LOOKBACK    500

//=== Input Parameters ================================================
//  Format: "TF_minutes:param1:param2, ..." — leave empty to disable
input string INP_UTBot       = "1:10:2.0, 3:10:2.0, 10:10:2.0, 15:10:2.0, 45:10:2.0"; // UT Bot → TF:ATR_Period:ATR_Mult
input string INP_DC          = "1:20:0, 3:20:0, 5:20:0, 15:20:0, 45:20:0";             // DC Chan → TF:Length:Offset
input int    WriteInterval   = 5;   // File write interval (seconds)

//=== UT Bot state ====================================================
int    g_utbot_count = 0;
int    g_utbot_tf[MAX_INST];
int    g_utbot_atr_period[MAX_INST];
double g_utbot_atr_mult[MAX_INST];
int    g_utbot_atr_handle[MAX_INST];

//=== DC Channel state ================================================
int    g_dc_count = 0;
int    g_dc_tf[MAX_INST];
int    g_dc_length[MAX_INST];
int    g_dc_offset[MAX_INST];

//+------------------------------------------------------------------+
//| Initialization                                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   ParseUTBotConfig(INP_UTBot);
   ParseDCConfig(INP_DC);

   for(int i = 0; i < g_utbot_count; i++)
   {
      if(IsNativeTF(g_utbot_tf[i]))
         g_utbot_atr_handle[i] = iATR(_Symbol, MinToTF(g_utbot_tf[i]), g_utbot_atr_period[i]);
      else
         g_utbot_atr_handle[i] = INVALID_HANDLE;
   }

   EventSetTimer(WriteInterval);
   Print("SignalMaster started: ", _Symbol,
         " | UTBot[", g_utbot_count, "] DC[", g_dc_count, "]");

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   for(int i = 0; i < g_utbot_count; i++)
      if(g_utbot_atr_handle[i] != INVALID_HANDLE)
         IndicatorRelease(g_utbot_atr_handle[i]);
}

void OnTick()  { /* computed on timer only */ }
void OnTimer() { WriteAllSignals(); }

//+------------------------------------------------------------------+
//| Write all indicator signals                                        |
//+------------------------------------------------------------------+
void WriteAllSignals()
{
   for(int i = 0; i < g_utbot_count; i++)
      WriteUTBotSignal(i);
   for(int i = 0; i < g_dc_count; i++)
      WriteDCSignal(i);
}

//=====================================================================
//  CONFIG PARSING
//=====================================================================
void ParseUTBotConfig(string config)
{
   if(StringLen(config) == 0) return;
   string items[];
   int count = StringSplit(config, ',', items);
   g_utbot_count = MathMin(count, MAX_INST);

   for(int i = 0; i < g_utbot_count; i++)
   {
      StringTrimLeft(items[i]);
      StringTrimRight(items[i]);
      string parts[];
      StringSplit(items[i], ':', parts);
      g_utbot_tf[i]         = (int)StringToInteger(parts[0]);
      g_utbot_atr_period[i] = (ArraySize(parts) > 1) ? (int)StringToInteger(parts[1]) : 10;
      g_utbot_atr_mult[i]   = (ArraySize(parts) > 2) ? StringToDouble(parts[2]) : 2.0;
   }
}

void ParseDCConfig(string config)
{
   if(StringLen(config) == 0) return;
   string items[];
   int count = StringSplit(config, ',', items);
   g_dc_count = MathMin(count, MAX_INST);

   for(int i = 0; i < g_dc_count; i++)
   {
      StringTrimLeft(items[i]);
      StringTrimRight(items[i]);
      string parts[];
      StringSplit(items[i], ':', parts);
      g_dc_tf[i]     = (int)StringToInteger(parts[0]);
      g_dc_length[i] = (ArraySize(parts) > 1) ? (int)StringToInteger(parts[1]) : 20;
      g_dc_offset[i] = (ArraySize(parts) > 2) ? (int)StringToInteger(parts[2]) : 0;
   }
}

//=====================================================================
//  TIMEFRAME UTILITIES
//=====================================================================
bool IsNativeTF(int minutes)
{
   int native[] = {1,2,3,4,5,6,10,12,15,20,30,60,120,180,240,360,480,720,1440};
   for(int i = 0; i < ArraySize(native); i++)
      if(native[i] == minutes) return true;
   return false;
}

ENUM_TIMEFRAMES MinToTF(int m)
{
   switch(m)
   {
      case 1:    return PERIOD_M1;   case 2:    return PERIOD_M2;
      case 3:    return PERIOD_M3;   case 4:    return PERIOD_M4;
      case 5:    return PERIOD_M5;   case 6:    return PERIOD_M6;
      case 10:   return PERIOD_M10;  case 12:   return PERIOD_M12;
      case 15:   return PERIOD_M15;  case 20:   return PERIOD_M20;
      case 30:   return PERIOD_M30;  case 60:   return PERIOD_H1;
      case 120:  return PERIOD_H2;   case 180:  return PERIOD_H3;
      case 240:  return PERIOD_H4;   case 360:  return PERIOD_H6;
      case 480:  return PERIOD_H8;   case 720:  return PERIOD_H12;
      case 1440: return PERIOD_D1;
      default:   return PERIOD_M1;
   }
}

string TFToString(int minutes)
{
   if(minutes < 60) return "M" + IntegerToString(minutes);
   if(minutes < 1440) return "H" + IntegerToString(minutes / 60);
   return "D1";
}

//=====================================================================
//  SYNTHETIC BAR BUILDER  (for non-native TFs like 45m)
//=====================================================================
int BuildSyntheticBars(int tf_minutes, int bars_needed,
                       double &opens[], double &highs[],
                       double &lows[],  double &closes[],
                       long &volumes[], datetime &times[])
{
   int m1_needed = bars_needed * tf_minutes + tf_minutes;
   MqlRates m1_rates[];
   ArraySetAsSeries(m1_rates, false);
   int copied = CopyRates(_Symbol, PERIOD_M1, 0, m1_needed, m1_rates);
   if(copied < tf_minutes * 3) return 0;

   int bar_count = copied / tf_minutes;
   ArrayResize(opens, bar_count);
   ArrayResize(highs, bar_count);
   ArrayResize(lows, bar_count);
   ArrayResize(closes, bar_count);
   ArrayResize(volumes, bar_count);
   ArrayResize(times, bar_count);

   for(int b = 0; b < bar_count; b++)
   {
      int start = b * tf_minutes;
      int end   = MathMin(start + tf_minutes, copied);

      opens[b]   = m1_rates[start].open;
      highs[b]   = m1_rates[start].high;
      lows[b]    = m1_rates[start].low;
      closes[b]  = m1_rates[end - 1].close;
      volumes[b] = 0;
      times[b]   = m1_rates[start].time;

      for(int j = start; j < end; j++)
      {
         if(m1_rates[j].high > highs[b]) highs[b] = m1_rates[j].high;
         if(m1_rates[j].low  < lows[b])  lows[b]  = m1_rates[j].low;
         volumes[b] += m1_rates[j].tick_volume;
      }
   }
   return bar_count;
}

//=====================================================================
//  MANUAL ATR  (Wilder smoothing, for synthetic TFs)
//=====================================================================
void ComputeATR(const double &highs[], const double &lows[],
                const double &closes[], int period, double &atr[], int total)
{
   ArrayResize(atr, total);
   ArrayInitialize(atr, 0);
   if(total < period + 1) return;

   // First TR values + initial ATR as simple average
   double sum = 0;
   for(int i = 1; i <= period; i++)
   {
      double tr = MathMax(highs[i] - lows[i],
                  MathMax(MathAbs(highs[i] - closes[i - 1]),
                          MathAbs(lows[i]  - closes[i - 1])));
      atr[i] = tr;
      sum += tr;
   }
   atr[period] = sum / period;

   // Wilder smoothing
   for(int i = period + 1; i < total; i++)
   {
      double tr = MathMax(highs[i] - lows[i],
                  MathMax(MathAbs(highs[i] - closes[i - 1]),
                          MathAbs(lows[i]  - closes[i - 1])));
      atr[i] = (atr[i - 1] * (period - 1) + tr) / period;
   }
}

//=====================================================================
//  STANDARD CSV HEADER  (written to every file)
//=====================================================================
void WriteStdHeader(int handle, string indicator, int tf_minutes)
{
   MqlTick tick;
   SymbolInfoTick(_Symbol, tick);

   FileWrite(handle, "key", "value");
   FileWrite(handle, "symbol",             _Symbol);
   FileWrite(handle, "indicator",          indicator);
   FileWrite(handle, "timeframe",          TFToString(tf_minutes));
   FileWrite(handle, "timeframe_minutes",  IntegerToString(tf_minutes));
   FileWrite(handle, "server_time",        TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS));
   FileWrite(handle, "bid",                DoubleToString(tick.bid, _Digits));
   FileWrite(handle, "ask",                DoubleToString(tick.ask, _Digits));
   FileWrite(handle, "spread",             DoubleToString(tick.ask - tick.bid, _Digits));
}

void WriteBarFields(int handle, string prefix,
                    double open, double high, double low, double close,
                    datetime time, long volume)
{
   FileWrite(handle, prefix + "_bar_time",   TimeToString(time, TIME_DATE | TIME_SECONDS));
   FileWrite(handle, prefix + "_open",       DoubleToString(open, _Digits));
   FileWrite(handle, prefix + "_high",       DoubleToString(high, _Digits));
   FileWrite(handle, prefix + "_low",        DoubleToString(low, _Digits));
   FileWrite(handle, prefix + "_close",      DoubleToString(close, _Digits));
   FileWrite(handle, prefix + "_volume",     IntegerToString(volume));
}

//=====================================================================
//  UT BOT — compute + write
//=====================================================================
void WriteUTBotSignal(int idx)
{
   int    tf_min  = g_utbot_tf[idx];
   int    atr_per = g_utbot_atr_period[idx];
   double atr_mul = g_utbot_atr_mult[idx];

   double close_arr[], atr_arr[];
   double open_arr[], high_arr[], low_arr[];
   datetime time_arr[];
   long vol_arr[];
   int total = 0;

   //--- Get bar data + ATR
   if(IsNativeTF(tf_min))
   {
      ENUM_TIMEFRAMES tf = MinToTF(tf_min);
      total = MathMin(Bars(_Symbol, tf), LOOKBACK);
      if(total < atr_per + 3) return;

      ArraySetAsSeries(open_arr, false);
      ArraySetAsSeries(high_arr, false);
      ArraySetAsSeries(low_arr, false);
      ArraySetAsSeries(close_arr, false);
      ArraySetAsSeries(atr_arr, false);
      ArraySetAsSeries(time_arr, false);

      MqlRates rates[];
      ArraySetAsSeries(rates, false);
      if(CopyRates(_Symbol, tf, 0, total, rates) < total) return;
      if(CopyBuffer(g_utbot_atr_handle[idx], 0, 0, total, atr_arr) < total) return;

      ArrayResize(open_arr, total);
      ArrayResize(high_arr, total);
      ArrayResize(low_arr, total);
      ArrayResize(close_arr, total);
      ArrayResize(time_arr, total);
      ArrayResize(vol_arr, total);

      for(int i = 0; i < total; i++)
      {
         open_arr[i]  = rates[i].open;
         high_arr[i]  = rates[i].high;
         low_arr[i]   = rates[i].low;
         close_arr[i] = rates[i].close;
         time_arr[i]  = rates[i].time;
         vol_arr[i]   = rates[i].tick_volume;
      }
   }
   else
   {
      total = BuildSyntheticBars(tf_min, LOOKBACK, open_arr, high_arr, low_arr, close_arr, vol_arr, time_arr);
      if(total < atr_per + 3) return;
      ComputeATR(high_arr, low_arr, close_arr, atr_per, atr_arr, total);
   }

   //--- Compute trail stop + direction
   double trail_stop[], direction[];
   ArrayResize(trail_stop, total);
   ArrayResize(direction, total);

   for(int i = 0; i < atr_per && i < total; i++)
   {
      trail_stop[i] = close_arr[i];
      direction[i]  = 1;
   }

   for(int i = atr_per; i < total; i++)
   {
      double nLoss     = atr_mul * atr_arr[i];
      double prev_stop = trail_stop[i - 1];
      double prev_dir  = direction[i - 1];

      if(close_arr[i] > prev_stop)
      {
         trail_stop[i] = close_arr[i] - nLoss;
         if(prev_dir > 0) trail_stop[i] = MathMax(trail_stop[i], prev_stop);
         direction[i] = 1;
      }
      else
      {
         trail_stop[i] = close_arr[i] + nLoss;
         if(prev_dir < 0) trail_stop[i] = MathMin(trail_stop[i], prev_stop);
         direction[i] = -1;
      }
   }

   //--- Extract running / closed / prev indices
   int run  = total - 1;   // current forming bar
   int cls  = total - 2;   // last completed bar
   int prev = total - 3;   // bar before closed

   string running_bias   = (direction[run] > 0) ? "BULLISH" : "BEARISH";
   string running_signal = "NONE";
   if(direction[run] > 0 && direction[cls] < 0) running_signal = "BUY";
   if(direction[run] < 0 && direction[cls] > 0) running_signal = "SELL";

   string closed_bias   = (direction[cls] > 0) ? "BULLISH" : "BEARISH";
   string closed_signal = "NONE";
   if(prev >= 0)
   {
      if(direction[cls] > 0 && direction[prev] < 0) closed_signal = "BUY";
      if(direction[cls] < 0 && direction[prev] > 0) closed_signal = "SELL";
   }

   //--- Consecutive bar counts
   int consec_bull = 0, consec_bear = 0;
   for(int i = run; i >= 0; i--)
   {
      if(direction[i] > 0) { if(consec_bear > 0) break; consec_bull++; }
      else                 { if(consec_bull > 0) break; consec_bear++; }
   }

   //--- Write CSV
   string filename = _Symbol + "_utbot_" + TFToString(tf_min) + ".csv";
   int handle = FileOpen(filename, FILE_WRITE | FILE_CSV | FILE_COMMON, ',');
   if(handle == INVALID_HANDLE) return;

   WriteStdHeader(handle, "utbot", tf_min);

   // Running bar OHLCV
   WriteBarFields(handle, "running", open_arr[run], high_arr[run], low_arr[run],
                  close_arr[run], time_arr[run], vol_arr[run]);
   // Closed bar OHLCV
   WriteBarFields(handle, "closed", open_arr[cls], high_arr[cls], low_arr[cls],
                  close_arr[cls], time_arr[cls], vol_arr[cls]);

   // UT Bot indicator values — running
   FileWrite(handle, "running_atr",           DoubleToString(atr_arr[run], _Digits));
   FileWrite(handle, "running_nloss",         DoubleToString(atr_mul * atr_arr[run], _Digits));
   FileWrite(handle, "running_trail_stop",    DoubleToString(trail_stop[run], _Digits));
   FileWrite(handle, "running_bias",          running_bias);
   FileWrite(handle, "running_signal",        running_signal);

   // UT Bot indicator values — closed
   FileWrite(handle, "closed_atr",            DoubleToString(atr_arr[cls], _Digits));
   FileWrite(handle, "closed_nloss",          DoubleToString(atr_mul * atr_arr[cls], _Digits));
   FileWrite(handle, "closed_trail_stop",     DoubleToString(trail_stop[cls], _Digits));
   FileWrite(handle, "closed_bias",           closed_bias);
   FileWrite(handle, "closed_signal",         closed_signal);

   // Streak info
   FileWrite(handle, "consecutive_bull_bars", IntegerToString(consec_bull));
   FileWrite(handle, "consecutive_bear_bars", IntegerToString(consec_bear));

   // Config echo (so reader knows what params produced this)
   FileWrite(handle, "cfg_atr_period",        IntegerToString(atr_per));
   FileWrite(handle, "cfg_atr_mult",          DoubleToString(atr_mul, 1));

   FileClose(handle);
}

//=====================================================================
//  DONCHIAN CHANNEL — compute + write
//=====================================================================
void WriteDCSignal(int idx)
{
   int tf_min = g_dc_tf[idx];
   int length = g_dc_length[idx];
   int offset = g_dc_offset[idx];

   double upper = 0, lower = 0, mid = 0;
   double run_open = 0, run_high = 0, run_low = 0, run_close = 0;
   double cls_open = 0, cls_high = 0, cls_low = 0, cls_close = 0;
   datetime run_time = 0, cls_time = 0;
   long run_vol = 0, cls_vol = 0;

   if(IsNativeTF(tf_min))
   {
      ENUM_TIMEFRAMES tf = MinToTF(tf_min);
      int bars_needed = length + offset + 2;

      double highs[], lows[];
      ArraySetAsSeries(highs, true);
      ArraySetAsSeries(lows, true);

      if(CopyHigh(_Symbol, tf, offset + 1, length, highs) < length) return;
      if(CopyLow(_Symbol, tf, offset + 1, length, lows) < length) return;

      upper = highs[ArrayMaximum(highs)];
      lower = lows[ArrayMinimum(lows)];
      mid   = (upper + lower) / 2.0;

      // Get running + closed bars
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(_Symbol, tf, 0, 2, rates) < 2) return;
      // rates[0] = running (series mode), rates[1] = closed
      run_open = rates[0].open; run_high = rates[0].high;
      run_low  = rates[0].low;  run_close = rates[0].close;
      run_time = rates[0].time; run_vol  = rates[0].tick_volume;
      cls_open = rates[1].open; cls_high = rates[1].high;
      cls_low  = rates[1].low;  cls_close = rates[1].close;
      cls_time = rates[1].time; cls_vol  = rates[1].tick_volume;
   }
   else
   {
      double opens[], hi[], lo[], cl[];
      long vols[];
      datetime times[];
      int total = BuildSyntheticBars(tf_min, length + offset + 5,
                                     opens, hi, lo, cl, vols, times);
      if(total < length + offset + 2) return;

      // DC from closed synthetic bars (skip last = running)
      upper = -DBL_MAX;
      lower =  DBL_MAX;
      int start_idx = total - 2 - offset;  // start from last closed bar
      for(int i = start_idx; i > start_idx - length && i >= 0; i--)
      {
         if(hi[i] > upper) upper = hi[i];
         if(lo[i] < lower) lower = lo[i];
      }
      mid = (upper + lower) / 2.0;

      int run_i = total - 1;
      int cls_i = total - 2;
      run_open = opens[run_i]; run_high = hi[run_i];
      run_low  = lo[run_i];    run_close = cl[run_i];
      run_time = times[run_i]; run_vol  = vols[run_i];
      cls_open = opens[cls_i]; cls_high = hi[cls_i];
      cls_low  = lo[cls_i];    cls_close = cl[cls_i];
      cls_time = times[cls_i]; cls_vol  = vols[cls_i];
   }

   //--- Price position within channel
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;

   double channel_width = upper - lower;
   double pct_running = (channel_width > 0)
      ? (tick.bid - lower) / channel_width * 100.0 : 50.0;
   double pct_closed = (channel_width > 0)
      ? (cls_close - lower) / channel_width * 100.0 : 50.0;

   string running_zone = PriceZone(pct_running);
   string closed_zone  = PriceZone(pct_closed);

   //--- Touch / breakout detection on running bar
   bool run_touch_upper = (run_high >= upper);
   bool run_touch_lower = (run_low  <= lower);
   bool run_break_upper = (run_close > upper);
   bool run_break_lower = (run_close < lower);

   //--- Touch / breakout detection on closed bar
   bool cls_touch_upper = (cls_high >= upper);
   bool cls_touch_lower = (cls_low  <= lower);
   bool cls_break_upper = (cls_close > upper);
   bool cls_break_lower = (cls_close < lower);

   //--- Wick rejection on closed bar
   double body_top    = MathMax(cls_open, cls_close);
   double body_bottom = MathMin(cls_open, cls_close);
   double upper_wick  = cls_high - body_top;
   double lower_wick  = body_bottom - cls_low;
   double body_size   = body_top - body_bottom;

   bool upper_wick_rej = cls_touch_upper && (upper_wick > body_size) && (cls_close < upper);
   bool lower_wick_rej = cls_touch_lower && (lower_wick > body_size) && (cls_close > lower);

   //--- Write CSV
   string filename = _Symbol + "_dc_" + TFToString(tf_min) + ".csv";
   int handle = FileOpen(filename, FILE_WRITE | FILE_CSV | FILE_COMMON, ',');
   if(handle == INVALID_HANDLE) return;

   WriteStdHeader(handle, "dc", tf_min);

   WriteBarFields(handle, "running", run_open, run_high, run_low, run_close, run_time, run_vol);
   WriteBarFields(handle, "closed",  cls_open, cls_high, cls_low, cls_close, cls_time, cls_vol);

   // Channel values
   FileWrite(handle, "upper_band",              DoubleToString(upper, _Digits));
   FileWrite(handle, "lower_band",              DoubleToString(lower, _Digits));
   FileWrite(handle, "mid_band",                DoubleToString(mid, _Digits));
   FileWrite(handle, "channel_width",           DoubleToString(channel_width, _Digits));

   // Running analysis
   FileWrite(handle, "running_price_zone",      running_zone);
   FileWrite(handle, "running_pct_in_channel",  DoubleToString(pct_running, 1));
   FileWrite(handle, "running_touched_upper",   run_touch_upper ? "TRUE" : "FALSE");
   FileWrite(handle, "running_touched_lower",   run_touch_lower ? "TRUE" : "FALSE");
   FileWrite(handle, "running_break_upper",     run_break_upper ? "TRUE" : "FALSE");
   FileWrite(handle, "running_break_lower",     run_break_lower ? "TRUE" : "FALSE");

   // Closed analysis
   FileWrite(handle, "closed_price_zone",       closed_zone);
   FileWrite(handle, "closed_pct_in_channel",   DoubleToString(pct_closed, 1));
   FileWrite(handle, "closed_touched_upper",    cls_touch_upper ? "TRUE" : "FALSE");
   FileWrite(handle, "closed_touched_lower",    cls_touch_lower ? "TRUE" : "FALSE");
   FileWrite(handle, "closed_break_upper",      cls_break_upper ? "TRUE" : "FALSE");
   FileWrite(handle, "closed_break_lower",      cls_break_lower ? "TRUE" : "FALSE");
   FileWrite(handle, "closed_upper_wick_rej",   upper_wick_rej ? "TRUE" : "FALSE");
   FileWrite(handle, "closed_lower_wick_rej",   lower_wick_rej ? "TRUE" : "FALSE");

   // Config echo
   FileWrite(handle, "cfg_length",              IntegerToString(length));
   FileWrite(handle, "cfg_offset",              IntegerToString(offset));

   FileClose(handle);
}

//+------------------------------------------------------------------+
string PriceZone(double pct)
{
   if(pct >= 90)      return "UPPER";
   if(pct >= 70)      return "UPPER_MID";
   if(pct <= 10)      return "LOWER";
   if(pct <= 30)      return "LOWER_MID";
   return "MIDDLE";
}
//+------------------------------------------------------------------+
