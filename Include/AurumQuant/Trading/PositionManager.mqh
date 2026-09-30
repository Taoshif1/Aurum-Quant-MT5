#ifndef AURUM_POSITION_MANAGER_MQH
#define AURUM_POSITION_MANAGER_MQH
#include <Trade/Trade.mqh>
#include <AurumQuant/Trading/ExecutionPolicy.mqh>
#include <AurumQuant/Risk/RiskManager.mqh>
class AQPositionManager
{
private: CTrade m_trade; string m_symbol; ulong m_magic; ENUM_AQ_MODE m_mode; bool m_armed;
public:
   AQPositionManager(void):m_symbol(""),m_magic(0),m_mode(MODE_OBSERVE),m_armed(false) {}
   void Init(ulong magic,string symbol,ENUM_AQ_MODE mode=MODE_OBSERVE,bool armed=false)
   { m_magic=magic;m_symbol=symbol;m_mode=mode;m_armed=armed;m_trade.SetAsyncMode(false);m_trade.SetExpertMagicNumber(magic);m_trade.SetTypeFillingBySymbol(symbol); }
   bool ExecutionAllowed(string &reason)
   { return AQExecutionPolicy::Allows(m_mode,m_armed,AccountInfoInteger(ACCOUNT_TRADE_MODE),reason); }
   bool Owns(ulong ticket) { return PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL)==m_symbol && (ulong)PositionGetInteger(POSITION_MAGIC)==m_magic; }
   // Management hooks are inert unless their individual feature is enabled by the caller.
   bool Modify(ulong ticket,double sl,double tp)
   {
      string lock_reason;if(!ExecutionAllowed(lock_reason) || !Owns(ticket)) return false; AQSymbolSpec spec; if(!AQSymbolProfile::Load(m_symbol,spec)) return false;
      ENUM_AQ_DIRECTION direction=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY ? AQ_BUY : AQ_SELL); string reason;
      if(!AQRiskManager::ValidateStops(spec,direction,sl,tp,true,reason)) return false;
      return m_trade.PositionModify(ticket,sl,tp) && (m_trade.ResultRetcode()==TRADE_RETCODE_DONE || m_trade.ResultRetcode()==TRADE_RETCODE_NO_CHANGES);
   }
   bool SafeClose(ulong ticket) { string lock_reason;if(!ExecutionAllowed(lock_reason) || !Owns(ticket)) return false; return m_trade.PositionClose(ticket) && (m_trade.ResultRetcode()==TRADE_RETCODE_DONE || m_trade.ResultRetcode()==TRADE_RETCODE_DONE_PARTIAL); }
};
#endif
