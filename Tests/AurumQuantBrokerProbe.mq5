#property script_show_inputs
#property strict
#property description "Exports broker/account symbol economics for Aurum Quant native validation."

input string SymbolsCSV="";

string Stamp()
{
   MqlDateTime t;
   datetime now=TimeGMT();
   if(now<=0) now=TimeLocal();
   if(!TimeToStruct(now,t)) return "unknown";
   return StringFormat("%04d%02d%02d-%02d%02d%02d",t.year,t.mon,t.day,t.hour,t.min,t.sec);
}

void WriteHeader(int h)
{
   FileWrite(h,
      "captured_gmt","terminal_build","account_login","account_server","broker_company","account_currency",
      "account_trade_mode","account_margin_mode","leverage","symbol","status","error",
      "digits","point","bid","ask","tick_size","tick_value","tick_value_profit","tick_value_loss",
      "contract_size","volume_min","volume_max","volume_step","stops_level","freeze_level","symbol_trade_mode",
      "swap_long","swap_short");
}

void WriteSymbol(int h,string symbol)
{
   StringTrimLeft(symbol);StringTrimRight(symbol);
   string status="OK",error="";
   if(symbol==""){status="ERROR";error="empty symbol";}
   else if(!SymbolSelect(symbol,true)){status="ERROR";error="SymbolSelect failed";}

   MqlTick tick;ZeroMemory(tick);
   if(status=="OK" && !SymbolInfoTick(symbol,tick)){status="ERROR";error="SymbolInfoTick failed";}

   double point=0,tick_size=0,tick_value=0,tick_value_profit=0,tick_value_loss=0,contract_size=0;
   double volume_min=0,volume_max=0,volume_step=0,swap_long=0,swap_short=0;
   long digits=0,stops_level=0,freeze_level=0,trade_mode=0;
   if(status=="OK")
   {
      point=SymbolInfoDouble(symbol,SYMBOL_POINT);
      digits=SymbolInfoInteger(symbol,SYMBOL_DIGITS);
      tick_size=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
      tick_value=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE);
      tick_value_profit=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE_PROFIT);
      tick_value_loss=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE_LOSS);
      contract_size=SymbolInfoDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE);
      volume_min=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
      volume_max=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
      volume_step=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);
      stops_level=SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL);
      freeze_level=SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL);
      trade_mode=SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE);
      swap_long=SymbolInfoDouble(symbol,SYMBOL_SWAP_LONG);
      swap_short=SymbolInfoDouble(symbol,SYMBOL_SWAP_SHORT);
      if(point<=0 || tick_size<=0 || volume_min<=0 || volume_step<=0 || volume_max<volume_min)
      {status="ERROR";error="invalid broker economics";}
   }

   FileWrite(h,
      TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS),
      TerminalInfoInteger(TERMINAL_BUILD),
      AccountInfoInteger(ACCOUNT_LOGIN),
      AccountInfoString(ACCOUNT_SERVER),
      AccountInfoString(ACCOUNT_COMPANY),
      AccountInfoString(ACCOUNT_CURRENCY),
      AccountInfoInteger(ACCOUNT_TRADE_MODE),
      AccountInfoInteger(ACCOUNT_MARGIN_MODE),
      AccountInfoInteger(ACCOUNT_LEVERAGE),
      symbol,status,error,digits,point,tick.bid,tick.ask,tick_size,tick_value,tick_value_profit,tick_value_loss,
      contract_size,volume_min,volume_max,volume_step,stops_level,freeze_level,trade_mode,swap_long,swap_short);
   PrintFormat("AURUM|BROKER_PROBE|symbol=%s|status=%s|error=%s",symbol,status,error);
}

void OnStart()
{
   string source=SymbolsCSV;
   if(source=="") source=_Symbol;
   string symbols[];
   ushort comma=(ushort)StringGetCharacter(",",0);
   int count=StringSplit(source,comma,symbols);
   if(count<=0){Print("AURUM|BROKER_PROBE|ERROR|no symbols");SetUserError(9101);return;}

   ResetLastError();
   FolderCreate("AurumQuant");
   string path="AurumQuant\\BrokerProbe-"+Stamp()+".csv";
   int h=FileOpen(path,FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(h==INVALID_HANDLE){PrintFormat("AURUM|BROKER_PROBE|ERROR|FileOpen=%d",GetLastError());SetUserError(9103);return;}
   WriteHeader(h);
   for(int i=0;i<count;i++) WriteSymbol(h,symbols[i]);
   FileFlush(h);FileClose(h);
   Print("AURUM|BROKER_PROBE|OUTPUT|MQL5\\Files\\",path);
}
