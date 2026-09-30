#ifndef AURUM_TRADE_MANAGER_MQH
#define AURUM_TRADE_MANAGER_MQH
#include <Trade/Trade.mqh>
#include <AurumQuant/Trading/ExecutionPolicy.mqh>
#include <AurumQuant/Risk/RiskManager.mqh>
struct AQTradeResult
{
   bool submitted; bool accepted; uint retcode; string description; double broker_price;
};
class AQTradeManager
{
private:
   CTrade m_trade; ENUM_AQ_MODE m_mode; bool m_armed; string m_symbol; datetime m_last_signal_bar; ulong m_magic; string m_bar_key;
   void ResetResult(AQTradeResult &result) { result.submitted=false;result.accepted=false;result.retcode=0;result.description="not submitted";result.broker_price=0; }
   bool RetcodeAccepted(uint code) { return code==TRADE_RETCODE_DONE || code==TRADE_RETCODE_DONE_PARTIAL || code==TRADE_RETCODE_PLACED; }
   bool Prepare(datetime signal_bar,AQTradeResult &result,string &reason)
   {
      ResetResult(result); if(!ExecutionAllowed(reason)) return false;
      if(signal_bar<=0 || signal_bar<=m_last_signal_bar) { reason="duplicate or stale signal bar"; return false; }
      if(MQLInfoInteger(MQL_TESTER)){m_last_signal_bar=signal_bar;return true;}
      if(m_bar_key=="" || StringLen(m_bar_key)>63) {reason="signal persistence key invalid";return false;}
      if(GlobalVariableCheck(m_bar_key))
      {
         double previous=GlobalVariableGet(m_bar_key);
         if(!MathIsValidNumber(previous) || previous<0 || signal_bar<=(datetime)previous || !GlobalVariableSetOnCondition(m_bar_key,(double)signal_bar,previous))
         {reason="signal already consumed or another instance is submitting";return false;}
      }
      else if(!GlobalVariableSet(m_bar_key,(double)signal_bar)) {reason="cannot persist signal identity";return false;}
      GlobalVariablesFlush();
      m_last_signal_bar=signal_bar; return true; // Mark before request: a rejection is not retried every tick.
   }
   bool ValidateRequest(ENUM_AQ_DIRECTION direction,string symbol,double volume,double entry,double sl,double tp,string &reason)
   {
      if(symbol!=m_symbol) { reason="request symbol differs from configured symbol"; return false; }
      AQSymbolSpec spec;if(!AQSymbolProfile::Load(symbol,spec)) { reason="SYMBOL DATA INVALID: "+spec.error; return false; }
      if(!AQSymbolProfile::DirectionAllowed(spec,direction,reason)) return false;
      double normalized_volume=AQSymbolProfile::NormalizeVolumeDown(spec,volume);if(normalized_volume<=0 || MathAbs(normalized_volume-volume)>1e-8) { reason="volume not normalized on broker grid"; return false; }
      double normalized_entry=AQSymbolProfile::NormalizePrice(spec,entry);if(normalized_entry<=0 || !MathIsValidNumber(entry) || entry<=0 || MathAbs(normalized_entry-entry)>spec.tick_size*0.1) { reason="entry not normalized to tick size"; return false; }
      if(!TerminalInfoInteger(TERMINAL_CONNECTED) || !TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ||
         !MQLInfoInteger(MQL_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
      {reason="terminal/account algorithmic trading unavailable";return false;}
      ENUM_ORDER_TYPE type=direction==AQ_BUY?ORDER_TYPE_BUY:ORDER_TYPE_SELL;double margin=0,free_margin=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(!MathIsValidNumber(free_margin) || free_margin<=0 || !OrderCalcMargin(type,symbol,volume,entry,margin) || !MathIsValidNumber(margin) || margin<0 || margin>free_margin)
      {reason="margin preflight failed";return false;}
      return AQRiskManager::ValidateStops(spec,direction,sl,tp,false,reason);
   }
   void Capture(bool call_result,string request,double volume,double entry,double sl,double tp,AQTradeResult &result)
   {
      result.submitted=true;result.retcode=m_trade.ResultRetcode();result.description=m_trade.ResultRetcodeDescription();result.broker_price=m_trade.ResultPrice();
      result.accepted=call_result && RetcodeAccepted(result.retcode);
      PrintFormat("AURUM|TRADE_RESULT|request=%s|symbol=%s|volume=%.8f|entry=%.*f|sl=%.*f|tp=%.*f|call=%s|retcode=%u|accepted=%s|broker_price=%.*f|description=%s",request,m_symbol,volume,(int)SymbolInfoInteger(m_symbol,SYMBOL_DIGITS),entry,(int)SymbolInfoInteger(m_symbol,SYMBOL_DIGITS),sl,(int)SymbolInfoInteger(m_symbol,SYMBOL_DIGITS),tp,(call_result?"true":"false"),result.retcode,(result.accepted?"true":"false"),(int)SymbolInfoInteger(m_symbol,SYMBOL_DIGITS),result.broker_price,result.description);
   }
public:
   AQTradeManager(void):m_mode(MODE_OBSERVE),m_armed(false),m_symbol(""),m_last_signal_bar(0),m_magic(0),m_bar_key("") {}
   void Init(ENUM_AQ_MODE mode,bool armed,ulong magic,string symbol) { m_mode=mode;m_armed=armed;m_symbol=symbol;m_magic=magic;m_last_signal_bar=0;
      m_bar_key=StringFormat("AQB.%I64d.%I64u.%s",AccountInfoInteger(ACCOUNT_LOGIN),magic,symbol);
      // Tester runs must not consume identities from independent passes.
      if(MQLInfoInteger(MQL_TESTER))m_bar_key="";
      m_trade.SetAsyncMode(false);m_trade.SetExpertMagicNumber(magic);m_trade.SetTypeFillingBySymbol(symbol); }
   void SetDeviation(ulong points) { m_trade.SetDeviationInPoints(points); }
   bool ExecutionAllowed(string &reason)
   {
      return AQExecutionPolicy::Allows(m_mode,m_armed,AccountInfoInteger(ACCOUNT_TRADE_MODE),reason);
   }
   bool Buy(datetime signal_bar,string symbol,double volume,double entry,double sl,double tp,string comment,AQTradeResult &result)
   { ResetResult(result);string why;if(!ValidateRequest(AQ_BUY,symbol,volume,entry,sl,tp,why)||!Prepare(signal_bar,result,why)){result.description=why;return false;}bool called=m_trade.Buy(volume,symbol,entry,sl,tp,comment);Capture(called,"BUY",volume,entry,sl,tp,result);return result.accepted; }
   bool Sell(datetime signal_bar,string symbol,double volume,double entry,double sl,double tp,string comment,AQTradeResult &result)
   { ResetResult(result);string why;if(!ValidateRequest(AQ_SELL,symbol,volume,entry,sl,tp,why)||!Prepare(signal_bar,result,why)){result.description=why;return false;}bool called=m_trade.Sell(volume,symbol,entry,sl,tp,comment);Capture(called,"SELL",volume,entry,sl,tp,result);return result.accepted; }
};
#endif
