#ifndef AURUM_POSITION_MANAGER_MQH
#define AURUM_POSITION_MANAGER_MQH
#include <Trade/Trade.mqh>
class AQPositionManager
{
private: CTrade m_trade; string m_symbol; ulong m_magic;
public:
   void Init(ulong magic,string symbol) { m_magic=magic; m_symbol=symbol; m_trade.SetExpertMagicNumber(magic); }
   bool Owns(ulong ticket) { return PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL)==m_symbol && (ulong)PositionGetInteger(POSITION_MAGIC)==m_magic; }
   // Management hooks are inert unless their individual feature is enabled by the caller.
   bool Modify(ulong ticket,double sl,double tp) { if(!Owns(ticket)) return false; return m_trade.PositionModify(ticket,sl,tp); }
   bool SafeClose(ulong ticket) { if(!Owns(ticket)) return false; return m_trade.PositionClose(ticket); }
};
#endif
