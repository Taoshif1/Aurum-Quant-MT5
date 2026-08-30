#property copyright "Aurum Quant MT5 research project"
#property version   "0.1.0"
#property strict
#property description "Multi-asset research-first EA foundation. No approved entry rules."

#include <AurumQuant/Core/Config.mqh>
#include <AurumQuant/Core/Logger.mqh>
#include <AurumQuant/Core/SymbolProfile.mqh>
#include <AurumQuant/Core/MarketData.mqh>
#include <AurumQuant/Strategy/TrendEngine.mqh>
#include <AurumQuant/Strategy/StrategyEngine.mqh>
#include <AurumQuant/Risk/RiskManager.mqh>
#include <AurumQuant/Risk/DailyGuard.mqh>
#include <AurumQuant/Risk/PositionGuard.mqh>
#include <AurumQuant/Filters/SpreadFilter.mqh>
#include <AurumQuant/Filters/SessionFilter.mqh>
#include <AurumQuant/Filters/NewsFilter.mqh>
#include <AurumQuant/Trading/TradeManager.mqh>
#include <AurumQuant/Trading/PositionManager.mqh>
#include <AurumQuant/UI/Dashboard.mqh>

input group "Safety and identity"
input ENUM_AQ_MODE OperatingMode=MODE_OBSERVE;
input bool EnableOrderSubmission=false;
input string TradeSymbol="";
input ENUM_ASSET_PROFILE AssetProfile=PROFILE_GENERIC;
input ulong MagicNumber=26083001;

input group "Research timeframes and trend method"
input ENUM_TIMEFRAMES EntryTimeframe=PERIOD_M15;
input ENUM_TIMEFRAMES TrendTimeframe=PERIOD_H1;
input int FastEMAPeriod=50;
input int SlowEMAPeriod=200;

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

AQSettings g_cfg; AQSymbolSpec g_spec; AQLogger g_log; AQMarketData g_market;
AQTrendEngine g_trend_engine; AQStrategyEngine g_strategy; AQDailyGuard g_daily;
AQTradeManager g_trader; AQPositionManager g_positions; AQDashboard g_dashboard;
ENUM_TREND_STATE g_trend=TREND_DATA_NOT_READY; ENUM_SIGNAL_STATE g_signal=NO_SETUP;
string g_critical=""; string g_spread_state="",g_session_state="",g_news_state="",g_weekend_state="";
double g_daily_dd=0;

void LoadSettings()
{
   g_cfg.mode=OperatingMode; g_cfg.profile=AssetProfile; g_cfg.symbol=(TradeSymbol==""?_Symbol:TradeSymbol);
   g_cfg.entry_tf=EntryTimeframe; g_cfg.trend_tf=TrendTimeframe; g_cfg.magic=MagicNumber;
   g_cfg.risk_percent=RiskPercent; g_cfg.daily_loss_percent=DailyLossLimitPercent; g_cfg.max_positions=MaxOpenPositions; g_cfg.reward_risk=RewardRiskRatio;
   g_cfg.spread_enabled=EnableSpreadFilter; g_cfg.max_spread_points=MaxSpreadPoints; g_cfg.session_enabled=EnableSessionFilter;
   g_cfg.session_start_hour=SessionStartHour; g_cfg.session_end_hour=SessionEndHour; g_cfg.news_enabled=EnableNewsFilter;
   g_cfg.news_before_minutes=NewsMinutesBefore; g_cfg.news_after_minutes=NewsMinutesAfter; g_cfg.allow_weekend=AllowWeekendTrading;
   g_cfg.break_even_enabled=EnableBreakEven; g_cfg.trailing_enabled=EnableTrailingStop;
}

