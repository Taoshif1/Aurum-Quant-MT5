#ifndef AURUM_RISK_MANAGER_MQH
#define AURUM_RISK_MANAGER_MQH
#include <AurumQuant/Core/SymbolProfile.mqh>
class AQRiskManager
{
public:
   static bool CalculateVolume(const AQSymbolSpec &s,double equity,double risk_percent,double entry,double stop,double &volume,string &reason)
   {
      volume=0; double distance=MathAbs(entry-stop);
      if(!s.valid || !AQSymbolProfile::VolumeGridValid(s) || !MathIsValidNumber(equity) || !MathIsValidNumber(risk_percent) || !MathIsValidNumber(entry) || !MathIsValidNumber(stop) || entry<=0 || stop<=0 || equity<=0 || risk_percent<=0 || risk_percent>100 || distance<s.tick_size || !MathIsValidNumber(s.tick_size) || !MathIsValidNumber(s.tick_value_loss) || s.tick_size<=0 || s.tick_value_loss<=0) { reason="invalid risk inputs"; return false; }
      double ticks=distance/s.tick_size, loss_per_lot=ticks*s.tick_value_loss, risk_cash=equity*risk_percent/100.0;
      if(!MathIsValidNumber(loss_per_lot) || !MathIsValidNumber(risk_cash) || loss_per_lot<=0 || risk_cash<=0) { reason="non-positive monetary risk model"; return false; }
      double raw=risk_cash/loss_per_lot;
      if(!MathIsValidNumber(raw) || raw<s.volume_min) { reason="calculated volume below broker minimum"; return false; }
      volume=AQSymbolProfile::NormalizeVolumeDown(s,raw);
      if(volume<s.volume_min || volume>s.volume_max) { reason="normalized volume outside broker limits"; volume=0; return false; }
      reason="OK"; return true;
   }
   static bool ValidateStops(const AQSymbolSpec &s,ENUM_AQ_DIRECTION direction,double stop,double target,bool modification,string &reason)
   {
      if(!s.valid || (direction!=AQ_BUY && direction!=AQ_SELL) ||
         !MathIsValidNumber(stop) || !MathIsValidNumber(target) ||
         !MathIsValidNumber(s.bid) || !MathIsValidNumber(s.ask) || s.bid<=0 || s.ask<=s.bid ||
         !MathIsValidNumber(s.point) || s.point<=0 || !MathIsValidNumber(s.tick_size) || s.tick_size<=0 ||
         s.stops_level<0 || s.freeze_level<0 || stop<=0 || target<=0) { reason="SYMBOL DATA INVALID or non-positive stops"; return false; }
      double reference=(direction==AQ_BUY ? s.bid : s.ask);
      double minimum=(modification ? MathMax(s.stops_level,s.freeze_level) : s.stops_level)*s.point;
      double epsilon=s.tick_size*0.1;
      if(direction==AQ_BUY && (!(stop<reference) || !(target>reference))) { reason="BUY requires SL below Bid and TP above Bid"; return false; }
      if(direction==AQ_SELL && (!(stop>reference) || !(target<reference))) { reason="SELL requires SL above Ask and TP below Ask"; return false; }
      if(MathAbs(reference-stop)+epsilon<minimum || MathAbs(target-reference)+epsilon<minimum) { reason=modification?"SL/TP violates stop/freeze distance":"SL/TP violates stop distance"; return false; }
      double ns=AQSymbolProfile::NormalizePrice(s,stop),nt=AQSymbolProfile::NormalizePrice(s,target);
      if(ns<=0 || nt<=0 || MathAbs(ns-stop)>epsilon || MathAbs(nt-target)>epsilon) { reason="SL/TP not aligned to broker tick size"; return false; }
      reason="OK"; return true;
   }
};
#endif
