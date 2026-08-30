#ifndef AURUM_NEWS_FILTER_MQH
#define AURUM_NEWS_FILTER_MQH
class AQNewsFilter
{
public:
   static bool Pass(bool enabled,int before_minutes,int after_minutes,string currency,string &reason)
   {
      if(!enabled) { reason="DISABLED"; return true; }
      datetime now=TimeTradeServer(); MqlCalendarValue values[];
      ResetLastError(); int n=CalendarValueHistory(values,now-after_minutes*60,now+before_minutes*60,NULL,currency);
      if(n<0) { reason=StringFormat("BLOCKED calendar unavailable err=%d",GetLastError()); return false; }
      for(int i=0;i<n;i++) { MqlCalendarEvent event; if(CalendarEventById(values[i].event_id,event) && event.importance==CALENDAR_IMPORTANCE_HIGH) { reason="BLOCKED high-impact "+currency+" event"; return false; } }
      reason="CLEAR"; return true;
   }
};
#endif

