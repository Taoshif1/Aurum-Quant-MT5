#ifndef AURUM_BREAKOUT_PULLBACK_MQH
#define AURUM_BREAKOUT_PULLBACK_MQH
#include <AurumQuant/Core/Config.mqh>
class AQBreakoutPullback
{
private: ENUM_SIGNAL_STATE m_state;
public:
   AQBreakoutPullback(void):m_state(NO_SETUP) {}
   void Reset() { m_state=NO_SETUP; }
   ENUM_SIGNAL_STATE State() const { return m_state; }
   void ArmTrend() { m_state=TREND_READY; }
   // Transition methods intentionally require future approved mathematical rules.
   void MarkBreakout() { m_state=BREAKOUT_DETECTED; }
   void WaitPullback() { m_state=WAITING_PULLBACK; }
   void WaitConfirmation() { m_state=WAITING_CONFIRMATION; }
};
#endif

