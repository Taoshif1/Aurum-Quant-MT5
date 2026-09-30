#property copyright "Aurum Quant MT5 research project"
#property version   "1.230"
#property strict
#property description "Multi-asset breakout/retest research EA. Unvalidated strategy."

#include <AurumQuant/Core/Config.mqh>
#include <AurumQuant/Core/Logger.mqh>
#include <AurumQuant/Core/SymbolProfile.mqh>
#include <AurumQuant/Core/MarketData.mqh>
#include <AurumQuant/Core/SelfDiagnostic.mqh>
#include <AurumQuant/Strategy/TrendEngine.mqh>
#include <AurumQuant/Strategy/StrategyEngine.mqh>
#include <AurumQuant/Strategy/CandlePatterns.mqh>
#include <AurumQuant/Strategy/MarketRegime.mqh>
#include <AurumQuant/Strategy/SignalQuality.mqh>
#include <AurumQuant/Risk/RiskManager.mqh>
#include <AurumQuant/Risk/DailyGuard.mqh>
#include <AurumQuant/Risk/PositionGuard.mqh>
#include <AurumQuant/Risk/PortfolioBudget.mqh>
#include <AurumQuant/Risk/PortfolioGuard.mqh>
#include <AurumQuant/Risk/PortfolioLockPolicy.mqh>
#include <AurumQuant/Risk/PortfolioExecutionLock.mqh>
#include <AurumQuant/Risk/EntryLimits.mqh>
#include <AurumQuant/Trading/OrderPlan.mqh>
#include <AurumQuant/Filters/SpreadFilter.mqh>
#include <AurumQuant/Filters/SessionFilter.mqh>
#include <AurumQuant/Filters/NewsFilter.mqh>
#include <AurumQuant/Trading/TradeManager.mqh>
#include <AurumQuant/Trading/PositionManager.mqh>
#include <AurumQuant/UI/Dashboard.mqh>
#include <AurumQuant/Research/TesterStatistics.mqh>
#include <AurumQuant/Research/ValidationSuite.mqh>

input group "Safety and identity"
input ENUM_AQ_MODE OperatingMode=MODE_OBSERVE;
input bool EnableOrderSubmission=false;
input string TradeSymbol="";
input ENUM_ASSET_PROFILE AssetProfile=PROFILE_GENERIC;
input ulong MagicNumber=26093099;
input bool RunDeterministicSelfTests=true;

input group "Research timeframes and trend method"
input ENUM_TIMEFRAMES EntryTimeframe=PERIOD_M15;
input ENUM_TIMEFRAMES TrendTimeframe=PERIOD_H1;
input int FastEMAPeriod=50;
input int SlowEMAPeriod=200;
input int MaxTickAgeSeconds=120;

input group "Breakout/retest v1 - unvalidated research"
input bool EnableResearchStrategy=false;
input int BreakoutLookback=20;
input double BreakoutBufferATR=0.10;
input double RetestToleranceATR=0.25;
input int RetestTimeoutBars=6;
input int MaxEntriesPerDay=3;
input int CooldownBars=4;
input ulong MaxDeviationPoints=20;

input group "Risk research defaults"
input double RiskPercent=0.25;
input double DailyLossLimitPercent=3.0;
input int MaxOpenPositions=1;
input double RewardRiskRatio=2.0;
input ENUM_SL_MODEL StopLossModel=SL_ATR;
input int ATRPeriod=14;
input double ATRMultiplier=2.0;
input double FixedStopPoints=0.0;

input group "Portfolio risk guard"
input ulong PortfolioMagicBase=26093000;
input int PortfolioMagicSpan=100;
input double MaxPortfolioRiskPercent=1.0;
input int MaxPortfolioExposures=3;

input group "Filters"
input bool EnableSpreadFilter=true;
input double MaxSpreadPoints=0.0;
input bool EnableSessionFilter=false;
input int SessionStartHour=7;
input int SessionEndHour=20;
input bool AllowWeekendTrading=false;
input bool EnableNewsFilter=false;
input int NewsMinutesBefore=30;
input int NewsMinutesAfter=30;
input string NewsCurrency="USD";

