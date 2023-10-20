/**
 * Umschaltzeiten von Normal- zu Sommerzeit und zur�ck von 1970 bis 2037.
 *
 *
 * Um die Ermittlung eines Timezone-Offsets f�r einen Zeitpunkt zu beschleunigen, sind f�r Jahre, in denen kein Wechsel
 * stattfindet, Platzhalter angegeben, wodurch die Arrayindizes aller Jahre in allen Zeitzonen identisch sind:
 *
 *    int index = TimeYear(datetime) - 1970;
 *
 *
 * Logik:
 * ------
 *  if      (datetime < TR_TO_DST) offset = STD_OFFSET;     // Normalzeit zu Jahresbeginn
 *  else if (datetime < TR_TO_STD) offset = DST_OFFSET;     // Sommerzeit
 *  else                           offset = STD_OFFSET;     // Normalzeit zu Jahresende
 *
 *
 * Szenarien:                           Wechsel zu Sommerzeit (TR_TO_DST)       Wechsel zu Normalzeit (TR_TO_STD)
 * ----------                           ----------------------------------      ----------------------------------
 *  kein Wechsel, st�ndig Normalzeit:   -1                      DST_OFFSET      -1                      STD_OFFSET      // durchgehend Normalzeit
 *  kein Wechsel, st�ndig DST:          -1                      DST_OFFSET      INT_MAX                 STD_OFFSET      // durchgehend Sommerzeit
 *  1 Wechsel zu Sommerzeit:            1975.04.11 00:00:00     DST_OFFSET      INT_MAX                 STD_OFFSET      // Jahr beginnt mit Normalzeit und endet mit Sommerzeit
 *  1 Wechsel zu Normalzeit:            -1                      DST_OFFSET      1975.11.01 00:00:00     STD_OFFSET      // Jahr beginnt mit Sommerzeit und endet mit Normalzeit
 *  2 Wechsel:                          1975.04.01 00:00:00     DST_OFFSET      1975.11.01 00:00:00     STD_OFFSET      // Normalzeit -> Sommerzeit -> Normalzeit
 *
 *
 * Notes:
 *  @see  https://www.appsloveworld.com/cplus/100/28/are-windows-timezone-written-in-registry-reliable#                            [Dynamic timezones explained]
 *  @see  https://www.anycodings.com/questions/windows-timezone-transition-information#                                               [Historic transition data]
 *  @see  https://www.ais.com/beware-daylight-saving-time-transitions-in-dot-net/
 *  @see  http://winapi.freetechsecrets.com/win32/WIN32System_Time00002387.htm
 *  @see  https://itecnote.com/tecnote/how-to-convert-gmt-to-localtime-in-win32-c/
 *  @see  http://web.archive.org/web/20080605162533/http://www.eggheadcafe.com/software/aspnet/31656478/get-current-time-in-diffe.aspx
 *  @see  https://zetcode.com/gui/winapi/datetime/
 *
 *  @see  https://www.codeguru.com/cplusplus/a-time-zone-api-supplement/
 *  @see  https://forums.codeguru.com/showthread.php?479121-How-can-I-check-if-DST-was-in-effect-for-a-given-time
 *
 *  @see  https://www.codeproject.com/Questions/66570/How-to-use-SystemTimeToTzSpecificLocalTime
 *  @see  https://www.codeproject.com/Articles/144159/Time-Format-Conversion-Made-Easy
 *
 *  @see  https://stackoverflow.com/questions/466071/how-do-i-get-a-specific-time-zone-information-struct-in-win32
 *  @see  https://stackoverflow.com/questions/597554/how-to-convert-between-timezones-with-win32-api
 *  @see  https://stackoverflow.com/questions/3623471/how-do-you-get-info-for-an-arbitrary-time-zone-in-windows
 *  @see  https://stackoverflow.com/questions/66615978/how-to-get-a-datetimes-offset-from-utc#                                           [Conversion test cases]
 *
 *  @see  https://docs.microsoft.com/en-us/windows/win32/api/timezoneapi/nf-timezoneapi-gettimezoneinformation#                       [GetTimeZoneInformation()]
 *  @see  https://docs.microsoft.com/en-us/windows/win32/api/timezoneapi/nf-timezoneapi-gettimezoneinformationforyear#         [GetTimeZoneInformationForYear()]
 *  @see  https://docs.microsoft.com/en-us/windows/win32/api/timezoneapi/ns-timezoneapi-dynamic_time_zone_information#    [struct DYNAMIC_TIME_ZONE_INFORMATION]
 *  @see  https://docs.microsoft.com/en-us/windows/win32/api/timezoneapi/nf-timezoneapi-tzspecificlocaltimetosystemtime
 *  @see  https://docs.microsoft.com/en-us/windows/win32/api/timezoneapi/nf-timezoneapi-tzspecificlocaltimetosystemtimeex
 *  @see  https://docs.microsoft.com/en-us/windows/win32/api/timezoneapi/nf-timezoneapi-systemtimetotzspecificlocaltime
 *  @see  https://social.msdn.microsoft.com/Forums/windowsapps/en-US/ef486e53-a27b-4dc9-8b5b-b56abdbb8723/how-to-get-a-different-timezone-from-gettimezoneinformationforyear?forum=vclanguage
 */


// Timezone-Offsets in Sekunden
#define PLUS_13h        46800
#define PLUS_12h30      45000
#define PLUS_12h        43200
#define PLUS_11h30      41400
#define PLUS_11h        39600
#define PLUS_10h30      37800
#define PLUS_10h        36000
#define PLUS_9h30       34200
#define PLUS_9h         32400
#define PLUS_8h30       30600
#define PLUS_8h         28800
#define PLUS_7h30       27000
#define PLUS_7h         25200
#define PLUS_6h30       23400
#define PLUS_6h         21600
#define PLUS_5h30       19800
#define PLUS_5h         18000
#define PLUS_4h30       16200
#define PLUS_4h         14400
#define PLUS_3h30       12600
#define PLUS_3h         10800
#define PLUS_2h30        9000
#define PLUS_2h          7200
#define PLUS_1h30        5400
#define PLUS_1h          3600
#define PLUS_0h30        1800
#define ZERO                0
#define MINUS_0h30      -1800
#define MINUS_1h        -3600
#define MINUS_1h30      -5400
#define MINUS_2h        -7200
#define MINUS_2h30      -9000
#define MINUS_3h       -10800
#define MINUS_3h30     -12600
#define MINUS_4h       -14400
#define MINUS_4h30     -16200
#define MINUS_5h       -18000
#define MINUS_5h30     -19800
#define MINUS_6h       -21600
#define MINUS_6h30     -23400
#define MINUS_7h       -25200
#define MINUS_7h30     -27000
#define MINUS_8h       -28800
#define MINUS_8h30     -30600
#define MINUS_9h       -32400
#define MINUS_9h30     -34200
#define MINUS_10h      -36000
#define MINUS_10h30    -37800
#define MINUS_11h      -39600
#define MINUS_11h30    -41400
#define MINUS_12h      -43200


// Spaltenindizes der Transition-Arrays
#define TR_TO_DST.gmt       0       // Wechsel zu Sommerzeit in GMT
#define TR_TO_DST.local     1       // Zeit nach der Umstellung in lokaler Zeit
#define DST_OFFSET          2
#define TR_TO_STD.gmt       3       // Wechsel zu Normalzeit in GMT
#define TR_TO_STD.local     4       // Zeit nach der Umstellung in lokaler Zeit
#define STD_OFFSET          5


