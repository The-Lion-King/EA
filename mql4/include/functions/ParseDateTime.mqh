/**
 * Parse the string representation of a date or time and return an array with the numeric representations. Missing date/time
 * parts are returned as 0 (zero),
 *
 * @param  _In_  string value    - string to parse
 * @param  _In_  int    flags    - accepted date/time formats, default: DATE_YYYYMMDD | DATE_DDMMYYYY | DATE_OPTIONAL | TIME_OPTIONAL
 * @param  _Out_ int    result[] - array receiving the parsed elements
 *
 * @return bool - success status
 *
 * � Supported date separators are ".", "/" and "-".
 *
 * � Supported date/time formats:
 *   "1980.07.19 12:30:27"          // full YYYY-MM-DD format, requires flag DATE_YYYYMMDD
 *   "19.07.1980 12:30:27"          // full DD-MM-YYYY format, requires flag DATE_DDMMYYYY
 *   "01.02.2004"                   // optional time part, requires flag TIME_OPTIONAL
 *   "1.2.2004"                     // zero-padding of month and day
 *   "12:30:27"                     // optional date part, requires flag DATE_OPTIONAL
 *   "12:30"                        // time part with optional seconds
 *
 * � Content of the returned result[] array for datetime string "2006.12.24 10:45":
 *   int[] = {
 *      PT_YEAR     => 2006,
 *      PT_MONTH    => 12,          // January = 1
 *      PT_DAY      => 24,
 *      PT_HOUR     => 10,
 *      PT_MINUTE   => 45,
 *      PT_SECOND   => 0,
 *      PT_HAS_DATE => 1,           // whether the passed string contains a date part
 *      PT_HAS_TIME => 1,           // whether the passed string contains a time part
 *      PT_ERROR    => string*      // pointer to error message (if any) or NULL
 *   }
 */
