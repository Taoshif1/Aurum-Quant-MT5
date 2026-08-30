#ifndef AURUM_DASHBOARD_MQH
#define AURUM_DASHBOARD_MQH
#include <AurumQuant/Core/Config.mqh>
class AQDashboard
{
public:
   void Render(const AQSettings &c,ENUM_TREND_STATE trend,ENUM_SIGNAL_STATE signal,double spread,string spread_state,string session_state,string news_state,string weekend_state,double daily_dd,int positions,string decision,string blocked_reason)
   {
      string s="AURUM QUANT EA\n";
      s+="Mode: "+AQModeName(c.mode)+"\nAsset profile: "+AQProfileName(c.profile)+"\nSymbol: "+c.symbol+"\n";
      s+=StringFormat("Entry TF: %s | Trend TF: %s\n",EnumToString(c.entry_tf),EnumToString(c.trend_tf));
      s+="Trend: "+AQTrendName(trend)+"\n"+StringFormat("Spread: %.1f / %.1f points [%s]\n",spread,c.max_spread_points,spread_state);
      s+="Session: "+session_state+"\nNews: "+news_state+"\nWeekend: "+weekend_state+"\n";
      s+=StringFormat("Daily drawdown: %.2f%% / %.2f%%\nEA positions: %d / %d\n",daily_dd,c.daily_loss_percent,positions,c.max_positions);
      s+="Strategy: "+AQSignalName(signal)+"\nDecision: "+decision;
      if(blocked_reason!="") s+="\nBlocked reason: "+blocked_reason;
      Comment(s);
   }
   void Clear() { Comment(""); }
};
#endif
