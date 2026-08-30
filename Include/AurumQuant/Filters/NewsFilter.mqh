#ifndef AURUM_NEWS_FILTER_MQH
#define AURUM_NEWS_FILTER_MQH
enum ENUM_NEWS_STATE { NEWS_CLEAR=0,NEWS_BLOCKED=1,NEWS_DISABLED=2,NEWS_UNAVAILABLE=3 };
class AQNewsFilter
{
public:
   static ENUM_NEWS_STATE Evaluate(bool enabled,int before_minutes,int after_minutes,string currency,string &reason)
   {
      if(!enabled) { reason="DISABLED"; return NEWS_DISABLED; }
      if(before_minutes<0 || after_minutes<0 || currency=="") { reason="UNAVAILABLE: invalid calendar configuration"; return NEWS_UNAVAILABLE; }
      datetime now=TimeTradeServer(); MqlCalendarValue values[];
      ResetLastError(); int n=CalendarValueHistory(values,now-after_minutes*60,now+before_minutes*60,NULL,currency);
      if(n<0) { reason=StringFormat("UNAVAILABLE: calendar err=%d",GetLastError()); return NEWS_UNAVAILABLE; }
      for(int i=0;i<n;i++)
      {
         MqlCalendarEvent event; ResetLastError();
         if(!CalendarEventById(values[i].event_id,event)) { reason=StringFormat("UNAVAILABLE: event lookup err=%d",GetLastError()); return NEWS_UNAVAILABLE; }
         if(event.importance==CALENDAR_IMPORTANCE_HIGH) { reason="BLOCKED: high-impact "+currency+" event"; return NEWS_BLOCKED; }
      }
      reason="CLEAR"; return NEWS_CLEAR;
   }
};
#endif
