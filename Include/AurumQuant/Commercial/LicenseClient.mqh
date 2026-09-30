#ifndef AURUM_LICENSE_CLIENT_MQH
#define AURUM_LICENSE_CLIENT_MQH
#include <AurumQuant/Commercial/LicensePolicy.mqh>

class AQLicenseClient
{
private:
   bool m_required,m_ready;
   string m_endpoint,m_key,m_fingerprint,m_reason,m_version;
   int m_timeout_ms,m_recheck_minutes;
   datetime m_expires,m_last_check,m_next_check;
   ENUM_AQ_LICENSE_STATE m_state;

   bool StartsWith(string value,string prefix)
   { return StringLen(value)>=StringLen(prefix) && StringSubstr(value,0,StringLen(prefix))==prefix; }

   bool KeySafe(string value)
   {
      int n=StringLen(value);
      if(n<8 || n>128)return false;
      for(int i=0;i<n;i++)
      {
         ushort c=(ushort)StringGetCharacter(value,i);
         bool ok=(c>='0' && c<='9') || (c>='A' && c<='Z') || (c>='a' && c<='z') || c=='-' || c=='_';
         if(!ok)return false;
      }
      return true;
   }

   string Hex(uchar &bytes[])
   {
      string out="";
      for(int i=0;i<ArraySize(bytes);i++)out+=StringFormat("%02x",bytes[i]);
      return out;
   }

   bool BuildFingerprint(string &reason)
   {
      string source=StringFormat("%I64d|%s|%s",
         AccountInfoInteger(ACCOUNT_LOGIN),AccountInfoString(ACCOUNT_SERVER),TerminalInfoString(TERMINAL_NAME));
      uchar data[],empty[],digest[];
      int copied=StringToCharArray(source,data,0,StringLen(source),CP_UTF8);
      if(copied<=0){reason="cannot encode license fingerprint";return false;}
      if(CryptEncode(CRYPT_HASH_SHA256,data,empty,digest)<=0 || ArraySize(digest)!=32)
      {reason="cannot hash license fingerprint";return false;}
      m_fingerprint=Hex(digest);
      if(StringLen(m_fingerprint)!=64){reason="invalid license fingerprint";return false;}
      reason="OK";return true;
   }

   bool ParseResponse(string body,datetime now,string &reason)
   {
      StringTrimLeft(body);StringTrimRight(body);
      string parts[];
      ushort sep=(ushort)StringGetCharacter("|",0);
      int count=StringSplit(body,sep,parts);
      if(count<2 || parts[0]!="AURUM_LICENSE"){m_state=LICENSE_INVALID;reason="license response malformed";return false;}
      string status="",expires_raw="";
      for(int i=1;i<count;i++)
      {
         int equals=StringFind(parts[i],"=");
         if(equals<=0)continue;
         string key=StringSubstr(parts[i],0,equals);
         string value=StringSubstr(parts[i],equals+1);
         if(key=="status")status=value;
         else if(key=="expires")expires_raw=value;
      }
      if(status=="VALID")
      {
         if(expires_raw==""){m_state=LICENSE_INVALID;reason="license expiry missing";return false;}
         long raw=StringToInteger(expires_raw);
         if(raw<0){m_state=LICENSE_INVALID;reason="license expiry invalid";return false;}
         m_expires=(datetime)raw;
         if(m_expires>0 && (now<=0 || now>=m_expires)){m_state=LICENSE_EXPIRED;reason="license expired";return false;}
         m_state=LICENSE_VALID;reason="license valid";return true;
      }
      if(status=="EXPIRED"){m_state=LICENSE_EXPIRED;reason="license expired";return false;}
      if(status=="INVALID" || status=="REVOKED"){m_state=LICENSE_INVALID;reason="license invalid or revoked";return false;}
      m_state=LICENSE_INVALID;reason="unknown license status";return false;
   }

   string ResponseString(char &result[])
   {
      int n=ArraySize(result);
      if(n<=0)return "";
      uchar bytes[];ArrayResize(bytes,n);
      for(int i=0;i<n;i++)bytes[i]=(uchar)result[i];
      return CharArrayToString(bytes,0,n,CP_UTF8);
   }

public:
   AQLicenseClient(void):m_required(false),m_ready(false),m_endpoint(""),m_key(""),m_fingerprint(""),m_reason(""),m_version(""),
      m_timeout_ms(3000),m_recheck_minutes(60),m_expires(0),m_last_check(0),m_next_check(0),m_state(LICENSE_NOT_REQUIRED) {}

