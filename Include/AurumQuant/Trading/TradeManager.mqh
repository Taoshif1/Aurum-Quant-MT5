#ifndef AURUM_TRADE_MANAGER_MQH
#define AURUM_TRADE_MANAGER_MQH
#include <Trade/Trade.mqh>
#include <AurumQuant/Core/Config.mqh>
class AQTradeManager
{
private: CTrade m_trade; ENUM_AQ_MODE m_mode; bool m_armed; string m_symbol;
public:
   void Init(ENUM_AQ_MODE mode,bool armed,ulong magic,string symbol) { m_mode=mode; m_armed=armed; m_symbol=symbol; m_trade.SetExpertMagicNumber(magic); m_trade.SetTypeFillingBySymbol(symbol); }
   bool ExecutionAllowed(string &reason)
   {
      if(m_mode==MODE_OBSERVE) { reason="OBSERVE mode prohibits order submission"; return false; }
      if(!m_armed) { reason="order submission master switch is OFF"; return false; }
      if(m_mode==MODE_DEMO && AccountInfoInteger(ACCOUNT_TRADE_MODE)!=ACCOUNT_TRADE_MODE_DEMO) { reason="DEMO mode requires a demo account"; return false; }
      if(m_mode==MODE_LIVE && AccountInfoInteger(ACCOUNT_TRADE_MODE)!=ACCOUNT_TRADE_MODE_REAL) { reason="LIVE mode requires a real account"; return false; }
      reason="OK"; return true;
   }
   bool Buy(string symbol,double volume,double sl,double tp,string comment) { string why; if(!ExecutionAllowed(why)) return false; return m_trade.Buy(volume,symbol,0,sl,tp,comment); }
   bool Sell(string symbol,double volume,double sl,double tp,string comment) { string why; if(!ExecutionAllowed(why)) return false; return m_trade.Sell(volume,symbol,0,sl,tp,comment); }
   uint ResultRetcode() const { return m_trade.ResultRetcode(); }
};
#endif
