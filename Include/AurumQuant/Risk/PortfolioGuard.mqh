#ifndef AURUM_PORTFOLIO_GUARD_MQH
#define AURUM_PORTFOLIO_GUARD_MQH
#include <AurumQuant/Risk/PortfolioBudget.mqh>
class AQPortfolioGuard
{
private:
   static bool AddRisk(ENUM_ORDER_TYPE type,string symbol,double volume,double entry,double stop,double &risk,string &reason)
   {
      if(symbol=="" || !MathIsValidNumber(volume) || !MathIsValidNumber(entry) || !MathIsValidNumber(stop) || volume<=0 || entry<=0)
      {reason="invalid Aurum portfolio exposure";return false;}
      if(stop<=0) {reason="Aurum portfolio exposure has no stop loss";return false;}
      double pnl_to_stop=0;
      if(!OrderCalcProfit(type,symbol,volume,entry,stop,pnl_to_stop) || !MathIsValidNumber(pnl_to_stop))
      {reason="portfolio stop risk cannot be priced";return false;}
      if(pnl_to_stop<0) risk+=-pnl_to_stop;
      if(!MathIsValidNumber(risk)) {reason="invalid portfolio risk total";return false;}
      return true;
   }
   static bool PendingDirection(long kind,ENUM_ORDER_TYPE &type)
   {
      if(kind==ORDER_TYPE_BUY || kind==ORDER_TYPE_BUY_LIMIT || kind==ORDER_TYPE_BUY_STOP || kind==ORDER_TYPE_BUY_STOP_LIMIT)
      {type=ORDER_TYPE_BUY;return true;}
      if(kind==ORDER_TYPE_SELL || kind==ORDER_TYPE_SELL_LIMIT || kind==ORDER_TYPE_SELL_STOP || kind==ORDER_TYPE_SELL_STOP_LIMIT)
      {type=ORDER_TYPE_SELL;return true;}
      return false;
   }
public:
   static bool Snapshot(ulong magic_base,int magic_span,double &risk,int &exposures,string &reason)
   {
      risk=0;exposures=0;
      if(magic_base==0 || magic_span<1) {reason="invalid portfolio magic group";return false;}
      for(int i=PositionsTotal()-1;i>=0;i--)
      {
         ulong ticket=PositionGetTicket(i); if(ticket==0) {reason="portfolio position data unavailable";return false;}
         ulong magic=(ulong)PositionGetInteger(POSITION_MAGIC); if(!AQPortfolioBudget::MagicInGroup(magic,magic_base,magic_span)) continue;
         exposures++; long kind=PositionGetInteger(POSITION_TYPE); ENUM_ORDER_TYPE type;
         if(kind==POSITION_TYPE_BUY) type=ORDER_TYPE_BUY; else if(kind==POSITION_TYPE_SELL) type=ORDER_TYPE_SELL; else {reason="unknown Aurum portfolio position type";return false;}
         if(!AddRisk(type,PositionGetString(POSITION_SYMBOL),PositionGetDouble(POSITION_VOLUME),PositionGetDouble(POSITION_PRICE_OPEN),PositionGetDouble(POSITION_SL),risk,reason)) return false;
      }
      for(int i=OrdersTotal()-1;i>=0;i--)
      {
         ulong ticket=OrderGetTicket(i); if(ticket==0) {reason="portfolio order data unavailable";return false;}
         ulong magic=(ulong)OrderGetInteger(ORDER_MAGIC); if(!AQPortfolioBudget::MagicInGroup(magic,magic_base,magic_span)) continue;
         exposures++; ENUM_ORDER_TYPE type; long kind=OrderGetInteger(ORDER_TYPE);
         if(!PendingDirection(kind,type)) {reason="unknown Aurum portfolio order type";return false;}
         if(!AddRisk(type,OrderGetString(ORDER_SYMBOL),OrderGetDouble(ORDER_VOLUME_CURRENT),OrderGetDouble(ORDER_PRICE_OPEN),OrderGetDouble(ORDER_SL),risk,reason)) return false;
      }
      reason="OK";return true;
   }
   static bool CurrentWithinLimits(ulong magic_base,int magic_span,int max_positions,double max_risk_percent,double &risk,int &exposures,double &used_percent,string &reason)
   {
      if(!Snapshot(magic_base,magic_span,risk,exposures,reason)) return false;
      return AQPortfolioBudget::Pass(AccountInfoDouble(ACCOUNT_EQUITY),max_risk_percent,risk,0,exposures,max_positions,used_percent,reason);
   }
   static bool CanAdd(ulong magic_base,int magic_span,int max_positions,double max_risk_percent,double candidate_risk,double &risk,int &exposures,double &used_percent,string &reason)
   {
      if(!Snapshot(magic_base,magic_span,risk,exposures,reason)) return false;
      return AQPortfolioBudget::Pass(AccountInfoDouble(ACCOUNT_EQUITY),max_risk_percent,risk,candidate_risk,exposures,max_positions,used_percent,reason);
   }
};
#endif
