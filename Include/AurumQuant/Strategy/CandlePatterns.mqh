#ifndef AURUM_CANDLE_PATTERNS_MQH
#define AURUM_CANDLE_PATTERNS_MQH
class AQCandlePatterns
{
private:
   static double Body(const MqlRates &c) { return MathAbs(c.close-c.open); }
   static double Range(const MqlRates &c) { return c.high-c.low; }
public:
   static bool BullishEngulfing(const MqlRates &current,const MqlRates &previous,double min_body_ratio)
   { return previous.close<previous.open && current.close>current.open && current.open<=previous.close && current.close>=previous.open && Body(current)>=Body(previous)*min_body_ratio; }
   static bool BearishEngulfing(const MqlRates &current,const MqlRates &previous,double min_body_ratio)
   { return previous.close>previous.open && current.close<current.open && current.open>=previous.close && current.close<=previous.open && Body(current)>=Body(previous)*min_body_ratio; }
   static bool BullishPinBar(const MqlRates &c,double wick_body_ratio,double max_opposite_fraction)
   { double b=Body(c),r=Range(c); if(b<=0||r<=0) return false; double lower=MathMin(c.open,c.close)-c.low,upper=c.high-MathMax(c.open,c.close); return lower>=b*wick_body_ratio && upper<=r*max_opposite_fraction && c.close>c.open; }
   static bool BearishPinBar(const MqlRates &c,double wick_body_ratio,double max_opposite_fraction)
   { double b=Body(c),r=Range(c); if(b<=0||r<=0) return false; double upper=c.high-MathMax(c.open,c.close),lower=MathMin(c.open,c.close)-c.low; return upper>=b*wick_body_ratio && lower<=r*max_opposite_fraction && c.close<c.open; }
};
#endif

