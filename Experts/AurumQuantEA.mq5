#property copyright "Aurum Quant MT5 research project"
#property version   "1.100"
#property strict
#property description "Multi-asset research engine. No approved entry rules."

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
input ulong MagicNumber=26083001;
input bool RunDeterministicSelfTests=true;

input group "Research timeframes and trend method"
input ENUM_TIMEFRAMES EntryTimeframe=PERIOD_M15;
input ENUM_TIMEFRAMES TrendTimeframe=PERIOD_H1;
input int FastEMAPeriod=50;
input int SlowEMAPeriod=200;
input int MaxTickAgeSeconds=120;

input group "Risk research defaults"
input double RiskPercent=1.0;
input double DailyLossLimitPercent=3.0;
input int MaxOpenPositions=1;
input double RewardRiskRatio=2.0;
input ENUM_SL_MODEL StopLossModel=SL_ATR;
input int ATRPeriod=14;
input double ATRMultiplier=2.0;
input double FixedStopPoints=0.0;

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
AQTradeManager g_trader; AQPositionManager g_positions; AQDashboard g_dashboard;
ENUM_TREND_STATE g_trend=TREND_DATA_NOT_READY; ENUM_SIGNAL_STATE g_signal=NO_SETUP; ENUM_NEWS_STATE g_news=NEWS_DISABLED;
string g_critical="",g_spread_state="",g_session_state="",g_news_state="DISABLED",g_weekend_state="";
double g_daily_loss=0; bool g_engine_ready=false,g_symbol_valid=false,g_trend_initialized=false,g_daily_initialized=false;
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
   g_diagnostic.Check(PeriodSeconds(EntryTimeframe)>0 && PeriodSeconds(TrendTimeframe)>0,"invalid timeframe");
   g_diagnostic.Check(RiskPercent>0 && RiskPercent<=100 && DailyLossLimitPercent>0 && DailyLossLimitPercent<=100 && MaxOpenPositions>=1 && RewardRiskRatio>0,"invalid risk inputs");
   g_diagnostic.Check(!EnableSpreadFilter || MaxSpreadPoints>0,"spread limit must be positive");
   g_diagnostic.Check(!EnableSessionFilter || (SessionStartHour>=0 && SessionStartHour<=23 && SessionEndHour>=0 && SessionEndHour<=23),"invalid session hours");
   g_diagnostic.Check(!EnableNewsFilter || (NewsMinutesBefore>=0 && NewsMinutesAfter>=0 && NewsCurrency!=""),"invalid news configuration");
   g_diagnostic.Check(OperatingMode==MODE_OBSERVE || OperatingMode==MODE_DEMO || OperatingMode==MODE_LIVE,"invalid operating mode");
   g_diagnostic.Check(MaxTickAgeSeconds>0,"invalid data freshness limit");
   g_symbol_valid=AQSymbolProfile::Load(g_cfg.symbol,g_spec);g_diagnostic.Check(g_symbol_valid,"SYMBOL DATA INVALID: "+g_spec.error);
   if(g_symbol_valid){g_trend_initialized=g_trend_engine.Init(g_cfg.symbol,g_cfg.trend_tf,FastEMAPeriod,SlowEMAPeriod);g_diagnostic.Check(g_trend_initialized,"indicator handles unavailable");}
   string daily_reason="symbol invalid";if(g_symbol_valid)g_daily_initialized=g_daily.Init(g_cfg.symbol,MagicNumber,DailyLossLimitPercent,daily_reason);g_diagnostic.Check(g_daily_initialized,"daily guard: "+daily_reason);
   g_market.Init(g_cfg.symbol,g_cfg.entry_tf);g_trader.Init(OperatingMode,EnableOrderSubmission,MagicNumber,g_cfg.symbol);g_positions.Init(MagicNumber,g_cfg.symbol);
   string execution_reason;bool execution_allowed=g_trader.ExecutionAllowed(execution_reason);g_diagnostic.Check(!(OperatingMode==MODE_OBSERVE && execution_allowed),"OBSERVE execution assertion failed");
   if(g_symbol_valid)g_log.Event("SYMBOL_VALID",StringFormat("digits=%d point=%g tick_size=%g tick_value_loss=%g contract=%g volume=[%g,%g] step=%g stops=%d freeze=%d mode=%d",g_spec.digits,g_spec.point,g_spec.tick_size,g_spec.tick_value_loss,g_spec.contract_size,g_spec.volume_min,g_spec.volume_max,g_spec.volume_step,g_spec.stops_level,g_spec.freeze_level,g_spec.trade_mode));
   g_engine_ready=g_diagnostic.Ready();g_critical=(g_engine_ready?"":g_diagnostic.Reasons());g_log.Event("SELF_DIAGNOSTIC",g_engine_ready?"READY":"BLOCKED: "+g_critical);g_log.Event("SAFETY",execution_reason);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason){if(g_trend_initialized)g_trend_engine.Shutdown();g_dashboard.Clear();g_log.Event("DEINIT",IntegerToString(reason));}

