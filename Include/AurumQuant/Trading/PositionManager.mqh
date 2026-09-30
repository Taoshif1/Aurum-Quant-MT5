#ifndef AURUM_POSITION_MANAGER_MQH
#define AURUM_POSITION_MANAGER_MQH
#include <Trade/Trade.mqh>
#include <AurumQuant/Trading/ExecutionPolicy.mqh>
#include <AurumQuant/Trading/StopManagementPolicy.mqh>
#include <AurumQuant/Risk/RiskManager.mqh>

class AQPositionManager
{
private:
   CTrade m_trade; string m_symbol; ulong m_magic; ENUM_AQ_MODE m_mode; bool m_armed;
   ENUM_TIMEFRAMES m_management_tf; int m_atr_period,m_atr_handle;

   bool ClosedATR(double &atr,string &reason)
   {
      atr=0;
      if(m_atr_handle==INVALID_HANDLE){reason="position-management ATR unavailable";return false;}
      double values[1];
      if(CopyBuffer(m_atr_handle,0,1,1,values)!=1 || !MathIsValidNumber(values[0]) || values[0]<=0)
      {reason="closed ATR unavailable for trailing";return false;}
      atr=values[0];reason="OK";return true;
   }

   bool OriginalRisk(ulong ticket,ENUM_AQ_DIRECTION direction,double entry,double current_sl,double &risk,string &reason)
   {
      risk=0;
      double raw=(direction==AQ_BUY ? entry-current_sl : current_sl-entry);
      if(!MathIsValidNumber(raw) || raw<=0){reason="original risk cannot be derived from current stop";return false;}
      if(MQLInfoInteger(MQL_TESTER)){risk=raw;reason="OK";return true;}
      string key=StringFormat("AQR.%I64d.%I64u",AccountInfoInteger(ACCOUNT_LOGIN),ticket);
      if(key=="" || StringLen(key)>63){reason="original-risk key invalid";return false;}
      if(GlobalVariableCheck(key))
      {
         if(!GlobalVariableGet(key,risk) || !MathIsValidNumber(risk) || risk<=0)
         {reason="persisted original risk invalid";return false;}
         reason="OK";return true;
      }
      if(GlobalVariableSet(key,raw)==0){reason="cannot persist original position risk";return false;}
      risk=raw;reason="OK";return true;
   }
public:
   AQPositionManager(void):m_symbol(""),m_magic(0),m_mode(MODE_OBSERVE),m_armed(false),
      m_management_tf(PERIOD_CURRENT),m_atr_period(14),m_atr_handle(INVALID_HANDLE) {}

   void Init(ulong magic,string symbol,ENUM_AQ_MODE mode=MODE_OBSERVE,bool armed=false)
   {
      m_magic=magic;m_symbol=symbol;m_mode=mode;m_armed=armed;
      m_trade.SetAsyncMode(false);m_trade.SetExpertMagicNumber(magic);m_trade.SetTypeFillingBySymbol(symbol);
   }

   bool InitManagement(ENUM_TIMEFRAMES tf,int atr_period,bool need_atr,string &reason)
   {
      ShutdownManagement();m_management_tf=tf;m_atr_period=atr_period;
      if(atr_period<2){reason="invalid position-management ATR period";return false;}
      if(!need_atr){reason="OK";return true;}
      m_atr_handle=iATR(m_symbol,tf,atr_period);
      if(m_atr_handle==INVALID_HANDLE){reason="position-management ATR handle unavailable";return false;}
      reason="OK";return true;
   }

   void ShutdownManagement()
   {
      if(m_atr_handle!=INVALID_HANDLE){IndicatorRelease(m_atr_handle);m_atr_handle=INVALID_HANDLE;}
   }

   bool ExecutionAllowed(string &reason)
   { return AQExecutionPolicy::Allows(m_mode,m_armed,AccountInfoInteger(ACCOUNT_TRADE_MODE),reason); }