input group "Position management (inactive by default)"
input bool EnableBreakEven=false;
input ENUM_BE_METHOD BreakEvenMethod=BE_BY_R;
input double BreakEvenTriggerR=1.0;
input double BreakEvenDistancePoints=0.0;
input bool EnableTrailingStop=false;
input ENUM_TRAIL_METHOD TrailingMethod=TRAIL_FIXED;
input double TrailingValue=0.0;

AQSettings g_cfg; AQSymbolSpec g_spec; AQLogger g_log; AQMarketData g_market; AQSelfDiagnostic g_diagnostic;
AQTrendEngine g_trend_engine; AQStrategyEngine g_strategy; AQDailyGuard g_daily;
AQTradeManager g_trader; AQPositionManager g_positions; AQDashboard g_dashboard; AQPortfolioExecutionLock g_portfolio_lock;
ENUM_TREND_STATE g_trend=TREND_DATA_NOT_READY; ENUM_SIGNAL_STATE g_signal=NO_SETUP; ENUM_NEWS_STATE g_news=NEWS_DISABLED;
string g_critical="",g_spread_state="",g_session_state="",g_news_state="DISABLED",g_weekend_state="";
double g_daily_loss=0; bool g_engine_ready=false,g_symbol_valid=false,g_trend_initialized=false,g_daily_initialized=false,g_management_initialized=false;
double g_portfolio_risk=0,g_portfolio_used_percent=0;int g_portfolio_exposures=0;
bool g_paused=false;
string g_risk_status="No candidate evaluated",g_management_status="DISABLED",g_last_decision="";
datetime g_evaluation_bar=0,g_evaluation_time=0,g_last_news_check=0;

void LoadSettings()
{
   g_cfg.mode=OperatingMode;g_cfg.profile=AssetProfile;g_cfg.symbol=(TradeSymbol==""?_Symbol:TradeSymbol);g_cfg.entry_tf=EntryTimeframe;g_cfg.trend_tf=TrendTimeframe;g_cfg.magic=MagicNumber;
   g_cfg.risk_percent=RiskPercent;g_cfg.daily_loss_percent=DailyLossLimitPercent;g_cfg.max_positions=MaxOpenPositions;g_cfg.reward_risk=RewardRiskRatio;
   g_cfg.spread_enabled=EnableSpreadFilter;g_cfg.max_spread_points=MaxSpreadPoints;g_cfg.session_enabled=EnableSessionFilter;g_cfg.session_start_hour=SessionStartHour;g_cfg.session_end_hour=SessionEndHour;
   g_cfg.news_enabled=EnableNewsFilter;g_cfg.news_before_minutes=NewsMinutesBefore;g_cfg.news_after_minutes=NewsMinutesAfter;g_cfg.allow_weekend=AllowWeekendTrading;g_cfg.break_even_enabled=EnableBreakEven;g_cfg.trailing_enabled=EnableTrailingStop;
}

