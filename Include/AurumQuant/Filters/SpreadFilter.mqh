#ifndef AURUM_SPREAD_FILTER_MQH
#define AURUM_SPREAD_FILTER_MQH
class AQSpreadFilter
{
public: static bool Pass(bool enabled,double current,double maximum,string &reason)
   { if(!enabled) { reason="DISABLED"; return true; } if(maximum<=0 || current>maximum) { reason=StringFormat("BLOCKED %.1f > %.1f points",current,maximum); return false; } reason="PASS"; return true; }
};
#endif

