#ifndef AURUM_DASHBOARD_MQH
#define AURUM_DASHBOARD_MQH
#include <AurumQuant/Core/Config.mqh>
class AQDashboard
{
public:
   void PauseButton(bool paused)
   {
      string name="AQ_PAUSE_ENTRIES";
      if(ObjectFind(0,name)<0)
      {
         if(!ObjectCreate(0,name,OBJ_BUTTON,0,0,0))return;
         ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
         ObjectSetInteger(0,name,OBJPROP_XDISTANCE,200);ObjectSetInteger(0,name,OBJPROP_YDISTANCE,20);
         ObjectSetInteger(0,name,OBJPROP_XSIZE,180);ObjectSetInteger(0,name,OBJPROP_YSIZE,28);
         ObjectSetInteger(0,name,OBJPROP_FONTSIZE,10);ObjectSetInteger(0,name,OBJPROP_COLOR,clrWhite);
         ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      }
      ObjectSetString(0,name,OBJPROP_TEXT,paused?"Resume new entries":"Pause new entries");
      ObjectSetInteger(0,name,OBJPROP_BGCOLOR,paused?clrDarkGreen:clrFireBrick);
      ObjectSetInteger(0,name,OBJPROP_STATE,false);ChartRedraw();
   }
   void Render(const AQSettings &c,string engine_state,string symbol_state,string freshness,string execution_lock,string risk_status,datetime evaluation_bar,datetime evaluation_time,ENUM_TREND_STATE trend,ENUM_SIGNAL_STATE signal,double spread,string spread_state,string session_state,string news_state,string weekend_state,double daily_loss,int positions,string decision,string blocked_reason)
   {
      string s="AURUM QUANT 1.25 | RESEARCH\n";
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
   void Clear() { Comment("");ObjectDelete(0,"AQ_PAUSE_ENTRIES"); }
};
#endif
