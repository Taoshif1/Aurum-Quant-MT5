#ifndef AURUM_DASHBOARD_MQH
#define AURUM_DASHBOARD_MQH
#include <AurumQuant/Core/Config.mqh>
class AQDashboard
{
public:
   void Render(const AQSettings &c,string engine_state,string symbol_state,string freshness,string execution_lock,string risk_status,datetime evaluation_bar,datetime evaluation_time,ENUM_TREND_STATE trend,ENUM_SIGNAL_STATE signal,double spread,string spread_state,string session_state,string news_state,string weekend_state,double daily_loss,int positions,string decision,string blocked_reason)
   {
      string s="AURUM QUANT EA\n";
      s+="Engine: "+engine_state+"\nSymbol data: "+symbol_state+"\nData freshness: "+freshness+"\nExecution lock: "+execution_lock+"\nRisk sizing: "+risk_status+"\n";
      s+="Mode: "+AQModeName(c.mode)+"\nAsset profile: "+AQProfileName(c.profile)+"\nSymbol: "+c.symbol+"\n";
      s+=StringFormat("Entry TF: %s | Trend TF: %s\n",EnumToString(c.entry_tf),EnumToString(c.trend_tf));
      s+="Trend: "+AQTrendName(trend)+"\n"+StringFormat("Spread: %.1f / %.1f broker points [%s]\n",spread,c.max_spread_points,spread_state);
      s+="Session: "+session_state+"\nNews: "+news_state+"\nWeekend: "+weekend_state+"\n";
      s+=StringFormat("Daily EA loss: %.2f%% / %.2f%%\nEA positions: %d / %d\n",daily_loss,c.daily_loss_percent,positions,c.max_positions);
      s+="Signal bar: "+(evaluation_bar>0?TimeToString(evaluation_bar,TIME_DATE|TIME_MINUTES):"NONE")+"\nEvaluated: "+(evaluation_time>0?TimeToString(evaluation_time,TIME_DATE|TIME_SECONDS):"NEVER")+"\n";
      s+="Strategy: "+AQSignalName(signal)+"\nDecision: "+decision;
      if(blocked_reason!="") s+="\nBlocked reason: "+blocked_reason;
      Comment(s);
   }
   void Clear() { Comment(""); }
};
#endif
