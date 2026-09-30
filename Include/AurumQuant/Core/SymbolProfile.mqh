#ifndef AURUM_SYMBOL_PROFILE_MQH
#define AURUM_SYMBOL_PROFILE_MQH
#include <AurumQuant/Core/Config.mqh>
struct AQSymbolSpec
{
   string name; double bid,ask,point,tick_size,tick_value,tick_value_profit,tick_value_loss,contract_size,volume_min,volume_max,volume_step;
   int digits,stops_level,freeze_level; long trade_mode; double swap_long,swap_short; bool valid; string error;
};
class AQSymbolProfile
{
public:
   static bool Load(string symbol,AQSymbolSpec &s)
   {
      ZeroMemory(s); s.name=symbol;
      if(!SymbolSelect(symbol,true)) { s.error="SymbolSelect failed"; return false; }
      MqlTick tick; if(!SymbolInfoTick(symbol,tick)) { s.error="SymbolInfoTick failed"; return false; } s.bid=tick.bid;s.ask=tick.ask;
      s.point=SymbolInfoDouble(symbol,SYMBOL_POINT); s.digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
      s.tick_size=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE); s.tick_value=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE);
      s.tick_value_profit=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE_PROFIT); s.tick_value_loss=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE_LOSS);
      s.contract_size=SymbolInfoDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE);
      s.volume_min=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN); s.volume_max=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX); s.volume_step=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);
      s.stops_level=(int)SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL); s.freeze_level=(int)SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL);
      s.trade_mode=SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE); s.swap_long=SymbolInfoDouble(symbol,SYMBOL_SWAP_LONG); s.swap_short=SymbolInfoDouble(symbol,SYMBOL_SWAP_SHORT);
      if(!MathIsValidNumber(s.bid) || !MathIsValidNumber(s.ask) || s.bid<=0 ||
         !MathIsValidNumber(s.point) || !MathIsValidNumber(s.tick_size) ||
         !MathIsValidNumber(s.tick_value) || !MathIsValidNumber(s.tick_value_loss) ||
         !MathIsValidNumber(s.contract_size) || s.contract_size<=0 || !VolumeGridValid(s))
      { s.error="non-finite or invalid broker economics"; return false; }
      if(s.digits<0 || s.digits>8 || s.point<=0 || s.tick_size<=0 || s.tick_value<=0 || s.tick_value_loss<=0 || s.volume_min<=0 || s.volume_max<s.volume_min || s.volume_step<=0 || s.stops_level<0 || s.freeze_level<0 || s.ask<=s.bid || s.trade_mode==SYMBOL_TRADE_MODE_DISABLED || s.trade_mode==SYMBOL_TRADE_MODE_CLOSEONLY)
      { s.error="essential broker specification invalid or trading disabled"; return false; }
      double steps=(s.volume_max-s.volume_min)/s.volume_step;
      if(!MathIsValidNumber(steps) || steps<0) { s.error="broker volume grid invalid"; return false; }
      s.valid=true; return true;
   }
   static double SpreadPoints(const AQSymbolSpec &s) { return s.point>0 ? (s.ask-s.bid)/s.point : DBL_MAX; }
   static bool VolumeGridValid(const AQSymbolSpec &s)
   {
      return MathIsValidNumber(s.volume_min) && MathIsValidNumber(s.volume_max) &&
             MathIsValidNumber(s.volume_step) && s.volume_min>0 &&
             s.volume_max>=s.volume_min && s.volume_step>=1e-8 &&
             MathAbs(NormalizeDouble(s.volume_min,8)-s.volume_min)<1e-12 &&
             MathAbs(NormalizeDouble(s.volume_step,8)-s.volume_step)<1e-12;
   }
   static double NormalizePrice(const AQSymbolSpec &s,double price)
   {
      if(!s.valid || !MathIsValidNumber(price) || price<=0 ||
         !MathIsValidNumber(s.tick_size) || s.tick_size<=0 || s.digits<0 || s.digits>8) return 0;
      double ticks=price/s.tick_size;if(!MathIsValidNumber(ticks)) return 0;
      double normalized=NormalizeDouble(MathRound(ticks)*s.tick_size,s.digits);
      return MathIsValidNumber(normalized) && normalized>0 ? normalized : 0;
   }
   static double NormalizeVolumeDown(const AQSymbolSpec &s,double raw)
   {
      if(!s.valid || !VolumeGridValid(s) || !MathIsValidNumber(raw) || raw<s.volume_min) return 0;
      // Cap BEFORE flooring, so a maximum between grid points cannot become an off-grid lot.
      double limit=MathMin(raw,s.volume_max);
      double steps=(limit-s.volume_min)/s.volume_step;if(!MathIsValidNumber(steps)) return 0;
      double count=MathFloor(steps+1e-10);
      double v=NormalizeDouble(s.volume_min+count*s.volume_step,8);
      // Permit only floating-point representation noise, never decimal rounding upward.
      double tolerance=MathMin(s.volume_step*1e-8,1e-12);
      if(v>limit+tolerance) v=NormalizeDouble(s.volume_min+(count-1)*s.volume_step,8);
      return MathIsValidNumber(v) && v>=s.volume_min && v<=limit+tolerance ? v : 0;
   }
   static bool DirectionAllowed(const AQSymbolSpec &s,ENUM_AQ_DIRECTION direction,string &reason)
   {
      if(direction!=AQ_BUY && direction!=AQ_SELL) { reason="invalid direction"; return false; }
      if(!s.valid) { reason="SYMBOL DATA INVALID"; return false; }
      if(direction==AQ_BUY && s.trade_mode==SYMBOL_TRADE_MODE_SHORTONLY) { reason="symbol is short-only"; return false; }
      if(direction==AQ_SELL && s.trade_mode==SYMBOL_TRADE_MODE_LONGONLY) { reason="symbol is long-only"; return false; }
      if(s.trade_mode!=SYMBOL_TRADE_MODE_FULL && s.trade_mode!=SYMBOL_TRADE_MODE_LONGONLY && s.trade_mode!=SYMBOL_TRADE_MODE_SHORTONLY) { reason="symbol mode blocks new positions"; return false; }
      reason="OK"; return true;
   }
};
#endif
