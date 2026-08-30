#ifndef AURUM_MARKET_REGIME_MQH
#define AURUM_MARKET_REGIME_MQH
enum ENUM_MARKET_REGIME { REGIME_TREND_UP=0,REGIME_TREND_DOWN=1,REGIME_RANGE=2,REGIME_HIGH_VOLATILITY=3,REGIME_LOW_VOLATILITY=4,REGIME_TRANSITION=5,REGIME_UNSAFE=6,REGIME_DATA_NOT_READY=7 };
struct AQRegimeEvidence { double normalized_atr; double trend_slope; double trend_strength; double compression; bool valid; };
class AQMarketRegime
{
public:
   ENUM_MARKET_REGIME Evaluate(const AQRegimeEvidence &evidence)
   { if(!evidence.valid) return REGIME_DATA_NOT_READY; return REGIME_TRANSITION; } // Classification thresholds require research approval.
};
#endif

