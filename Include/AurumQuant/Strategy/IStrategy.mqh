#ifndef AURUM_ISTRATEGY_MQH
#define AURUM_ISTRATEGY_MQH
#include <AurumQuant/Core/Config.mqh>
class IAQStrategy
{
public:
   virtual string Name() const=0;
   virtual ENUM_SIGNAL_STATE Evaluate(ENUM_TREND_STATE trend,datetime closed_bar)=0;
};
#endif