   bool Init(bool required,string endpoint,string license_key,int timeout_ms,int recheck_minutes,string product_version,string &reason)
   {
      m_required=required;m_endpoint=endpoint;m_key=license_key;m_timeout_ms=timeout_ms;m_recheck_minutes=recheck_minutes;m_version=product_version;
      m_expires=0;m_last_check=0;m_next_check=0;m_fingerprint="";m_ready=false;
      if(!required){m_state=LICENSE_NOT_REQUIRED;m_ready=true;m_reason="license not required";reason=m_reason;return true;}
      if(!StartsWith(endpoint,"https://")){m_state=LICENSE_CONFIG_ERROR;m_reason="license endpoint must use https://";reason=m_reason;return false;}
      if(!KeySafe(license_key)){m_state=LICENSE_CONFIG_ERROR;m_reason="license key format invalid";reason=m_reason;return false;}
      if(product_version=="" || timeout_ms<250 || timeout_ms>10000 || recheck_minutes<1 || recheck_minutes>1440)
      {m_state=LICENSE_CONFIG_ERROR;m_reason="license timing configuration invalid";reason=m_reason;return false;}
      if(!BuildFingerprint(reason)){m_state=LICENSE_CONFIG_ERROR;m_reason=reason;return false;}
      m_state=LICENSE_UNCHECKED;m_ready=true;m_reason="license not checked yet";reason=m_reason;return true;
   }

   bool CheckNow(string &reason)
   {
      if(!m_required){m_state=LICENSE_NOT_REQUIRED;m_reason="license not required";reason=m_reason;return true;}
      if(!m_ready){reason=m_reason;return false;}
      datetime now=TimeTradeServer();if(now<=0)now=TimeCurrent();
      m_last_check=now;m_next_check=(now>0?now+m_recheck_minutes*60:0);
      if(MQLInfoInteger(MQL_TESTER))
      {
         m_state=LICENSE_UNAVAILABLE;m_reason="WebRequest unavailable in Strategy Tester";reason=m_reason;return false;
      }

      string body="license_key="+m_key+"&account_fingerprint="+m_fingerprint+"&version="+m_version;
      uchar encoded[];int copied=StringToCharArray(body,encoded,0,StringLen(body),CP_UTF8);
      if(copied<=0){m_state=LICENSE_UNAVAILABLE;m_reason="license request encoding failed";reason=m_reason;return false;}
      char data[];ArrayResize(data,copied);
      for(int i=0;i<copied;i++)data[i]=(char)encoded[i];

      char result[];string result_headers;
      string headers="Content-Type: application/x-www-form-urlencoded\r\nAccept: text/plain\r\n";
      ResetLastError();
      int http=WebRequest("POST",m_endpoint,headers,m_timeout_ms,data,result,result_headers);
      if(http==-1)
      {
         m_state=LICENSE_UNAVAILABLE;m_reason=StringFormat("license request unavailable (MT5 error %d)",GetLastError());reason=m_reason;return false;
      }
      string response=ResponseString(result);
      if(http==401 || http==403){m_state=LICENSE_INVALID;m_reason="license rejected";reason=m_reason;return false;}
      if(http==410){m_state=LICENSE_EXPIRED;m_reason="license expired";reason=m_reason;return false;}
      if(http!=200){m_state=LICENSE_UNAVAILABLE;m_reason=StringFormat("license service HTTP %d",http);reason=m_reason;return false;}
      bool ok=ParseResponse(response,now,reason);m_reason=reason;return ok;
   }

   bool RefreshIfDue(string &reason)
   {
      if(!m_required){reason="license not required";return true;}
      datetime now=TimeTradeServer();if(now<=0)now=TimeCurrent();
      if(m_state==LICENSE_UNCHECKED || m_next_check==0 || (now>0 && now>=m_next_check))return CheckNow(reason);
      reason=m_reason;return m_state==LICENSE_VALID;
   }

   bool AllowsNewEntries(ENUM_AQ_MODE mode,string &reason)
   {
      datetime now=TimeTradeServer();if(now<=0)now=TimeCurrent();
      return AQLicensePolicy::AllowsNewEntries(m_required,mode,m_state,now,m_expires,reason);
   }

   string Status(void)
   {
      string suffix=(m_expires>0?StringFormat(" until %s",TimeToString(m_expires,TIME_DATE|TIME_MINUTES)):"");
      return AQLicenseStateName(m_state)+suffix;
   }
   ENUM_AQ_LICENSE_STATE State(void) const {return m_state;}
   string Fingerprint(void) const {return m_fingerprint;}
};
#endif
