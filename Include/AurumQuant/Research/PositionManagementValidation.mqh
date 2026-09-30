#ifndef AURUM_POSITION_MANAGEMENT_VALIDATION_MQH
#define AURUM_POSITION_MANAGEMENT_VALIDATION_MQH
#include <AurumQuant/Trading/StopManagementPolicy.mqh>

class AQPositionManagementValidation
{
private:
   static void Check(bool ok,int &passed,int &failed){if(ok)passed++;else failed++;}
   static bool Near(double a,double b){return MathAbs(a-b)<=1e-8;}
public:
   static bool Run(int &passed,int &failed)
   {
      passed=0;failed=0;AQStopProposal p;
      Check(AQStopManagementPolicy::Build(AQ_BUY,100,110,90,10,0.1,0.1,true,BE_BY_R,1,0,false,TRAIL_FIXED,0,0,p)&&p.change&&Near(p.stop,100),passed,failed);
      Check(AQStopManagementPolicy::Build(AQ_BUY,100,109,90,10,0.1,0.1,true,BE_BY_R,1,0,false,TRAIL_FIXED,0,0,p)&&!p.change,passed,failed);
      Check(AQStopManagementPolicy::Build(AQ_SELL,100,90,110,10,0.1,0.1,true,BE_BY_R,1,0,false,TRAIL_FIXED,0,0,p)&&p.change&&Near(p.stop,100),passed,failed);
      Check(AQStopManagementPolicy::Build(AQ_BUY,100,105,90,10,0.1,0.1,true,BE_BY_DISTANCE,1,50,false,TRAIL_FIXED,0,0,p)&&p.change&&Near(p.stop,100),passed,failed);
      Check(AQStopManagementPolicy::Build(AQ_BUY,100,110,90,10,0.1,0.1,false,BE_BY_R,1,0,true,TRAIL_FIXED,20,0,p)&&p.change&&Near(p.stop,108),passed,failed);
      Check(AQStopManagementPolicy::Build(AQ_SELL,100,90,110,10,0.1,0.1,false,BE_BY_R,1,0,true,TRAIL_FIXED,20,0,p)&&p.change&&Near(p.stop,92),passed,failed);
      Check(AQStopManagementPolicy::Build(AQ_BUY,100,110,90,10,0.1,0.1,false,BE_BY_R,1,0,true,TRAIL_ATR,1.5,2,p)&&p.change&&Near(p.stop,107),passed,failed);
      Check(AQStopManagementPolicy::Build(AQ_BUY,100,110,90,10,0.1,0.1,true,BE_BY_R,1,0,true,TRAIL_FIXED,20,0,p)&&p.change&&Near(p.stop,108),passed,failed);
      Check(AQStopManagementPolicy::Build(AQ_BUY,100,110,109,10,0.1,0.1,false,BE_BY_R,1,0,true,TRAIL_FIXED,20,0,p)&&!p.change&&Near(p.stop,109),passed,failed);
      Check(!AQStopManagementPolicy::Build(AQ_BUY,100,110,90,10,0.1,0.1,false,BE_BY_R,1,0,true,TRAIL_SWING,2,0,p),passed,failed);
      Check(!AQStopManagementPolicy::Build(AQ_BUY,100,110,90,10,0.1,0.1,false,BE_BY_R,1,0,true,TRAIL_R,2,0,p),passed,failed);
      Check(!AQStopManagementPolicy::Build(AQ_BUY,100,110,90,10,0.1,0.1,false,BE_BY_R,1,0,true,TRAIL_FIXED,0,0,p),passed,failed);
      Check(!AQStopManagementPolicy::Build(AQ_BUY,100,110,0,10,0.1,0.1,true,BE_BY_R,1,0,false,TRAIL_FIXED,0,0,p),passed,failed);
      return failed==0;
   }
};
#endif
