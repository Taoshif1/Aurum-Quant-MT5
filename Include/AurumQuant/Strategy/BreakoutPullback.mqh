#ifndef AURUM_BREAKOUT_PULLBACK_MQH
#define AURUM_BREAKOUT_PULLBACK_MQH
#include <AurumQuant/Core/Config.mqh>
// Pure closed-bar state machine. No terminal access and no order calls.
struct AQSetupBar
{
   datetime time;
   double open,high,low,close,previous_close,channel_high,channel_low,atr;
};
class AQBreakoutPullback
{
private:
   ENUM_SIGNAL_STATE m_state;
   ENUM_TREND_STATE m_trend;
   datetime m_last_bar;
   double m_level,m_atr;
   int m_age;
public:
   AQBreakoutPullback(void):m_state(NO_SETUP),m_trend(TREND_NEUTRAL),m_last_bar(0),m_level(0),m_atr(0),m_age(0) {}
   void Reset() { m_state=NO_SETUP;m_trend=TREND_NEUTRAL;m_level=0;m_atr=0;m_age=0; }
   ENUM_SIGNAL_STATE State() const { return m_state; }
   double Level() const { return m_level; }
   static bool Valid(const AQSetupBar &b)
   {
      return b.time>0 && MathIsValidNumber(b.open) && MathIsValidNumber(b.high) &&
         MathIsValidNumber(b.low) && MathIsValidNumber(b.close) &&
         MathIsValidNumber(b.previous_close) && MathIsValidNumber(b.channel_high) &&
         MathIsValidNumber(b.channel_low) && MathIsValidNumber(b.atr) && b.atr>0 &&
         b.low>0 && b.high>=b.low && b.open>=b.low && b.open<=b.high &&
         b.close>=b.low && b.close<=b.high && b.previous_close>0 &&
         b.channel_low>0 && b.channel_high>=b.channel_low;
   }
   ENUM_SIGNAL_STATE Step(ENUM_TREND_STATE trend,const AQSetupBar &b,double buffer_atr,double tolerance_atr,int timeout)
   {
      if(!Valid(b) || !MathIsValidNumber(buffer_atr) || !MathIsValidNumber(tolerance_atr) ||
         buffer_atr<0 || tolerance_atr<0 || timeout<1)
      { Reset();return SIGNAL_BLOCKED; }
      if(b.time<=m_last_bar) return NO_SETUP; // No repeated candidate for duplicate or stale bars.
      m_last_bar=b.time;
      if(trend!=TREND_BULLISH && trend!=TREND_BEARISH) { Reset();return NO_SETUP; }
      if(m_state==BREAKOUT_DETECTED || m_state==WAITING_PULLBACK)
      {
         m_age++;
         if(trend!=m_trend || m_age>timeout) { Reset();return NO_SETUP; }
         double tolerance=m_atr*tolerance_atr;
         bool buy=(m_trend==TREND_BULLISH);
         if((buy && b.close<m_level-tolerance) || (!buy && b.close>m_level+tolerance))
         { Reset();return NO_SETUP; }
         bool touch=buy ? (b.low>=m_level-tolerance && b.low<=m_level+tolerance) :
                          (b.high>=m_level-tolerance && b.high<=m_level+tolerance);
         bool confirm=buy ? (b.close>m_level && b.close>b.open) : (b.close<m_level && b.close<b.open);
         if(touch && confirm) { Reset();return buy ? BUY_CANDIDATE : SELL_CANDIDATE; }
         m_state=WAITING_PULLBACK;return m_state;
      }
      bool up=trend==TREND_BULLISH && b.previous_close<=b.channel_high && b.close>b.channel_high+b.atr*buffer_atr;
      bool down=trend==TREND_BEARISH && b.previous_close>=b.channel_low && b.close<b.channel_low-b.atr*buffer_atr;
      if(up || down) { m_trend=trend;m_level=up?b.channel_high:b.channel_low;m_atr=b.atr;m_age=0;m_state=BREAKOUT_DETECTED; }
      else m_state=TREND_READY;
      return m_state;
   }
};
#endif
