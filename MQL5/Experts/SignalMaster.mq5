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
input string INP_LiqGrab     = "3:50:5:2.0:5:100, 5:50:5:2.0:5:100, 15:50:5:2.0:5:100, 60:50:5:2.0:5:200, 240:50:5:2.0:5:200"; // LiqGrab → TF:LookbackRange:BarsN:WickBodyRatio:CandlesBeforeBreakout:MAPeriod
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

//=== Liquidity Grab state ============================================
int    g_liq_count = 0;
int    g_liq_tf[MAX_INST];
int    g_liq_lookback[MAX_INST];      // Range for finding key levels
int    g_liq_barsN[MAX_INST];         // Bars for rejection confirmation
double g_liq_wick_ratio[MAX_INST];    // Min wick:body ratio for rejection
int    g_liq_candles_bk[MAX_INST];    // Lookback for recent rejections before breakout
int    g_liq_ma_period[MAX_INST];     // MA period for trend filter
int    g_liq_ma_handle[MAX_INST];

//+------------------------------------------------------------------+
//| Initialization                                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   ParseUTBotConfig(INP_UTBot);
   ParseDCConfig(INP_DC);
   ParseLiqGrabConfig(INP_LiqGrab);

   for(int i = 0; i < g_utbot_count; i++)
   {
      if(IsNativeTF(g_utbot_tf[i]))
         g_utbot_atr_handle[i] = iATR(_Symbol, MinToTF(g_utbot_tf[i]), g_utbot_atr_period[i]);
      else
         g_utbot_atr_handle[i] = INVALID_HANDLE;
   }

   for(int i = 0; i < g_liq_count; i++)
   {
      if(IsNativeTF(g_liq_tf[i]))
         g_liq_ma_handle[i] = iMA(_Symbol, MinToTF(g_liq_tf[i]), g_liq_ma_period[i], 0, MODE_SMA, PRICE_CLOSE);
      else
         g_liq_ma_handle[i] = INVALID_HANDLE;
   }

   EventSetTimer(WriteInterval);
   Print("SignalMaster started: ", _Symbol,
         " | UTBot[", g_utbot_count, "] DC[", g_dc_count, "] LiqGrab[", g_liq_count, "]");

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   for(int i = 0; i < g_utbot_count; i++)
      if(g_utbot_atr_handle[i] != INVALID_HANDLE)
         IndicatorRelease(g_utbot_atr_handle[i]);
   for(int i = 0; i < g_liq_count; i++)
      if(g_liq_ma_handle[i] != INVALID_HANDLE)
         IndicatorRelease(g_liq_ma_handle[i]);
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
   for(int i = 0; i < g_liq_count; i++)
      WriteLiqGrabSignal(i);
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