bool ParseDateTime(string value, int flags, int &result[]) {
   if (ArraySize(result) != PT_ERROR+1) ArrayResize(result, PT_ERROR+1);
   ArrayInitialize(result, 0);

   value = StrTrim(value);
   if (value == "") return(ParseDateTime.Error("ParseDateTime(1)  invalid date/time value (empty)", result));

   if (!flags) flags = DATE_YYYYMMDD | DATE_DDMMYYYY | DATE_OPTIONAL | TIME_OPTIONAL;
   bool isDATE_OPTIONAL = (flags & DATE_OPTIONAL == DATE_OPTIONAL);
   bool isTIME_OPTIONAL = (flags & TIME_OPTIONAL == TIME_OPTIONAL);
   bool isDATE_YYYYMMDD = (flags & DATE_YYYYMMDD == DATE_YYYYMMDD);
   bool isDATE_DDMMYYYY = (flags & DATE_DDMMYYYY == DATE_DDMMYYYY);

   string sValueOrig=value, sDate="", sTime="", sYYYY="", sMM="", sDD="", exprs[]={""};
   int iYYYY, iMM, iDD, iHH, iII, iSS;

   // split into date and time values
   int size = Explode(value, " ", exprs, NULL);
   if (size > 2)    return(ParseDateTime.Error("ParseDateTime(2)  invalid number of space chars in \""+ value +"\"", result));

   // check existing and optional parts
   if (!isDATE_OPTIONAL && !isTIME_OPTIONAL) {           // no optional parts, requires a full date/time
      if (size < 2) return(ParseDateTime.Error("ParseDateTime(3)  "+ ifString(StrContains(exprs[0], ":"), "missing date part", "missing time part") +" in \""+ sValueOrig +"\"", result));
      sDate = exprs[0];
      sTime = exprs[1];
   }
   else {                                                // optional parts
      if (size == 2) {
         sDate = exprs[0];
         sTime = exprs[1];
      }
      else if (!isDATE_OPTIONAL) {                       // requires a date
         sDate = exprs[0];
      }
      else if (!isTIME_OPTIONAL) {                       // requires a time
         sTime = exprs[0];
      }
      else if (StrContains(exprs[0], ":")) {             // a single element and both parts are optional
         sTime = exprs[0];                               // must be a time
      }
      else {
         sDate = exprs[0];                               // must be a date
      }
   }

   // parse a date value: yyyy-mm-dd | dd-mm-yyyy
   if (sDate != "") {
      if (!isDATE_YYYYMMDD && !isDATE_DDMMYYYY)               return(ParseDateTime.Error("ParseDateTime(4)  invalid flags (missing date format specifier)", result));
      string separator = "";
      if      (StrContains(sDate, ".")) separator = ".";
      else if (StrContains(sDate, "-")) separator = "-";
      else if (StrContains(sDate, "/")) separator = "/";
      else                                                    return(ParseDateTime.Error("ParseDateTime(5)  invalid date \""+ sDate +"\" in \""+ sValueOrig +"\"", result));
      if (Explode(sDate, separator, exprs, NULL) != 3)        return(ParseDateTime.Error("ParseDateTime(6)  invalid date \""+ sDate +"\" in \""+ sValueOrig +"\"", result));

      if (isDATE_YYYYMMDD && StringLen(exprs[0])==4 && StringLen(exprs[1])<=2 && StringLen(exprs[2])<=2) {
         sYYYY = exprs[0];
         sMM   = exprs[1];
         sDD   = exprs[2];
      }
      if (isDATE_DDMMYYYY && StringLen(exprs[0])<=2 && StringLen(exprs[1])<=2 && StringLen(exprs[2])==4) {
         sDD   = exprs[0];
         sMM   = exprs[1];
         sYYYY = exprs[2];
      }
      if (sYYYY == "")                                        return(ParseDateTime.Error("ParseDateTime(7)  invalid date \""+ sDate +"\" in \""+ sValueOrig +"\"", result));

      // year
      if (!StrIsDigits(sYYYY))                                return(ParseDateTime.Error("ParseDateTime(8)  invalid year \""+ sYYYY +"\" in \""+ sValueOrig +"\"", result));
      iYYYY = StrToInteger(sYYYY);
      if (iYYYY < 1970 || iYYYY > 2037)                       return(ParseDateTime.Error("ParseDateTime(9)  invalid year \""+ sYYYY +"\" in \""+ sValueOrig +"\" (not between 1970-2037)", result));

      // month
      if (StringLen(sMM) > 2 || !StrIsDigits(sMM))            return(ParseDateTime.Error("ParseDateTime(10)  invalid month \""+ sMM +"\" in \""+ sValueOrig +"\"", result));
      iMM = StrToInteger(sMM);
      if (iMM < 1 || iMM > 12)                                return(ParseDateTime.Error("ParseDateTime(11)  invalid month \""+ sMM +"\" in \""+ sValueOrig +"\" (not between 1-12)", result));

      // day
      if (StringLen(sDD) > 2 || !StrIsDigits(sDD))            return(ParseDateTime.Error("ParseDateTime(12)  invalid day \""+ sDD +"\" in \""+ sValueOrig +"\"", result));
      iDD = StrToInteger(sDD);
      if (iDD < 1 || iDD > 31)                                return(ParseDateTime.Error("ParseDateTime(13)  invalid day \""+ sDD +"\" in \""+ sValueOrig +"\" (not between 1-31)", result));
      if (iDD > 28) {
         if (iMM == FEB) {
            if (iDD > 29)                                     return(ParseDateTime.Error("ParseDateTime(14)  invalid day \""+ sDD +"."+ sMM +".\" in \""+ sValueOrig +"\"", result));
            if (!IsLeapYear(iYYYY))                           return(ParseDateTime.Error("ParseDateTime(15)  invalid day \""+ sDD +"."+ sMM +"."+ sYYYY +"\" in \""+ sValueOrig +"\" (not a leap year)", result));
         }
         else if (iDD == 31) {
            if (iMM==APR || iMM==JUN || iMM==SEP || iMM==NOV) return(ParseDateTime.Error("ParseDateTime(16)  invalid day \""+ sDD +"."+ sMM +".\" in \""+ sValueOrig +"\"", result));
         }
      }
   }

   // parse a time value: hh:ii[:ss]
   if (sTime != "") {
      size = Explode(sTime, ":", exprs, NULL);
      if (size < 2 || size > 3)                               return(ParseDateTime.Error("ParseDateTime(17)  invalid time \""+ sTime +"\" in \""+ sValueOrig +"\"", result));

      // hour
      string sHH = exprs[0];
      if (StringLen(sHH)!=2 || !StrIsDigits(sHH))             return(ParseDateTime.Error("ParseDateTime(18)  invalid hour \""+ sHH +"\" in \""+ sValueOrig +"\"", result));
      iHH = StrToInteger(sHH);
      if (iHH < 0 || iHH > 23)                                return(ParseDateTime.Error("ParseDateTime(19)  invalid hour \""+ sHH +"\" in \""+ sValueOrig +"\" (not between 00-23)", result));

      // minutes
      string sII = exprs[1];
      if (StringLen(sII)!=2 || !StrIsDigits(sII))             return(ParseDateTime.Error("ParseDateTime(20)  invalid minutes \""+ sII +"\" in \""+ sValueOrig +"\"", result));
      iII = StrToInteger(sII);
      if (iII < 0 || iII > 59)                                return(ParseDateTime.Error("ParseDateTime(21)  invalid minutes \""+ sII +"\" in \""+ sValueOrig +"\" (not between 00-59)", result));

      // optional seconds
      if (size == 3) {
         string sSS = exprs[2];
         if (StringLen(sSS)!=2 || !StrIsDigits(sSS))          return(ParseDateTime.Error("ParseDateTime(22)  invalid seconds \""+ sSS +"\" in \""+ sValueOrig +"\"", result));
         iSS = StrToInteger(sSS);
         if (iSS < 0 || iSS > 59)                             return(ParseDateTime.Error("ParseDateTime(23)  invalid seconds \""+ sSS +"\" in \""+ sValueOrig +"\" (not between 00-59)", result));
      }
   }

   result[PT_YEAR    ] = iYYYY;
   result[PT_MONTH   ] = iMM;
   result[PT_DAY     ] = iDD;
   result[PT_HAS_DATE] = (sDate != "");
   result[PT_HOUR    ] = iHH;
   result[PT_MINUTE  ] = iII;
   result[PT_SECOND  ] = iSS;
   result[PT_HAS_TIME] = (sTime != "");
   result[PT_ERROR   ] = NULL;
   return(true);
}


/**
 * Process a ParseDateTime() error.
 *
 * @param  _In_  string msg      - error message
 * @param  _Out_ int    result[] - array to be returned by the ParseDateTime() call
 *
 * @return bool - success status of the ParseDateTime() call
 */
bool ParseDateTime.Error(string msg, int &result[]) {
   if (IsLogDebug()) debug(msg);

   if (StrStartsWith(msg, "ParseDateTime(")) {
      msg = StrTrimLeft(StrRightFrom(msg, ")"));
   }

   string array[1];
   array[0] = msg;

   result[PT_ERROR] = GetStringAddress(array[0]);
   return(false);
}
