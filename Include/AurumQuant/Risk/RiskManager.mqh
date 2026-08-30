#ifndef AURUM_RISK_MANAGER_MQH
#define AURUM_RISK_MANAGER_MQH
#include <AurumQuant/Core/SymbolProfile.mqh>
class AQRiskManager
{
public:
   static bool CalculateVolume(const AQSymbolSpec &s,double equity,double risk_percent,double entry,double stop,double &volume,string &reason)
   {
      volume=0; double distance=MathAbs(entry-stop);
      if(!s.valid || equity<=0 || risk_percent<=0 || distance<s.tick_size || s.tick_size<=0 || s.tick_value<=0) { reason="invalid risk inputs"; return false; }
      double ticks=distance/s.tick_size, loss_per_lot=ticks*s.tick_value, risk_cash=equity*risk_percent/100.0;
      if(loss_per_lot<=0 || risk_cash<=0) { reason="non-positive monetary risk model"; return false; }
      double raw=risk_cash/loss_per_lot;
      if(raw<s.volume_min) { reason="calculated volume below broker minimum"; return false; }
      volume=MathFloor(raw/s.volume_step+1e-9)*s.volume_step; volume=MathMin(volume,s.volume_max);
      int vd=0; double step=s.volume_step; while(step<1.0 && vd<8) { step*=10.0; vd++; } volume=NormalizeDouble(volume,vd);
      if(volume<s.volume_min || volume>s.volume_max) { reason="normalized volume outside broker limits"; volume=0; return false; }
      reason="OK"; return true;
   }
   static bool ValidateStops(const AQSymbolSpec &s,double entry,double stop,double target,string &reason)
   {
      double minimum=s.stops_level*s.point;
      if(stop<=0 || target<=0 || MathAbs(entry-stop)<minimum || MathAbs(target-entry)<minimum) { reason="SL/TP violates broker stop distance"; return false; }
      reason="OK"; return true;
   }
};
#endif