int OnInit()
{
   LoadSettings();g_log.Init(g_cfg.symbol,g_cfg.magic);g_diagnostic.Reset();
   if(RunDeterministicSelfTests){int tests_passed=0,tests_failed=0;g_diagnostic.Check(AQValidationSuite::Run(tests_passed,tests_failed),StringFormat("deterministic self-tests failed %d",tests_failed));}
   g_diagnostic.Check(g_cfg.symbol!="","symbol is empty");
   g_diagnostic.Check(g_cfg.symbol==_Symbol,"attach EA to the configured symbol chart");
   g_diagnostic.Check(!EnableBreakEven ||
      (BreakEvenMethod==BE_BY_R && MathIsValidNumber(BreakEvenTriggerR) && BreakEvenTriggerR>0) ||
      (BreakEvenMethod==BE_BY_DISTANCE && MathIsValidNumber(BreakEvenDistancePoints) && BreakEvenDistancePoints>0),
      "invalid break-even configuration");
   g_diagnostic.Check(!EnableTrailingStop ||
      ((TrailingMethod==TRAIL_FIXED || TrailingMethod==TRAIL_ATR) && MathIsValidNumber(TrailingValue) && TrailingValue>0),
      "trailing v1 supports only positive FIXED or ATR distance");
   g_diagnostic.Check(!EnableResearchStrategy || (StopLossModel==SL_ATR && ATRMultiplier>0 && MathIsValidNumber(ATRMultiplier)),"v1 requires a positive ATR stop model");
   g_diagnostic.Check(MaxEntriesPerDay>=1 && CooldownBars>=0,"invalid entry frequency limits");
   g_diagnostic.Check(g_strategy.Init(g_cfg.symbol,EntryTimeframe,EnableResearchStrategy,BreakoutLookback,ATRPeriod,BreakoutBufferATR,RetestToleranceATR,RetestTimeoutBars),"strategy/ATR initialization failed");
   g_diagnostic.Check(PeriodSeconds(EntryTimeframe)>0 && PeriodSeconds(TrendTimeframe)>0,"invalid timeframe");
   g_diagnostic.Check(RiskPercent>0 && RiskPercent<=100 && DailyLossLimitPercent>0 && DailyLossLimitPercent<=100 && MaxOpenPositions>=1 && RewardRiskRatio>0 && MathIsValidNumber(RewardRiskRatio),"invalid risk inputs");
   g_diagnostic.Check(PortfolioMagicBase>0 && PortfolioMagicSpan>0 && AQPortfolioBudget::MagicInGroup(MagicNumber,PortfolioMagicBase,PortfolioMagicSpan),"MagicNumber is outside the Aurum portfolio magic range");
   g_diagnostic.Check(MathIsValidNumber(MaxPortfolioRiskPercent) && MaxPortfolioRiskPercent>=RiskPercent && MaxPortfolioRiskPercent<=100 && MaxPortfolioExposures>=1,"invalid portfolio risk limits");
   g_diagnostic.Check(!EnableSpreadFilter || (MaxSpreadPoints>0 && MathIsValidNumber(MaxSpreadPoints)),"spread limit must be positive");
   g_diagnostic.Check(!EnableSessionFilter || (SessionStartHour>=0 && SessionStartHour<=23 && SessionEndHour>=0 && SessionEndHour<=23),"invalid session hours");
   g_diagnostic.Check(!EnableNewsFilter || (NewsMinutesBefore>=0 && NewsMinutesAfter>=0 && NewsCurrency!=""),"invalid news configuration");
   g_diagnostic.Check(OperatingMode==MODE_OBSERVE || OperatingMode==MODE_DEMO || OperatingMode==MODE_LIVE,"invalid operating mode");
   g_diagnostic.Check(MaxTickAgeSeconds>0,"invalid data freshness limit");
   g_symbol_valid=AQSymbolProfile::Load(g_cfg.symbol,g_spec);g_diagnostic.Check(g_symbol_valid,"SYMBOL DATA INVALID: "+g_spec.error);
   if(g_symbol_valid){g_trend_initialized=g_trend_engine.Init(g_cfg.symbol,g_cfg.trend_tf,FastEMAPeriod,SlowEMAPeriod);g_diagnostic.Check(g_trend_initialized,"indicator handles unavailable");}
   string daily_reason="symbol invalid";if(g_symbol_valid)g_daily_initialized=g_daily.Init(g_cfg.symbol,MagicNumber,DailyLossLimitPercent,daily_reason);g_diagnostic.Check(g_daily_initialized,"daily guard: "+daily_reason);
   string portfolio_lock_reason;g_diagnostic.Check(g_portfolio_lock.Init(PortfolioMagicBase,PortfolioMagicSpan,MagicNumber,portfolio_lock_reason),"portfolio execution lock: "+portfolio_lock_reason);
   g_market.Init(g_cfg.symbol,g_cfg.entry_tf);g_trader.Init(OperatingMode,EnableOrderSubmission,MagicNumber,g_cfg.symbol);g_positions.Init(MagicNumber,g_cfg.symbol,OperatingMode,EnableOrderSubmission);
   string management_init_reason;
   g_management_initialized=g_positions.InitManagement(EntryTimeframe,ATRPeriod,EnableTrailingStop && TrailingMethod==TRAIL_ATR,management_init_reason);
   g_diagnostic.Check(g_management_initialized,"position management: "+management_init_reason);
   g_trader.SetDeviation(MaxDeviationPoints);
   string execution_reason;bool execution_allowed=g_trader.ExecutionAllowed(execution_reason);g_diagnostic.Check(!(OperatingMode==MODE_OBSERVE && execution_allowed),"OBSERVE execution assertion failed");
   if(g_symbol_valid)g_log.Event("SYMBOL_VALID",StringFormat("digits=%d point=%g tick_size=%g tick_value_loss=%g contract=%g volume=[%g,%g] step=%g stops=%d freeze=%d mode=%d",g_spec.digits,g_spec.point,g_spec.tick_size,g_spec.tick_value_loss,g_spec.contract_size,g_spec.volume_min,g_spec.volume_max,g_spec.volume_step,g_spec.stops_level,g_spec.freeze_level,g_spec.trade_mode));
   g_engine_ready=g_diagnostic.Ready();g_critical=(g_engine_ready?"":g_diagnostic.Reasons());g_log.Event("SELF_DIAGNOSTIC",g_engine_ready?"READY":"BLOCKED: "+g_critical);g_log.Event("SAFETY",execution_reason);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason){g_portfolio_lock.Release();g_positions.ShutdownManagement();g_strategy.Shutdown();g_trend_engine.Shutdown();g_dashboard.Clear();g_log.Event("DEINIT",IntegerToString(reason));}

