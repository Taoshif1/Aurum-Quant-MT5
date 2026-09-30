#ifndef AURUM_SESSION_FILTER_MQH
#define AURUM_SESSION_FILTER_MQH
class AQSessionFilter
{
public: static bool Pass(bool enabled,int start_hour,int end_hour,string &reason)
   {
      if(!enabled) { reason="DISABLED"; return true; } if(start_hour<0||start_hour>23||end_hour<0||end_hour>23) { reason="BLOCKED invalid hours"; return false; }
      MqlDateTime t;datetime now=TimeTradeServer();if(now<=0 || !TimeToStruct(now,t)){reason="BLOCKED: server time unavailable";return false;} bool active=(start_hour==end_hour)||(start_hour<end_hour ? t.hour>=start_hour&&t.hour<end_hour : t.hour>=start_hour||t.hour<end_hour);
      reason=active?"ACTIVE":"BLOCKED"; return active;
   }
   static bool WeekendPass(bool allowed,string &reason)
   { MqlDateTime t;datetime now=TimeTradeServer();if(now<=0 || !TimeToStruct(now,t)){reason="BLOCKED: server time unavailable";return false;} bool weekend=(t.day_of_week==0||t.day_of_week==6); if(weekend&&!allowed) { reason="BLOCKED by weekend policy"; return false; } reason=weekend?"ALLOWED (broker availability still required)":"WEEKDAY"; return true; }
};
#endif

