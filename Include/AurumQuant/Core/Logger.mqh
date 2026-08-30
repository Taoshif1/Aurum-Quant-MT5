#ifndef AURUM_LOGGER_MQH
#define AURUM_LOGGER_MQH
class AQLogger
{
private:
   string m_prefix;
public:
   AQLogger(void):m_prefix("AURUM") {}
   void Init(string symbol, ulong magic) { m_prefix=StringFormat("AURUM|%s|%I64u",symbol,magic); Event("INIT","logger initialized"); }
   void Event(string type,string message) { PrintFormat("%s|%s|%s",m_prefix,type,message); }
   void Error(string message) { PrintFormat("%s|CRITICAL|err=%d|%s",m_prefix,GetLastError(),message); }
};
#endif