void OnTick()
{
   g_symbol_valid=AQSymbolProfile::Load(g_cfg.symbol,g_spec);if(!g_symbol_valid){g_signal=SIGNAL_BLOCKED;g_critical="SYMBOL DATA INVALID: "+g_spec.error;}
   double spread=AQSymbolProfile::SpreadPoints(g_spec);bool spread_ok=AQSpreadFilter::Pass(EnableSpreadFilter,spread,MaxSpreadPoints,g_spread_state);
   bool session_ok=AQSessionFilter::Pass(EnableSessionFilter,SessionStartHour,SessionEndHour,g_session_state);bool weekend_ok=AQSessionFilter::WeekendPass(AllowWeekendTrading,g_weekend_state);
   datetime server=TimeTradeServer();if(g_last_news_check==0 || server-g_last_news_check>=60){g_news=AQNewsFilter::Evaluate(EnableNewsFilter,NewsMinutesBefore,NewsMinutesAfter,NewsCurrency,g_news_state);g_last_news_check=server;}
   bool news_ok=(g_news==NEWS_CLEAR || g_news==NEWS_DISABLED);string daily_reason="daily guard unavailable";bool daily_block=(!g_daily_initialized || g_daily.IsBlocked(g_daily_loss,daily_reason));
   string position_reason;bool position_ok=AQPositionGuard::CanOpen(g_cfg.symbol,MagicNumber,MaxOpenPositions,position_reason);int tick_age=INT_MAX;bool fresh=g_symbol_valid && g_market.Fresh(MaxTickAgeSeconds,tick_age);datetime closed_bar=0;
   if(g_engine_ready && fresh && g_market.IsNewBar(closed_bar))
   {
      g_evaluation_bar=closed_bar;g_evaluation_time=server;g_log.Event("NEW_BAR",StringFormat("tf=%s|closed_bar=%s",EnumToString(EntryTimeframe),TimeToString(closed_bar,TIME_DATE|TIME_MINUTES)));
      ENUM_TREND_STATE previous=g_trend;g_trend=g_trend_engine.Evaluate();if(previous!=g_trend)g_log.Event("TREND_CHANGE",AQTrendName(g_trend));g_signal=g_strategy.Evaluate(g_trend,closed_bar);
   }
   string blocked="";
   if(!g_engine_ready || !g_symbol_valid)blocked=g_critical;else if(!fresh)blocked=StringFormat("market data stale (%d seconds)",tick_age);else if(!spread_ok)blocked=g_spread_state;else if(!session_ok)blocked="session filter";else if(!weekend_ok)blocked=g_weekend_state;else if(!news_ok)blocked=g_news_state;else if(daily_block)blocked=daily_reason;else if(!position_ok)blocked=position_reason;else if(g_trend==TREND_DATA_NOT_READY)blocked="trend data not ready";
   string decision=(blocked!=""?"BLOCKED":"WAIT - research entry rules not approved");int count=AQPositionGuard::Count(g_cfg.symbol,MagicNumber);
   string execution_reason;bool execution_allowed=g_trader.ExecutionAllowed(execution_reason);string lock_state=(execution_allowed?"ARMED":"LOCKED: "+execution_reason);string freshness=(fresh?StringFormat("FRESH (%d seconds)",tick_age):StringFormat("STALE/UNAVAILABLE (%d seconds)",tick_age));
   g_dashboard.Render(g_cfg,(g_engine_ready?"READY":"BLOCKED"),(g_symbol_valid?"VALID":"INVALID"),freshness,lock_state,"WAITING FOR APPROVED ENTRY/SL",g_evaluation_bar,g_evaluation_time,g_trend,g_signal,spread,g_spread_state,g_session_state,g_news_state,g_weekend_state,g_daily_loss,count,decision,blocked);
}

double OnTester(){AQTesterMetrics metrics;AQTesterResearch::Capture(metrics);AQTesterResearch::Log(metrics);return AQTesterResearch::UntunedDiagnosticScore(metrics);}