// Europe/Kiev: GMT+0200/+0300
int transitions.Europe_Kiev[68][6] = {
   // Wechsel zu DST                                               DST-Offset   // Wechsel zu Normalzeit                                        Std-Offset
           -1,                             -1,                     PLUS_3h,             -1,                             -1,                     PLUS_3h,    // durchgehend Normalzeit
           -1,                             -1,                     PLUS_3h,             -1,                             -1,                     PLUS_3h,
           -1,                             -1,                     PLUS_3h,             -1,                             -1,                     PLUS_3h,
           -1,                             -1,                     PLUS_3h,             -1,                             -1,                     PLUS_3h,
           -1,                             -1,                     PLUS_3h,             -1,                             -1,                     PLUS_3h,
           -1,                             -1,                     PLUS_3h,             -1,                             -1,                     PLUS_3h,
           -1,                             -1,                     PLUS_3h,             -1,                             -1,                     PLUS_3h,
           -1,                             -1,                     PLUS_3h,             -1,                             -1,                     PLUS_3h,
           -1,                             -1,                     PLUS_3h,             -1,                             -1,                     PLUS_3h,
           -1,                             -1,                     PLUS_3h,             -1,                             -1,                     PLUS_3h,
           -1,                             -1,                     PLUS_3h,             -1,                             -1,                     PLUS_3h,
   /*Tue*/ D'1981.03.31 21:00:00', /*Wed*/ D'1981.04.01 01:00:00', PLUS_4h,     /*Wed*/ D'1981.09.30 20:00:00', /*Wed*/ D'1981.09.30 23:00:00', PLUS_3h,    // Einf�hrung Sommerzeit
   /*Wed*/ D'1982.03.31 21:00:00', /*Thu*/ D'1982.04.01 01:00:00', PLUS_4h,     /*Thu*/ D'1982.09.30 20:00:00', /*Thu*/ D'1982.09.30 23:00:00', PLUS_3h,
   /*Thu*/ D'1983.03.31 21:00:00', /*Fri*/ D'1983.04.01 01:00:00', PLUS_4h,     /*Fri*/ D'1983.09.30 20:00:00', /*Fri*/ D'1983.09.30 23:00:00', PLUS_3h,
   /*Sat*/ D'1984.03.31 21:00:00', /*Sun*/ D'1984.04.01 01:00:00', PLUS_4h,     /*Sat*/ D'1984.09.29 23:00:00', /*Sun*/ D'1984.09.30 02:00:00', PLUS_3h,
   /*Sat*/ D'1985.03.30 23:00:00', /*Sun*/ D'1985.03.31 03:00:00', PLUS_4h,     /*Sat*/ D'1985.09.28 23:00:00', /*Sun*/ D'1985.09.29 02:00:00', PLUS_3h,
   /*Sat*/ D'1986.03.29 23:00:00', /*Sun*/ D'1986.03.30 03:00:00', PLUS_4h,     /*Sat*/ D'1986.09.27 23:00:00', /*Sun*/ D'1986.09.28 02:00:00', PLUS_3h,
   /*Sat*/ D'1987.03.28 23:00:00', /*Sun*/ D'1987.03.29 03:00:00', PLUS_4h,     /*Sat*/ D'1987.09.26 23:00:00', /*Sun*/ D'1987.09.27 02:00:00', PLUS_3h,
   /*Sat*/ D'1988.03.26 23:00:00', /*Sun*/ D'1988.03.27 03:00:00', PLUS_4h,     /*Sat*/ D'1988.09.24 23:00:00', /*Sun*/ D'1988.09.25 02:00:00', PLUS_3h,
   /*Sat*/ D'1989.03.25 23:00:00', /*Sun*/ D'1989.03.26 03:00:00', PLUS_4h,     /*Sat*/ D'1989.09.23 23:00:00', /*Sun*/ D'1989.09.24 02:00:00', PLUS_3h,
           -1,                             -1,                     PLUS_3h,     /*Sat*/ D'1990.06.30 23:00:00', /*Sun*/ D'1990.07.01 01:00:00', PLUS_2h,    // Offset�nderung der Zeitzone
           -1,                             -1,                     PLUS_2h,             -1,                             -1,                     PLUS_2h,    // durchgehend Normalzeit
   /*Sat*/ D'1992.03.28 22:00:00', /*Sun*/ D'1992.03.29 01:00:00', PLUS_3h,     /*Sat*/ D'1992.09.26 21:00:00', /*Sat*/ D'1992.09.26 23:00:00', PLUS_2h,
   /*Sat*/ D'1993.03.27 22:00:00', /*Sun*/ D'1993.03.28 01:00:00', PLUS_3h,     /*Sat*/ D'1993.09.25 21:00:00', /*Sat*/ D'1993.09.25 23:00:00', PLUS_2h,
   /*Sat*/ D'1994.03.26 22:00:00', /*Sun*/ D'1994.03.27 01:00:00', PLUS_3h,     /*Sat*/ D'1994.09.24 21:00:00', /*Sat*/ D'1994.09.24 23:00:00', PLUS_2h,
   /*Sun*/ D'1995.03.26 01:00:00', /*Sun*/ D'1995.03.26 04:00:00', PLUS_3h,     /*Sun*/ D'1995.09.24 01:00:00', /*Sun*/ D'1995.09.24 03:00:00', PLUS_2h,
   /*Sun*/ D'1996.03.31 01:00:00', /*Sun*/ D'1996.03.31 04:00:00', PLUS_3h,     /*Sun*/ D'1996.10.27 01:00:00', /*Sun*/ D'1996.10.27 03:00:00', PLUS_2h,
   /*Sun*/ D'1997.03.30 01:00:00', /*Sun*/ D'1997.03.30 04:00:00', PLUS_3h,     /*Sun*/ D'1997.10.26 01:00:00', /*Sun*/ D'1997.10.26 03:00:00', PLUS_2h,
   /*Sun*/ D'1998.03.29 01:00:00', /*Sun*/ D'1998.03.29 04:00:00', PLUS_3h,     /*Sun*/ D'1998.10.25 01:00:00', /*Sun*/ D'1998.10.25 03:00:00', PLUS_2h,
   /*Sun*/ D'1999.03.28 01:00:00', /*Sun*/ D'1999.03.28 04:00:00', PLUS_3h,     /*Sun*/ D'1999.10.31 01:00:00', /*Sun*/ D'1999.10.31 03:00:00', PLUS_2h,
   /*Sun*/ D'2000.03.26 01:00:00', /*Sun*/ D'2000.03.26 04:00:00', PLUS_3h,     /*Sun*/ D'2000.10.29 01:00:00', /*Sun*/ D'2000.10.29 03:00:00', PLUS_2h,
   /*Sun*/ D'2001.03.25 01:00:00', /*Sun*/ D'2001.03.25 04:00:00', PLUS_3h,     /*Sun*/ D'2001.10.28 01:00:00', /*Sun*/ D'2001.10.28 03:00:00', PLUS_2h,
   /*Sun*/ D'2002.03.31 01:00:00', /*Sun*/ D'2002.03.31 04:00:00', PLUS_3h,     /*Sun*/ D'2002.10.27 01:00:00', /*Sun*/ D'2002.10.27 03:00:00', PLUS_2h,
   /*Sun*/ D'2003.03.30 01:00:00', /*Sun*/ D'2003.03.30 04:00:00', PLUS_3h,     /*Sun*/ D'2003.10.26 01:00:00', /*Sun*/ D'2003.10.26 03:00:00', PLUS_2h,
   /*Sun*/ D'2004.03.28 01:00:00', /*Sun*/ D'2004.03.28 04:00:00', PLUS_3h,     /*Sun*/ D'2004.10.31 01:00:00', /*Sun*/ D'2004.10.31 03:00:00', PLUS_2h,
   /*Sun*/ D'2005.03.27 01:00:00', /*Sun*/ D'2005.03.27 04:00:00', PLUS_3h,     /*Sun*/ D'2005.10.30 01:00:00', /*Sun*/ D'2005.10.30 03:00:00', PLUS_2h,
   /*Sun*/ D'2006.03.26 01:00:00', /*Sun*/ D'2006.03.26 04:00:00', PLUS_3h,     /*Sun*/ D'2006.10.29 01:00:00', /*Sun*/ D'2006.10.29 03:00:00', PLUS_2h,
   /*Sun*/ D'2007.03.25 01:00:00', /*Sun*/ D'2007.03.25 04:00:00', PLUS_3h,     /*Sun*/ D'2007.10.28 01:00:00', /*Sun*/ D'2007.10.28 03:00:00', PLUS_2h,
   /*Sun*/ D'2008.03.30 01:00:00', /*Sun*/ D'2008.03.30 04:00:00', PLUS_3h,     /*Sun*/ D'2008.10.26 01:00:00', /*Sun*/ D'2008.10.26 03:00:00', PLUS_2h,
   /*Sun*/ D'2009.03.29 01:00:00', /*Sun*/ D'2009.03.29 04:00:00', PLUS_3h,     /*Sun*/ D'2009.10.25 01:00:00', /*Sun*/ D'2009.10.25 03:00:00', PLUS_2h,
   /*Sun*/ D'2010.03.28 01:00:00', /*Sun*/ D'2010.03.28 04:00:00', PLUS_3h,     /*Sun*/ D'2010.10.31 01:00:00', /*Sun*/ D'2010.10.31 03:00:00', PLUS_2h,
   /*Sun*/ D'2011.03.27 01:00:00', /*Sun*/ D'2011.03.27 04:00:00', PLUS_3h,     /*Sun*/ D'2011.10.30 01:00:00', /*Sun*/ D'2011.10.30 03:00:00', PLUS_2h,
   /*Sun*/ D'2012.03.25 01:00:00', /*Sun*/ D'2012.03.25 04:00:00', PLUS_3h,     /*Sun*/ D'2012.10.28 01:00:00', /*Sun*/ D'2012.10.28 03:00:00', PLUS_2h,
   /*Sun*/ D'2013.03.31 01:00:00', /*Sun*/ D'2013.03.31 04:00:00', PLUS_3h,     /*Sun*/ D'2013.10.27 01:00:00', /*Sun*/ D'2013.10.27 03:00:00', PLUS_2h,
   /*Sun*/ D'2014.03.30 01:00:00', /*Sun*/ D'2014.03.30 04:00:00', PLUS_3h,     /*Sun*/ D'2014.10.26 01:00:00', /*Sun*/ D'2014.10.26 03:00:00', PLUS_2h,
   /*Sun*/ D'2015.03.29 01:00:00', /*Sun*/ D'2015.03.29 04:00:00', PLUS_3h,     /*Sun*/ D'2015.10.25 01:00:00', /*Sun*/ D'2015.10.25 03:00:00', PLUS_2h,
   /*Sun*/ D'2016.03.27 01:00:00', /*Sun*/ D'2016.03.27 04:00:00', PLUS_3h,     /*Sun*/ D'2016.10.30 01:00:00', /*Sun*/ D'2016.10.30 03:00:00', PLUS_2h,
   /*Sun*/ D'2017.03.26 01:00:00', /*Sun*/ D'2017.03.26 04:00:00', PLUS_3h,     /*Sun*/ D'2017.10.29 01:00:00', /*Sun*/ D'2017.10.29 03:00:00', PLUS_2h,
   /*Sun*/ D'2018.03.25 01:00:00', /*Sun*/ D'2018.03.25 04:00:00', PLUS_3h,     /*Sun*/ D'2018.10.28 01:00:00', /*Sun*/ D'2018.10.28 03:00:00', PLUS_2h,
   /*Sun*/ D'2019.03.31 01:00:00', /*Sun*/ D'2019.03.31 04:00:00', PLUS_3h,     /*Sun*/ D'2019.10.27 01:00:00', /*Sun*/ D'2019.10.27 03:00:00', PLUS_2h,
   /*Sun*/ D'2020.03.29 01:00:00', /*Sun*/ D'2020.03.29 04:00:00', PLUS_3h,     /*Sun*/ D'2020.10.25 01:00:00', /*Sun*/ D'2020.10.25 03:00:00', PLUS_2h,
   /*Sun*/ D'2021.03.28 01:00:00', /*Sun*/ D'2021.03.28 04:00:00', PLUS_3h,     /*Sun*/ D'2021.10.31 01:00:00', /*Sun*/ D'2021.10.31 03:00:00', PLUS_2h,
   /*Sun*/ D'2022.03.27 01:00:00', /*Sun*/ D'2022.03.27 04:00:00', PLUS_3h,     /*Sun*/ D'2022.10.30 01:00:00', /*Sun*/ D'2022.10.30 03:00:00', PLUS_2h,
   /*Sun*/ D'2023.03.26 01:00:00', /*Sun*/ D'2023.03.26 04:00:00', PLUS_3h,     /*Sun*/ D'2023.10.29 01:00:00', /*Sun*/ D'2023.10.29 03:00:00', PLUS_2h,
   /*Sun*/ D'2024.03.31 01:00:00', /*Sun*/ D'2024.03.31 04:00:00', PLUS_3h,     /*Sun*/ D'2024.10.27 01:00:00', /*Sun*/ D'2024.10.27 03:00:00', PLUS_2h,
   /*Sun*/ D'2025.03.30 01:00:00', /*Sun*/ D'2025.03.30 04:00:00', PLUS_3h,     /*Sun*/ D'2025.10.26 01:00:00', /*Sun*/ D'2025.10.26 03:00:00', PLUS_2h,
   /*Sun*/ D'2026.03.29 01:00:00', /*Sun*/ D'2026.03.29 04:00:00', PLUS_3h,     /*Sun*/ D'2026.10.25 01:00:00', /*Sun*/ D'2026.10.25 03:00:00', PLUS_2h,
   /*Sun*/ D'2027.03.28 01:00:00', /*Sun*/ D'2027.03.28 04:00:00', PLUS_3h,     /*Sun*/ D'2027.10.31 01:00:00', /*Sun*/ D'2027.10.31 03:00:00', PLUS_2h,
   /*Sun*/ D'2028.03.26 01:00:00', /*Sun*/ D'2028.03.26 04:00:00', PLUS_3h,     /*Sun*/ D'2028.10.29 01:00:00', /*Sun*/ D'2028.10.29 03:00:00', PLUS_2h,
   /*Sun*/ D'2029.03.25 01:00:00', /*Sun*/ D'2029.03.25 04:00:00', PLUS_3h,     /*Sun*/ D'2029.10.28 01:00:00', /*Sun*/ D'2029.10.28 03:00:00', PLUS_2h,
   /*Sun*/ D'2030.03.31 01:00:00', /*Sun*/ D'2030.03.31 04:00:00', PLUS_3h,     /*Sun*/ D'2030.10.27 01:00:00', /*Sun*/ D'2030.10.27 03:00:00', PLUS_2h,
   /*Sun*/ D'2031.03.30 01:00:00', /*Sun*/ D'2031.03.30 04:00:00', PLUS_3h,     /*Sun*/ D'2031.10.26 01:00:00', /*Sun*/ D'2031.10.26 03:00:00', PLUS_2h,
   /*Sun*/ D'2032.03.28 01:00:00', /*Sun*/ D'2032.03.28 04:00:00', PLUS_3h,     /*Sun*/ D'2032.10.31 01:00:00', /*Sun*/ D'2032.10.31 03:00:00', PLUS_2h,
   /*Sun*/ D'2033.03.27 01:00:00', /*Sun*/ D'2033.03.27 04:00:00', PLUS_3h,     /*Sun*/ D'2033.10.30 01:00:00', /*Sun*/ D'2033.10.30 03:00:00', PLUS_2h,
   /*Sun*/ D'2034.03.26 01:00:00', /*Sun*/ D'2034.03.26 04:00:00', PLUS_3h,     /*Sun*/ D'2034.10.29 01:00:00', /*Sun*/ D'2034.10.29 03:00:00', PLUS_2h,
   /*Sun*/ D'2035.03.25 01:00:00', /*Sun*/ D'2035.03.25 04:00:00', PLUS_3h,     /*Sun*/ D'2035.10.28 01:00:00', /*Sun*/ D'2035.10.28 03:00:00', PLUS_2h,
   /*Sun*/ D'2036.03.30 01:00:00', /*Sun*/ D'2036.03.30 04:00:00', PLUS_3h,     /*Sun*/ D'2036.10.26 01:00:00', /*Sun*/ D'2036.10.26 03:00:00', PLUS_2h,
   /*Sun*/ D'2037.03.29 01:00:00', /*Sun*/ D'2037.03.29 04:00:00', PLUS_3h,     /*Sun*/ D'2037.10.25 01:00:00', /*Sun*/ D'2037.10.25 03:00:00', PLUS_2h,
};


