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
const int INVALID_HANDLE=-1;
const int PERIOD_CURRENT=0;
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
ACCOUNT_TRADE_MODE_DEMO, ACCOUNT_TRADE_MODE_REAL, ACCOUNT_TRADE_MODE_CONTEST, ACCOUNT_LOGIN,
POSITION_SYMBOL, POSITION_MAGIC, POSITION_TYPE, POSITION_TYPE_BUY, POSITION_TYPE_SELL,
POSITION_PRICE_OPEN, POSITION_SL, POSITION_TP,
TRADE_RETCODE_DONE, TRADE_RETCODE_NO_CHANGES, TRADE_RETCODE_DONE_PARTIAL };
struct MqlTick{double bid,ask;};
inline bool SymbolSelect(string,bool){return false;}
inline bool SymbolInfoTick(string,MqlTick&){return false;}
inline double SymbolInfoDouble(string,int){return 0;}
inline long SymbolInfoInteger(string,int){return 0;}
inline long account_mode=ACCOUNT_TRADE_MODE_DEMO;
inline long AccountInfoInteger(int p){return p==ACCOUNT_LOGIN?999001:account_mode;}
inline int position_reads=0,trade_calls=0,test_positions_total=0;
inline double test_position_entry=100,test_position_sl=90,test_position_tp=120;
inline bool PositionSelectByTicket(unsigned long){++position_reads;return true;}
inline int PositionsTotal(){return test_positions_total;}
inline unsigned long PositionGetTicket(int){++position_reads;return 1;}
inline string PositionGetString(int){return "SYNTH";}
inline long PositionGetInteger(int p){return p==POSITION_MAGIC?123:POSITION_TYPE_BUY;}
inline double PositionGetDouble(int p){if(p==POSITION_PRICE_OPEN)return test_position_entry;if(p==POSITION_SL)return test_position_sl;if(p==POSITION_TP)return test_position_tp;return 0;}
inline long MQLInfoInteger(int){return 0;}
enum {MQL_TESTER=1};
inline int iATR(string,ENUM_TIMEFRAMES,int){return 1;}
inline bool IndicatorRelease(int){return true;}
inline int CopyBuffer(int,int,int,int,double *out){if(out)out[0]=2;return 1;}
inline int StringLen(const string &s){return (int)s.size();}
template<typename... Args> inline string StringFormat(const char*,Args...){return "AQR.TEST";}
inline bool GlobalVariableCheck(const string&){return false;}
inline bool GlobalVariableGet(const string&,double &v){v=10;return true;}
inline datetime GlobalVariableSet(const string&,double){return 1;}

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
