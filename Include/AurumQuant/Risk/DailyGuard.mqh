#ifndef AURUM_DAILY_GUARD_MQH
#define AURUM_DAILY_GUARD_MQH
class AQDailyGuard
{
private: datetime m_day; double m_start_equity,m_limit; bool m_blocked;
   datetime DayStart(datetime t) { MqlDateTime x; TimeToStruct(t,x); x.hour=0;x.min=0;x.sec=0; return StructToTime(x); }
public:
   AQDailyGuard(void):m_day(0),m_start_equity(0),m_limit(0),m_blocked(false) {}
   void Init(double limit_percent) { m_limit=limit_percent; ResetIfNeeded(); }
   void ResetIfNeeded()
   {
      datetime d=DayStart(TimeTradeServer()); if(d!=m_day) { m_day=d; m_start_equity=AccountInfoDouble(ACCOUNT_EQUITY); m_blocked=false; }
   }
   bool IsBlocked(double &drawdown_percent)
   {
      ResetIfNeeded(); double eq=AccountInfoDouble(ACCOUNT_EQUITY); drawdown_percent=(m_start_equity>0 ? MathMax(0.0,(m_start_equity-eq)/m_start_equity*100.0) : 100.0);
      if(m_start_equity<=0 || (m_limit>0 && drawdown_percent>=m_limit)) m_blocked=true; return m_blocked;
   }
   double StartEquity() const { return m_start_equity; }
};
#endif