// Europe/Minsk: GMT+0200/+0300 (seit Sommer 2011 durchgehend Sommerzeit)
int transitions.Europe_Minsk[68][6] = {
   // Wechsel zu DST                                               DST-Offset   // Wechsel zu Normalzeit                                        Std-Offset
           -1,                             -1,                     PLUS_3h,             -1,                             -1,                     PLUS_3h,    // durchgehend Normalzeit
           -1,                             -1,                     PLUS_3h,             -1,                             -1,                     PLUS_3h,
           -1,                             -1,                     PLUS_3h,             -1,                             -1,                     PLUS_3h,
           -1,                             -1,                     PLUS_3h,             -1,                             -1,                     PLUS_3h,
           -1,                             -1,                     PLUS_3h,             -1,                             -1,                     PLUS_3h,
           -1,                             -1,                     PLUS_3h,             -1,                             -1,                     PLUS_3h,
           -1,                             -1,                     PLUS_3h,             -1,                             -1,                     PLUS_3h,
           -1,                             -1,                     PLUS_3h,             -1,                             -1,                     PLUS_3h,
           -1,                             -1,                     PLUS_3h,             -1,                             -1,                     PLUS_3h,
           -1,                             -1,                     PLUS_3h,             -1,                             -1,                     PLUS_3h,
           -1,                             -1,                     PLUS_3h,             -1,                             -1,                     PLUS_3h,
   /*Tue*/ D'1981.03.31 21:00:00', /*Wed*/ D'1981.04.01 01:00:00', PLUS_4h,     /*Wed*/ D'1981.09.30 20:00:00', /*Wed*/ D'1981.09.30 23:00:00', PLUS_3h,    // Einf�hrung Sommerzeit
   /*Wed*/ D'1982.03.31 21:00:00', /*Thu*/ D'1982.04.01 01:00:00', PLUS_4h,     /*Thu*/ D'1982.09.30 20:00:00', /*Thu*/ D'1982.09.30 23:00:00', PLUS_3h,
   /*Thu*/ D'1983.03.31 21:00:00', /*Fri*/ D'1983.04.01 01:00:00', PLUS_4h,     /*Fri*/ D'1983.09.30 20:00:00', /*Fri*/ D'1983.09.30 23:00:00', PLUS_3h,
   /*Sat*/ D'1984.03.31 21:00:00', /*Sun*/ D'1984.04.01 01:00:00', PLUS_4h,     /*Sat*/ D'1984.09.29 23:00:00', /*Sun*/ D'1984.09.30 02:00:00', PLUS_3h,
   /*Sat*/ D'1985.03.30 23:00:00', /*Sun*/ D'1985.03.31 03:00:00', PLUS_4h,     /*Sat*/ D'1985.09.28 23:00:00', /*Sun*/ D'1985.09.29 02:00:00', PLUS_3h,
   /*Sat*/ D'1986.03.29 23:00:00', /*Sun*/ D'1986.03.30 03:00:00', PLUS_4h,     /*Sat*/ D'1986.09.27 23:00:00', /*Sun*/ D'1986.09.28 02:00:00', PLUS_3h,
   /*Sat*/ D'1987.03.28 23:00:00', /*Sun*/ D'1987.03.29 03:00:00', PLUS_4h,     /*Sat*/ D'1987.09.26 23:00:00', /*Sun*/ D'1987.09.27 02:00:00', PLUS_3h,
   /*Sat*/ D'1988.03.26 23:00:00', /*Sun*/ D'1988.03.27 03:00:00', PLUS_4h,     /*Sat*/ D'1988.09.24 23:00:00', /*Sun*/ D'1988.09.25 02:00:00', PLUS_3h,
   /*Sat*/ D'1989.03.25 23:00:00', /*Sun*/ D'1989.03.26 03:00:00', PLUS_4h,     /*Sat*/ D'1989.09.23 23:00:00', /*Sun*/ D'1989.09.24 02:00:00', PLUS_3h,
           -1,                             -1,                     PLUS_3h,             -1,                             -1,                     PLUS_3h,    // durchgehend Normalzeit
   /*Sat*/ D'1991.03.30 23:00:00', /*Sun*/ D'1991.03.31 02:00:00', PLUS_3h,     /*Sun*/ D'1991.09.29 00:00:00', /*Sun*/ D'1991.09.29 02:00:00', PLUS_2h,    // Offset�nderung der Zeitzone
   /*Sat*/ D'1992.03.28 22:00:00', /*Sun*/ D'1992.03.29 01:00:00', PLUS_3h,     /*Sat*/ D'1992.09.26 22:00:00', /*Sun*/ D'1992.09.27 00:00:00', PLUS_2h,
   /*Sun*/ D'1993.03.28 00:00:00', /*Sun*/ D'1993.03.28 03:00:00', PLUS_3h,     /*Sun*/ D'1993.09.26 00:00:00', /*Sun*/ D'1993.09.26 02:00:00', PLUS_2h,
   /*Sun*/ D'1994.03.27 00:00:00', /*Sun*/ D'1994.03.27 03:00:00', PLUS_3h,     /*Sun*/ D'1994.09.25 00:00:00', /*Sun*/ D'1994.09.25 02:00:00', PLUS_2h,
   /*Sun*/ D'1995.03.26 00:00:00', /*Sun*/ D'1995.03.26 03:00:00', PLUS_3h,     /*Sun*/ D'1995.09.24 00:00:00', /*Sun*/ D'1995.09.24 02:00:00', PLUS_2h,
   /*Sun*/ D'1996.03.31 00:00:00', /*Sun*/ D'1996.03.31 03:00:00', PLUS_3h,     /*Sun*/ D'1996.10.27 00:00:00', /*Sun*/ D'1996.10.27 02:00:00', PLUS_2h,
   /*Sun*/ D'1997.03.30 00:00:00', /*Sun*/ D'1997.03.30 03:00:00', PLUS_3h,     /*Sun*/ D'1997.10.26 00:00:00', /*Sun*/ D'1997.10.26 02:00:00', PLUS_2h,
   /*Sun*/ D'1998.03.29 00:00:00', /*Sun*/ D'1998.03.29 03:00:00', PLUS_3h,     /*Sun*/ D'1998.10.25 00:00:00', /*Sun*/ D'1998.10.25 02:00:00', PLUS_2h,
   /*Sun*/ D'1999.03.28 00:00:00', /*Sun*/ D'1999.03.28 03:00:00', PLUS_3h,     /*Sun*/ D'1999.10.31 00:00:00', /*Sun*/ D'1999.10.31 02:00:00', PLUS_2h,
   /*Sun*/ D'2000.03.26 00:00:00', /*Sun*/ D'2000.03.26 03:00:00', PLUS_3h,     /*Sun*/ D'2000.10.29 00:00:00', /*Sun*/ D'2000.10.29 02:00:00', PLUS_2h,
   /*Sun*/ D'2001.03.25 00:00:00', /*Sun*/ D'2001.03.25 03:00:00', PLUS_3h,     /*Sun*/ D'2001.10.28 00:00:00', /*Sun*/ D'2001.10.28 02:00:00', PLUS_2h,
   /*Sun*/ D'2002.03.31 00:00:00', /*Sun*/ D'2002.03.31 03:00:00', PLUS_3h,     /*Sun*/ D'2002.10.27 00:00:00', /*Sun*/ D'2002.10.27 02:00:00', PLUS_2h,
   /*Sun*/ D'2003.03.30 00:00:00', /*Sun*/ D'2003.03.30 03:00:00', PLUS_3h,     /*Sun*/ D'2003.10.26 00:00:00', /*Sun*/ D'2003.10.26 02:00:00', PLUS_2h,
   /*Sun*/ D'2004.03.28 00:00:00', /*Sun*/ D'2004.03.28 03:00:00', PLUS_3h,     /*Sun*/ D'2004.10.31 00:00:00', /*Sun*/ D'2004.10.31 02:00:00', PLUS_2h,
   /*Sun*/ D'2005.03.27 00:00:00', /*Sun*/ D'2005.03.27 03:00:00', PLUS_3h,     /*Sun*/ D'2005.10.30 00:00:00', /*Sun*/ D'2005.10.30 02:00:00', PLUS_2h,
   /*Sun*/ D'2006.03.26 00:00:00', /*Sun*/ D'2006.03.26 03:00:00', PLUS_3h,     /*Sun*/ D'2006.10.29 00:00:00', /*Sun*/ D'2006.10.29 02:00:00', PLUS_2h,
   /*Sun*/ D'2007.03.25 00:00:00', /*Sun*/ D'2007.03.25 03:00:00', PLUS_3h,     /*Sun*/ D'2007.10.28 00:00:00', /*Sun*/ D'2007.10.28 02:00:00', PLUS_2h,
   /*Sun*/ D'2008.03.30 00:00:00', /*Sun*/ D'2008.03.30 03:00:00', PLUS_3h,     /*Sun*/ D'2008.10.26 00:00:00', /*Sun*/ D'2008.10.26 02:00:00', PLUS_2h,
   /*Sun*/ D'2009.03.29 00:00:00', /*Sun*/ D'2009.03.29 03:00:00', PLUS_3h,     /*Sun*/ D'2009.10.25 00:00:00', /*Sun*/ D'2009.10.25 02:00:00', PLUS_2h,
   /*Sun*/ D'2010.03.28 00:00:00', /*Sun*/ D'2010.03.28 03:00:00', PLUS_3h,     /*Sun*/ D'2010.10.31 00:00:00', /*Sun*/ D'2010.10.31 02:00:00', PLUS_2h,
   /*Sun*/ D'2011.03.27 00:00:00', /*Sun*/ D'2011.03.27 03:00:00', PLUS_3h,     /*Sun*/ INT_MAX,                        INT_MAX,                PLUS_3h,    // durchgehend Sommerzeit
           -1,                             -1,                     PLUS_3h,             INT_MAX,                        INT_MAX,                PLUS_3h,
           -1,                             -1,                     PLUS_3h,             INT_MAX,                        INT_MAX,                PLUS_3h,
           -1,                             -1,                     PLUS_3h,             INT_MAX,                        INT_MAX,                PLUS_3h,
           -1,                             -1,                     PLUS_3h,             INT_MAX,                        INT_MAX,                PLUS_3h,
           -1,                             -1,                     PLUS_3h,             INT_MAX,                        INT_MAX,                PLUS_3h,
           -1,                             -1,                     PLUS_3h,             INT_MAX,                        INT_MAX,                PLUS_3h,
           -1,                             -1,                     PLUS_3h,             INT_MAX,                        INT_MAX,                PLUS_3h,
           -1,                             -1,                     PLUS_3h,             INT_MAX,                        INT_MAX,                PLUS_3h,
           -1,                             -1,                     PLUS_3h,             INT_MAX,                        INT_MAX,                PLUS_3h,
           -1,                             -1,                     PLUS_3h,             INT_MAX,                        INT_MAX,                PLUS_3h,
           -1,                             -1,                     PLUS_3h,             INT_MAX,                        INT_MAX,                PLUS_3h,
           -1,                             -1,                     PLUS_3h,             INT_MAX,                        INT_MAX,                PLUS_3h,
           -1,                             -1,                     PLUS_3h,             INT_MAX,                        INT_MAX,                PLUS_3h,
           -1,                             -1,                     PLUS_3h,             INT_MAX,                        INT_MAX,                PLUS_3h,
           -1,                             -1,                     PLUS_3h,             INT_MAX,                        INT_MAX,                PLUS_3h,
           -1,                             -1,                     PLUS_3h,             INT_MAX,                        INT_MAX,                PLUS_3h,
           -1,                             -1,                     PLUS_3h,             INT_MAX,                        INT_MAX,                PLUS_3h,
           -1,                             -1,                     PLUS_3h,             INT_MAX,                        INT_MAX,                PLUS_3h,
           -1,                             -1,                     PLUS_3h,             INT_MAX,                        INT_MAX,                PLUS_3h,
           -1,                             -1,                     PLUS_3h,             INT_MAX,                        INT_MAX,                PLUS_3h,
           -1,                             -1,                     PLUS_3h,             INT_MAX,                        INT_MAX,                PLUS_3h,
           -1,                             -1,                     PLUS_3h,             INT_MAX,                        INT_MAX,                PLUS_3h,
           -1,                             -1,                     PLUS_3h,             INT_MAX,                        INT_MAX,                PLUS_3h,
           -1,                             -1,                     PLUS_3h,             INT_MAX,                        INT_MAX,                PLUS_3h,
           -1,                             -1,                     PLUS_3h,             INT_MAX,                        INT_MAX,                PLUS_3h,
           -1,                             -1,                     PLUS_3h,             INT_MAX,                        INT_MAX,                PLUS_3h,
};


