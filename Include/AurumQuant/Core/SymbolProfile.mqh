#ifndef AURUM_SYMBOL_PROFILE_MQH
#define AURUM_SYMBOL_PROFILE_MQH
#include <AurumQuant/Core/Config.mqh>
struct AQSymbolSpec
{
   string name; double bid,ask,point,tick_size,tick_value,contract_size,volume_min,volume_max,volume_step;
   int digits,stops_level,freeze_level; long trade_mode; double swap_long,swap_short; bool valid; string error;
};
class AQSymbolProfile
{
public:
   static bool Load(string symbol,AQSymbolSpec &s)
   {
      ZeroMemory(s); s.name=symbol;
      if(!SymbolSelect(symbol,true)) { s.error="SymbolSelect failed"; return false; }
      s.bid=SymbolInfoDouble(symbol,SYMBOL_BID); s.ask=SymbolInfoDouble(symbol,SYMBOL_ASK);
      s.point=SymbolInfoDouble(symbol,SYMBOL_POINT); s.digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
      s.tick_size=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE); s.tick_value=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE);
      s.contract_size=SymbolInfoDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE);
      s.volume_min=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN); s.volume_max=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX); s.volume_step=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);
      s.stops_level=(int)SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL); s.freeze_level=(int)SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL);
      s.trade_mode=SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE); s.swap_long=SymbolInfoDouble(symbol,SYMBOL_SWAP_LONG); s.swap_short=SymbolInfoDouble(symbol,SYMBOL_SWAP_SHORT);
      if(s.point<=0 || s.tick_size<=0 || s.tick_value<=0 || s.volume_min<=0 || s.volume_max<s.volume_min || s.volume_step<=0 || s.ask<=s.bid || s.trade_mode==SYMBOL_TRADE_MODE_DISABLED)
      { s.error="essential broker specification invalid or trading disabled"; return false; }
      s.valid=true; return true;
   }
   static double SpreadPoints(const AQSymbolSpec &s) { return s.point>0 ? (s.ask-s.bid)/s.point : DBL_MAX; }
};
#endif