void ParseLiqGrabConfig(string config)
{
   if(StringLen(config) == 0) return;
   string items[];
   int count = StringSplit(config, ',', items);
   g_liq_count = MathMin(count, MAX_INST);

   for(int i = 0; i < g_liq_count; i++)
   {
      StringTrimLeft(items[i]);
      StringTrimRight(items[i]);
      string parts[];
      StringSplit(items[i], ':', parts);
      g_liq_tf[i]          = (int)StringToInteger(parts[0]);
      g_liq_lookback[i]    = (ArraySize(parts) > 1) ? (int)StringToInteger(parts[1]) : 50;
      g_liq_barsN[i]       = (ArraySize(parts) > 2) ? (int)StringToInteger(parts[2]) : 5;
      g_liq_wick_ratio[i]  = (ArraySize(parts) > 3) ? StringToDouble(parts[3]) : 2.0;
      g_liq_candles_bk[i]  = (ArraySize(parts) > 4) ? (int)StringToInteger(parts[4]) : 5;
      g_liq_ma_period[i]   = (ArraySize(parts) > 5) ? (int)StringToInteger(parts[5]) : 100;
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

//=====================================================================
//  LIQUIDITY GRAB — compute + write
//=====================================================================

// Find key high: highest high within range that has rejection (local peak)
double LiqFindKeyHigh(const double &highs[], const double &lows[],
                      const double &closes[], int total, int barsN, int range)
{
   double highestHigh = 0;
   int limit = MathMin(range, total - barsN);
   for(int i = barsN; i < limit; i++)
   {
      double hi = highs[i];
      // Check if this bar is the highest in a window of 2*barsN+1
      bool isPeak = true;
      for(int j = i - barsN; j <= i + barsN && j < total; j++)
      {
         if(j < 0) continue;
         if(j != i && highs[j] > hi) { isPeak = false; break; }
      }
      if(isPeak && hi > highestHigh)
         return hi;
      highestHigh = MathMax(highestHigh, hi);
   }
   return 99999;
}

// Find key low: lowest low within range that has rejection (local trough)
double LiqFindKeyLow(const double &highs[], const double &lows[],
                     const double &closes[], int total, int barsN, int range)
{
   double lowestLow = DBL_MAX;
   int limit = MathMin(range, total - barsN);
   for(int i = barsN; i < limit; i++)
   {
      double lo = lows[i];
      bool isTrough = true;
      for(int j = i - barsN; j <= i + barsN && j < total; j++)
      {
         if(j < 0) continue;
         if(j != i && lows[j] < lo) { isTrough = false; break; }
      }
      if(isTrough && lo < lowestLow)
         return lo;
      lowestLow = MathMin(lowestLow, lo);
   }
   return -1;
}

// Check if bar at shift is a rejection UP (bullish — lower wick grabs liquidity)
bool LiqIsRejectionUp(const double &opens[], const double &highs[],
                      const double &lows[], const double &closes[],
                      int shift, double wickRatio, double keyLow)
{
   double open  = opens[shift];
   double close = closes[shift];
   double high  = highs[shift];
   double low   = lows[shift];
   double bodySize = MathAbs(close - open);
   if(bodySize < _Point) return false;
   double lowerWick = MathMin(open, close) - low;
   // Wick must be big enough AND candle must sweep below key low but close above it
   return (lowerWick >= wickRatio * bodySize && low < keyLow && high > keyLow);
}

// Check if bar at shift is a rejection DOWN (bearish — upper wick grabs liquidity)
bool LiqIsRejectionDown(const double &opens[], const double &highs[],
                        const double &lows[], const double &closes[],
                        int shift, double wickRatio, double keyHigh)
{
   double open  = opens[shift];
   double close = closes[shift];
   double high  = highs[shift];
   double low   = lows[shift];
   double bodySize = MathAbs(close - open);
   if(bodySize < _Point) return false;
   double upperWick = high - MathMax(open, close);
   return (upperWick >= wickRatio * bodySize && high > keyHigh && low < keyHigh);
}

void WriteLiqGrabSignal(int idx)
{
   int    tf_min      = g_liq_tf[idx];
   int    lookback    = g_liq_lookback[idx];
   int    barsN       = g_liq_barsN[idx];
   double wickRatio   = g_liq_wick_ratio[idx];
   int    candlesBk   = g_liq_candles_bk[idx];
   int    maPeriod    = g_liq_ma_period[idx];

   int bars_needed = MathMax(lookback, maPeriod) + barsN + 10;

   double opens[], highs[], lows[], closes[];
   datetime times[];
   long vols[];
   int total = 0;

   //--- Get bar data
   if(IsNativeTF(tf_min))
   {
      ENUM_TIMEFRAMES tf = MinToTF(tf_min);
      MqlRates rates[];
      ArraySetAsSeries(rates, true);  // [0]=most recent
      total = CopyRates(_Symbol, tf, 0, bars_needed, rates);
      if(total < bars_needed) return;

      ArrayResize(opens, total);  ArrayResize(highs, total);
      ArrayResize(lows, total);   ArrayResize(closes, total);
      ArrayResize(times, total);  ArrayResize(vols, total);

      for(int i = 0; i < total; i++)
      {
         opens[i]  = rates[i].open;   highs[i] = rates[i].high;
         lows[i]   = rates[i].low;    closes[i] = rates[i].close;
         times[i]  = rates[i].time;   vols[i]  = rates[i].tick_volume;
      }
   }
   else
   {
      // Build synthetic bars (returns non-series: [0]=oldest)
      double s_opens[], s_highs[], s_lows[], s_closes[];
      long s_vols[];
      datetime s_times[];
      int synth = BuildSyntheticBars(tf_min, bars_needed, s_opens, s_highs, s_lows, s_closes, s_vols, s_times);
      if(synth < bars_needed) return;

      // Reverse to series order [0]=most recent
      total = synth;
      ArrayResize(opens, total);  ArrayResize(highs, total);
      ArrayResize(lows, total);   ArrayResize(closes, total);
      ArrayResize(times, total);  ArrayResize(vols, total);

      for(int i = 0; i < total; i++)
      {
         int ri = total - 1 - i;
         opens[i] = s_opens[ri];  highs[i] = s_highs[ri];
         lows[i]  = s_lows[ri];   closes[i] = s_closes[ri];
         times[i] = s_times[ri];  vols[i]  = s_vols[ri];
      }
   }

   //--- Index 0 = running bar, 1 = last closed bar (series order)
   //--- Key levels (search from bar 1 onwards — closed bars only)
   double keyHigh = LiqFindKeyHigh(highs, lows, closes, total, barsN, lookback);
   double keyLow  = LiqFindKeyLow(highs, lows, closes, total, barsN, lookback);

   //--- Check for recent rejection (liquidity grab) in last N closed candles
   bool wasRejUp   = false;
   bool wasRejDown = false;
   int  rejUpBar   = -1;
   int  rejDownBar = -1;

   for(int i = 1; i <= candlesBk && i < total; i++)
   {
      if(!wasRejUp && LiqIsRejectionUp(opens, highs, lows, closes, i, wickRatio, keyLow))
      {
         wasRejUp = true;
         rejUpBar = i;
      }
      if(!wasRejDown && LiqIsRejectionDown(opens, highs, lows, closes, i, wickRatio, keyHigh))
      {
         wasRejDown = true;
         rejDownBar = i;
      }
   }

   //--- Breakout detection: price broke past key level on opposite side (short lookback)
   bool breakoutUp   = false;
   bool breakoutDown = false;
   for(int i = 1; i <= candlesBk && i < total; i++)
   {
      if(closes[i] > LiqFindKeyHigh(highs, lows, closes, total, barsN, candlesBk + barsN))
         breakoutUp = true;
      if(closes[i] < LiqFindKeyLow(highs, lows, closes, total, barsN, candlesBk + barsN))
         breakoutDown = true;
   }

   //--- MA trend filter
   double maValue = 0;
   if(IsNativeTF(tf_min) && g_liq_ma_handle[idx] != INVALID_HANDLE)
   {
      double maBuf[];
      if(CopyBuffer(g_liq_ma_handle[idx], 0, 1, 1, maBuf) > 0)
         maValue = maBuf[0];
   }
   else
   {
      // Manual SMA for synthetic TFs
      double sum = 0;
      int count = MathMin(maPeriod, total - 1);
      for(int i = 1; i <= count; i++) sum += closes[i];
      if(count > 0) maValue = sum / count;
   }

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;

   string maTrend = (tick.bid > maValue) ? "ABOVE" : "BELOW";

   //--- Composite signal: rejection + breakout + trend alignment
   string liqSignal = "NONE";
   if(wasRejUp && breakoutUp && tick.ask > maValue)
      liqSignal = "BUY";
   else if(wasRejDown && breakoutDown && tick.bid < maValue)
      liqSignal = "SELL";

   //--- Running bar proximity to key levels
   double distToKeyHigh = (keyHigh < 99999) ? highs[0] - keyHigh : 0;
   double distToKeyLow  = (keyLow > -1) ? lows[0] - keyLow : 0;

   //--- Write CSV
   string filename = _Symbol + "_liqgrab_" + TFToString(tf_min) + ".csv";
   int handle = FileOpen(filename, FILE_WRITE | FILE_CSV | FILE_COMMON, ',');
   if(handle == INVALID_HANDLE) return;

   WriteStdHeader(handle, "liqgrab", tf_min);

   // Running + closed bar
   WriteBarFields(handle, "running", opens[0], highs[0], lows[0], closes[0], times[0], vols[0]);
   WriteBarFields(handle, "closed",  opens[1], highs[1], lows[1], closes[1], times[1], vols[1]);

   // Key levels
   FileWrite(handle, "key_high",                (keyHigh < 99999) ? DoubleToString(keyHigh, _Digits) : "NONE");
   FileWrite(handle, "key_low",                 (keyLow > -1) ? DoubleToString(keyLow, _Digits) : "NONE");
   FileWrite(handle, "dist_to_key_high",        DoubleToString(distToKeyHigh, _Digits));
   FileWrite(handle, "dist_to_key_low",         DoubleToString(distToKeyLow, _Digits));

   // Liquidity grab detection
   FileWrite(handle, "rejection_up",            wasRejUp ? "TRUE" : "FALSE");
   FileWrite(handle, "rejection_up_bar",        IntegerToString(rejUpBar));
   FileWrite(handle, "rejection_down",          wasRejDown ? "TRUE" : "FALSE");
   FileWrite(handle, "rejection_down_bar",      IntegerToString(rejDownBar));

   // Breakout
   FileWrite(handle, "breakout_up",             breakoutUp ? "TRUE" : "FALSE");
   FileWrite(handle, "breakout_down",           breakoutDown ? "TRUE" : "FALSE");

   // Trend filter
   FileWrite(handle, "ma_value",                DoubleToString(maValue, _Digits));
   FileWrite(handle, "ma_trend",                maTrend);

   // Composite signal
   FileWrite(handle, "liq_signal",              liqSignal);

   // Config echo
   FileWrite(handle, "cfg_lookback",            IntegerToString(lookback));
   FileWrite(handle, "cfg_barsN",               IntegerToString(barsN));
   FileWrite(handle, "cfg_wick_ratio",          DoubleToString(wickRatio, 1));
   FileWrite(handle, "cfg_candles_bk",          IntegerToString(candlesBk));
   FileWrite(handle, "cfg_ma_period",           IntegerToString(maPeriod));

   FileClose(handle);
}
//+------------------------------------------------------------------+
