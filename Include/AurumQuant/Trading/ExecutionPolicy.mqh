#ifndef AURUM_EXECUTION_POLICY_MQH
#define AURUM_EXECUTION_POLICY_MQH
#include <AurumQuant/Core/Config.mqh>
// Shared by every entry and position mutation boundary.
class AQExecutionPolicy
{
public:
   static bool Allows(ENUM_AQ_MODE mode,bool armed,long account_mode,string &reason)
   {
      if(mode==MODE_OBSERVE) { reason="OBSERVE mode prohibits trade requests"; return false; }
      if(!armed) { reason="order submission master switch is OFF"; return false; }
      if(mode==MODE_DEMO && account_mode!=ACCOUNT_TRADE_MODE_DEMO) { reason="DEMO mode requires a demo account"; return false; }
      if(mode==MODE_LIVE && account_mode!=ACCOUNT_TRADE_MODE_REAL) { reason="LIVE mode requires a real account"; return false; }
      if(mode!=MODE_DEMO && mode!=MODE_LIVE) { reason="unknown operating mode"; return false; }
      reason="OK"; return true;
   }
};
#endif
