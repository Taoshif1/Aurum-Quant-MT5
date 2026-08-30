#ifndef AURUM_STRATEGY_ENGINE_MQH
#define AURUM_STRATEGY_ENGINE_MQH
#include <AurumQuant/Strategy/BreakoutPullback.mqh>
#include <AurumQuant/Strategy/IStrategy.mqh>
class AQStrategyEngine : public IAQStrategy
{
private: AQBreakoutPullback m_setup; ENUM_SIGNAL_STATE m_state;
public:
   AQStrategyEngine(void):m_state(NO_SETUP) {}
   string Name() const { return "BreakoutPullback (research scaffold)"; }
   ENUM_SIGNAL_STATE Evaluate(ENUM_TREND_STATE trend,datetime closed_bar)
   {
      if(closed_bar<=0) { m_state=SIGNAL_BLOCKED; return m_state; }
      // Foundation phase: trend readiness is observable, but no entry candidate is emitted.
      if(trend==TREND_BULLISH || trend==TREND_BEARISH) { m_setup.ArmTrend(); m_state=TREND_READY; }
      else m_state=NO_SETUP;
      return m_state;
   }
   ENUM_SIGNAL_STATE State() const { return m_state; }
};
#endif
