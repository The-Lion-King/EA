/**
 * SendTestMail
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <core/script.mqh>
#include <stdfunctions.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   string section = "Mail";
   string key     = "Sender";
   string sender  = GetConfigString(section, key);
   if (!StrIsEmailAddress(sender))   return(!catch("onStart(1)  invalid email address: ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(sender), ERR_INVALID_CONFIG_VALUE));

   key = "Receiver";
   string receiver = GetConfigString(section, key);
   if (!StrIsEmailAddress(receiver)) return(!catch("onStart(2)  invalid email address: ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(receiver), ERR_INVALID_CONFIG_VALUE));

   string message = "Test email "+ TimeToStr(GetLocalTime(), TIME_MINUTES);
   SendEmail(sender, receiver, message, message);

   return(catch("onStart(3)"));
}
