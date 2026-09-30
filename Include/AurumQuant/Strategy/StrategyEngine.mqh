#ifndef AURUM_STRATEGY_ENGINE_MQH
#define AURUM_STRATEGY_ENGINE_MQH
#include <AurumQuant/Strategy/BreakoutPullback.mqh>
#include <AurumQuant/Strategy/IStrategy.mqh>
class AQStrategyEngine : public IAQStrategy
{
private:
   AQBreakoutPullback m_setup;ENUM_SIGNAL_STATE m_state;
   string m_symbol;ENUM_TIMEFRAMES m_tf;int m_lookback,m_timeout,m_atr_handle;
   datetime m_previous_bar;double m_buffer,m_tolerance,m_atr;bool m_enabled;
public:
   AQStrategyEngine(void):m_state(NO_SETUP),m_lookback(20),m_timeout(6),m_atr_handle(INVALID_HANDLE),m_previous_bar(0),m_buffer(0.1),m_tolerance(0.25),m_atr(0),m_enabled(false) {}
   string Name() const { return "Breakout/retest v1 (unvalidated research)"; }
   bool Init(string symbol,ENUM_TIMEFRAMES tf,bool enabled,int lookback,int atr_period,double buffer,double tolerance,int timeout)
   {
      m_symbol=symbol;m_tf=tf;m_enabled=enabled;m_lookback=lookback;m_buffer=buffer;m_tolerance=tolerance;m_timeout=timeout;
      if(lookback<2 || lookback>1000 || atr_period<2 || timeout<1 || buffer<0 || tolerance<0 || !MathIsValidNumber(buffer) || !MathIsValidNumber(tolerance)) return false;
      if(!enabled) return true;
      m_atr_handle=iATR(symbol,tf,atr_period);return m_atr_handle!=INVALID_HANDLE;
   }
   void Shutdown() { if(m_atr_handle!=INVALID_HANDLE){IndicatorRelease(m_atr_handle);m_atr_handle=INVALID_HANDLE;} }
   double ATR() const { return m_atr; }
   double Level() const { return m_setup.Level(); }
   ENUM_SIGNAL_STATE Evaluate(ENUM_TREND_STATE trend,datetime closed_bar)
   {
      if(!m_enabled) {m_state=NO_SETUP;return m_state;}
      MqlRates rates[];ArraySetAsSeries(rates,true);double atr[1];
      if(closed_bar<=0 || CopyRates(m_symbol,m_tf,1,m_lookback+1,rates)!=m_lookback+1 ||
         rates[0].time!=closed_bar || CopyBuffer(m_atr_handle,0,1,1,atr)!=1)
      { m_setup.Reset();m_state=SIGNAL_BLOCKED;m_atr=0;return m_state; }
      // Missing evaluation bars (disconnect/history gap) invalidate a pending setup.
      if(m_previous_bar>0 && closed_bar>m_previous_bar && iBarShift(m_symbol,m_tf,m_previous_bar,true)!=2)m_setup.Reset();
      m_previous_bar=closed_bar;
      AQSetupBar b;b.time=closed_bar;b.open=rates[0].open;b.high=rates[0].high;b.low=rates[0].low;b.close=rates[0].close;
      b.previous_close=rates[1].close;b.channel_high=rates[1].high;b.channel_low=rates[1].low;b.atr=atr[0];
      for(int i=1;i<=m_lookback;i++)
      {
         if(rates[i].time<=0 || rates[i].time>=rates[i-1].time ||
            !MathIsValidNumber(rates[i].high) || !MathIsValidNumber(rates[i].low) || rates[i].low<=0 || rates[i].high<rates[i].low)
         {m_setup.Reset();m_state=SIGNAL_BLOCKED;m_atr=0;return m_state;}
         b.channel_high=MathMax(b.channel_high,rates[i].high);b.channel_low=MathMin(b.channel_low,rates[i].low);
      }
      m_atr=b.atr;m_state=m_setup.Step(trend,b,m_buffer,m_tolerance,m_timeout);return m_state;
   }
   ENUM_SIGNAL_STATE State() const { return m_state; }
};
#endif
