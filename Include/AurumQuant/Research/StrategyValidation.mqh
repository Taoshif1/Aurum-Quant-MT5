#ifndef AURUM_STRATEGY_VALIDATION_MQH
#define AURUM_STRATEGY_VALIDATION_MQH
#include <AurumQuant/Strategy/BreakoutPullback.mqh>
// Shared pure logic tests run in MT5 and in the portable regression harness.
class AQStrategyValidation
{
private:
   static void Check(bool ok,int &passed,int &failed) {if(ok)passed++;else failed++;}
   static AQSetupBar Bar(datetime t,double open,double high,double low,double close)
   {AQSetupBar b;b.time=t;b.open=open;b.high=high;b.low=low;b.close=close;b.previous_close=99;b.channel_high=100;b.channel_low=90;b.atr=2;return b;}
public:
   static bool Run(int &passed,int &failed)
   {
      passed=0;failed=0;AQBreakoutPullback setup;
      AQSetupBar b=Bar(100,99,102,98,101);
      Check(setup.Step(TREND_BULLISH,b,0.1,0.25,6)==BREAKOUT_DETECTED,passed,failed);
      Check(setup.Step(TREND_BULLISH,b,0.1,0.25,6)==NO_SETUP,passed,failed);
      b=Bar(200,100,102,99.8,101);
      Check(setup.Step(TREND_BULLISH,b,0.1,0.25,6)==BUY_CANDIDATE,passed,failed);
      Check(setup.Step(TREND_BULLISH,b,0.1,0.25,6)==NO_SETUP,passed,failed);
      b=Bar(300,91,92,88,89);b.previous_close=91;
      Check(setup.Step(TREND_BEARISH,b,0.1,0.25,6)==BREAKOUT_DETECTED,passed,failed);
      b=Bar(400,90,90.2,88,89);
      Check(setup.Step(TREND_BEARISH,b,0.1,0.25,6)==SELL_CANDIDATE,passed,failed);
      b=Bar(500,99,102,98,101);setup.Step(TREND_BULLISH,b,0.1,0.25,6);
      b=Bar(600,100,102,99.8,101);
      Check(setup.Step(TREND_BEARISH,b,0.1,0.25,6)==NO_SETUP,passed,failed);
      b=Bar(700,99,102,98,101);setup.Step(TREND_BULLISH,b,0.1,0.25,1);
      b=Bar(800,101,103,101,102);
      Check(setup.Step(TREND_BULLISH,b,0.1,0.25,1)==WAITING_PULLBACK,passed,failed);
      b=Bar(900,100,102,99.8,101);
      Check(setup.Step(TREND_BULLISH,b,0.1,0.25,1)==NO_SETUP,passed,failed);
      b=Bar(1000,99,102,98,101);setup.Step(TREND_BULLISH,b,0.1,0.25,6);
      b=Bar(1100,100,101,98,99);
      Check(setup.Step(TREND_BULLISH,b,0.1,0.25,6)==NO_SETUP,passed,failed);
      b=Bar(1200,99,102,98,101);b.atr=0;
      Check(setup.Step(TREND_BULLISH,b,0.1,0.25,6)==SIGNAL_BLOCKED,passed,failed);
      b.atr=2;
      Check(setup.Step(TREND_NEUTRAL,b,0.1,0.25,6)==NO_SETUP,passed,failed);
      b=Bar(1300,99,101,98,100.1);
      Check(setup.Step(TREND_BULLISH,b,0.1,0.25,6)==TREND_READY,passed,failed);
      b=Bar(1400,99,102,98,101);b.previous_close=101;
      Check(setup.Step(TREND_BULLISH,b,0.1,0.25,6)==TREND_READY,passed,failed);
      b=Bar(1500,99,102,98,101);b.low=103;
      Check(setup.Step(TREND_BULLISH,b,0.1,0.25,6)==SIGNAL_BLOCKED,passed,failed);
      return failed==0;
   }
};
#endif
