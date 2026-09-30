#pragma once
class CTrade {
public:
 void SetAsyncMode(bool){}
 void SetExpertMagicNumber(unsigned long){}
 bool SetTypeFillingBySymbol(string){return true;}
 bool PositionModify(unsigned long,double,double){++trade_calls;return true;}
 bool PositionClose(unsigned long){++trade_calls;return true;}
 uint ResultRetcode(){return TRADE_RETCODE_DONE;}
};