int OnInit()
{
   LoadSettings(); g_log.Init(g_cfg.symbol,g_cfg.magic);
   if(RiskPercent<=0 || RiskPercent>100 || DailyLossLimitPercent<=0 || MaxOpenPositions<1 || RewardRiskRatio<=0) { g_critical="invalid configuration"; g_log.Event("CONFIG_REJECT",g_critical); return INIT_PARAMETERS_INCORRECT; }
   if(!AQSymbolProfile::Load(g_cfg.symbol,g_spec)) { g_critical=g_spec.error; g_log.Event("SYMBOL_REJECT",g_critical); return INIT_FAILED; }
   if(EnableSpreadFilter && MaxSpreadPoints<=0) { g_critical="MaxSpreadPoints must be configured per broker symbol"; g_log.Event("CONFIG_REJECT",g_critical); return INIT_PARAMETERS_INCORRECT; }
   if(!g_trend_engine.Init(g_cfg.symbol,g_cfg.trend_tf,FastEMAPeriod,SlowEMAPeriod)) { g_critical="trend handles failed"; g_log.Event("CRITICAL",g_critical); return INIT_FAILED; }
   g_market.Init(g_cfg.symbol,g_cfg.entry_tf); g_daily.Init(DailyLossLimitPercent);
   g_trader.Init(OperatingMode,EnableOrderSubmission,MagicNumber,g_cfg.symbol); g_positions.Init(MagicNumber,g_cfg.symbol);
   string execution_reason; g_trader.ExecutionAllowed(execution_reason);
   g_log.Event("SYMBOL_VALID",StringFormat("point=%g tick_size=%g tick_value=%g contract=%g volume=[%g,%g] step=%g stops=%d freeze=%d mode=%d swap_long=%g swap_short=%g",g_spec.point,g_spec.tick_size,g_spec.tick_value,g_spec.contract_size,g_spec.volume_min,g_spec.volume_max,g_spec.volume_step,g_spec.stops_level,g_spec.freeze_level,g_spec.trade_mode,g_spec.swap_long,g_spec.swap_short));
   g_log.Event("SAFETY",execution_reason); return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { g_trend_engine.Shutdown(); g_dashboard.Clear(); g_log.Event("DEINIT",IntegerToString(reason)); }

void OnTick()
{
   if(!AQSymbolProfile::Load(g_cfg.symbol,g_spec)) { g_critical=g_spec.error; g_signal=SIGNAL_BLOCKED; return; }
   double spread=AQSymbolProfile::SpreadPoints(g_spec); bool spread_ok=AQSpreadFilter::Pass(EnableSpreadFilter,spread,MaxSpreadPoints,g_spread_state);
   bool session_ok=AQSessionFilter::Pass(EnableSessionFilter,SessionStartHour,SessionEndHour,g_session_state);
   bool weekend_ok=AQSessionFilter::WeekendPass(AllowWeekendTrading,g_weekend_state);
   bool news_ok=AQNewsFilter::Pass(EnableNewsFilter,NewsMinutesBefore,NewsMinutesAfter,NewsCurrency,g_news_state);
   bool daily_block=g_daily.IsBlocked(g_daily_dd); string position_reason; bool position_ok=AQPositionGuard::CanOpen(g_cfg.symbol,MagicNumber,MaxOpenPositions,position_reason);
   if(g_market.IsNewBar())
   {
      g_log.Event("NEW_BAR",EnumToString(EntryTimeframe)); ENUM_TREND_STATE previous=g_trend; g_trend=g_trend_engine.Evaluate();
      if(previous!=g_trend) g_log.Event("TREND_CHANGE",AQTrendName(g_trend)); g_signal=g_strategy.Evaluate(g_trend);
   }
   string blocked="";
   if(!spread_ok) blocked=g_spread_state; else if(!session_ok) blocked="session filter"; else if(!weekend_ok) blocked=g_weekend_state; else if(!news_ok) blocked=g_news_state; else if(daily_block) blocked="daily equity drawdown limit"; else if(!position_ok) blocked=position_reason; else if(g_critical!="") blocked=g_critical;
   string decision=(blocked!=""?"BLOCKED":"WAIT — research entry rules not approved");
   int count=AQPositionGuard::Count(g_cfg.symbol,MagicNumber);
   g_dashboard.Render(g_cfg,g_trend,g_signal,spread,g_spread_state,g_session_state,g_news_state,g_weekend_state,g_daily_dd,count,decision,blocked);
   // No order method is called in this foundation: StrategyEngine never emits a candidate.
}
