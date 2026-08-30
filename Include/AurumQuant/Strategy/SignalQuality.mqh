#ifndef AURUM_SIGNAL_QUALITY_MQH
#define AURUM_SIGNAL_QUALITY_MQH
struct AQSignalQuality
{
   double trend; double breakout; double pullback; double confirmation;
   double volatility; double execution_quality; double risk_quality;
   bool complete;
   void Reset() { trend=0;breakout=0;pullback=0;confirmation=0;volatility=0;execution_quality=0;risk_quality=0;complete=false; }
};
#endif

