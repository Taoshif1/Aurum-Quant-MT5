#ifndef AURUM_VALIDATION_SUITE_MQH
#define AURUM_VALIDATION_SUITE_MQH
#include <AurumQuant/Risk/RiskManager.mqh>
#include <AurumQuant/Risk/DailyGuard.mqh>
#include <AurumQuant/Risk/PortfolioBudget.mqh>
#include <AurumQuant/Risk/PortfolioLockPolicy.mqh>
#include <AurumQuant/Trading/TradeManager.mqh>
#include <AurumQuant/Trading/PositionManager.mqh>
#include <AurumQuant/Research/StrategyValidation.mqh>
class AQValidationSuite
{
private:
   static void Check(bool condition,string name,int &passed,int &failed){if(condition){passed++;Print("AURUM|SELF_TEST|PASS|",name);}else{failed++;Print("AURUM|SELF_TEST|FAIL|",name);}}
   static bool Near(double a,double b,double tolerance=1e-8){return MathAbs(a-b)<=tolerance;}
   static AQSymbolSpec Synthetic(double tick_size,double tick_value_loss,double minimum,double maximum,double step)
   { AQSymbolSpec s;ZeroMemory(s);s.name="SYNTH";s.bid=100.0;s.ask=100.1;s.point=0.1;s.digits=2;s.tick_size=tick_size;s.tick_value=tick_value_loss;s.tick_value_loss=tick_value_loss;s.tick_value_profit=tick_value_loss;s.contract_size=1;s.volume_min=minimum;s.volume_max=maximum;s.volume_step=step;s.stops_level=5;s.freeze_level=3;s.trade_mode=SYMBOL_TRADE_MODE_FULL;s.valid=true;return s; }
public:
   static bool Run(int &passed,int &failed)
   {
      passed=0;failed=0;string reason;double volume=0;AQSymbolSpec s=Synthetic(1.0,10.0,0.1,10.0,0.1);
      Check(AQRiskManager::CalculateVolume(s,10000,1,100,90,volume,reason)&&Near(volume,1.0),"risk baseline",passed,failed);
      Check(AQRiskManager::CalculateVolume(s,20000,0.5,100,95,volume,reason)&&Near(volume,2.0),"equity risk and shorter stop",passed,failed);
      Check(!AQRiskManager::CalculateVolume(s,10000,1,100,100,volume,reason),"zero stop distance fails closed",passed,failed);
      Check(!AQRiskManager::CalculateVolume(s,-1,1,100,90,volume,reason),"negative equity fails closed",passed,failed);
      AQSymbolSpec no_tick=Synthetic(0,10,0.1,10,0.1);Check(!AQRiskManager::CalculateVolume(no_tick,10000,1,100,90,volume,reason),"zero tick size fails closed",passed,failed);
      AQSymbolSpec no_value=Synthetic(1,0,0.1,10,0.1);Check(!AQRiskManager::CalculateVolume(no_value,10000,1,100,90,volume,reason),"zero tick value fails closed",passed,failed);
      Check(!AQRiskManager::CalculateVolume(s,100,1,100,0,volume,reason),"below minimum volume fails closed",passed,failed);
      Check(AQRiskManager::CalculateVolume(s,100000,10,100,99,volume,reason)&&Near(volume,10.0),"volume capped at maximum",passed,failed);
      AQSymbolSpec unusual=Synthetic(0.25,2.5,0.03,1.01,0.02);Check(AQRiskManager::CalculateVolume(unusual,1000,0.11,100,99,volume,reason)&&Near(volume,0.11),"unusual volume step rounds down",passed,failed);
      Check(Near(AQSymbolProfile::NormalizePrice(unusual,100.13),100.25),"price aligns to tick size",passed,failed);Check(Near(AQSymbolProfile::NormalizeVolumeDown(unusual,0.129),0.11),"volume never rounds upward",passed,failed);Check(Near(AQSymbolProfile::NormalizeVolumeDown(unusual,0.02),0),"volume below minimum returns zero",passed,failed);
      unusual.tick_size=0.1;Check(AQRiskManager::ValidateStops(unusual,AQ_BUY,99.0,102.0,false,reason),"valid BUY stops",passed,failed);Check(!AQRiskManager::ValidateStops(unusual,AQ_BUY,100.1,102.0,false,reason),"BUY stop wrong side blocked",passed,failed);Check(!AQRiskManager::ValidateStops(unusual,AQ_SELL,100.2,99.0,true,reason),"freeze distance modification blocked",passed,failed);
      double loss=0;Check(!AQDailyGuard::Evaluate(10000,500,3,loss)&&Near(loss,0),"daily profit",passed,failed);Check(!AQDailyGuard::Evaluate(10000,-100,3,loss)&&Near(loss,1),"daily small loss",passed,failed);Check(AQDailyGuard::Evaluate(10000,-300,3,loss)&&Near(loss,3),"daily exact limit",passed,failed);Check(AQDailyGuard::Evaluate(10000,-301,3,loss),"daily exceeded limit",passed,failed);
      Check(AQDailyGuard::IsNewBrokerDay(D'2026.08.29 00:00',D'2026.08.30 00:00'),"new broker day detected",passed,failed);Check(!AQDailyGuard::IsNewBrokerDay(D'2026.08.30 00:00',D'2026.08.30 00:00'),"same-day restart preserves baseline key",passed,failed);
      double portfolio_percent=0;
      Check(AQPortfolioBudget::MagicInGroup(26093001,26093000,100),"portfolio magic inside group",passed,failed);
      Check(!AQPortfolioBudget::MagicInGroup(26093100,26093000,100),"portfolio magic outside group",passed,failed);
      Check(AQPortfolioBudget::Pass(10000,1.0,40,20,1,3,portfolio_percent,reason)&&Near(portfolio_percent,0.6),"portfolio candidate within risk budget",passed,failed);
      Check(AQPortfolioBudget::Pass(10000,1.0,75,25,2,3,portfolio_percent,reason)&&Near(portfolio_percent,1.0),"portfolio exact risk cap allowed",passed,failed);
      Check(!AQPortfolioBudget::Pass(10000,1.0,90,20,2,3,portfolio_percent,reason),"portfolio risk excess blocked",passed,failed);
      Check(!AQPortfolioBudget::Pass(10000,1.0,20,10,3,3,portfolio_percent,reason),"portfolio position cap blocked",passed,failed);
      Check(AQPortfolioLockPolicy::CanAcquire(1000,0),"portfolio lock free",passed,failed);
      Check(AQPortfolioLockPolicy::CanAcquire(1000,1000),"portfolio lock exact expiry reclaimable",passed,failed);
      Check(!AQPortfolioLockPolicy::CanAcquire(1000,1001),"portfolio lock future expiry blocks",passed,failed);
      Check(!AQPortfolioLockPolicy::CanAcquire(1000,-1),"portfolio lock invalid state blocked",passed,failed);
      AQTradeManager manager;manager.Init(MODE_OBSERVE,true,123,"SYNTH");Check(!manager.ExecutionAllowed(reason),"OBSERVE blocks even if master switch requested",passed,failed);manager.Init(MODE_LIVE,false,123,"SYNTH");Check(!manager.ExecutionAllowed(reason),"LIVE requires master lock",passed,failed);
      AQSymbolSpec quarter=Synthetic(0.25,2.5,0.25,2.0,0.25);
      Check(Near(AQSymbolProfile::NormalizeVolumeDown(quarter,0.79),0.75),"quarter lots retain decimal precision",passed,failed);
      quarter.volume_max=0.9;Check(Near(AQSymbolProfile::NormalizeVolumeDown(quarter,2.0),0.75),"off-grid maximum floors to grid",passed,failed);
      quarter.volume_step=0;Check(Near(AQSymbolProfile::NormalizeVolumeDown(quarter,0.8),0),"zero volume step blocked",passed,failed);
      Check(!AQRiskManager::ValidateStops(s,(ENUM_AQ_DIRECTION)99,90,110,false,reason),"unknown stop direction blocked",passed,failed);
      Check(!AQSymbolProfile::DirectionAllowed(s,(ENUM_AQ_DIRECTION)99,reason),"unknown execution direction blocked",passed,failed);
      Check(!AQRiskManager::CalculateVolume(s,10000,1,100,-1,volume,reason),"negative stop price blocked",passed,failed);
      Check(!AQExecutionPolicy::Allows(MODE_DEMO,true,ACCOUNT_TRADE_MODE_REAL,reason),"DEMO rejects real account",passed,failed);
      Check(!AQExecutionPolicy::Allows(MODE_LIVE,true,ACCOUNT_TRADE_MODE_DEMO,reason),"LIVE rejects demo account",passed,failed);
      Check(AQExecutionPolicy::Allows(MODE_DEMO,true,ACCOUNT_TRADE_MODE_DEMO,reason),"armed DEMO policy",passed,failed);
      Check(AQExecutionPolicy::Allows(MODE_LIVE,true,ACCOUNT_TRADE_MODE_REAL,reason),"armed LIVE policy",passed,failed);
      Check(!AQExecutionPolicy::Allows((ENUM_AQ_MODE)99,true,ACCOUNT_TRADE_MODE_DEMO,reason),"unknown execution mode blocked",passed,failed);
      AQPositionManager positions;Check(!positions.ExecutionAllowed(reason),"position manager starts locked",passed,failed);
      positions.Init(123,"SYNTH",MODE_OBSERVE,true);Check(!positions.ExecutionAllowed(reason),"OBSERVE position mutations blocked",passed,failed);
      positions.Init(123,"SYNTH",MODE_LIVE,false);Check(!positions.ExecutionAllowed(reason),"position mutations require master lock",passed,failed);
      int strategy_passed=0,strategy_failed=0;AQStrategyValidation::Run(strategy_passed,strategy_failed);passed+=strategy_passed;failed+=strategy_failed;
      PrintFormat("AURUM|SELF_TEST|RESULT|passed=%d|failed=%d",passed,failed);return failed==0;
   }
};
#endif
