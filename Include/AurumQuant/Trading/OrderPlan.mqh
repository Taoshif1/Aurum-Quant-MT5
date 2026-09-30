#ifndef AURUM_ORDER_PLAN_MQH
#define AURUM_ORDER_PLAN_MQH
#include <AurumQuant/Risk/RiskManager.mqh>
struct AQOrderPlan
{
   ENUM_AQ_DIRECTION direction;
   double entry,sl,tp,volume,estimated_loss,margin;
};
class AQOrderPlanner
{
public:
   static bool Build(const AQSymbolSpec &s,ENUM_AQ_DIRECTION direction,double atr,double multiplier,double reward_risk,double risk_percent,AQOrderPlan &p,string &reason)
   {
      ZeroMemory(p);p.direction=direction;
      if(!AQSymbolProfile::DirectionAllowed(s,direction,reason)) return false;
      if(!MathIsValidNumber(atr) || !MathIsValidNumber(multiplier) || !MathIsValidNumber(reward_risk) ||
         !MathIsValidNumber(risk_percent) || atr<=0 || multiplier<=0 || reward_risk<=0 || risk_percent<=0 || risk_percent>100)
      {reason="invalid order plan inputs";return false;}
      bool buy=(direction==AQ_BUY);p.entry=AQSymbolProfile::NormalizePrice(s,buy?s.ask:s.bid);
      double distance=atr*multiplier;
      double raw_stop=buy?p.entry-distance:p.entry+distance;
      p.sl=NormalizeDouble((buy?MathFloor(raw_stop/s.tick_size):MathCeil(raw_stop/s.tick_size))*s.tick_size,s.digits);
      double target=buy?p.entry+(p.entry-p.sl)*reward_risk:p.entry-(p.sl-p.entry)*reward_risk;
      p.tp=NormalizeDouble((buy?MathCeil(target/s.tick_size):MathFloor(target/s.tick_size))*s.tick_size,s.digits);
      if(p.entry<=0 || !AQRiskManager::ValidateStops(s,direction,p.sl,p.tp,false,reason))return false;
      ENUM_ORDER_TYPE type=buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
      double equity=AccountInfoDouble(ACCOUNT_EQUITY),minimum_loss=0;
      if(!MathIsValidNumber(equity) || equity<=0 || !OrderCalcProfit(type,s.name,s.volume_min,p.entry,p.sl,minimum_loss) ||
         !MathIsValidNumber(minimum_loss) || minimum_loss>=0) {reason="broker loss calculation unavailable";return false;}
      double budget=equity*risk_percent/100.0;
      p.volume=AQSymbolProfile::NormalizeVolumeDown(s,budget/(-minimum_loss)*s.volume_min);
      if(p.volume<=0) {reason="risk budget below broker minimum lot or invalid volume";return false;}
      double loss=0;
      if(!OrderCalcProfit(type,s.name,p.volume,p.entry,p.sl,loss) || !MathIsValidNumber(loss) || loss>=0 || -loss>budget+1e-8)
      {reason="rounded lot exceeds risk budget or cannot be priced";return false;}
      p.estimated_loss=-loss;
      double free=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(!MathIsValidNumber(free) || free<=0 || !OrderCalcMargin(type,s.name,p.volume,p.entry,p.margin) ||
         !MathIsValidNumber(p.margin) || p.margin<0 || p.margin>free)
      {reason="insufficient or unavailable margin";return false;}
      reason="OK";return true;
   }
};
#endif
