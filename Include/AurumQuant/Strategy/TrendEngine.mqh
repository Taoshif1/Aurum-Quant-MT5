#ifndef AURUM_TREND_ENGINE_MQH
#define AURUM_TREND_ENGINE_MQH
#include <AurumQuant/Core/Config.mqh>
class AQTrendEngine
{
private:
   string m_symbol; ENUM_TIMEFRAMES m_tf; int m_fast,m_slow; int m_fast_handle,m_slow_handle;
public:
   AQTrendEngine(void):m_fast_handle(INVALID_HANDLE),m_slow_handle(INVALID_HANDLE) {}
   bool Init(string symbol,ENUM_TIMEFRAMES tf,int fast_period,int slow_period)
   {
      m_symbol=symbol; m_tf=tf; m_fast=fast_period; m_slow=slow_period;
      if(fast_period<=0 || slow_period<=fast_period) return false;
      m_fast_handle=iMA(symbol,tf,fast_period,0,MODE_EMA,PRICE_CLOSE); m_slow_handle=iMA(symbol,tf,slow_period,0,MODE_EMA,PRICE_CLOSE);
      if(m_fast_handle==INVALID_HANDLE || m_slow_handle==INVALID_HANDLE){Shutdown();return false;}
      return true;
   }
   ENUM_TREND_STATE Evaluate()
   {
      if(BarsCalculated(m_fast_handle)<m_slow || BarsCalculated(m_slow_handle)<m_slow) return TREND_DATA_NOT_READY;
      double f[1],s[1]; if(CopyBuffer(m_fast_handle,0,1,1,f)!=1 || CopyBuffer(m_slow_handle,0,1,1,s)!=1) return TREND_DATA_NOT_READY;
      if(!MathIsValidNumber(f[0]) || !MathIsValidNumber(s[0]) || f[0]<=0 || s[0]<=0) return TREND_DATA_NOT_READY;
      if(f[0]>s[0]) return TREND_BULLISH; if(f[0]<s[0]) return TREND_BEARISH; return TREND_NEUTRAL;
   }
   void Shutdown() { if(m_fast_handle!=INVALID_HANDLE) IndicatorRelease(m_fast_handle); if(m_slow_handle!=INVALID_HANDLE) IndicatorRelease(m_slow_handle);m_fast_handle=INVALID_HANDLE;m_slow_handle=INVALID_HANDLE; }
};
#endif