void OnTick()
{
   g_symbol_valid=AQSymbolProfile::Load(g_cfg.symbol,g_spec);if(!g_symbol_valid){g_signal=SIGNAL_BLOCKED;g_critical="SYMBOL DATA INVALID: "+g_spec.error;}
   double spread=AQSymbolProfile::SpreadPoints(g_spec);bool spread_ok=AQSpreadFilter::Pass(EnableSpreadFilter,spread,MaxSpreadPoints,g_spread_state);
   bool session_ok=AQSessionFilter::Pass(EnableSessionFilter,SessionStartHour,SessionEndHour,g_session_state);bool weekend_ok=AQSessionFilter::WeekendPass(AllowWeekendTrading,g_weekend_state);
   datetime server=TimeTradeServer();if(g_last_news_check==0 || server-g_last_news_check>=60){g_news=AQNewsFilter::Evaluate(EnableNewsFilter,NewsMinutesBefore,NewsMinutesAfter,NewsCurrency,g_news_state);g_last_news_check=server;}
   bool news_ok=(g_news==NEWS_CLEAR || g_news==NEWS_DISABLED);string daily_reason="daily guard unavailable";bool daily_block=(!g_daily_initialized || g_daily.IsBlocked(g_daily_loss,daily_reason));
   string position_reason;bool position_ok=AQPositionGuard::CanOpen(g_cfg.symbol,MagicNumber,MaxOpenPositions,position_reason);
   string portfolio_reason;bool portfolio_ok=AQPortfolioGuard::CurrentWithinLimits(PortfolioMagicBase,PortfolioMagicSpan,MaxPortfolioExposures,MaxPortfolioRiskPercent,g_portfolio_risk,g_portfolio_exposures,g_portfolio_used_percent,portfolio_reason);
   int tick_age=INT_MAX;bool fresh=g_symbol_valid && g_market.Fresh(MaxTickAgeSeconds,tick_age);datetime closed_bar=0;bool evaluated=false;
   if(EnableBreakEven || EnableTrailingStop)
   {
      string management_lock;
      if(!g_management_initialized)g_management_status="BLOCKED: initialization failed";
      else if(!g_positions.ExecutionAllowed(management_lock))g_management_status="LOCKED: "+management_lock;
      else if(!g_symbol_valid)g_management_status="BLOCKED: symbol data invalid";
      else if(!fresh)g_management_status=StringFormat("BLOCKED: market data stale (%d seconds)",tick_age);
      else
      {
         int modified=0;string management_reason;
         if(g_positions.Manage(EnableBreakEven,BreakEvenMethod,BreakEvenTriggerR,BreakEvenDistancePoints,
              EnableTrailingStop,TrailingMethod,TrailingValue,modified,management_reason))
         {
            g_management_status=management_reason;
            if(modified>0)g_log.Event("POSITION_MANAGEMENT",StringFormat("modified=%d|status=%s",modified,management_reason));
         }
         else g_management_status="BLOCKED: "+management_reason;
      }
   }
   else g_management_status="DISABLED";
   if(g_engine_ready && fresh && g_market.IsNewBar(closed_bar))
   {
      evaluated=true;g_evaluation_bar=closed_bar;g_evaluation_time=server;g_log.Event("NEW_BAR",StringFormat("tf=%s|closed_bar=%s",EnumToString(EntryTimeframe),TimeToString(closed_bar,TIME_DATE|TIME_MINUTES)));
      ENUM_TREND_STATE previous=g_trend;g_trend=g_trend_engine.Evaluate();if(previous!=g_trend)g_log.Event("TREND_CHANGE",AQTrendName(g_trend));g_signal=g_strategy.Evaluate(g_trend,closed_bar);
   }
   string blocked="";
   if(!g_engine_ready || !g_symbol_valid)blocked=g_critical;else if(!fresh)blocked=StringFormat("market data stale (%d seconds)",tick_age);else if(!spread_ok)blocked=g_spread_state;else if(!session_ok)blocked="session filter";else if(!weekend_ok)blocked=g_weekend_state;else if(!news_ok)blocked=g_news_state;else if(daily_block)blocked=daily_reason;else if(!position_ok)blocked=position_reason;else if(!portfolio_ok)blocked=portfolio_reason;else if(g_trend==TREND_DATA_NOT_READY)blocked="trend data not ready";else if(g_signal==SIGNAL_BLOCKED)blocked="strategy data invalid or unavailable";
   if(g_paused)blocked="entries paused by user";
   string decision=(blocked!=""?"BLOCKED":(EnableResearchStrategy?"WAIT - breakout/retest v1":"OBSERVATION - strategy disabled"));
   bool candidate=evaluated && (g_signal==BUY_CANDIDATE || g_signal==SELL_CANDIDATE);
   if(!candidate)g_risk_status=(portfolio_ok?StringFormat("Portfolio risk %.2f%% / %.2f%% | exposures %d/%d",g_portfolio_used_percent,MaxPortfolioRiskPercent,g_portfolio_exposures,MaxPortfolioExposures):portfolio_reason);
   if(candidate)
   {
      string why=blocked;AQOrderPlan plan;
      bool ready=why=="";
      if(ready)ready=AQEntryLimits::Pass(g_cfg.symbol,MagicNumber,MaxEntriesPerDay,CooldownBars,EntryTimeframe,why);
      if(ready)ready=AQOrderPlanner::Build(g_spec,g_signal==BUY_CANDIDATE?AQ_BUY:AQ_SELL,g_strategy.ATR(),ATRMultiplier,RewardRiskRatio,RiskPercent,plan,why);
      if(ready)ready=AQPortfolioGuard::CanAdd(PortfolioMagicBase,PortfolioMagicSpan,MaxPortfolioExposures,MaxPortfolioRiskPercent,plan.estimated_loss,g_portfolio_risk,g_portfolio_exposures,g_portfolio_used_percent,why);
      if(ready)
      {
         g_risk_status=StringFormat("%.8f lots | estimated SL loss %.2f | margin %.2f | portfolio after candidate %.2f%% / %.2f%% | exposures %d/%d",plan.volume,plan.estimated_loss,plan.margin,g_portfolio_used_percent,MaxPortfolioRiskPercent,g_portfolio_exposures,MaxPortfolioExposures);
         g_log.Event("CANDIDATE",StringFormat("direction=%s|bar=%I64d|entry=%g|sl=%g|tp=%g|volume=%.8f",g_signal==BUY_CANDIDATE?"BUY":"SELL",(long)closed_bar,plan.entry,plan.sl,plan.tp,plan.volume));
         if(g_trader.ExecutionAllowed(why))
         {
            string gate_reason;
            if(!g_portfolio_lock.Acquire(120,gate_reason))
            {decision="CANDIDATE DISCARDED";why=gate_reason;g_risk_status=why;}
            else
            {
               bool live_ok=AQPortfolioGuard::CanAdd(PortfolioMagicBase,PortfolioMagicSpan,MaxPortfolioExposures,MaxPortfolioRiskPercent,plan.estimated_loss,g_portfolio_risk,g_portfolio_exposures,g_portfolio_used_percent,gate_reason);
               bool request_accepted=false;
               if(live_ok)
               {
                  AQTradeResult result;
                  if(g_signal==BUY_CANDIDATE)request_accepted=g_trader.Buy(closed_bar,g_cfg.symbol,plan.volume,plan.entry,plan.sl,plan.tp,"Aurum v1",result);
                  else request_accepted=g_trader.Sell(closed_bar,g_cfg.symbol,plan.volume,plan.entry,plan.sl,plan.tp,"Aurum v1",result);
                  decision=request_accepted?"REQUEST ACCEPTED":"REQUEST REJECTED";why=result.description;
               }
               else {decision="CANDIDATE DISCARDED";why=gate_reason;g_risk_status=why;}
               if(request_accepted)g_portfolio_lock.HoldUntilExpiry();
               else g_portfolio_lock.Release();
            }
         }
         else decision="CANDIDATE ONLY - execution locked";
      }
      else {decision="CANDIDATE DISCARDED";g_risk_status=why;}
      g_log.Event("CANDIDATE_DECISION",decision+" | "+why);
      // This signal is never retried on later ticks, including broker rejection.
   }
   if(decision!=g_last_decision){g_log.Event("DECISION",decision+" | "+blocked);g_last_decision=decision;}
   int count=AQPositionGuard::Count(g_cfg.symbol,MagicNumber);
   string execution_reason;bool execution_allowed=g_trader.ExecutionAllowed(execution_reason);string lock_state=(execution_allowed?"ARMED":"LOCKED: "+execution_reason);string freshness=(fresh?StringFormat("FRESH (%d seconds)",tick_age):StringFormat("STALE/UNAVAILABLE (%d seconds)",tick_age));
   g_dashboard.PauseButton(g_paused);
   string dashboard_risk=g_risk_status+" | Mgmt: "+g_management_status;
   g_dashboard.Render(g_cfg,(g_engine_ready?"READY":"BLOCKED"),(g_symbol_valid?"VALID":"INVALID"),freshness,lock_state,dashboard_risk,g_evaluation_bar,g_evaluation_time,g_trend,g_signal,spread,g_spread_state,g_session_state,g_news_state,g_weekend_state,g_daily_loss,count,decision,blocked);
}

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id==CHARTEVENT_OBJECT_CLICK && sparam=="AQ_PAUSE_ENTRIES")
   {
      g_paused=!g_paused;g_dashboard.PauseButton(g_paused);
      g_log.Event("USER_PAUSE",g_paused?"new entries paused; existing positions unchanged":"new entry evaluation resumed");
   }
}

double OnTester(){AQTesterMetrics metrics;AQTesterResearch::Capture(metrics);AQTesterResearch::Log(metrics);return AQTesterResearch::UntunedDiagnosticScore(metrics);}
