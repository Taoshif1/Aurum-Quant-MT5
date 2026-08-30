#ifndef AURUM_MARKET_DATA_MQH
#define AURUM_MARKET_DATA_MQH
class AQMarketData
{
private:
   string m_symbol; ENUM_TIMEFRAMES m_entry_tf; datetime m_last_bar;
public:
   void Init(string symbol,ENUM_TIMEFRAMES tf) { m_symbol=symbol; m_entry_tf=tf; m_last_bar=iTime(symbol,tf,0); }
   bool IsNewBar()
   {
      datetime now=iTime(m_symbol,m_entry_tf,0); if(now<=0 || now==m_last_bar) return false; m_last_bar=now; return true;
   }
   bool Rates(ENUM_TIMEFRAMES tf,int start,int count,MqlRates &rates[])
   { ArraySetAsSeries(rates,true); return CopyRates(m_symbol,tf,start,count,rates)==count; }
};
#endif

