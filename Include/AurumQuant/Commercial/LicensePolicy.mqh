#ifndef AURUM_LICENSE_POLICY_MQH
#define AURUM_LICENSE_POLICY_MQH
#include <AurumQuant/Core/Config.mqh>

enum ENUM_AQ_LICENSE_STATE
{
   LICENSE_NOT_REQUIRED=0,
   LICENSE_UNCHECKED=1,
   LICENSE_VALID=2,
   LICENSE_INVALID=3,
   LICENSE_EXPIRED=4,
   LICENSE_UNAVAILABLE=5,
   LICENSE_CONFIG_ERROR=6
};

string AQLicenseStateName(ENUM_AQ_LICENSE_STATE state)
{
   switch(state)
   {
      case LICENSE_NOT_REQUIRED:return "NOT_REQUIRED";
      case LICENSE_UNCHECKED:return "UNCHECKED";
      case LICENSE_VALID:return "VALID";
      case LICENSE_INVALID:return "INVALID";
      case LICENSE_EXPIRED:return "EXPIRED";
      case LICENSE_UNAVAILABLE:return "UNAVAILABLE";
      case LICENSE_CONFIG_ERROR:return "CONFIG_ERROR";
   }
   return "UNKNOWN";
}

class AQLicensePolicy
{
public:
   static bool AllowsNewEntries(bool required,ENUM_AQ_MODE mode,ENUM_AQ_LICENSE_STATE state,
                                datetime now,datetime expires,string &reason)
   {
      if(!required){reason="license not required";return true;}
      if(mode==MODE_OBSERVE){reason="OBSERVE does not require commercial activation";return true;}
      if(state==LICENSE_VALID)
      {
         if(now<=0){reason="license clock unavailable";return false;}
         if(expires>0 && now>=expires){reason="license expired";return false;}
         reason="license valid";return true;
      }
      if(state==LICENSE_EXPIRED){reason="license expired";return false;}
      if(state==LICENSE_INVALID){reason="license invalid or revoked";return false;}
      if(state==LICENSE_CONFIG_ERROR){reason="license configuration invalid";return false;}
      if(state==LICENSE_UNAVAILABLE){reason="license service unavailable";return false;}
      reason="license not checked yet";return false;
   }
};
#endif
