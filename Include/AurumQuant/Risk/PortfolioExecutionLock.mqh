#ifndef AURUM_PORTFOLIO_EXECUTION_LOCK_MQH
#define AURUM_PORTFOLIO_EXECUTION_LOCK_MQH
#include <AurumQuant/Risk/PortfolioBudget.mqh>
#include <AurumQuant/Risk/PortfolioLockPolicy.mqh>
class AQPortfolioExecutionLock
{
private:
   string m_key; ulong m_owner; double m_value; bool m_owned,m_ready,m_tester;
public:
   AQPortfolioExecutionLock(void):m_key(""),m_owner(0),m_value(0),m_owned(false),m_ready(false),m_tester(false) {}
   bool Init(ulong magic_base,int magic_span,ulong owner_magic,string &reason)
   {
      m_key="";m_owner=owner_magic;m_value=0;m_owned=false;m_ready=false;m_tester=(bool)MQLInfoInteger(MQL_TESTER);
      if(magic_base==0 || magic_span<1 || !AQPortfolioBudget::MagicInGroup(owner_magic,magic_base,magic_span))
      {reason="invalid portfolio execution-lock identity";return false;}
      if(m_tester){m_ready=true;reason="OK";return true;}
      m_key=StringFormat("AQL.%I64d.%I64u.%d",AccountInfoInteger(ACCOUNT_LOGIN),magic_base,magic_span);
      if(m_key=="" || StringLen(m_key)>63) {reason="portfolio execution-lock key invalid";return false;}
      // Multiple charts share one terminal variable. Race-safe creation: another chart may create it
      // between Check and Temp, which is acceptable as long as the variable exists afterwards.
      if(!GlobalVariableCheck(m_key))
      {
         if(!GlobalVariableTemp(m_key) && !GlobalVariableCheck(m_key))
         {reason="cannot initialize portfolio execution lock";return false;}
      }
      double current=0;
      if(!GlobalVariableGet(m_key,current) || !MathIsValidNumber(current) || current<0)
      {reason="portfolio execution lock contains invalid state";return false;}
      m_ready=true;reason="OK";return true;
   }
   bool Acquire(int ttl_seconds,string &reason)
   {
      if(!m_ready) {reason="portfolio execution lock unavailable";return false;}
      if(m_owned) {reason="portfolio execution lock already held";return false;}
      if(ttl_seconds<1 || ttl_seconds>3600) {reason="invalid portfolio execution-lock TTL";return false;}
      if(m_tester) {m_owned=true;reason="OK";return true;}
      datetime now=TimeTradeServer();
      if(now<=0) {reason="server time unavailable for portfolio execution lock";return false;}
      for(int attempt=0;attempt<3;attempt++)
      {
         double current=GlobalVariableGet(m_key);
         if(!AQPortfolioLockPolicy::CanAcquire(now,current))
         {reason="portfolio execution gate busy";return false;}
         double owner_fraction=(double)(m_owner%1000000)/1000000.0;
         double proposed=(double)(now+ttl_seconds)+owner_fraction;
         if(GlobalVariableSetOnCondition(m_key,proposed,current))
         {m_value=proposed;m_owned=true;reason="OK";return true;}
      }
      reason="portfolio execution gate contention";return false;
   }
   void Release()
   {
      if(!m_owned)return;
      if(!m_tester && m_key!="") GlobalVariableSetOnCondition(m_key,0.0,m_value);
      m_owned=false;m_value=0;
   }
};
#endif
