#ifndef AURUM_ENTRY_LIMITS_MQH
#define AURUM_ENTRY_LIMITS_MQH
class AQEntryLimits
{
public:
   static bool Pass(string symbol,ulong magic,int max_daily,int cooldown_bars,ENUM_TIMEFRAMES tf,string &reason)
   {
      datetime now=TimeTradeServer();MqlDateTime d;
      if(max_daily<1 || cooldown_bars<0 || now<=0 || !TimeToStruct(now,d)) {reason="invalid entry limit inputs";return false;}
      d.hour=0;d.min=0;d.sec=0;datetime day=StructToTime(d);
      // Full history preserves cooldown across weekends and terminal restarts.
      if(!HistorySelect(0,now)){reason="entry history unavailable";return false;}
      int count=0;datetime latest=0;
      for(int i=HistoryDealsTotal()-1;i>=0;i--)
      {
         ulong ticket=HistoryDealGetTicket(i);if(ticket==0){reason="entry history unreadable";return false;}
         if(HistoryDealGetString(ticket,DEAL_SYMBOL)!=symbol || (ulong)HistoryDealGetInteger(ticket,DEAL_MAGIC)!=magic) continue;
         long entry=HistoryDealGetInteger(ticket,DEAL_ENTRY);
         if(entry!=DEAL_ENTRY_IN && entry!=DEAL_ENTRY_INOUT) continue;
         datetime when=(datetime)HistoryDealGetInteger(ticket,DEAL_TIME);
         if(when<=0 || when>now){reason="invalid entry history timestamp";return false;}
         if(when>=day) count++;if(when>latest)latest=when;
      }
      if(count>=max_daily){reason="daily entry count reached";return false;}
      if(latest>0 && cooldown_bars>0)
      {
         int shift=iBarShift(symbol,tf,latest,false);
         if(shift<0 || shift<cooldown_bars){reason="entry cooldown or bar history unavailable";return false;}
      }
      reason="OK";return true;
   }
};
#endif