// Europe/Berlin: GMT+0100/+0200
int transitions.Europe_Berlin[68][6] = {
   // Wechsel zu DST                                               DST-Offset   // Wechsel zu Normalzeit                                        Std-Offset
           -1,                             -1,                     PLUS_1h,             -1,                             -1,                     PLUS_1h,    // durchgehend Normalzeit
           -1,                             -1,                     PLUS_1h,             -1,                             -1,                     PLUS_1h,
           -1,                             -1,                     PLUS_1h,             -1,                             -1,                     PLUS_1h,
           -1,                             -1,                     PLUS_1h,             -1,                             -1,                     PLUS_1h,
           -1,                             -1,                     PLUS_1h,             -1,                             -1,                     PLUS_1h,
           -1,                             -1,                     PLUS_1h,             -1,                             -1,                     PLUS_1h,
           -1,                             -1,                     PLUS_1h,             -1,                             -1,                     PLUS_1h,
           -1,                             -1,                     PLUS_1h,             -1,                             -1,                     PLUS_1h,
           -1,                             -1,                     PLUS_1h,             -1,                             -1,                     PLUS_1h,
           -1,                             -1,                     PLUS_1h,             -1,                             -1,                     PLUS_1h,
   /*Sun*/ D'1980.04.06 01:00:00', /*Sun*/ D'1980.04.06 03:00:00', PLUS_2h,     /*Sun*/ D'1980.09.28 01:00:00', /*Sun*/ D'1980.09.28 02:00:00', PLUS_1h,    // Einf�hrung Sommerzeit
   /*Sun*/ D'1981.03.29 01:00:00', /*Sun*/ D'1981.03.29 03:00:00', PLUS_2h,     /*Sun*/ D'1981.09.27 01:00:00', /*Sun*/ D'1981.09.27 02:00:00', PLUS_1h,
   /*Sun*/ D'1982.03.28 01:00:00', /*Sun*/ D'1982.03.28 03:00:00', PLUS_2h,     /*Sun*/ D'1982.09.26 01:00:00', /*Sun*/ D'1982.09.26 02:00:00', PLUS_1h,
   /*Sun*/ D'1983.03.27 01:00:00', /*Sun*/ D'1983.03.27 03:00:00', PLUS_2h,     /*Sun*/ D'1983.09.25 01:00:00', /*Sun*/ D'1983.09.25 02:00:00', PLUS_1h,
   /*Sun*/ D'1984.03.25 01:00:00', /*Sun*/ D'1984.03.25 03:00:00', PLUS_2h,     /*Sun*/ D'1984.09.30 01:00:00', /*Sun*/ D'1984.09.30 02:00:00', PLUS_1h,
   /*Sun*/ D'1985.03.31 01:00:00', /*Sun*/ D'1985.03.31 03:00:00', PLUS_2h,     /*Sun*/ D'1985.09.29 01:00:00', /*Sun*/ D'1985.09.29 02:00:00', PLUS_1h,
   /*Sun*/ D'1986.03.30 01:00:00', /*Sun*/ D'1986.03.30 03:00:00', PLUS_2h,     /*Sun*/ D'1986.09.28 01:00:00', /*Sun*/ D'1986.09.28 02:00:00', PLUS_1h,
   /*Sun*/ D'1987.03.29 01:00:00', /*Sun*/ D'1987.03.29 03:00:00', PLUS_2h,     /*Sun*/ D'1987.09.27 01:00:00', /*Sun*/ D'1987.09.27 02:00:00', PLUS_1h,
   /*Sun*/ D'1988.03.27 01:00:00', /*Sun*/ D'1988.03.27 03:00:00', PLUS_2h,     /*Sun*/ D'1988.09.25 01:00:00', /*Sun*/ D'1988.09.25 02:00:00', PLUS_1h,
   /*Sun*/ D'1989.03.26 01:00:00', /*Sun*/ D'1989.03.26 03:00:00', PLUS_2h,     /*Sun*/ D'1989.09.24 01:00:00', /*Sun*/ D'1989.09.24 02:00:00', PLUS_1h,
   /*Sun*/ D'1990.03.25 01:00:00', /*Sun*/ D'1990.03.25 03:00:00', PLUS_2h,     /*Sun*/ D'1990.09.30 01:00:00', /*Sun*/ D'1990.09.30 02:00:00', PLUS_1h,
   /*Sun*/ D'1991.03.31 01:00:00', /*Sun*/ D'1991.03.31 03:00:00', PLUS_2h,     /*Sun*/ D'1991.09.29 01:00:00', /*Sun*/ D'1991.09.29 02:00:00', PLUS_1h,
   /*Sun*/ D'1992.03.29 01:00:00', /*Sun*/ D'1992.03.29 03:00:00', PLUS_2h,     /*Sun*/ D'1992.09.27 01:00:00', /*Sun*/ D'1992.09.27 02:00:00', PLUS_1h,
   /*Sun*/ D'1993.03.28 01:00:00', /*Sun*/ D'1993.03.28 03:00:00', PLUS_2h,     /*Sun*/ D'1993.09.26 01:00:00', /*Sun*/ D'1993.09.26 02:00:00', PLUS_1h,
   /*Sun*/ D'1994.03.27 01:00:00', /*Sun*/ D'1994.03.27 03:00:00', PLUS_2h,     /*Sun*/ D'1994.09.25 01:00:00', /*Sun*/ D'1994.09.25 02:00:00', PLUS_1h,
   /*Sun*/ D'1995.03.26 01:00:00', /*Sun*/ D'1995.03.26 03:00:00', PLUS_2h,     /*Sun*/ D'1995.09.24 01:00:00', /*Sun*/ D'1995.09.24 02:00:00', PLUS_1h,
   /*Sun*/ D'1996.03.31 01:00:00', /*Sun*/ D'1996.03.31 03:00:00', PLUS_2h,     /*Sun*/ D'1996.10.27 01:00:00', /*Sun*/ D'1996.10.27 02:00:00', PLUS_1h,
   /*Sun*/ D'1997.03.30 01:00:00', /*Sun*/ D'1997.03.30 03:00:00', PLUS_2h,     /*Sun*/ D'1997.10.26 01:00:00', /*Sun*/ D'1997.10.26 02:00:00', PLUS_1h,
   /*Sun*/ D'1998.03.29 01:00:00', /*Sun*/ D'1998.03.29 03:00:00', PLUS_2h,     /*Sun*/ D'1998.10.25 01:00:00', /*Sun*/ D'1998.10.25 02:00:00', PLUS_1h,
   /*Sun*/ D'1999.03.28 01:00:00', /*Sun*/ D'1999.03.28 03:00:00', PLUS_2h,     /*Sun*/ D'1999.10.31 01:00:00', /*Sun*/ D'1999.10.31 02:00:00', PLUS_1h,
   /*Sun*/ D'2000.03.26 01:00:00', /*Sun*/ D'2000.03.26 03:00:00', PLUS_2h,     /*Sun*/ D'2000.10.29 01:00:00', /*Sun*/ D'2000.10.29 02:00:00', PLUS_1h,
   /*Sun*/ D'2001.03.25 01:00:00', /*Sun*/ D'2001.03.25 03:00:00', PLUS_2h,     /*Sun*/ D'2001.10.28 01:00:00', /*Sun*/ D'2001.10.28 02:00:00', PLUS_1h,
   /*Sun*/ D'2002.03.31 01:00:00', /*Sun*/ D'2002.03.31 03:00:00', PLUS_2h,     /*Sun*/ D'2002.10.27 01:00:00', /*Sun*/ D'2002.10.27 02:00:00', PLUS_1h,
   /*Sun*/ D'2003.03.30 01:00:00', /*Sun*/ D'2003.03.30 03:00:00', PLUS_2h,     /*Sun*/ D'2003.10.26 01:00:00', /*Sun*/ D'2003.10.26 02:00:00', PLUS_1h,
   /*Sun*/ D'2004.03.28 01:00:00', /*Sun*/ D'2004.03.28 03:00:00', PLUS_2h,     /*Sun*/ D'2004.10.31 01:00:00', /*Sun*/ D'2004.10.31 02:00:00', PLUS_1h,
   /*Sun*/ D'2005.03.27 01:00:00', /*Sun*/ D'2005.03.27 03:00:00', PLUS_2h,     /*Sun*/ D'2005.10.30 01:00:00', /*Sun*/ D'2005.10.30 02:00:00', PLUS_1h,
   /*Sun*/ D'2006.03.26 01:00:00', /*Sun*/ D'2006.03.26 03:00:00', PLUS_2h,     /*Sun*/ D'2006.10.29 01:00:00', /*Sun*/ D'2006.10.29 02:00:00', PLUS_1h,
   /*Sun*/ D'2007.03.25 01:00:00', /*Sun*/ D'2007.03.25 03:00:00', PLUS_2h,     /*Sun*/ D'2007.10.28 01:00:00', /*Sun*/ D'2007.10.28 02:00:00', PLUS_1h,
   /*Sun*/ D'2008.03.30 01:00:00', /*Sun*/ D'2008.03.30 03:00:00', PLUS_2h,     /*Sun*/ D'2008.10.26 01:00:00', /*Sun*/ D'2008.10.26 02:00:00', PLUS_1h,
   /*Sun*/ D'2009.03.29 01:00:00', /*Sun*/ D'2009.03.29 03:00:00', PLUS_2h,     /*Sun*/ D'2009.10.25 01:00:00', /*Sun*/ D'2009.10.25 02:00:00', PLUS_1h,
   /*Sun*/ D'2010.03.28 01:00:00', /*Sun*/ D'2010.03.28 03:00:00', PLUS_2h,     /*Sun*/ D'2010.10.31 01:00:00', /*Sun*/ D'2010.10.31 02:00:00', PLUS_1h,
   /*Sun*/ D'2011.03.27 01:00:00', /*Sun*/ D'2011.03.27 03:00:00', PLUS_2h,     /*Sun*/ D'2011.10.30 01:00:00', /*Sun*/ D'2011.10.30 02:00:00', PLUS_1h,
   /*Sun*/ D'2012.03.25 01:00:00', /*Sun*/ D'2012.03.25 03:00:00', PLUS_2h,     /*Sun*/ D'2012.10.28 01:00:00', /*Sun*/ D'2012.10.28 02:00:00', PLUS_1h,
   /*Sun*/ D'2013.03.31 01:00:00', /*Sun*/ D'2013.03.31 03:00:00', PLUS_2h,     /*Sun*/ D'2013.10.27 01:00:00', /*Sun*/ D'2013.10.27 02:00:00', PLUS_1h,
   /*Sun*/ D'2014.03.30 01:00:00', /*Sun*/ D'2014.03.30 03:00:00', PLUS_2h,     /*Sun*/ D'2014.10.26 01:00:00', /*Sun*/ D'2014.10.26 02:00:00', PLUS_1h,
   /*Sun*/ D'2015.03.29 01:00:00', /*Sun*/ D'2015.03.29 03:00:00', PLUS_2h,     /*Sun*/ D'2015.10.25 01:00:00', /*Sun*/ D'2015.10.25 02:00:00', PLUS_1h,
   /*Sun*/ D'2016.03.27 01:00:00', /*Sun*/ D'2016.03.27 03:00:00', PLUS_2h,     /*Sun*/ D'2016.10.30 01:00:00', /*Sun*/ D'2016.10.30 02:00:00', PLUS_1h,
   /*Sun*/ D'2017.03.26 01:00:00', /*Sun*/ D'2017.03.26 03:00:00', PLUS_2h,     /*Sun*/ D'2017.10.29 01:00:00', /*Sun*/ D'2017.10.29 02:00:00', PLUS_1h,
   /*Sun*/ D'2018.03.25 01:00:00', /*Sun*/ D'2018.03.25 03:00:00', PLUS_2h,     /*Sun*/ D'2018.10.28 01:00:00', /*Sun*/ D'2018.10.28 02:00:00', PLUS_1h,
   /*Sun*/ D'2019.03.31 01:00:00', /*Sun*/ D'2019.03.31 03:00:00', PLUS_2h,     /*Sun*/ D'2019.10.27 01:00:00', /*Sun*/ D'2019.10.27 02:00:00', PLUS_1h,
   /*Sun*/ D'2020.03.29 01:00:00', /*Sun*/ D'2020.03.29 03:00:00', PLUS_2h,     /*Sun*/ D'2020.10.25 01:00:00', /*Sun*/ D'2020.10.25 02:00:00', PLUS_1h,
   /*Sun*/ D'2021.03.28 01:00:00', /*Sun*/ D'2021.03.28 03:00:00', PLUS_2h,     /*Sun*/ D'2021.10.31 01:00:00', /*Sun*/ D'2021.10.31 02:00:00', PLUS_1h,
   /*Sun*/ D'2022.03.27 01:00:00', /*Sun*/ D'2022.03.27 03:00:00', PLUS_2h,     /*Sun*/ D'2022.10.30 01:00:00', /*Sun*/ D'2022.10.30 02:00:00', PLUS_1h,
   /*Sun*/ D'2023.03.26 01:00:00', /*Sun*/ D'2023.03.26 03:00:00', PLUS_2h,     /*Sun*/ D'2023.10.29 01:00:00', /*Sun*/ D'2023.10.29 02:00:00', PLUS_1h,
   /*Sun*/ D'2024.03.31 01:00:00', /*Sun*/ D'2024.03.31 03:00:00', PLUS_2h,     /*Sun*/ D'2024.10.27 01:00:00', /*Sun*/ D'2024.10.27 02:00:00', PLUS_1h,
   /*Sun*/ D'2025.03.30 01:00:00', /*Sun*/ D'2025.03.30 03:00:00', PLUS_2h,     /*Sun*/ D'2025.10.26 01:00:00', /*Sun*/ D'2025.10.26 02:00:00', PLUS_1h,
   /*Sun*/ D'2026.03.29 01:00:00', /*Sun*/ D'2026.03.29 03:00:00', PLUS_2h,     /*Sun*/ D'2026.10.25 01:00:00', /*Sun*/ D'2026.10.25 02:00:00', PLUS_1h,
   /*Sun*/ D'2027.03.28 01:00:00', /*Sun*/ D'2027.03.28 03:00:00', PLUS_2h,     /*Sun*/ D'2027.10.31 01:00:00', /*Sun*/ D'2027.10.31 02:00:00', PLUS_1h,
   /*Sun*/ D'2028.03.26 01:00:00', /*Sun*/ D'2028.03.26 03:00:00', PLUS_2h,     /*Sun*/ D'2028.10.29 01:00:00', /*Sun*/ D'2028.10.29 02:00:00', PLUS_1h,
   /*Sun*/ D'2029.03.25 01:00:00', /*Sun*/ D'2029.03.25 03:00:00', PLUS_2h,     /*Sun*/ D'2029.10.28 01:00:00', /*Sun*/ D'2029.10.28 02:00:00', PLUS_1h,
   /*Sun*/ D'2030.03.31 01:00:00', /*Sun*/ D'2030.03.31 03:00:00', PLUS_2h,     /*Sun*/ D'2030.10.27 01:00:00', /*Sun*/ D'2030.10.27 02:00:00', PLUS_1h,
   /*Sun*/ D'2031.03.30 01:00:00', /*Sun*/ D'2031.03.30 03:00:00', PLUS_2h,     /*Sun*/ D'2031.10.26 01:00:00', /*Sun*/ D'2031.10.26 02:00:00', PLUS_1h,
   /*Sun*/ D'2032.03.28 01:00:00', /*Sun*/ D'2032.03.28 03:00:00', PLUS_2h,     /*Sun*/ D'2032.10.31 01:00:00', /*Sun*/ D'2032.10.31 02:00:00', PLUS_1h,
   /*Sun*/ D'2033.03.27 01:00:00', /*Sun*/ D'2033.03.27 03:00:00', PLUS_2h,     /*Sun*/ D'2033.10.30 01:00:00', /*Sun*/ D'2033.10.30 02:00:00', PLUS_1h,
   /*Sun*/ D'2034.03.26 01:00:00', /*Sun*/ D'2034.03.26 03:00:00', PLUS_2h,     /*Sun*/ D'2034.10.29 01:00:00', /*Sun*/ D'2034.10.29 02:00:00', PLUS_1h,
   /*Sun*/ D'2035.03.25 01:00:00', /*Sun*/ D'2035.03.25 03:00:00', PLUS_2h,     /*Sun*/ D'2035.10.28 01:00:00', /*Sun*/ D'2035.10.28 02:00:00', PLUS_1h,
   /*Sun*/ D'2036.03.30 01:00:00', /*Sun*/ D'2036.03.30 03:00:00', PLUS_2h,     /*Sun*/ D'2036.10.26 01:00:00', /*Sun*/ D'2036.10.26 02:00:00', PLUS_1h,
   /*Sun*/ D'2037.03.29 01:00:00', /*Sun*/ D'2037.03.29 03:00:00', PLUS_2h,     /*Sun*/ D'2037.10.25 01:00:00', /*Sun*/ D'2037.10.25 02:00:00', PLUS_1h,
};


