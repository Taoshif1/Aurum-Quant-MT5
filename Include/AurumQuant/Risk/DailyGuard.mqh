#ifndef AURUM_DAILY_GUARD_MQH
#define AURUM_DAILY_GUARD_MQH
class AQDailyGuard
{
private:
   string m_symbol; ulong m_magic; datetime m_day,m_start_time; double m_start_equity,m_start_floating,m_limit; bool m_blocked; string m_key;
   datetime DayStart(datetime t) { MqlDateTime x; if(!TimeToStruct(t,x)) return 0; x.hour=0;x.min=0;x.sec=0; return StructToTime(x); }
   string Key(datetime day) { return StringFormat("AQD.%I64d.%I64u.%s.%I64d",AccountInfoInteger(ACCOUNT_LOGIN),m_magic,StringSubstr(m_symbol,0,12),(long)day); }
   bool OwnPositionSelected() { return PositionGetString(POSITION_SYMBOL)==m_symbol && (ulong)PositionGetInteger(POSITION_MAGIC)==m_magic; }
   double OwnedFloating()
   { double value=0;for(int i=PositionsTotal()-1;i>=0;i--){ulong ticket=PositionGetTicket(i);if(ticket>0&&OwnPositionSelected())value+=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);}return value; }
public:
   AQDailyGuard(void):m_symbol(""),m_magic(0),m_day(0),m_start_time(0),m_start_equity(0),m_start_floating(0),m_limit(0),m_blocked(false),m_key("") {}
   bool Init(string symbol,ulong magic,double limit_percent,string &reason) { m_symbol=symbol;m_magic=magic;m_limit=limit_percent; return ResetIfNeeded(reason); }
   bool ResetIfNeeded(string &reason)
   {
      datetime server=TimeTradeServer(),day=DayStart(server); if(server<=0||day<=0) { reason="server time unavailable"; return false; }
      if(day==m_day && m_start_time>0 && m_start_equity>0) { reason="OK"; return true; }
      m_day=day;m_key=Key(day);m_blocked=false;
      if(MQLInfoInteger(MQL_TESTER))
      {
         m_start_equity=AccountInfoDouble(ACCOUNT_EQUITY);m_start_time=server;m_start_floating=OwnedFloating();
         if(!MathIsValidNumber(m_start_equity) || m_start_equity<=0 || !MathIsValidNumber(m_start_floating)) {reason="invalid tester baseline";return false;}
         reason="OK";return true;
      }
      string time_key=m_key+".T",floating_key=m_key+".F";
      if(GlobalVariableCheck(m_key)&&GlobalVariableCheck(time_key)&&GlobalVariableCheck(floating_key)){m_start_equity=GlobalVariableGet(m_key);m_start_time=(datetime)GlobalVariableGet(time_key);m_start_floating=GlobalVariableGet(floating_key);}
      else
      {
         m_start_equity=AccountInfoDouble(ACCOUNT_EQUITY);m_start_time=server;m_start_floating=OwnedFloating();
         if(m_start_equity<=0 || !GlobalVariableSet(m_key,m_start_equity) || !GlobalVariableSet(time_key,(double)m_start_time) || !GlobalVariableSet(floating_key,m_start_floating)) { reason="cannot persist daily baseline"; return false; }
      }
      if(!MathIsValidNumber(m_start_equity) || !MathIsValidNumber(m_start_floating) || m_start_equity<=0 || m_start_time<day || m_start_time>server) { reason="invalid persisted daily baseline"; return false; }
      reason="OK"; return true;
   }
   bool CurrentOwnedPnL(double &pnl,string &reason)
   {
      pnl=0; if(!HistorySelect(m_start_time,TimeTradeServer())) { reason="history unavailable"; return false; }
      int deals=HistoryDealsTotal();
      for(int i=0;i<deals;i++)
      {
         ulong ticket=HistoryDealGetTicket(i); if(ticket==0) { reason="deal history selection failed"; return false; }
         if(HistoryDealGetString(ticket,DEAL_SYMBOL)!=m_symbol || (ulong)HistoryDealGetInteger(ticket,DEAL_MAGIC)!=m_magic) continue;
         pnl+=HistoryDealGetDouble(ticket,DEAL_PROFIT)+HistoryDealGetDouble(ticket,DEAL_COMMISSION)+HistoryDealGetDouble(ticket,DEAL_SWAP)+HistoryDealGetDouble(ticket,DEAL_FEE);
      }
      pnl+=OwnedFloating()-m_start_floating;
      reason="OK"; return true;
   }
   static bool Evaluate(double baseline,double owned_pnl,double limit_percent,double &loss_percent)
   {
      loss_percent=0; if(baseline<=0||limit_percent<=0||!MathIsValidNumber(baseline)||!MathIsValidNumber(owned_pnl)||!MathIsValidNumber(limit_percent)) { loss_percent=100; return true; }
      loss_percent=MathMax(0.0,-owned_pnl/baseline*100.0); return loss_percent+1e-10>=limit_percent;
   }
   static bool IsNewBrokerDay(datetime stored_day,datetime current_day) { return stored_day<=0 || current_day<=0 || stored_day!=current_day; }
   bool IsBlocked(double &loss_percent,string &reason)
   {
      if(!ResetIfNeeded(reason)) { loss_percent=100;m_blocked=true;return true; }
      double pnl=0; if(!CurrentOwnedPnL(pnl,reason)) { loss_percent=100;m_blocked=true;return true; }
      if(Evaluate(m_start_equity,pnl,m_limit,loss_percent)) m_blocked=true; reason=(m_blocked?"daily EA loss limit reached":"OK"); return m_blocked;
   }
   double StartEquity() const { return m_start_equity; }
   datetime Day() const { return m_day; }
   datetime StartTime() const { return m_start_time; }
};
#endif
