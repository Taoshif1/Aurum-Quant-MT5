// Test-only MQL API substitutes. No network, terminal, or broker access.
#pragma once
#include <cmath>
#include <cfloat>
#include <string>
#include <algorithm>
#include <cassert>
#include <iostream>
using string=std::string;
using ENUM_TIMEFRAMES=int;
using uint=unsigned int;
using datetime=long;
inline bool MathIsValidNumber(double x){return std::isfinite(x);}
inline double MathAbs(double x){return std::abs(x);}
inline double MathMin(double x,double y){return std::min(x,y);}
inline double MathMax(double x,double y){return std::max(x,y);}
inline double MathFloor(double x){return std::floor(x);}
inline double MathRound(double x){return std::round(x);}
inline double NormalizeDouble(double x,int d){return std::round(x*std::pow(10,d))/std::pow(10,d);}
template<class T> void ZeroMemory(T &v){v=T{};}
enum { SYMBOL_POINT, SYMBOL_DIGITS, SYMBOL_TRADE_TICK_SIZE, SYMBOL_TRADE_TICK_VALUE,
SYMBOL_TRADE_TICK_VALUE_PROFIT, SYMBOL_TRADE_TICK_VALUE_LOSS, SYMBOL_TRADE_CONTRACT_SIZE,
SYMBOL_VOLUME_MIN, SYMBOL_VOLUME_MAX, SYMBOL_VOLUME_STEP, SYMBOL_TRADE_STOPS_LEVEL,
SYMBOL_TRADE_FREEZE_LEVEL, SYMBOL_TRADE_MODE, SYMBOL_SWAP_LONG, SYMBOL_SWAP_SHORT,
SYMBOL_TRADE_MODE_DISABLED, SYMBOL_TRADE_MODE_CLOSEONLY, SYMBOL_TRADE_MODE_SHORTONLY,
SYMBOL_TRADE_MODE_LONGONLY, SYMBOL_TRADE_MODE_FULL, ACCOUNT_TRADE_MODE,
ACCOUNT_TRADE_MODE_DEMO, ACCOUNT_TRADE_MODE_REAL, ACCOUNT_TRADE_MODE_CONTEST,
POSITION_SYMBOL, POSITION_MAGIC, POSITION_TYPE, POSITION_TYPE_BUY,
TRADE_RETCODE_DONE, TRADE_RETCODE_NO_CHANGES, TRADE_RETCODE_DONE_PARTIAL };
struct MqlTick{double bid,ask;};
inline bool SymbolSelect(string,bool){return false;}
inline bool SymbolInfoTick(string,MqlTick&){return false;}
inline double SymbolInfoDouble(string,int){return 0;}
inline long SymbolInfoInteger(string,int){return 0;}
inline long account_mode=ACCOUNT_TRADE_MODE_DEMO;
inline long AccountInfoInteger(int){return account_mode;}
inline int position_reads=0,trade_calls=0;
inline bool PositionSelectByTicket(unsigned long){++position_reads;return true;}
inline string PositionGetString(int){return "SYNTH";}
inline long PositionGetInteger(int p){return p==POSITION_MAGIC?123:POSITION_TYPE_BUY;}

inline double MathCeil(double x){return std::ceil(x);}
enum ENUM_ORDER_TYPE{ORDER_TYPE_BUY,ORDER_TYPE_SELL};
enum {ACCOUNT_EQUITY=1000,ACCOUNT_MARGIN_FREE};
inline double test_equity=10000,test_free_margin=10000;
inline bool test_profit_available=true,test_margin_available=true;
inline double AccountInfoDouble(int p){return p==ACCOUNT_EQUITY?test_equity:test_free_margin;}
inline bool OrderCalcProfit(ENUM_ORDER_TYPE type,string,double volume,double entry,double stop,double &profit){
 profit=(type==ORDER_TYPE_BUY?stop-entry:entry-stop)*volume*100;return test_profit_available;
}
inline bool OrderCalcMargin(ENUM_ORDER_TYPE,string,double volume,double,double &margin){margin=volume*1000;return test_margin_available;}
