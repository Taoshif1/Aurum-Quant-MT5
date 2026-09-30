#ifndef AURUM_STOP_MANAGEMENT_POLICY_MQH
#define AURUM_STOP_MANAGEMENT_POLICY_MQH
#include <AurumQuant/Core/Config.mqh>

struct AQStopProposal
{
   bool change;
   double stop;
   string reason;
};

class AQStopManagementPolicy
{
private:
   static bool MoreProtective(ENUM_AQ_DIRECTION direction,double candidate,double current)
   {
      if(direction==AQ_BUY) return candidate>current;
      if(direction==AQ_SELL) return candidate<current;
      return false;
   }
public:
   static bool Build(ENUM_AQ_DIRECTION direction,double entry,double market,double current_sl,double original_risk,
                     double point,double tick_size,
                     bool break_even_enabled,ENUM_BE_METHOD break_even_method,
                     double break_even_trigger_r,double break_even_distance_points,
                     bool trailing_enabled,ENUM_TRAIL_METHOD trailing_method,
                     double trailing_value,double atr,AQStopProposal &out)
   {
      out.change=false;out.stop=current_sl;out.reason="NO_CHANGE";
      if((direction!=AQ_BUY && direction!=AQ_SELL) ||
         !MathIsValidNumber(entry) || !MathIsValidNumber(market) || !MathIsValidNumber(current_sl) ||
         !MathIsValidNumber(original_risk) || !MathIsValidNumber(point) || !MathIsValidNumber(tick_size) ||
         entry<=0 || market<=0 || current_sl<=0 || point<=0 || tick_size<=0)
      {out.reason="invalid stop-management inputs";return false;}

      double favorable=(direction==AQ_BUY ? market-entry : entry-market);
      double proposal=current_sl;

      if(break_even_enabled)
      {
         bool trigger=false;
         if(break_even_method==BE_BY_R)
         {
            if(!MathIsValidNumber(break_even_trigger_r) || break_even_trigger_r<=0)
            {out.reason="invalid break-even R trigger";return false;}
            bool already_protected=(direction==AQ_BUY ? current_sl>=entry : current_sl<=entry);
            if(!already_protected)
            {
               if(original_risk<=0)
               {out.reason="original risk unavailable for R break-even";return false;}
               trigger=favorable>=original_risk*break_even_trigger_r;
            }
         }
         else if(break_even_method==BE_BY_DISTANCE)
         {
            if(!MathIsValidNumber(break_even_distance_points) || break_even_distance_points<=0)
            {out.reason="invalid break-even distance trigger";return false;}
            trigger=favorable>=break_even_distance_points*point;
         }
         else {out.reason="unsupported break-even method";return false;}

         if(trigger && MoreProtective(direction,entry,proposal)) proposal=entry;
      }

      if(trailing_enabled)
      {
         if(!MathIsValidNumber(trailing_value) || trailing_value<=0)
         {out.reason="invalid trailing value";return false;}
         double distance=0;
         if(trailing_method==TRAIL_FIXED) distance=trailing_value*point;
         else if(trailing_method==TRAIL_ATR)
         {
            if(!MathIsValidNumber(atr) || atr<=0)
            {out.reason="ATR unavailable for trailing";return false;}
            distance=trailing_value*atr;
         }
         else {out.reason="trailing method not implemented in v1";return false;}

         if(!MathIsValidNumber(distance) || distance<tick_size)
         {out.reason="trailing distance below broker tick";return false;}
         double candidate=(direction==AQ_BUY ? market-distance : market+distance);
         if(candidate<=0 || !MathIsValidNumber(candidate))
         {out.reason="invalid trailing stop candidate";return false;}
         if(MoreProtective(direction,candidate,proposal)) proposal=candidate;
      }

      double improvement=(direction==AQ_BUY ? proposal-current_sl : current_sl-proposal);
      if(improvement>=tick_size*0.5)
      {
         out.change=true;out.stop=proposal;out.reason="TIGHTEN";
      }
      return true;
   }
};
#endif