// Europe/London: GMT+0000/+0100
int transitions.Europe_London[68][6] = {
   // Wechsel zu DST                                               DST-Offset   // Wechsel zu Normalzeit                                        Std-Offset
           -1,                             -1,                     PLUS_1h,             INT_MAX,                        INT_MAX,                PLUS_1h,    // Vom 18.02.1968 bis
           -1,                             -1,                     PLUS_1h,     /*Sun*/ D'1971.10.31 02:00:00', /*Sun*/ D'1971.10.31 02:00:00', 0,          // 31.10.1971 durchgehend
   /*Sun*/ D'1972.03.19 02:00:00', /*Sun*/ D'1972.03.19 03:00:00', PLUS_1h,     /*Sun*/ D'1972.10.29 02:00:00', /*Sun*/ D'1972.10.29 02:00:00', 0,          // Sommerzeit.
   /*Sun*/ D'1973.03.18 02:00:00', /*Sun*/ D'1973.03.18 03:00:00', PLUS_1h,     /*Sun*/ D'1973.10.28 02:00:00', /*Sun*/ D'1973.10.28 02:00:00', 0,
   /*Sun*/ D'1974.03.17 02:00:00', /*Sun*/ D'1974.03.17 03:00:00', PLUS_1h,     /*Sun*/ D'1974.10.27 02:00:00', /*Sun*/ D'1974.10.27 02:00:00', 0,
   /*Sun*/ D'1975.03.16 02:00:00', /*Sun*/ D'1975.03.16 03:00:00', PLUS_1h,     /*Sun*/ D'1975.10.26 02:00:00', /*Sun*/ D'1975.10.26 02:00:00', 0,
   /*Sun*/ D'1976.03.21 02:00:00', /*Sun*/ D'1976.03.21 03:00:00', PLUS_1h,     /*Sun*/ D'1976.10.24 02:00:00', /*Sun*/ D'1976.10.24 02:00:00', 0,
   /*Sun*/ D'1977.03.20 02:00:00', /*Sun*/ D'1977.03.20 03:00:00', PLUS_1h,     /*Sun*/ D'1977.10.23 02:00:00', /*Sun*/ D'1977.10.23 02:00:00', 0,
   /*Sun*/ D'1978.03.19 02:00:00', /*Sun*/ D'1978.03.19 03:00:00', PLUS_1h,     /*Sun*/ D'1978.10.29 02:00:00', /*Sun*/ D'1978.10.29 02:00:00', 0,
   /*Sun*/ D'1979.03.18 02:00:00', /*Sun*/ D'1979.03.18 03:00:00', PLUS_1h,     /*Sun*/ D'1979.10.28 02:00:00', /*Sun*/ D'1979.10.28 02:00:00', 0,
   /*Sun*/ D'1980.03.16 02:00:00', /*Sun*/ D'1980.03.16 03:00:00', PLUS_1h,     /*Sun*/ D'1980.10.26 02:00:00', /*Sun*/ D'1980.10.26 02:00:00', 0,
   /*Sun*/ D'1981.03.29 01:00:00', /*Sun*/ D'1981.03.29 02:00:00', PLUS_1h,     /*Sun*/ D'1981.10.25 01:00:00', /*Sun*/ D'1981.10.25 01:00:00', 0,
   /*Sun*/ D'1982.03.28 01:00:00', /*Sun*/ D'1982.03.28 02:00:00', PLUS_1h,     /*Sun*/ D'1982.10.24 01:00:00', /*Sun*/ D'1982.10.24 01:00:00', 0,
   /*Sun*/ D'1983.03.27 01:00:00', /*Sun*/ D'1983.03.27 02:00:00', PLUS_1h,     /*Sun*/ D'1983.10.23 01:00:00', /*Sun*/ D'1983.10.23 01:00:00', 0,
   /*Sun*/ D'1984.03.25 01:00:00', /*Sun*/ D'1984.03.25 02:00:00', PLUS_1h,     /*Sun*/ D'1984.10.28 01:00:00', /*Sun*/ D'1984.10.28 01:00:00', 0,
   /*Sun*/ D'1985.03.31 01:00:00', /*Sun*/ D'1985.03.31 02:00:00', PLUS_1h,     /*Sun*/ D'1985.10.27 01:00:00', /*Sun*/ D'1985.10.27 01:00:00', 0,
   /*Sun*/ D'1986.03.30 01:00:00', /*Sun*/ D'1986.03.30 02:00:00', PLUS_1h,     /*Sun*/ D'1986.10.26 01:00:00', /*Sun*/ D'1986.10.26 01:00:00', 0,
   /*Sun*/ D'1987.03.29 01:00:00', /*Sun*/ D'1987.03.29 02:00:00', PLUS_1h,     /*Sun*/ D'1987.10.25 01:00:00', /*Sun*/ D'1987.10.25 01:00:00', 0,
   /*Sun*/ D'1988.03.27 01:00:00', /*Sun*/ D'1988.03.27 02:00:00', PLUS_1h,     /*Sun*/ D'1988.10.23 01:00:00', /*Sun*/ D'1988.10.23 01:00:00', 0,
   /*Sun*/ D'1989.03.26 01:00:00', /*Sun*/ D'1989.03.26 02:00:00', PLUS_1h,     /*Sun*/ D'1989.10.29 01:00:00', /*Sun*/ D'1989.10.29 01:00:00', 0,
   /*Sun*/ D'1990.03.25 01:00:00', /*Sun*/ D'1990.03.25 02:00:00', PLUS_1h,     /*Sun*/ D'1990.10.28 01:00:00', /*Sun*/ D'1990.10.28 01:00:00', 0,
   /*Sun*/ D'1991.03.31 01:00:00', /*Sun*/ D'1991.03.31 02:00:00', PLUS_1h,     /*Sun*/ D'1991.10.27 01:00:00', /*Sun*/ D'1991.10.27 01:00:00', 0,
   /*Sun*/ D'1992.03.29 01:00:00', /*Sun*/ D'1992.03.29 02:00:00', PLUS_1h,     /*Sun*/ D'1992.10.25 01:00:00', /*Sun*/ D'1992.10.25 01:00:00', 0,
   /*Sun*/ D'1993.03.28 01:00:00', /*Sun*/ D'1993.03.28 02:00:00', PLUS_1h,     /*Sun*/ D'1993.10.24 01:00:00', /*Sun*/ D'1993.10.24 01:00:00', 0,
   /*Sun*/ D'1994.03.27 01:00:00', /*Sun*/ D'1994.03.27 02:00:00', PLUS_1h,     /*Sun*/ D'1994.10.23 01:00:00', /*Sun*/ D'1994.10.23 01:00:00', 0,
   /*Sun*/ D'1995.03.26 01:00:00', /*Sun*/ D'1995.03.26 02:00:00', PLUS_1h,     /*Sun*/ D'1995.10.22 01:00:00', /*Sun*/ D'1995.10.22 01:00:00', 0,
   /*Sun*/ D'1996.03.31 01:00:00', /*Sun*/ D'1996.03.31 02:00:00', PLUS_1h,     /*Sun*/ D'1996.10.27 01:00:00', /*Sun*/ D'1996.10.27 01:00:00', 0,
   /*Sun*/ D'1997.03.30 01:00:00', /*Sun*/ D'1997.03.30 02:00:00', PLUS_1h,     /*Sun*/ D'1997.10.26 01:00:00', /*Sun*/ D'1997.10.26 01:00:00', 0,
   /*Sun*/ D'1998.03.29 01:00:00', /*Sun*/ D'1998.03.29 02:00:00', PLUS_1h,     /*Sun*/ D'1998.10.25 01:00:00', /*Sun*/ D'1998.10.25 01:00:00', 0,
   /*Sun*/ D'1999.03.28 01:00:00', /*Sun*/ D'1999.03.28 02:00:00', PLUS_1h,     /*Sun*/ D'1999.10.31 01:00:00', /*Sun*/ D'1999.10.31 01:00:00', 0,
   /*Sun*/ D'2000.03.26 01:00:00', /*Sun*/ D'2000.03.26 02:00:00', PLUS_1h,     /*Sun*/ D'2000.10.29 01:00:00', /*Sun*/ D'2000.10.29 01:00:00', 0,
   /*Sun*/ D'2001.03.25 01:00:00', /*Sun*/ D'2001.03.25 02:00:00', PLUS_1h,     /*Sun*/ D'2001.10.28 01:00:00', /*Sun*/ D'2001.10.28 01:00:00', 0,
   /*Sun*/ D'2002.03.31 01:00:00', /*Sun*/ D'2002.03.31 02:00:00', PLUS_1h,     /*Sun*/ D'2002.10.27 01:00:00', /*Sun*/ D'2002.10.27 01:00:00', 0,
   /*Sun*/ D'2003.03.30 01:00:00', /*Sun*/ D'2003.03.30 02:00:00', PLUS_1h,     /*Sun*/ D'2003.10.26 01:00:00', /*Sun*/ D'2003.10.26 01:00:00', 0,
   /*Sun*/ D'2004.03.28 01:00:00', /*Sun*/ D'2004.03.28 02:00:00', PLUS_1h,     /*Sun*/ D'2004.10.31 01:00:00', /*Sun*/ D'2004.10.31 01:00:00', 0,
   /*Sun*/ D'2005.03.27 01:00:00', /*Sun*/ D'2005.03.27 02:00:00', PLUS_1h,     /*Sun*/ D'2005.10.30 01:00:00', /*Sun*/ D'2005.10.30 01:00:00', 0,
   /*Sun*/ D'2006.03.26 01:00:00', /*Sun*/ D'2006.03.26 02:00:00', PLUS_1h,     /*Sun*/ D'2006.10.29 01:00:00', /*Sun*/ D'2006.10.29 01:00:00', 0,
   /*Sun*/ D'2007.03.25 01:00:00', /*Sun*/ D'2007.03.25 02:00:00', PLUS_1h,     /*Sun*/ D'2007.10.28 01:00:00', /*Sun*/ D'2007.10.28 01:00:00', 0,
   /*Sun*/ D'2008.03.30 01:00:00', /*Sun*/ D'2008.03.30 02:00:00', PLUS_1h,     /*Sun*/ D'2008.10.26 01:00:00', /*Sun*/ D'2008.10.26 01:00:00', 0,
   /*Sun*/ D'2009.03.29 01:00:00', /*Sun*/ D'2009.03.29 02:00:00', PLUS_1h,     /*Sun*/ D'2009.10.25 01:00:00', /*Sun*/ D'2009.10.25 01:00:00', 0,
   /*Sun*/ D'2010.03.28 01:00:00', /*Sun*/ D'2010.03.28 02:00:00', PLUS_1h,     /*Sun*/ D'2010.10.31 01:00:00', /*Sun*/ D'2010.10.31 01:00:00', 0,
   /*Sun*/ D'2011.03.27 01:00:00', /*Sun*/ D'2011.03.27 02:00:00', PLUS_1h,     /*Sun*/ D'2011.10.30 01:00:00', /*Sun*/ D'2011.10.30 01:00:00', 0,
   /*Sun*/ D'2012.03.25 01:00:00', /*Sun*/ D'2012.03.25 02:00:00', PLUS_1h,     /*Sun*/ D'2012.10.28 01:00:00', /*Sun*/ D'2012.10.28 01:00:00', 0,
   /*Sun*/ D'2013.03.31 01:00:00', /*Sun*/ D'2013.03.31 02:00:00', PLUS_1h,     /*Sun*/ D'2013.10.27 01:00:00', /*Sun*/ D'2013.10.27 01:00:00', 0,
   /*Sun*/ D'2014.03.30 01:00:00', /*Sun*/ D'2014.03.30 02:00:00', PLUS_1h,     /*Sun*/ D'2014.10.26 01:00:00', /*Sun*/ D'2014.10.26 01:00:00', 0,
   /*Sun*/ D'2015.03.29 01:00:00', /*Sun*/ D'2015.03.29 02:00:00', PLUS_1h,     /*Sun*/ D'2015.10.25 01:00:00', /*Sun*/ D'2015.10.25 01:00:00', 0,
   /*Sun*/ D'2016.03.27 01:00:00', /*Sun*/ D'2016.03.27 02:00:00', PLUS_1h,     /*Sun*/ D'2016.10.30 01:00:00', /*Sun*/ D'2016.10.30 01:00:00', 0,
   /*Sun*/ D'2017.03.26 01:00:00', /*Sun*/ D'2017.03.26 02:00:00', PLUS_1h,     /*Sun*/ D'2017.10.29 01:00:00', /*Sun*/ D'2017.10.29 01:00:00', 0,
   /*Sun*/ D'2018.03.25 01:00:00', /*Sun*/ D'2018.03.25 02:00:00', PLUS_1h,     /*Sun*/ D'2018.10.28 01:00:00', /*Sun*/ D'2018.10.28 01:00:00', 0,
   /*Sun*/ D'2019.03.31 01:00:00', /*Sun*/ D'2019.03.31 02:00:00', PLUS_1h,     /*Sun*/ D'2019.10.27 01:00:00', /*Sun*/ D'2019.10.27 01:00:00', 0,
   /*Sun*/ D'2020.03.29 01:00:00', /*Sun*/ D'2020.03.29 02:00:00', PLUS_1h,     /*Sun*/ D'2020.10.25 01:00:00', /*Sun*/ D'2020.10.25 01:00:00', 0,
   /*Sun*/ D'2021.03.28 01:00:00', /*Sun*/ D'2021.03.28 02:00:00', PLUS_1h,     /*Sun*/ D'2021.10.31 01:00:00', /*Sun*/ D'2021.10.31 01:00:00', 0,
   /*Sun*/ D'2022.03.27 01:00:00', /*Sun*/ D'2022.03.27 02:00:00', PLUS_1h,     /*Sun*/ D'2022.10.30 01:00:00', /*Sun*/ D'2022.10.30 01:00:00', 0,
   /*Sun*/ D'2023.03.26 01:00:00', /*Sun*/ D'2023.03.26 02:00:00', PLUS_1h,     /*Sun*/ D'2023.10.29 01:00:00', /*Sun*/ D'2023.10.29 01:00:00', 0,
   /*Sun*/ D'2024.03.31 01:00:00', /*Sun*/ D'2024.03.31 02:00:00', PLUS_1h,     /*Sun*/ D'2024.10.27 01:00:00', /*Sun*/ D'2024.10.27 01:00:00', 0,
   /*Sun*/ D'2025.03.30 01:00:00', /*Sun*/ D'2025.03.30 02:00:00', PLUS_1h,     /*Sun*/ D'2025.10.26 01:00:00', /*Sun*/ D'2025.10.26 01:00:00', 0,
   /*Sun*/ D'2026.03.29 01:00:00', /*Sun*/ D'2026.03.29 02:00:00', PLUS_1h,     /*Sun*/ D'2026.10.25 01:00:00', /*Sun*/ D'2026.10.25 01:00:00', 0,
   /*Sun*/ D'2027.03.28 01:00:00', /*Sun*/ D'2027.03.28 02:00:00', PLUS_1h,     /*Sun*/ D'2027.10.31 01:00:00', /*Sun*/ D'2027.10.31 01:00:00', 0,
   /*Sun*/ D'2028.03.26 01:00:00', /*Sun*/ D'2028.03.26 02:00:00', PLUS_1h,     /*Sun*/ D'2028.10.29 01:00:00', /*Sun*/ D'2028.10.29 01:00:00', 0,
   /*Sun*/ D'2029.03.25 01:00:00', /*Sun*/ D'2029.03.25 02:00:00', PLUS_1h,     /*Sun*/ D'2029.10.28 01:00:00', /*Sun*/ D'2029.10.28 01:00:00', 0,
   /*Sun*/ D'2030.03.31 01:00:00', /*Sun*/ D'2030.03.31 02:00:00', PLUS_1h,     /*Sun*/ D'2030.10.27 01:00:00', /*Sun*/ D'2030.10.27 01:00:00', 0,
   /*Sun*/ D'2031.03.30 01:00:00', /*Sun*/ D'2031.03.30 02:00:00', PLUS_1h,     /*Sun*/ D'2031.10.26 01:00:00', /*Sun*/ D'2031.10.26 01:00:00', 0,
   /*Sun*/ D'2032.03.28 01:00:00', /*Sun*/ D'2032.03.28 02:00:00', PLUS_1h,     /*Sun*/ D'2032.10.31 01:00:00', /*Sun*/ D'2032.10.31 01:00:00', 0,
   /*Sun*/ D'2033.03.27 01:00:00', /*Sun*/ D'2033.03.27 02:00:00', PLUS_1h,     /*Sun*/ D'2033.10.30 01:00:00', /*Sun*/ D'2033.10.30 01:00:00', 0,
   /*Sun*/ D'2034.03.26 01:00:00', /*Sun*/ D'2034.03.26 02:00:00', PLUS_1h,     /*Sun*/ D'2034.10.29 01:00:00', /*Sun*/ D'2034.10.29 01:00:00', 0,
   /*Sun*/ D'2035.03.25 01:00:00', /*Sun*/ D'2035.03.25 02:00:00', PLUS_1h,     /*Sun*/ D'2035.10.28 01:00:00', /*Sun*/ D'2035.10.28 01:00:00', 0,
   /*Sun*/ D'2036.03.30 01:00:00', /*Sun*/ D'2036.03.30 02:00:00', PLUS_1h,     /*Sun*/ D'2036.10.26 01:00:00', /*Sun*/ D'2036.10.26 01:00:00', 0,
   /*Sun*/ D'2037.03.29 01:00:00', /*Sun*/ D'2037.03.29 02:00:00', PLUS_1h,     /*Sun*/ D'2037.10.25 01:00:00', /*Sun*/ D'2037.10.25 01:00:00', 0,
};


