#ifndef AURUM_CONFIG_MQH
#define AURUM_CONFIG_MQH

enum ENUM_AQ_MODE { MODE_OBSERVE=0, MODE_DEMO=1, MODE_LIVE=2 };
enum ENUM_ASSET_PROFILE { PROFILE_GENERIC=0, PROFILE_CRYPTO=1, PROFILE_GOLD=2, PROFILE_FOREX=3, PROFILE_INDEX=4 };
enum ENUM_TREND_STATE { TREND_DATA_NOT_READY=0, TREND_NEUTRAL=1, TREND_BULLISH=2, TREND_BEARISH=3 };
enum ENUM_SIGNAL_STATE { NO_SETUP=0, TREND_READY=1, BREAKOUT_DETECTED=2, WAITING_PULLBACK=3, WAITING_CONFIRMATION=4, BUY_CANDIDATE=5, SELL_CANDIDATE=6, SIGNAL_BLOCKED=7 };
enum ENUM_SL_MODEL { SL_SWING=0, SL_ATR=1, SL_FIXED_DISTANCE=2 };
enum ENUM_BE_METHOD { BE_BY_R=0, BE_BY_DISTANCE=1 };
enum ENUM_TRAIL_METHOD { TRAIL_FIXED=0, TRAIL_ATR=1, TRAIL_SWING=2, TRAIL_R=3 };
enum ENUM_AQ_DIRECTION { AQ_BUY=0, AQ_SELL=1 };
enum ENUM_ENGINE_STATE { ENGINE_READY=0, ENGINE_BLOCKED=1 };

struct AQSettings
{
   ENUM_AQ_MODE mode;
   ENUM_ASSET_PROFILE profile;
   string symbol;
   ENUM_TIMEFRAMES entry_tf;
   ENUM_TIMEFRAMES trend_tf;
   ulong magic;
   double risk_percent;
   double daily_loss_percent;
   int max_positions;
   double reward_risk;
   bool spread_enabled;
   double max_spread_points;
   bool session_enabled;
   int session_start_hour;
   int session_end_hour;
   bool news_enabled;
   int news_before_minutes;
   int news_after_minutes;
   bool allow_weekend;
   bool break_even_enabled;
   bool trailing_enabled;
};

string AQModeName(ENUM_AQ_MODE v) { if(v==MODE_DEMO) return "DEMO"; if(v==MODE_LIVE) return "LIVE"; return "OBSERVE"; }
string AQProfileName(ENUM_ASSET_PROFILE v) { if(v==PROFILE_CRYPTO) return "CRYPTO"; if(v==PROFILE_GOLD) return "GOLD"; if(v==PROFILE_FOREX) return "FOREX"; if(v==PROFILE_INDEX) return "INDEX"; return "GENERIC"; }
string AQTrendName(ENUM_TREND_STATE v) { if(v==TREND_BULLISH) return "BULLISH"; if(v==TREND_BEARISH) return "BEARISH"; if(v==TREND_NEUTRAL) return "NEUTRAL"; return "DATA_NOT_READY"; }
string AQSignalName(ENUM_SIGNAL_STATE v)
{
   switch(v) { case TREND_READY:return "TREND_READY"; case BREAKOUT_DETECTED:return "BREAKOUT_DETECTED"; case WAITING_PULLBACK:return "WAITING_PULLBACK"; case WAITING_CONFIRMATION:return "WAITING_CONFIRMATION"; case BUY_CANDIDATE:return "BUY_CANDIDATE"; case SELL_CANDIDATE:return "SELL_CANDIDATE"; case SIGNAL_BLOCKED:return "BLOCKED"; default:return "NO_SETUP"; }
}
#endif
