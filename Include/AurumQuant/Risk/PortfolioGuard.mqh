#ifndef AURUM_PORTFOLIO_GUARD_MQH
#define AURUM_PORTFOLIO_GUARD_MQH
#include <AurumQuant/Risk/PortfolioBudget.mqh>
// Cross-symbol guard for Aurum positions whose magic numbers share a reserved range.
class AQPortfolioGuard
{
public:
   static bool Snapshot(ulong magic_base,int magic_span,double &risk,int &positions,string &reason)
   {
      risk=0;positions=0;
      if(magic_base==0 || magic_span<1) {reason="invalid portfolio magic group";return false;}
      for(int i=PositionsTotal()-1;i>=0;i--)
      {
         ulong ticket=PositionGetTicket(i);
         if(ticket==0) {reason="portfolio position data unavailable";return false;}
         ulong magic=(ulong)PositionGetInteger(POSITION_MAGIC);
         if(!AQPortfolioBudget::MagicInGroup(magic,magic_base,magic_span)) continue;
         positions++;
         string symbol=PositionGetString(POSITION_SYMBOL);
         long kind=PositionGetInteger(POSITION_TYPE);
         double volume=PositionGetDouble(POSITION_VOLUME);
         double entry=PositionGetDouble(POSITION_PRICE_OPEN);
         double stop=PositionGetDouble(POSITION_SL);
         if(symbol=="" || !MathIsValidNumber(volume) || !MathIsValidNumber(entry) ||
            !MathIsValidNumber(stop) || volume<=0 || entry<=0)
         {reason="invalid Aurum portfolio position";return false;}
         if(stop<=0) {reason="Aurum portfolio position has no stop loss";return false;}
         ENUM_ORDER_TYPE type;
         if(kind==POSITION_TYPE_BUY) type=ORDER_TYPE_BUY;
         else if(kind==POSITION_TYPE_SELL) type=ORDER_TYPE_SELL;
         else {reason="unknown Aurum portfolio position type";return false;}
         double pnl_to_stop=0;
         if(!OrderCalcProfit(type,symbol,volume,entry,stop,pnl_to_stop) || !MathIsValidNumber(pnl_to_stop))
         {reason="portfolio stop risk cannot be priced";return false;}
         if(pnl_to_stop<0) risk+=-pnl_to_stop;
         if(!MathIsValidNumber(risk)) {reason="invalid portfolio risk total";return false;}
      }
      reason="OK";return true;
   }
   static bool CurrentWithinLimits(ulong magic_base,int magic_span,int max_positions,double max_risk_percent,
                                   double &risk,int &positions,double &used_percent,string &reason)
   {
      if(!Snapshot(magic_base,magic_span,risk,positions,reason)) return false;
      return AQPortfolioBudget::Pass(AccountInfoDouble(ACCOUNT_EQUITY),max_risk_percent,risk,0,
                                     positions,max_positions,used_percent,reason);
   }
   static bool CanAdd(ulong magic_base,int magic_span,int max_positions,double max_risk_percent,double candidate_risk,
                      double &risk,int &positions,double &used_percent,string &reason)
   {
      if(!Snapshot(magic_base,magic_span,risk,positions,reason)) return false;
      return AQPortfolioBudget::Pass(AccountInfoDouble(ACCOUNT_EQUITY),max_risk_percent,risk,candidate_risk,
                                     positions,max_positions,used_percent,reason);
   }
};
#endif