// America/New_York: GMT-0500/-0400
int transitions.America_New_York[68][6] = {
   // Wechsel zu DST                                               DST-Offset   // Wechsel zu Normalzeit                                        Std-Offset
   /*Sun*/ D'1970.04.26 07:00:00', /*Sun*/ D'1970.04.26 03:00:00', MINUS_4h,    /*Sun*/ D'1970.10.25 06:00:00', /*Sun*/ D'1970.10.25 01:00:00', MINUS_5h,
   /*Sun*/ D'1971.04.25 07:00:00', /*Sun*/ D'1971.04.25 03:00:00', MINUS_4h,    /*Sun*/ D'1971.10.31 06:00:00', /*Sun*/ D'1971.10.31 01:00:00', MINUS_5h,
   /*Sun*/ D'1972.04.30 07:00:00', /*Sun*/ D'1972.04.30 03:00:00', MINUS_4h,    /*Sun*/ D'1972.10.29 06:00:00', /*Sun*/ D'1972.10.29 01:00:00', MINUS_5h,
   /*Sun*/ D'1973.04.29 07:00:00', /*Sun*/ D'1973.04.29 03:00:00', MINUS_4h,    /*Sun*/ D'1973.10.28 06:00:00', /*Sun*/ D'1973.10.28 01:00:00', MINUS_5h,
   /*Sun*/ D'1974.01.06 07:00:00', /*Sun*/ D'1974.01.06 03:00:00', MINUS_4h,    /*Sun*/ D'1974.10.27 06:00:00', /*Sun*/ D'1974.10.27 01:00:00', MINUS_5h,
   /*Sun*/ D'1975.02.23 07:00:00', /*Sun*/ D'1975.02.23 03:00:00', MINUS_4h,    /*Sun*/ D'1975.10.26 06:00:00', /*Sun*/ D'1975.10.26 01:00:00', MINUS_5h,
   /*Sun*/ D'1976.04.25 07:00:00', /*Sun*/ D'1976.04.25 03:00:00', MINUS_4h,    /*Sun*/ D'1976.10.31 06:00:00', /*Sun*/ D'1976.10.31 01:00:00', MINUS_5h,
   /*Sun*/ D'1977.04.24 07:00:00', /*Sun*/ D'1977.04.24 03:00:00', MINUS_4h,    /*Sun*/ D'1977.10.30 06:00:00', /*Sun*/ D'1977.10.30 01:00:00', MINUS_5h,
   /*Sun*/ D'1978.04.30 07:00:00', /*Sun*/ D'1978.04.30 03:00:00', MINUS_4h,    /*Sun*/ D'1978.10.29 06:00:00', /*Sun*/ D'1978.10.29 01:00:00', MINUS_5h,
   /*Sun*/ D'1979.04.29 07:00:00', /*Sun*/ D'1979.04.29 03:00:00', MINUS_4h,    /*Sun*/ D'1979.10.28 06:00:00', /*Sun*/ D'1979.10.28 01:00:00', MINUS_5h,
   /*Sun*/ D'1980.04.27 07:00:00', /*Sun*/ D'1980.04.27 03:00:00', MINUS_4h,    /*Sun*/ D'1980.10.26 06:00:00', /*Sun*/ D'1980.10.26 01:00:00', MINUS_5h,
   /*Sun*/ D'1981.04.26 07:00:00', /*Sun*/ D'1981.04.26 03:00:00', MINUS_4h,    /*Sun*/ D'1981.10.25 06:00:00', /*Sun*/ D'1981.10.25 01:00:00', MINUS_5h,
   /*Sun*/ D'1982.04.25 07:00:00', /*Sun*/ D'1982.04.25 03:00:00', MINUS_4h,    /*Sun*/ D'1982.10.31 06:00:00', /*Sun*/ D'1982.10.31 01:00:00', MINUS_5h,
   /*Sun*/ D'1983.04.24 07:00:00', /*Sun*/ D'1983.04.24 03:00:00', MINUS_4h,    /*Sun*/ D'1983.10.30 06:00:00', /*Sun*/ D'1983.10.30 01:00:00', MINUS_5h,
   /*Sun*/ D'1984.04.29 07:00:00', /*Sun*/ D'1984.04.29 03:00:00', MINUS_4h,    /*Sun*/ D'1984.10.28 06:00:00', /*Sun*/ D'1984.10.28 01:00:00', MINUS_5h,
   /*Sun*/ D'1985.04.28 07:00:00', /*Sun*/ D'1985.04.28 03:00:00', MINUS_4h,    /*Sun*/ D'1985.10.27 06:00:00', /*Sun*/ D'1985.10.27 01:00:00', MINUS_5h,
   /*Sun*/ D'1986.04.27 07:00:00', /*Sun*/ D'1986.04.27 03:00:00', MINUS_4h,    /*Sun*/ D'1986.10.26 06:00:00', /*Sun*/ D'1986.10.26 01:00:00', MINUS_5h,
   /*Sun*/ D'1987.04.05 07:00:00', /*Sun*/ D'1987.04.05 03:00:00', MINUS_4h,    /*Sun*/ D'1987.10.25 06:00:00', /*Sun*/ D'1987.10.25 01:00:00', MINUS_5h,
   /*Sun*/ D'1988.04.03 07:00:00', /*Sun*/ D'1988.04.03 03:00:00', MINUS_4h,    /*Sun*/ D'1988.10.30 06:00:00', /*Sun*/ D'1988.10.30 01:00:00', MINUS_5h,
   /*Sun*/ D'1989.04.02 07:00:00', /*Sun*/ D'1989.04.02 03:00:00', MINUS_4h,    /*Sun*/ D'1989.10.29 06:00:00', /*Sun*/ D'1989.10.29 01:00:00', MINUS_5h,
   /*Sun*/ D'1990.04.01 07:00:00', /*Sun*/ D'1990.04.01 03:00:00', MINUS_4h,    /*Sun*/ D'1990.10.28 06:00:00', /*Sun*/ D'1990.10.28 01:00:00', MINUS_5h,
   /*Sun*/ D'1991.04.07 07:00:00', /*Sun*/ D'1991.04.07 03:00:00', MINUS_4h,    /*Sun*/ D'1991.10.27 06:00:00', /*Sun*/ D'1991.10.27 01:00:00', MINUS_5h,
   /*Sun*/ D'1992.04.05 07:00:00', /*Sun*/ D'1992.04.05 03:00:00', MINUS_4h,    /*Sun*/ D'1992.10.25 06:00:00', /*Sun*/ D'1992.10.25 01:00:00', MINUS_5h,
   /*Sun*/ D'1993.04.04 07:00:00', /*Sun*/ D'1993.04.04 03:00:00', MINUS_4h,    /*Sun*/ D'1993.10.31 06:00:00', /*Sun*/ D'1993.10.31 01:00:00', MINUS_5h,
   /*Sun*/ D'1994.04.03 07:00:00', /*Sun*/ D'1994.04.03 03:00:00', MINUS_4h,    /*Sun*/ D'1994.10.30 06:00:00', /*Sun*/ D'1994.10.30 01:00:00', MINUS_5h,
   /*Sun*/ D'1995.04.02 07:00:00', /*Sun*/ D'1995.04.02 03:00:00', MINUS_4h,    /*Sun*/ D'1995.10.29 06:00:00', /*Sun*/ D'1995.10.29 01:00:00', MINUS_5h,
   /*Sun*/ D'1996.04.07 07:00:00', /*Sun*/ D'1996.04.07 03:00:00', MINUS_4h,    /*Sun*/ D'1996.10.27 06:00:00', /*Sun*/ D'1996.10.27 01:00:00', MINUS_5h,
   /*Sun*/ D'1997.04.06 07:00:00', /*Sun*/ D'1997.04.06 03:00:00', MINUS_4h,    /*Sun*/ D'1997.10.26 06:00:00', /*Sun*/ D'1997.10.26 01:00:00', MINUS_5h,
   /*Sun*/ D'1998.04.05 07:00:00', /*Sun*/ D'1998.04.05 03:00:00', MINUS_4h,    /*Sun*/ D'1998.10.25 06:00:00', /*Sun*/ D'1998.10.25 01:00:00', MINUS_5h,
   /*Sun*/ D'1999.04.04 07:00:00', /*Sun*/ D'1999.04.04 03:00:00', MINUS_4h,    /*Sun*/ D'1999.10.31 06:00:00', /*Sun*/ D'1999.10.31 01:00:00', MINUS_5h,
   /*Sun*/ D'2000.04.02 07:00:00', /*Sun*/ D'2000.04.02 03:00:00', MINUS_4h,    /*Sun*/ D'2000.10.29 06:00:00', /*Sun*/ D'2000.10.29 01:00:00', MINUS_5h,
   /*Sun*/ D'2001.04.01 07:00:00', /*Sun*/ D'2001.04.01 03:00:00', MINUS_4h,    /*Sun*/ D'2001.10.28 06:00:00', /*Sun*/ D'2001.10.28 01:00:00', MINUS_5h,
   /*Sun*/ D'2002.04.07 07:00:00', /*Sun*/ D'2002.04.07 03:00:00', MINUS_4h,    /*Sun*/ D'2002.10.27 06:00:00', /*Sun*/ D'2002.10.27 01:00:00', MINUS_5h,
   /*Sun*/ D'2003.04.06 07:00:00', /*Sun*/ D'2003.04.06 03:00:00', MINUS_4h,    /*Sun*/ D'2003.10.26 06:00:00', /*Sun*/ D'2003.10.26 01:00:00', MINUS_5h,
   /*Sun*/ D'2004.04.04 07:00:00', /*Sun*/ D'2004.04.04 03:00:00', MINUS_4h,    /*Sun*/ D'2004.10.31 06:00:00', /*Sun*/ D'2004.10.31 01:00:00', MINUS_5h,
   /*Sun*/ D'2005.04.03 07:00:00', /*Sun*/ D'2005.04.03 03:00:00', MINUS_4h,    /*Sun*/ D'2005.10.30 06:00:00', /*Sun*/ D'2005.10.30 01:00:00', MINUS_5h,
   /*Sun*/ D'2006.04.02 07:00:00', /*Sun*/ D'2006.04.02 03:00:00', MINUS_4h,    /*Sun*/ D'2006.10.29 06:00:00', /*Sun*/ D'2006.10.29 01:00:00', MINUS_5h,
   /*Sun*/ D'2007.03.11 07:00:00', /*Sun*/ D'2007.03.11 03:00:00', MINUS_4h,    /*Sun*/ D'2007.11.04 06:00:00', /*Sun*/ D'2007.11.04 01:00:00', MINUS_5h,
   /*Sun*/ D'2008.03.09 07:00:00', /*Sun*/ D'2008.03.09 03:00:00', MINUS_4h,    /*Sun*/ D'2008.11.02 06:00:00', /*Sun*/ D'2008.11.02 01:00:00', MINUS_5h,
   /*Sun*/ D'2009.03.08 07:00:00', /*Sun*/ D'2009.03.08 03:00:00', MINUS_4h,    /*Sun*/ D'2009.11.01 06:00:00', /*Sun*/ D'2009.11.01 01:00:00', MINUS_5h,
   /*Sun*/ D'2010.03.14 07:00:00', /*Sun*/ D'2010.03.14 03:00:00', MINUS_4h,    /*Sun*/ D'2010.11.07 06:00:00', /*Sun*/ D'2010.11.07 01:00:00', MINUS_5h,
   /*Sun*/ D'2011.03.13 07:00:00', /*Sun*/ D'2011.03.13 03:00:00', MINUS_4h,    /*Sun*/ D'2011.11.06 06:00:00', /*Sun*/ D'2011.11.06 01:00:00', MINUS_5h,
   /*Sun*/ D'2012.03.11 07:00:00', /*Sun*/ D'2012.03.11 03:00:00', MINUS_4h,    /*Sun*/ D'2012.11.04 06:00:00', /*Sun*/ D'2012.11.04 01:00:00', MINUS_5h,
   /*Sun*/ D'2013.03.10 07:00:00', /*Sun*/ D'2013.03.10 03:00:00', MINUS_4h,    /*Sun*/ D'2013.11.03 06:00:00', /*Sun*/ D'2013.11.03 01:00:00', MINUS_5h,
   /*Sun*/ D'2014.03.09 07:00:00', /*Sun*/ D'2014.03.09 03:00:00', MINUS_4h,    /*Sun*/ D'2014.11.02 06:00:00', /*Sun*/ D'2014.11.02 01:00:00', MINUS_5h,
   /*Sun*/ D'2015.03.08 07:00:00', /*Sun*/ D'2015.03.08 03:00:00', MINUS_4h,    /*Sun*/ D'2015.11.01 06:00:00', /*Sun*/ D'2015.11.01 01:00:00', MINUS_5h,
   /*Sun*/ D'2016.03.13 07:00:00', /*Sun*/ D'2016.03.13 03:00:00', MINUS_4h,    /*Sun*/ D'2016.11.06 06:00:00', /*Sun*/ D'2016.11.06 01:00:00', MINUS_5h,
   /*Sun*/ D'2017.03.12 07:00:00', /*Sun*/ D'2017.03.12 03:00:00', MINUS_4h,    /*Sun*/ D'2017.11.05 06:00:00', /*Sun*/ D'2017.11.05 01:00:00', MINUS_5h,
   /*Sun*/ D'2018.03.11 07:00:00', /*Sun*/ D'2018.03.11 03:00:00', MINUS_4h,    /*Sun*/ D'2018.11.04 06:00:00', /*Sun*/ D'2018.11.04 01:00:00', MINUS_5h,
   /*Sun*/ D'2019.03.10 07:00:00', /*Sun*/ D'2019.03.10 03:00:00', MINUS_4h,    /*Sun*/ D'2019.11.03 06:00:00', /*Sun*/ D'2019.11.03 01:00:00', MINUS_5h,
   /*Sun*/ D'2020.03.08 07:00:00', /*Sun*/ D'2020.03.08 03:00:00', MINUS_4h,    /*Sun*/ D'2020.11.01 06:00:00', /*Sun*/ D'2020.11.01 01:00:00', MINUS_5h,
   /*Sun*/ D'2021.03.14 07:00:00', /*Sun*/ D'2021.03.14 03:00:00', MINUS_4h,    /*Sun*/ D'2021.11.07 06:00:00', /*Sun*/ D'2021.11.07 01:00:00', MINUS_5h,
   /*Sun*/ D'2022.03.13 07:00:00', /*Sun*/ D'2022.03.13 03:00:00', MINUS_4h,    /*Sun*/ D'2022.11.06 06:00:00', /*Sun*/ D'2022.11.06 01:00:00', MINUS_5h,
   /*Sun*/ D'2023.03.12 07:00:00', /*Sun*/ D'2023.03.12 03:00:00', MINUS_4h,    /*Sun*/ D'2023.11.05 06:00:00', /*Sun*/ D'2023.11.05 01:00:00', MINUS_5h,
   /*Sun*/ D'2024.03.10 07:00:00', /*Sun*/ D'2024.03.10 03:00:00', MINUS_4h,    /*Sun*/ D'2024.11.03 06:00:00', /*Sun*/ D'2024.11.03 01:00:00', MINUS_5h,
   /*Sun*/ D'2025.03.09 07:00:00', /*Sun*/ D'2025.03.09 03:00:00', MINUS_4h,    /*Sun*/ D'2025.11.02 06:00:00', /*Sun*/ D'2025.11.02 01:00:00', MINUS_5h,
   /*Sun*/ D'2026.03.08 07:00:00', /*Sun*/ D'2026.03.08 03:00:00', MINUS_4h,    /*Sun*/ D'2026.11.01 06:00:00', /*Sun*/ D'2026.11.01 01:00:00', MINUS_5h,
   /*Sun*/ D'2027.03.14 07:00:00', /*Sun*/ D'2027.03.14 03:00:00', MINUS_4h,    /*Sun*/ D'2027.11.07 06:00:00', /*Sun*/ D'2027.11.07 01:00:00', MINUS_5h,
   /*Sun*/ D'2028.03.12 07:00:00', /*Sun*/ D'2028.03.12 03:00:00', MINUS_4h,    /*Sun*/ D'2028.11.05 06:00:00', /*Sun*/ D'2028.11.05 01:00:00', MINUS_5h,
   /*Sun*/ D'2029.03.11 07:00:00', /*Sun*/ D'2029.03.11 03:00:00', MINUS_4h,    /*Sun*/ D'2029.11.04 06:00:00', /*Sun*/ D'2029.11.04 01:00:00', MINUS_5h,
   /*Sun*/ D'2030.03.10 07:00:00', /*Sun*/ D'2030.03.10 03:00:00', MINUS_4h,    /*Sun*/ D'2030.11.03 06:00:00', /*Sun*/ D'2030.11.03 01:00:00', MINUS_5h,
   /*Sun*/ D'2031.03.09 07:00:00', /*Sun*/ D'2031.03.09 03:00:00', MINUS_4h,    /*Sun*/ D'2031.11.02 06:00:00', /*Sun*/ D'2031.11.02 01:00:00', MINUS_5h,
   /*Sun*/ D'2032.03.14 07:00:00', /*Sun*/ D'2032.03.14 03:00:00', MINUS_4h,    /*Sun*/ D'2032.11.07 06:00:00', /*Sun*/ D'2032.11.07 01:00:00', MINUS_5h,
   /*Sun*/ D'2033.03.13 07:00:00', /*Sun*/ D'2033.03.13 03:00:00', MINUS_4h,    /*Sun*/ D'2033.11.06 06:00:00', /*Sun*/ D'2033.11.06 01:00:00', MINUS_5h,
   /*Sun*/ D'2034.03.12 07:00:00', /*Sun*/ D'2034.03.12 03:00:00', MINUS_4h,    /*Sun*/ D'2034.11.05 06:00:00', /*Sun*/ D'2034.11.05 01:00:00', MINUS_5h,
   /*Sun*/ D'2035.03.11 07:00:00', /*Sun*/ D'2035.03.11 03:00:00', MINUS_4h,    /*Sun*/ D'2035.11.04 06:00:00', /*Sun*/ D'2035.11.04 01:00:00', MINUS_5h,
   /*Sun*/ D'2036.03.09 07:00:00', /*Sun*/ D'2036.03.09 03:00:00', MINUS_4h,    /*Sun*/ D'2036.11.02 06:00:00', /*Sun*/ D'2036.11.02 01:00:00', MINUS_5h,
   /*Sun*/ D'2037.03.08 07:00:00', /*Sun*/ D'2037.03.08 03:00:00', MINUS_4h,    /*Sun*/ D'2037.11.01 06:00:00', /*Sun*/ D'2037.11.01 01:00:00', MINUS_5h,
};


