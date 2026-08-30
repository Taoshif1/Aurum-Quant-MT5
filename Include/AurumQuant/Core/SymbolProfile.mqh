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
      if(s.digits<0 || s.digits>16 || s.point<=0 || s.tick_size<=0 || s.tick_value<=0 || s.tick_value_loss<=0 || s.volume_min<=0 || s.volume_max<s.volume_min || s.volume_step<=0 || s.stops_level<0 || s.freeze_level<0 || s.ask<=s.bid || s.trade_mode==SYMBOL_TRADE_MODE_DISABLED || s.trade_mode==SYMBOL_TRADE_MODE_CLOSEONLY)
      { s.error="essential broker specification invalid or trading disabled"; return false; }
      double steps=(s.volume_max-s.volume_min)/s.volume_step;
      if(!MathIsValidNumber(steps) || steps<0) { s.error="broker volume grid invalid"; return false; }
      s.valid=true; return true;
   }
   static double SpreadPoints(const AQSymbolSpec &s) { return s.point>0 ? (s.ask-s.bid)/s.point : DBL_MAX; }
   static double NormalizePrice(const AQSymbolSpec &s,double price)
   { if(!s.valid || price<=0) return 0; return NormalizeDouble(MathRound(price/s.tick_size)*s.tick_size,s.digits); }
   static double NormalizeVolumeDown(const AQSymbolSpec &s,double raw)
   {
      if(!s.valid || raw<s.volume_min) return 0;
      double v=MathFloor((raw-s.volume_min)/s.volume_step+1e-10)*s.volume_step+s.volume_min;
      v=MathMin(v,s.volume_max); int vd=0; double step=s.volume_step; while(step<1.0 && vd<8){step*=10.0;vd++;}
      v=NormalizeDouble(v,vd); return (v>=s.volume_min && v<=s.volume_max ? v : 0);
   }
   static bool DirectionAllowed(const AQSymbolSpec &s,ENUM_AQ_DIRECTION direction,string &reason)
   {
      if(!s.valid) { reason="SYMBOL DATA INVALID"; return false; }
      if(direction==AQ_BUY && s.trade_mode==SYMBOL_TRADE_MODE_SHORTONLY) { reason="symbol is short-only"; return false; }
      if(direction==AQ_SELL && s.trade_mode==SYMBOL_TRADE_MODE_LONGONLY) { reason="symbol is long-only"; return false; }
      if(s.trade_mode!=SYMBOL_TRADE_MODE_FULL && s.trade_mode!=SYMBOL_TRADE_MODE_LONGONLY && s.trade_mode!=SYMBOL_TRADE_MODE_SHORTONLY) { reason="symbol mode blocks new positions"; return false; }
      reason="OK"; return true;
   }
};
#endif
