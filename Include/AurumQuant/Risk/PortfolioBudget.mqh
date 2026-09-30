#ifndef AURUM_PORTFOLIO_BUDGET_MQH
#define AURUM_PORTFOLIO_BUDGET_MQH
// Pure portfolio budget logic. No terminal access; shared by native and portable tests.
class AQPortfolioBudget
{
public:
   static bool MagicInGroup(ulong magic,ulong base,int span)
   {
      return base>0 && span>0 && magic>=base && (magic-base)<(ulong)span;
   }
   static bool Pass(double equity,double limit_percent,double existing_risk,double candidate_risk,
                    int positions,int max_positions,double &used_percent,string &reason)
   {
      used_percent=0;
      if(!MathIsValidNumber(equity) || !MathIsValidNumber(limit_percent) ||
         !MathIsValidNumber(existing_risk) || !MathIsValidNumber(candidate_risk) ||
         equity<=0 || limit_percent<=0 || limit_percent>100 ||
         existing_risk<0 || candidate_risk<0 || positions<0 || max_positions<1)
      { reason="invalid portfolio risk inputs"; return false; }
      double total=existing_risk+candidate_risk;
      if(!MathIsValidNumber(total)) { reason="invalid portfolio risk total"; return false; }
      used_percent=total/equity*100.0;
      if(positions>=max_positions) { reason="portfolio exposure-count limit reached"; return false; }
      double budget=equity*limit_percent/100.0;
      if(total>budget+1e-8) { reason="portfolio risk budget exceeded"; return false; }
      reason="OK"; return true;
   }
};
#endif
