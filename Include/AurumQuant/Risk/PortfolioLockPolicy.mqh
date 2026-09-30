#ifndef AURUM_PORTFOLIO_LOCK_POLICY_MQH
#define AURUM_PORTFOLIO_LOCK_POLICY_MQH
class AQPortfolioLockPolicy
{
public:
   static bool CanAcquire(datetime now,double current)
   { return now>0 && MathIsValidNumber(current) && current>=0 && current<=(double)now; }
};
#endif