   bool Owns(ulong ticket)
   { return PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL)==m_symbol && (ulong)PositionGetInteger(POSITION_MAGIC)==m_magic; }

   bool Modify(ulong ticket,double sl,double tp,string &reason)
   {
      string lock_reason;
      if(!ExecutionAllowed(lock_reason)){reason=lock_reason;return false;}
      if(!Owns(ticket)){reason="position is not owned by this EA instance";return false;}
      AQSymbolSpec spec;if(!AQSymbolProfile::Load(m_symbol,spec)){reason="symbol unavailable for position modification";return false;}
      long type=PositionGetInteger(POSITION_TYPE);ENUM_AQ_DIRECTION direction;
      if(type==POSITION_TYPE_BUY)direction=AQ_BUY;
      else if(type==POSITION_TYPE_SELL)direction=AQ_SELL;
      else {reason="unknown position type";return false;}
      if(!AQRiskManager::ValidateStops(spec,direction,sl,tp,true,reason))return false;
      bool called=m_trade.PositionModify(ticket,sl,tp);uint code=m_trade.ResultRetcode();
      if(!called || (code!=TRADE_RETCODE_DONE && code!=TRADE_RETCODE_NO_CHANGES))
      {reason="broker rejected position modification";return false;}
      reason="OK";return true;
   }

   bool Modify(ulong ticket,double sl,double tp)
   { string reason;return Modify(ticket,sl,tp,reason); }

   bool Manage(bool break_even_enabled,ENUM_BE_METHOD break_even_method,
               double break_even_trigger_r,double break_even_distance_points,
               bool trailing_enabled,ENUM_TRAIL_METHOD trailing_method,double trailing_value,
               int &modified,string &reason)
   {
      modified=0;
      if(!break_even_enabled && !trailing_enabled){reason="DISABLED";return true;}
      if(!ExecutionAllowed(reason))return false;
      if(trailing_enabled && trailing_method!=TRAIL_FIXED && trailing_method!=TRAIL_ATR)
      {reason="trailing method not implemented in v1";return false;}

      AQSymbolSpec spec;if(!AQSymbolProfile::Load(m_symbol,spec)){reason="symbol unavailable for position management";return false;}
      double atr=0;
      if(trailing_enabled && trailing_method==TRAIL_ATR && !ClosedATR(atr,reason))return false;

      for(int i=PositionsTotal()-1;i>=0;i--)
      {
         ulong ticket=PositionGetTicket(i);
         if(ticket==0){reason="position enumeration failed";return false;}
         if(PositionGetString(POSITION_SYMBOL)!=m_symbol || (ulong)PositionGetInteger(POSITION_MAGIC)!=m_magic)continue;

         long type=PositionGetInteger(POSITION_TYPE);ENUM_AQ_DIRECTION direction;
         if(type==POSITION_TYPE_BUY)direction=AQ_BUY;
         else if(type==POSITION_TYPE_SELL)direction=AQ_SELL;
         else {reason="unknown owned position type";return false;}

         double entry=PositionGetDouble(POSITION_PRICE_OPEN);
         double current_sl=PositionGetDouble(POSITION_SL);
         double tp=PositionGetDouble(POSITION_TP);
         double market=(direction==AQ_BUY?spec.bid:spec.ask);
         double original_risk=0;
         bool risk_side=(direction==AQ_BUY ? current_sl>0 && current_sl<entry : current_sl>entry);
         if(risk_side && !OriginalRisk(ticket,direction,entry,current_sl,original_risk,reason))return false;
         AQStopProposal proposal;
         if(!AQStopManagementPolicy::Build(direction,entry,market,current_sl,original_risk,spec.point,spec.tick_size,
              break_even_enabled,break_even_method,break_even_trigger_r,break_even_distance_points,
              trailing_enabled,trailing_method,trailing_value,atr,proposal))
         {reason=proposal.reason;return false;}
         if(!proposal.change)continue;

         double normalized=AQSymbolProfile::NormalizePrice(spec,proposal.stop);
         if(normalized<=0){reason="position-management stop normalization failed";return false;}
         double epsilon=spec.tick_size*0.1;
         if(direction==AQ_BUY && normalized<=current_sl+epsilon)continue;
         if(direction==AQ_SELL && normalized>=current_sl-epsilon)continue;
         if(!Modify(ticket,normalized,tp,reason))return false;
         modified++;
      }
      reason=(modified>0?"MODIFIED":"NO_CHANGE");return true;
   }

   bool SafeClose(ulong ticket)
   {
      string lock_reason;if(!ExecutionAllowed(lock_reason) || !Owns(ticket)) return false;
      return m_trade.PositionClose(ticket) && (m_trade.ResultRetcode()==TRADE_RETCODE_DONE || m_trade.ResultRetcode()==TRADE_RETCODE_DONE_PARTIAL);
   }
};
#endif
