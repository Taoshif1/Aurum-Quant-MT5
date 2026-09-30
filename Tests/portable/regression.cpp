// Executes unchanged production headers under a small C++ API shim.
// This does not validate MQL syntax, terminal APIs, fills, or MetaEditor compilation.
#include "runtime.hpp"
#include <AurumQuant/Risk/RiskManager.mqh>
#include <AurumQuant/Trading/PositionManager.mqh>
#include <limits>
#include <AurumQuant/Research/StrategyValidation.mqh>
#include <AurumQuant/Trading/OrderPlan.mqh>
#include <AurumQuant/Risk/PortfolioBudget.mqh>
int main(){
 AQSymbolSpec s{};s.valid=true;s.bid=100;s.ask=100.1;s.point=0.1;s.digits=2;
 s.tick_size=0.25;s.tick_value_loss=2.5;s.volume_min=0.25;s.volume_max=2;s.volume_step=0.25;
 s.trade_mode=SYMBOL_TRADE_MODE_FULL;
 auto near=[](double a,double b){return std::abs(a-b)<1e-10;};
 assert(near(AQSymbolProfile::NormalizeVolumeDown(s,0.79),0.75));
 s.volume_max=0.9;assert(near(AQSymbolProfile::NormalizeVolumeDown(s,2),0.75));
 // Sweep budgets: each returned lot stays on-grid and within budget and maximum.
 int samples=0;
 for(double step:{0.01,0.02,0.125,0.25,0.5,1.0}){
  s.volume_step=step;s.volume_min=step;s.volume_max=step*7.7;
  for(int i=1;i<=1000;++i){double raw=i*step/100;double v=AQSymbolProfile::NormalizeVolumeDown(s,raw);
   assert(v>=0 && v<=raw+1e-12 && v<=s.volume_max+1e-12);
   if(v>0){assert(v>=s.volume_min);double n=(v-s.volume_min)/step;assert(near(n,std::round(n)));}
   ++samples;
  }
 }
 s.volume_min=0.03;s.volume_step=0.02;s.volume_max=1.01;
 assert(near(AQSymbolProfile::NormalizeVolumeDown(s,0.129),0.11));
 double nan=std::numeric_limits<double>::quiet_NaN(),inf=std::numeric_limits<double>::infinity();
 assert(AQSymbolProfile::NormalizeVolumeDown(s,nan)==0);
 assert(AQSymbolProfile::NormalizeVolumeDown(s,inf)==0);
 assert(AQSymbolProfile::NormalizePrice(s,nan)==0);
 s.volume_step=0;assert(AQSymbolProfile::NormalizeVolumeDown(s,1)==0);s.volume_step=0.02;
 string reason;double volume=0;
 assert(!AQRiskManager::CalculateVolume(s,10000,1,100,-1,volume,reason));
 assert(!AQRiskManager::CalculateVolume(s,inf,1,100,90,volume,reason));
 assert(!AQRiskManager::ValidateStops(s,(ENUM_AQ_DIRECTION)99,90,110,false,reason));
 assert(!AQRiskManager::ValidateStops(s,AQ_BUY,nan,110,false,reason));
 assert(!AQSymbolProfile::DirectionAllowed(s,(ENUM_AQ_DIRECTION)99,reason));
 assert(AQRiskManager::ValidateStops(s,AQ_BUY,90,110,false,reason));
 s.volume_min=-1;assert(!AQRiskManager::CalculateVolume(s,10000,1,100,90,volume,reason));

 s.volume_min=0.01;s.volume_step=0.01;s.volume_max=100;s.tick_size=0.1;s.digits=2;s.name="SYNTH";
 AQOrderPlan plan;
 assert(AQOrderPlanner::Build(s,AQ_BUY,2,2,2,1,plan,reason));
 assert(plan.sl<plan.entry && plan.tp>plan.entry && plan.estimated_loss<=100+1e-8);
 assert(plan.volume>=0.24 && plan.volume<=0.25); // Outward tick rounding can add one tick of stop distance.
 assert(AQOrderPlanner::Build(s,AQ_SELL,2,2,2,1,plan,reason));
 assert(plan.sl>plan.entry && plan.tp<plan.entry && plan.estimated_loss<=100+1e-8);
 test_free_margin=1;assert(!AQOrderPlanner::Build(s,AQ_BUY,2,2,2,1,plan,reason));test_free_margin=10000;
 test_profit_available=false;assert(!AQOrderPlanner::Build(s,AQ_BUY,2,2,2,1,plan,reason));test_profit_available=true;
 test_margin_available=false;assert(!AQOrderPlanner::Build(s,AQ_BUY,2,2,2,1,plan,reason));test_margin_available=true;
 assert(!AQOrderPlanner::Build(s,AQ_BUY,0,2,2,1,plan,reason));
 test_equity=1;assert(!AQOrderPlanner::Build(s,AQ_BUY,2,2,2,1,plan,reason));test_equity=10000;
 double portfolio_percent=0;
 assert(AQPortfolioBudget::MagicInGroup(26093001,26093000,100));
 assert(!AQPortfolioBudget::MagicInGroup(26093100,26093000,100));
 assert(AQPortfolioBudget::Pass(10000,1.0,40,20,1,3,portfolio_percent,reason) && near(portfolio_percent,0.6));
 assert(AQPortfolioBudget::Pass(10000,1.0,75,25,2,3,portfolio_percent,reason) && near(portfolio_percent,1.0));
 assert(!AQPortfolioBudget::Pass(10000,1.0,90,20,2,3,portfolio_percent,reason));
 assert(!AQPortfolioBudget::Pass(10000,1.0,20,10,3,3,portfolio_percent,reason));
 int policies=0;
 for(int mode:{0,1,2,99})for(bool armed:{false,true})for(long account:{ACCOUNT_TRADE_MODE_DEMO,ACCOUNT_TRADE_MODE_REAL,ACCOUNT_TRADE_MODE_CONTEST}){
  bool expected=armed && ((mode==1 && account==ACCOUNT_TRADE_MODE_DEMO)||(mode==2 && account==ACCOUNT_TRADE_MODE_REAL));
  assert(AQExecutionPolicy::Allows((ENUM_AQ_MODE)mode,armed,account,reason)==expected);
  if(!expected){
   account_mode=account;AQPositionManager manager;manager.Init(123,"SYNTH",(ENUM_AQ_MODE)mode,armed);
   position_reads=0;trade_calls=0;
   assert(!manager.Modify(1,90,110));assert(!manager.SafeClose(1));
   assert(position_reads==0 && trade_calls==0);
  }
  ++policies;
 }
 AQPositionManager defaults;assert(!defaults.ExecutionAllowed(reason));
 int strategy_passed=0,strategy_failed=0;assert(AQStrategyValidation::Run(strategy_passed,strategy_failed));
 std::cout<<"Strategy assertions: "<<strategy_passed<<" passed, "<<strategy_failed<<" failed\n";
 std::cout<<"PASS: "<<samples<<" volume budgets, "<<policies<<" execution policies, portfolio budgets, invalid numeric inputs, locked mutation paths\n";
}
