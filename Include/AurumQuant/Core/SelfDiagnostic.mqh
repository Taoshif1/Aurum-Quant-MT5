#ifndef AURUM_SELF_DIAGNOSTIC_MQH
#define AURUM_SELF_DIAGNOSTIC_MQH
class AQSelfDiagnostic
{
private: bool m_ready; string m_reasons;
public:
   AQSelfDiagnostic(void):m_ready(true),m_reasons("") {}
   void Reset() { m_ready=true;m_reasons=""; }
   void Check(bool condition,string reason) { if(condition) return; m_ready=false;if(m_reasons!="")m_reasons+="; ";m_reasons+=reason; }
   bool Ready() const { return m_ready; }
   string Reasons() const { return m_reasons; }
};
#endif