// FXT: GMT+0200/+0300 mit Umschaltzeiten von America/New_York
int transitions.FXT[68][6] = {
   // Wechsel zu DST                                               DST-Offset   // Wechsel zu Normalzeit                                        Std-Offset
   /*Sun*/ D'1970.04.26 07:00:00', /*Sun*/ D'1970.04.26 10:00:00', PLUS_3h,     /*Sun*/ D'1970.10.25 06:00:00', /*Sun*/ D'1970.10.25 08:00:00', PLUS_2h,
   /*Sun*/ D'1971.04.25 07:00:00', /*Sun*/ D'1971.04.25 10:00:00', PLUS_3h,     /*Sun*/ D'1971.10.31 06:00:00', /*Sun*/ D'1971.10.31 08:00:00', PLUS_2h,
   /*Sun*/ D'1972.04.30 07:00:00', /*Sun*/ D'1972.04.30 10:00:00', PLUS_3h,     /*Sun*/ D'1972.10.29 06:00:00', /*Sun*/ D'1972.10.29 08:00:00', PLUS_2h,
   /*Sun*/ D'1973.04.29 07:00:00', /*Sun*/ D'1973.04.29 10:00:00', PLUS_3h,     /*Sun*/ D'1973.10.28 06:00:00', /*Sun*/ D'1973.10.28 08:00:00', PLUS_2h,
   /*Sun*/ D'1974.01.06 07:00:00', /*Sun*/ D'1974.01.06 10:00:00', PLUS_3h,     /*Sun*/ D'1974.10.27 06:00:00', /*Sun*/ D'1974.10.27 08:00:00', PLUS_2h,
   /*Sun*/ D'1975.02.23 07:00:00', /*Sun*/ D'1975.02.23 10:00:00', PLUS_3h,     /*Sun*/ D'1975.10.26 06:00:00', /*Sun*/ D'1975.10.26 08:00:00', PLUS_2h,
   /*Sun*/ D'1976.04.25 07:00:00', /*Sun*/ D'1976.04.25 10:00:00', PLUS_3h,     /*Sun*/ D'1976.10.31 06:00:00', /*Sun*/ D'1976.10.31 08:00:00', PLUS_2h,
   /*Sun*/ D'1977.04.24 07:00:00', /*Sun*/ D'1977.04.24 10:00:00', PLUS_3h,     /*Sun*/ D'1977.10.30 06:00:00', /*Sun*/ D'1977.10.30 08:00:00', PLUS_2h,
   /*Sun*/ D'1978.04.30 07:00:00', /*Sun*/ D'1978.04.30 10:00:00', PLUS_3h,     /*Sun*/ D'1978.10.29 06:00:00', /*Sun*/ D'1978.10.29 08:00:00', PLUS_2h,
   /*Sun*/ D'1979.04.29 07:00:00', /*Sun*/ D'1979.04.29 10:00:00', PLUS_3h,     /*Sun*/ D'1979.10.28 06:00:00', /*Sun*/ D'1979.10.28 08:00:00', PLUS_2h,
   /*Sun*/ D'1980.04.27 07:00:00', /*Sun*/ D'1980.04.27 10:00:00', PLUS_3h,     /*Sun*/ D'1980.10.26 06:00:00', /*Sun*/ D'1980.10.26 08:00:00', PLUS_2h,
   /*Sun*/ D'1981.04.26 07:00:00', /*Sun*/ D'1981.04.26 10:00:00', PLUS_3h,     /*Sun*/ D'1981.10.25 06:00:00', /*Sun*/ D'1981.10.25 08:00:00', PLUS_2h,
   /*Sun*/ D'1982.04.25 07:00:00', /*Sun*/ D'1982.04.25 10:00:00', PLUS_3h,     /*Sun*/ D'1982.10.31 06:00:00', /*Sun*/ D'1982.10.31 08:00:00', PLUS_2h,
   /*Sun*/ D'1983.04.24 07:00:00', /*Sun*/ D'1983.04.24 10:00:00', PLUS_3h,     /*Sun*/ D'1983.10.30 06:00:00', /*Sun*/ D'1983.10.30 08:00:00', PLUS_2h,
   /*Sun*/ D'1984.04.29 07:00:00', /*Sun*/ D'1984.04.29 10:00:00', PLUS_3h,     /*Sun*/ D'1984.10.28 06:00:00', /*Sun*/ D'1984.10.28 08:00:00', PLUS_2h,
   /*Sun*/ D'1985.04.28 07:00:00', /*Sun*/ D'1985.04.28 10:00:00', PLUS_3h,     /*Sun*/ D'1985.10.27 06:00:00', /*Sun*/ D'1985.10.27 08:00:00', PLUS_2h,
   /*Sun*/ D'1986.04.27 07:00:00', /*Sun*/ D'1986.04.27 10:00:00', PLUS_3h,     /*Sun*/ D'1986.10.26 06:00:00', /*Sun*/ D'1986.10.26 08:00:00', PLUS_2h,
   /*Sun*/ D'1987.04.05 07:00:00', /*Sun*/ D'1987.04.05 10:00:00', PLUS_3h,     /*Sun*/ D'1987.10.25 06:00:00', /*Sun*/ D'1987.10.25 08:00:00', PLUS_2h,
   /*Sun*/ D'1988.04.03 07:00:00', /*Sun*/ D'1988.04.03 10:00:00', PLUS_3h,     /*Sun*/ D'1988.10.30 06:00:00', /*Sun*/ D'1988.10.30 08:00:00', PLUS_2h,
   /*Sun*/ D'1989.04.02 07:00:00', /*Sun*/ D'1989.04.02 10:00:00', PLUS_3h,     /*Sun*/ D'1989.10.29 06:00:00', /*Sun*/ D'1989.10.29 08:00:00', PLUS_2h,
   /*Sun*/ D'1990.04.01 07:00:00', /*Sun*/ D'1990.04.01 10:00:00', PLUS_3h,     /*Sun*/ D'1990.10.28 06:00:00', /*Sun*/ D'1990.10.28 08:00:00', PLUS_2h,
   /*Sun*/ D'1991.04.07 07:00:00', /*Sun*/ D'1991.04.07 10:00:00', PLUS_3h,     /*Sun*/ D'1991.10.27 06:00:00', /*Sun*/ D'1991.10.27 08:00:00', PLUS_2h,
   /*Sun*/ D'1992.04.05 07:00:00', /*Sun*/ D'1992.04.05 10:00:00', PLUS_3h,     /*Sun*/ D'1992.10.25 06:00:00', /*Sun*/ D'1992.10.25 08:00:00', PLUS_2h,
   /*Sun*/ D'1993.04.04 07:00:00', /*Sun*/ D'1993.04.04 10:00:00', PLUS_3h,     /*Sun*/ D'1993.10.31 06:00:00', /*Sun*/ D'1993.10.31 08:00:00', PLUS_2h,
   /*Sun*/ D'1994.04.03 07:00:00', /*Sun*/ D'1994.04.03 10:00:00', PLUS_3h,     /*Sun*/ D'1994.10.30 06:00:00', /*Sun*/ D'1994.10.30 08:00:00', PLUS_2h,
   /*Sun*/ D'1995.04.02 07:00:00', /*Sun*/ D'1995.04.02 10:00:00', PLUS_3h,     /*Sun*/ D'1995.10.29 06:00:00', /*Sun*/ D'1995.10.29 08:00:00', PLUS_2h,
   /*Sun*/ D'1996.04.07 07:00:00', /*Sun*/ D'1996.04.07 10:00:00', PLUS_3h,     /*Sun*/ D'1996.10.27 06:00:00', /*Sun*/ D'1996.10.27 08:00:00', PLUS_2h,
   /*Sun*/ D'1997.04.06 07:00:00', /*Sun*/ D'1997.04.06 10:00:00', PLUS_3h,     /*Sun*/ D'1997.10.26 06:00:00', /*Sun*/ D'1997.10.26 08:00:00', PLUS_2h,
   /*Sun*/ D'1998.04.05 07:00:00', /*Sun*/ D'1998.04.05 10:00:00', PLUS_3h,     /*Sun*/ D'1998.10.25 06:00:00', /*Sun*/ D'1998.10.25 08:00:00', PLUS_2h,
   /*Sun*/ D'1999.04.04 07:00:00', /*Sun*/ D'1999.04.04 10:00:00', PLUS_3h,     /*Sun*/ D'1999.10.31 06:00:00', /*Sun*/ D'1999.10.31 08:00:00', PLUS_2h,
   /*Sun*/ D'2000.04.02 07:00:00', /*Sun*/ D'2000.04.02 10:00:00', PLUS_3h,     /*Sun*/ D'2000.10.29 06:00:00', /*Sun*/ D'2000.10.29 08:00:00', PLUS_2h,
   /*Sun*/ D'2001.04.01 07:00:00', /*Sun*/ D'2001.04.01 10:00:00', PLUS_3h,     /*Sun*/ D'2001.10.28 06:00:00', /*Sun*/ D'2001.10.28 08:00:00', PLUS_2h,
   /*Sun*/ D'2002.04.07 07:00:00', /*Sun*/ D'2002.04.07 10:00:00', PLUS_3h,     /*Sun*/ D'2002.10.27 06:00:00', /*Sun*/ D'2002.10.27 08:00:00', PLUS_2h,
   /*Sun*/ D'2003.04.06 07:00:00', /*Sun*/ D'2003.04.06 10:00:00', PLUS_3h,     /*Sun*/ D'2003.10.26 06:00:00', /*Sun*/ D'2003.10.26 08:00:00', PLUS_2h,
   /*Sun*/ D'2004.04.04 07:00:00', /*Sun*/ D'2004.04.04 10:00:00', PLUS_3h,     /*Sun*/ D'2004.10.31 06:00:00', /*Sun*/ D'2004.10.31 08:00:00', PLUS_2h,
   /*Sun*/ D'2005.04.03 07:00:00', /*Sun*/ D'2005.04.03 10:00:00', PLUS_3h,     /*Sun*/ D'2005.10.30 06:00:00', /*Sun*/ D'2005.10.30 08:00:00', PLUS_2h,
   /*Sun*/ D'2006.04.02 07:00:00', /*Sun*/ D'2006.04.02 10:00:00', PLUS_3h,     /*Sun*/ D'2006.10.29 06:00:00', /*Sun*/ D'2006.10.29 08:00:00', PLUS_2h,
   /*Sun*/ D'2007.03.11 07:00:00', /*Sun*/ D'2007.03.11 10:00:00', PLUS_3h,     /*Sun*/ D'2007.11.04 06:00:00', /*Sun*/ D'2007.11.04 08:00:00', PLUS_2h,
   /*Sun*/ D'2008.03.09 07:00:00', /*Sun*/ D'2008.03.09 10:00:00', PLUS_3h,     /*Sun*/ D'2008.11.02 06:00:00', /*Sun*/ D'2008.11.02 08:00:00', PLUS_2h,
   /*Sun*/ D'2009.03.08 07:00:00', /*Sun*/ D'2009.03.08 10:00:00', PLUS_3h,     /*Sun*/ D'2009.11.01 06:00:00', /*Sun*/ D'2009.11.01 08:00:00', PLUS_2h,
   /*Sun*/ D'2010.03.14 07:00:00', /*Sun*/ D'2010.03.14 10:00:00', PLUS_3h,     /*Sun*/ D'2010.11.07 06:00:00', /*Sun*/ D'2010.11.07 08:00:00', PLUS_2h,
   /*Sun*/ D'2011.03.13 07:00:00', /*Sun*/ D'2011.03.13 10:00:00', PLUS_3h,     /*Sun*/ D'2011.11.06 06:00:00', /*Sun*/ D'2011.11.06 08:00:00', PLUS_2h,
   /*Sun*/ D'2012.03.11 07:00:00', /*Sun*/ D'2012.03.11 10:00:00', PLUS_3h,     /*Sun*/ D'2012.11.04 06:00:00', /*Sun*/ D'2012.11.04 08:00:00', PLUS_2h,
   /*Sun*/ D'2013.03.10 07:00:00', /*Sun*/ D'2013.03.10 10:00:00', PLUS_3h,     /*Sun*/ D'2013.11.03 06:00:00', /*Sun*/ D'2013.11.03 08:00:00', PLUS_2h,
   /*Sun*/ D'2014.03.09 07:00:00', /*Sun*/ D'2014.03.09 10:00:00', PLUS_3h,     /*Sun*/ D'2014.11.02 06:00:00', /*Sun*/ D'2014.11.02 08:00:00', PLUS_2h,
   /*Sun*/ D'2015.03.08 07:00:00', /*Sun*/ D'2015.03.08 10:00:00', PLUS_3h,     /*Sun*/ D'2015.11.01 06:00:00', /*Sun*/ D'2015.11.01 08:00:00', PLUS_2h,
   /*Sun*/ D'2016.03.13 07:00:00', /*Sun*/ D'2016.03.13 10:00:00', PLUS_3h,     /*Sun*/ D'2016.11.06 06:00:00', /*Sun*/ D'2016.11.06 08:00:00', PLUS_2h,
   /*Sun*/ D'2017.03.12 07:00:00', /*Sun*/ D'2017.03.12 10:00:00', PLUS_3h,     /*Sun*/ D'2017.11.05 06:00:00', /*Sun*/ D'2017.11.05 08:00:00', PLUS_2h,
   /*Sun*/ D'2018.03.11 07:00:00', /*Sun*/ D'2018.03.11 10:00:00', PLUS_3h,     /*Sun*/ D'2018.11.04 06:00:00', /*Sun*/ D'2018.11.04 08:00:00', PLUS_2h,
   /*Sun*/ D'2019.03.10 07:00:00', /*Sun*/ D'2019.03.10 10:00:00', PLUS_3h,     /*Sun*/ D'2019.11.03 06:00:00', /*Sun*/ D'2019.11.03 08:00:00', PLUS_2h,
   /*Sun*/ D'2020.03.08 07:00:00', /*Sun*/ D'2020.03.08 10:00:00', PLUS_3h,     /*Sun*/ D'2020.11.01 06:00:00', /*Sun*/ D'2020.11.01 08:00:00', PLUS_2h,
   /*Sun*/ D'2021.03.14 07:00:00', /*Sun*/ D'2021.03.14 10:00:00', PLUS_3h,     /*Sun*/ D'2021.11.07 06:00:00', /*Sun*/ D'2021.11.07 08:00:00', PLUS_2h,
   /*Sun*/ D'2022.03.13 07:00:00', /*Sun*/ D'2022.03.13 10:00:00', PLUS_3h,     /*Sun*/ D'2022.11.06 06:00:00', /*Sun*/ D'2022.11.06 08:00:00', PLUS_2h,
   /*Sun*/ D'2023.03.12 07:00:00', /*Sun*/ D'2023.03.12 10:00:00', PLUS_3h,     /*Sun*/ D'2023.11.05 06:00:00', /*Sun*/ D'2023.11.05 08:00:00', PLUS_2h,
   /*Sun*/ D'2024.03.10 07:00:00', /*Sun*/ D'2024.03.10 10:00:00', PLUS_3h,     /*Sun*/ D'2024.11.03 06:00:00', /*Sun*/ D'2024.11.03 08:00:00', PLUS_2h,
   /*Sun*/ D'2025.03.09 07:00:00', /*Sun*/ D'2025.03.09 10:00:00', PLUS_3h,     /*Sun*/ D'2025.11.02 06:00:00', /*Sun*/ D'2025.11.02 08:00:00', PLUS_2h,
   /*Sun*/ D'2026.03.08 07:00:00', /*Sun*/ D'2026.03.08 10:00:00', PLUS_3h,     /*Sun*/ D'2026.11.01 06:00:00', /*Sun*/ D'2026.11.01 08:00:00', PLUS_2h,
   /*Sun*/ D'2027.03.14 07:00:00', /*Sun*/ D'2027.03.14 10:00:00', PLUS_3h,     /*Sun*/ D'2027.11.07 06:00:00', /*Sun*/ D'2027.11.07 08:00:00', PLUS_2h,
   /*Sun*/ D'2028.03.12 07:00:00', /*Sun*/ D'2028.03.12 10:00:00', PLUS_3h,     /*Sun*/ D'2028.11.05 06:00:00', /*Sun*/ D'2028.11.05 08:00:00', PLUS_2h,
   /*Sun*/ D'2029.03.11 07:00:00', /*Sun*/ D'2029.03.11 10:00:00', PLUS_3h,     /*Sun*/ D'2029.11.04 06:00:00', /*Sun*/ D'2029.11.04 08:00:00', PLUS_2h,
   /*Sun*/ D'2030.03.10 07:00:00', /*Sun*/ D'2030.03.10 10:00:00', PLUS_3h,     /*Sun*/ D'2030.11.03 06:00:00', /*Sun*/ D'2030.11.03 08:00:00', PLUS_2h,
   /*Sun*/ D'2031.03.09 07:00:00', /*Sun*/ D'2031.03.09 10:00:00', PLUS_3h,     /*Sun*/ D'2031.11.02 06:00:00', /*Sun*/ D'2031.11.02 08:00:00', PLUS_2h,
   /*Sun*/ D'2032.03.14 07:00:00', /*Sun*/ D'2032.03.14 10:00:00', PLUS_3h,     /*Sun*/ D'2032.11.07 06:00:00', /*Sun*/ D'2032.11.07 08:00:00', PLUS_2h,
   /*Sun*/ D'2033.03.13 07:00:00', /*Sun*/ D'2033.03.13 10:00:00', PLUS_3h,     /*Sun*/ D'2033.11.06 06:00:00', /*Sun*/ D'2033.11.06 08:00:00', PLUS_2h,
   /*Sun*/ D'2034.03.12 07:00:00', /*Sun*/ D'2034.03.12 10:00:00', PLUS_3h,     /*Sun*/ D'2034.11.05 06:00:00', /*Sun*/ D'2034.11.05 08:00:00', PLUS_2h,
   /*Sun*/ D'2035.03.11 07:00:00', /*Sun*/ D'2035.03.11 10:00:00', PLUS_3h,     /*Sun*/ D'2035.11.04 06:00:00', /*Sun*/ D'2035.11.04 08:00:00', PLUS_2h,
   /*Sun*/ D'2036.03.09 07:00:00', /*Sun*/ D'2036.03.09 10:00:00', PLUS_3h,     /*Sun*/ D'2036.11.02 06:00:00', /*Sun*/ D'2036.11.02 08:00:00', PLUS_2h,
   /*Sun*/ D'2037.03.08 07:00:00', /*Sun*/ D'2037.03.08 10:00:00', PLUS_3h,     /*Sun*/ D'2037.11.01 06:00:00', /*Sun*/ D'2037.11.01 08:00:00', PLUS_2h,
};
