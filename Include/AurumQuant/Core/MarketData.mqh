#ifndef AURUM_MARKET_DATA_MQH
#define AURUM_MARKET_DATA_MQH
class AQMarketData
{
private:
   string m_symbol; ENUM_TIMEFRAMES m_entry_tf; datetime m_last_bar; datetime m_last_evaluated_bar; datetime m_last_submitted_bar;
public:
   void Init(string symbol,ENUM_TIMEFRAMES tf) { m_symbol=symbol; m_entry_tf=tf; m_last_bar=iTime(symbol,tf,0); m_last_evaluated_bar=0; m_last_submitted_bar=0; }
   bool IsNewBar(datetime &closed_bar_identity)
   {
      closed_bar_identity=0; datetime now=iTime(m_symbol,m_entry_tf,0); if(now<=0 || now==m_last_bar) return false;
      m_last_bar=now; datetime closed=iTime(m_symbol,m_entry_tf,1); if(closed<=0 || closed==m_last_evaluated_bar) return false;
      m_last_evaluated_bar=closed; closed_bar_identity=closed; return true;
   }
   bool Rates(ENUM_TIMEFRAMES tf,int start,int count,MqlRates &rates[])
   { ArraySetAsSeries(rates,true); return CopyRates(m_symbol,tf,start,count,rates)==count; }
   bool Fresh(int maximum_age_seconds,int &age_seconds)
   {
      datetime tick_time=(datetime)SymbolInfoInteger(m_symbol,SYMBOL_TIME); datetime server=TimeTradeServer();
      if(tick_time<=0 || server<=0 || tick_time>server+5) { age_seconds=INT_MAX; return false; }
      age_seconds=(int)MathMax(0,server-tick_time); return age_seconds<=maximum_age_seconds;
   }
   bool CanSubmit(datetime signal_bar,string &reason)
   { if(signal_bar<=0 || signal_bar!=m_last_evaluated_bar || signal_bar==m_last_submitted_bar) { reason="duplicate or stale signal identity"; return false; } reason="OK"; return true; }
   void MarkSubmitted(datetime signal_bar) { if(signal_bar==m_last_evaluated_bar) m_last_submitted_bar=signal_bar; }
   datetime LastEvaluatedBar() const { return m_last_evaluated_bar; }
};
#endif
