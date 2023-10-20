/**
 * Management of single history files (1 timeframe) and full history sets (9 timeframes).
 *
 *
 * Usage examples
 * --------------
 *  - Open an existing history (all timeframes) with existing data (e.g. for appending data):
 *     int hSet = HistorySet2.Get(symbol);
 *
 *  - Create a new history and delete all existing data (e.g. for writing a new history):
 *     int hSet = HistorySet2.Create(symbol, description, digits, format);
 *
 *  - How to synchronize rsfHistory{1-3}.mq4:
 *     search:  (HistoryFile|HistorySet)[1-3]\>
 *     replace: \11 or \12 or \13
 *
 *
 * Notes:
 * ------
 *  - The MQL4 language in terminal builds <= 509 imposes a limit of 16 open files per MQL module. In terminal builds > 509
 *    this limit was extended to 64 open files per MQL module. It means older terminals can manage max. 1 full history set
 *    and newer terminals max. 7 full history sets per MQL module. For some use cases this is still not sufficient.
 *    To overcome this limits there are 3 fully identical history libraries, extending the limits for newer terminal builds
 *    to max. 21 full history sets per MQL program.
 *
 *  - Since terminal builds > 509 MT4 supports two history file formats. The format is identified in history files by the
 *    field HISTORY_HEADER.barFormat. The default bar format in builds <= 509 is "400" and in builds > 509 "401".
 *    Builds <= 509 can only read/write format "400". Builds > 509 can read both formats but write only format "401".
 *
 *  - If a terminal build <= 509 accesses history files in new format (401) it will delete those files on shutdown.
 *
 *  - If a terminal build > 509 accesses history files in old format (400) it will convert them to the new format (401) except
 *    offline history files for custom symbols. Such offline history files will not be converted.
 *
 *  @see  https://github.com/rosasurfer/mt4-expander/blob/master/header/struct/mt4/HistoryHeader.h
 */
#property library

#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];
#include <core/library.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/InitializeByteBuffer.mqh>
#include <structs/mt4/HistoryHeader.mqh>


// Standard-Timeframes ------------------------------------------------------------------------------------------------------------------------------------
int      periods[] = { PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1 };


// Daten kompletter History-Sets --------------------------------------------------------------------------------------------------------------------------
int      hs.hSet       [];                            // Set-Handle: gr��er 0 = offenes Handle; kleiner 0 = geschlossenes Handle; 0 = ung�ltiges Handle
int      hs.hSet.lastValid;                           // das letzte g�ltige, offene Handle (um ein �bergebenes Handle nicht st�ndig neu validieren zu m�ssen)
string   hs.symbol     [];                            // Symbol
string   hs.symbolU    [];                            // Symbol (Upper-Case)
string   hs.description[];                            // Beschreibung
int      hs.digits     [];                            // Symbol-Digits
string   hs.directory  [];                            // Speicherverzeichnis des Sets
int      hs.hFile      [][9];                         // HistoryFile-Handles des Sets je Standard-Timeframe
int      hs.format     [];                            // Datenformat f�r neu zu erstellende HistoryFiles


// Daten einzelner History-Files --------------------------------------------------------------------------------------------------------------------------
int      hf.hFile      [];                            // Dateihandle: gr��er 0 = offenes Handle; kleiner 0 = geschlossenes Handle; 0 = ung�ltiges Handle
int      hf.hFile.lastValid;                          // das letzte g�ltige, offene Handle (um ein �bergebenes Handle nicht st�ndig neu validieren zu m�ssen)
string   hf.name       [];                            // Dateiname, ggf. mit Unterverzeichnis "XTrade-Synthetic\"
bool     hf.readAccess [];                            // ob das Handle Lese-Zugriff erlaubt
bool     hf.writeAccess[];                            // ob das Handle Schreib-Zugriff erlaubt

int      hf.header     [][HISTORY_HEADER_intSize];    // History-Header der Datei
int      hf.format     [];                            // Datenformat: 400 | 401
int      hf.barSize    [];                            // Gr��e einer Bar entsprechend dem Datenformat
string   hf.symbol     [];                            // Symbol
string   hf.symbolU    [];                            // Symbol (Upper-Case)
int      hf.period     [];                            // Periode
int      hf.periodSecs [];                            // Dauer einer Periode in Sekunden (nicht g�ltig f�r Perioden > 1 Woche)
int      hf.digits     [];                            // Digits
string   hf.directory  [];                            // Speicherverzeichnis der Datei

int      hf.stored.bars              [];              // Metadaten: Anzahl der gespeicherten Bars der Datei
int      hf.stored.from.offset       [];              // Offset der ersten gespeicherten Bar der Datei
datetime hf.stored.from.openTime     [];              // OpenTime der ersten gespeicherten Bar der Datei
datetime hf.stored.from.closeTime    [];              // CloseTime der ersten gespeicherten Bar der Datei
datetime hf.stored.from.nextCloseTime[];              // CloseTime der der ersten gespeicherten Bar der Datei folgenden Bar
int      hf.stored.to.offset         [];              // Offset der letzten gespeicherten Bar der Datei
datetime hf.stored.to.openTime       [];              // OpenTime der letzten gespeicherten Bar der Datei
datetime hf.stored.to.closeTime      [];              // CloseTime der letzten gespeicherten Bar der Datei
datetime hf.stored.to.nextCloseTime  [];              // CloseTime der der letzten gespeicherten Bar der Datei folgenden Bar

int      hf.total.bars              [];               // Metadaten: Anzahl der Bars der Datei inkl. ungespeicherter Daten im Schreibpuffer
int      hf.total.from.offset       [];               // Offset der ersten Bar der Datei inkl. ungespeicherter Daten im Schreibpuffer
datetime hf.total.from.openTime     [];               // OpenTime der ersten Bar der Datei inkl. ungespeicherter Daten im Schreibpuffer
datetime hf.total.from.closeTime    [];               // CloseTime der ersten Bar der Datei inkl. ungespeicherter Daten im Schreibpuffer
datetime hf.total.from.nextCloseTime[];               // CloseTime der der ersten Bar der Datei inkl. ungespeicherter Daten im Schreibpuffer folgenden Bar
int      hf.total.to.offset         [];               // Offset der letzten Bar der Datei inkl. ungespeicherter Daten im Schreibpuffer
datetime hf.total.to.openTime       [];               // OpenTime der letzten Bar der Datei inkl. ungespeicherter Daten im Schreibpuffer
datetime hf.total.to.closeTime      [];               // CloseTime der letzten Bar der Datei inkl. ungespeicherter Daten im Schreibpuffer
datetime hf.total.to.nextCloseTime  [];               // CloseTime dre der letzten Bar der Datei inkl. ungespeicherter Daten im Schreibpuffer folgenden Bar


// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
// Cache der Bar, die in der Historydatei zuletzt gelesen oder geschrieben wurde (eine beliebige in der Datei existierende Bar).
//
// (1) Beim Aktualisieren dieser Bar mit neuen Ticks braucht die Bar nicht jedesmal neu eingelesen werden: siehe HistoryFile2.UpdateBar().
// (2) Bei funktions�bergreifenden Abl�ufen mu� diese Bar nicht �berall als Parameter durchgeschleift werden (durch unterschiedliche Arraydimensionen schwierig).
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
int      hf.lastStoredBar.offset       [];            // Offset relativ zum Header: Offset 0 ist die �lteste Bar, initialisiert mit -1
datetime hf.lastStoredBar.openTime     [];            // z.B. 12:00:00      |                  time < openTime:      time liegt irgendwo in einer vorherigen Bar
datetime hf.lastStoredBar.closeTime    [];            //      13:00:00      |      openTime <= time < closeTime:     time liegt genau in der Bar
datetime hf.lastStoredBar.nextCloseTime[];            //      14:00:00      |     closeTime <= time < nextCloseTime: time liegt genau in der n�chsten Bar
double   hf.lastStoredBar.data         [][6];         // Bardaten (T-OHLCV) | nextCloseTime <= time:                 time liegt irgendwo vor der n�chsten Bar


// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
// Schreibpuffer f�r eintreffende Ticks einer bereits gespeicherten oder noch nicht gespeicherten Bar. Die Variable hf.bufferedBar.modified signalisiert, ob die
// Bardaten in hf.bufferedBar von den in der Datei gespeicherten Daten abweichen.
//
// (1) Diese Bar stimmt mit hf.lastStoredBar nur dann �berein, wenn hf.lastStoredBar die j�ngste Bar der Datei ist und mit HST_BUFFER_TICKS=On weitere Ticks f�r diese
//     j�ngste Bar gepuffert werden. Stimmen beide Bars �berein, werden sie bei �nderungen an einer der Bars jeweils synchronisiert.
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
int      hf.bufferedBar.offset       [];              // Offset relativ zum Header: Offset 0 ist die �lteste Bar, initialisiert mit -1
datetime hf.bufferedBar.openTime     [];              // z.B. 12:00:00      |                  time < openTime:      time liegt irgendwo in einer vorherigen Bar
datetime hf.bufferedBar.closeTime    [];              //      13:00:00      |      openTime <= time < closeTime:     time liegt genau in der Bar
datetime hf.bufferedBar.nextCloseTime[];              //      14:00:00      |     closeTime <= time < nextCloseTime: time liegt genau in der n�chsten Bar
double   hf.bufferedBar.data         [][6];           // Bardaten (T-OHLCV) | nextCloseTime <= time:                 time liegt irgendwo vor der n�chsten Bar
bool     hf.bufferedBar.modified     [];              // ob die Daten seit dem letzten Schreiben modifiziert wurden


/**
 * Create a new history set for the specified symbol and return its handle. Existing history files are reset, open history
 * files are closed. Not existing history files are created once new history data is appended. Multiple calls for the same
 * symbol return a new handle on every call. Previously open history set handles are closed.
 *
 * @param  string symbol               - symbol
 * @param  string description          - symbol description
 * @param  int    digits               - digits of the timeseries
 * @param  int    format               - bar format of the timeseries, one of
 *                                        400: compatible with all MetaTrader builds
 *                                        401: compatible with MetaTrader builds > 509 only
 * @param  string directory [optional] - directory to store history files in
 *                                        if empty:            the current trade server directory (default)
 *                                        if a relative path:  relative to the MQL sandbox/files directory
 *                                        if an absolute path: as is
 *
 * @return int - history set handle or NULL (0) in case of errors
 */
int HistorySet2.Create(string symbol, string description, int digits, int format, string directory = "") {
   // validate parameters
   if (!StringLen(symbol))                    return(!catch("HistorySet2.Create(1)  invalid parameter symbol: "+ DoubleQuoteStr(symbol), ERR_INVALID_PARAMETER));
   if (StringLen(symbol) > MAX_SYMBOL_LENGTH) return(!catch("HistorySet2.Create(2)  invalid parameter symbol: "+ DoubleQuoteStr(symbol) +" (max "+ MAX_SYMBOL_LENGTH +" characters)", ERR_INVALID_PARAMETER));
   if (StrContains(symbol, " "))              return(!catch("HistorySet2.Create(3)  invalid parameter symbol: "+ DoubleQuoteStr(symbol) +" (must not contain spaces)", ERR_INVALID_PARAMETER));
   string symbolU = StrToUpper(symbol);
   if (StringLen(description) > 63) {             logNotice("HistorySet2.Create(4)  truncating too long history description "+ DoubleQuoteStr(description) +" to 63 chars...");
      description = StrLeft(description, 63);
   }
   if (digits < 0)                            return(!catch("HistorySet2.Create(5)  invalid parameter digits: "+ digits +" (symbol="+ DoubleQuoteStr(symbol) +")", ERR_INVALID_PARAMETER));
   if (format!=400 && format!=401)            return(!catch("HistorySet2.Create(6)  invalid parameter format: "+ format +" (must be 400 or 401, symbol="+ DoubleQuoteStr(symbol) +")", ERR_INVALID_PARAMETER));
   if (directory == "0") directory = "";                                // (string) NULL

   // check open HistorySets of the same symbol and close them
   int size = ArraySize(hs.hSet);
   for (int i=0; i < size; i++) {
      if (hs.hSet[i] > 0) /*&&*/ if (hs.symbolU[i]==symbolU) /*&&*/ if (StrCompareI(hs.directory[i], directory)) {
         if (hs.hSet.lastValid == hs.hSet[i])
            hs.hSet.lastValid = NULL;
         hs.hSet[i] = -1;                                               // mark open sets of the same symbol as closed

         size = ArrayRange(hs.hFile, 1);
         for (int n=0; n < size; n++) {
            if (hs.hFile[i][n] > 0) {
               if (!HistoryFile2.Close(hs.hFile[i][n])) return(NULL);   // close open files of the just closed set
               hs.hFile[i][n] = -1;
            }
         }
      }
   }

   // check open HistoryFiles of the same symbol and close them
   size = ArraySize(hf.hFile);
   for (i=0; i < size; i++) {
      if (hf.hFile[i] > 0) /*&&*/ if (hf.symbolU[i]==symbolU) /*&&*/ if (StrCompareI(hf.directory[i], directory)){
         if (!HistoryFile2.Close(hf.hFile[i])) return(NULL);
      }
   }

   // reset existing HistoryFiles of the same symbol and update their headers
   int hFile, hh[], error, sizeOfPeriods = ArraySize(periods);
   string filename = "", basename = "";

   InitializeByteBuffer(hh, HISTORY_HEADER_size);
   hh_SetBarFormat  (hh, format     );
   hh_SetDescription(hh, description);
   hh_SetSymbol     (hh, symbol     );
   hh_SetDigits     (hh, digits     );

   if (directory == "") {                                               // current trade server, use MQL::FileOpenHistory()
      string serverPath = GetAccountServerPath();
      if (!UseTradeServerPath(serverPath, "HistorySet2.Create(7)")) return(NULL);

      for (i=0; i < sizeOfPeriods; i++) {
         basename = StringConcatenate(symbol, periods[i], ".hst");
         filename = StringConcatenate(serverPath, "/", basename);

         if (IsFile(filename, MODE_SYSTEM)) {                           // reset existing file to 0
            hFile = FileOpenHistory(basename, FILE_WRITE|FILE_BIN);
            if (hFile <= 0) return(!catch("HistorySet2.Create(8)->FileOpenHistory(\""+ basename +"\", FILE_WRITE) => "+ hFile, intOr(GetLastError(), ERR_RUNTIME_ERROR)));

            hh_SetPeriod(hh, periods[i]);
            FileWriteArray(hFile, hh, 0, ArraySize(hh));                // write new HISTORY_HEADER
            FileClose(hFile);
            error = GetLastError();
            if (error != NO_ERROR) return(!catch("HistorySet2.Create(9)  symbol="+ DoubleQuoteStr(symbol), error));
         }
      }
   }

   else if (!IsAbsolutePath(directory)) {                               // relative sandbox path, use MQL::FileOpen()
      if (!UseTradeServerPath(directory, "HistorySet2.Create(10)")) return(NULL);

      for (i=0; i < sizeOfPeriods; i++) {
         filename = StringConcatenate(directory, "/", symbol, periods[i], ".hst");

         if (IsFile(filename, MODE_MQL)) {                              // reset existing file to 0
            hFile = FileOpen(filename, FILE_BIN|FILE_WRITE);
            if (hFile <= 0) return(!catch("HistorySet2.Create(11)->FileOpen(\""+ filename +"\") => "+ hFile, intOr(GetLastError(), ERR_RUNTIME_ERROR)));

            hh_SetPeriod(hh, periods[i]);
            FileWriteArray(hFile, hh, 0, ArraySize(hh));                // write new HISTORY_HEADER
            FileClose(hFile);
            error = GetLastError();
            if (error != NO_ERROR) return(!catch("HistorySet2.Create(12)  symbol="+ DoubleQuoteStr(symbol), error));
         }
      }
   }

   else {                                                               // absolute path, use Expander
      return(!catch("HistorySet2.Create(13)  accessing absolute path \""+ directory +"\" not yet implemented", ERR_NOT_IMPLEMENTED));
   }

   ArrayResize(hh, 0);

   // create a new HistorySet
   size = Max(ArraySize(hs.hSet), 1) + 1;                               // min. sizeof(hs.hSet)=2 as index[0] can't hold a handle
   __ResizeSetArrays(size);
   int iH   = size-1;
   int hSet = iH;                                                       // the HistorySet handle matches the array index of hs.*

   hs.hSet       [iH] = hSet;
   hs.symbol     [iH] = symbol;
   hs.symbolU    [iH] = symbolU;
   hs.description[iH] = description;
   hs.digits     [iH] = digits;
   hs.directory  [iH] = directory;
   hs.format     [iH] = format;

   return(hSet);
}


/**
 * Return a handle for a symbol's full set of history files (9 timeframes). Requires at least one of the 9 files to exist.
 * Non-existing files will be created once new data is added with HistorySet.AddTick(). The default bar format for new files
 * is "400" (if not specified otherwise). Multiple calls for the same symbol return the same handle. Calling this function
 * doesn't keep files open or locked.
 *
 * @param  string symbol               - symbol
 * @param  string directory [optional] - directory to read history files from
 *                                        if empty:            the current trade server directory (default)
 *                                        if a relative path:  relative to the MQL sandbox/files directory
 *                                        if an absolute path: as is
 *
 * @return int - history set handle or EMPTY (-1) if none of the 9 history files exists. Use HistorySet.Create() in this case.
 *               NULL in case of errors.
 */
int HistorySet2.Get(string symbol, string directory = "") {
   if (!StringLen(symbol))                    return(!catch("HistorySet2.Get(1)  invalid parameter symbol: "+ DoubleQuoteStr(symbol), ERR_INVALID_PARAMETER));
   if (StringLen(symbol) > MAX_SYMBOL_LENGTH) return(!catch("HistorySet2.Get(2)  invalid parameter symbol: "+ DoubleQuoteStr(symbol) +" (max "+ MAX_SYMBOL_LENGTH +" chars)", ERR_INVALID_PARAMETER));
   if (StrContains(symbol, " "))              return(!catch("HistorySet2.Get(3)  invalid parameter symbol: "+ DoubleQuoteStr(symbol) +" (must not contain spaces)", ERR_INVALID_PARAMETER));
   string symbolU = StrToUpper(symbol);
   if (directory == "0") directory = "";                             // (string) NULL

   // check open history sets of the same symbol
   int size = ArraySize(hs.hSet), iH, hSet=-1;
   for (int i=0; i < size; i++) {
      if (hs.hSet[i] > 0) /*&&*/ if (hs.symbolU[i]==symbolU) /*&&*/ if (StrCompareI(hs.directory[i], directory))
         return(hs.hSet[i]);
   }

   // check open history files of the same symbol
   size = ArraySize(hf.hFile);
   for (i=0; i < size; i++) {
      if (hf.hFile[i] > 0) /*&&*/ if (hf.symbolU[i]==symbolU) /*&&*/ if (StrCompareI(hf.directory[i], directory)) {
         size = Max(ArraySize(hs.hSet), 1) + 1;                      // open handle found: create new HistorySet (min. sizeof(hs.hSet)=2 as index[0] can't hold a handle)
         __ResizeSetArrays(size);
         iH   = size-1;
         hSet = iH;                                                  // the HistorySet handle matches the array index of hs.*
         hs.hSet       [iH] = hSet;
         hs.symbol     [iH] = hf.symbol   [i];
         hs.symbolU    [iH] = hf.symbolU  [i];
         hs.description[iH] = hhs_Description(hf.header, i);
         hs.digits     [iH] = hf.digits   [i];
         hs.directory  [iH] = hf.directory[i];
         hs.format     [iH] = 400;                                   // default bar format for non-existing files
         return(hSet);
      }
   }

   // look-up existing history files
   int sizeOfPeriods = ArraySize(periods), hFile, fileSize, hh[];
   string filename = "";

   if (directory == "") {                                            // current trade server, use MQL::FileOpenHistory()
      string serverPath = GetAccountServerPath();

      for (i=0; i < sizeOfPeriods; i++) {
         filename = StringConcatenate(serverPath, "/", symbol, periods[i], ".hst");

         if (IsFile(filename, MODE_SYSTEM)) {                        // without the additional check FileOpenHistory(READ) logs a warning if the file doesn't exist
            hFile = FileOpenHistory(filename, FILE_READ|FILE_BIN);   // open the file
            if (hFile <= 0) return(!catch("HistorySet2.Get(4)->FileOpenHistory(\""+ filename +"\", FILE_READ) => "+ hFile, intOr(GetLastError(), ERR_RUNTIME_ERROR)));

            fileSize = FileSize(hFile);
            if (fileSize < HISTORY_HEADER_size) {
               FileClose(hFile);
               logWarn("HistorySet2.Get(5)  invalid history file \""+ filename +"\" (size="+ fileSize +", too small), skipping...");
               continue;
            }

            ArrayResize(hh, HISTORY_HEADER_intSize);                 // read HISTORY_HEADER
            FileReadArray(hFile, hh, 0, HISTORY_HEADER_intSize);
            FileClose(hFile);

            size = Max(ArraySize(hs.hSet), 1) + 1;                   // create new HistorySet (min. sizeof(hs.hSet)=2 as index[0] can't hold a handle)
            __ResizeSetArrays(size);
            iH   = size-1;
            hSet = iH;                                               // the HistorySet handle matches the array index of hs.*
            hs.hSet       [iH] = hSet;
            hs.symbol     [iH] = hh_Symbol(hh);
            hs.symbolU    [iH] = StrToUpper(hs.symbol[iH]);
            hs.description[iH] = hh_Description(hh);
            hs.digits     [iH] = hh_Digits(hh);
            hs.directory  [iH] = directory;
            hs.format     [iH] = 400;                                // default bar format for non-existing files
            ArrayResize(hh, 0);
            return(hSet);                                            // return after the first existing file
         }
      }
   }

   else if (!IsAbsolutePath(directory)) {                            // relative sandbox path, use MQL::FileOpen()
      for (i=0; i < sizeOfPeriods; i++) {
         filename = StringConcatenate(directory, "/", symbol, periods[i], ".hst");

         if (IsFile(filename, MODE_MQL)) {                           // without the additional check FileOpen(READ) logs a warning if the file doesn't exist
            hFile = FileOpen(filename, FILE_READ|FILE_BIN);          // open the file
            if (hFile <= 0) return(!catch("HistorySet2.Get(6)  hFile(\""+ filename +"\") => "+ hFile, intOr(GetLastError(), ERR_RUNTIME_ERROR)));

            fileSize = FileSize(hFile);
            if (fileSize < HISTORY_HEADER_size) {
               FileClose(hFile);
               logWarn("HistorySet2.Get(7)  invalid history file \""+ filename +"\" (size="+ fileSize +", too small), skipping...");
               continue;
            }

            ArrayResize(hh, HISTORY_HEADER_intSize);                 // read HISTORY_HEADER
            FileReadArray(hFile, hh, 0, HISTORY_HEADER_intSize);
            FileClose(hFile);

            size = Max(ArraySize(hs.hSet), 1) + 1;                   // create new HistorySet (min. sizeof(hs.hSet)=2 as index[0] can't hold a handle)
            __ResizeSetArrays(size);
            iH   = size-1;
            hSet = iH;                                               // the HistorySet handle matches the array index of hs.*
            hs.hSet       [iH] = hSet;
            hs.symbol     [iH] = hh_Symbol(hh);
            hs.symbolU    [iH] = StrToUpper(hs.symbol[iH]);
            hs.description[iH] = hh_Description(hh);
            hs.digits     [iH] = hh_Digits(hh);
            hs.directory  [iH] = directory;
            hs.format     [iH] = 400;                                // default bar format for non-existing files
            ArrayResize(hh, 0);
            return(hSet);                                            // return after the first existing file
         }
      }
   }

   else {                                                            // absolute path, use Expander
      return(!catch("HistorySet2.Get(8)  accessing absolute path \""+ directory +"\" not yet implemented", ERR_NOT_IMPLEMENTED));
   }

   int error = GetLastError();
   if (!error) return(-1);
   return(!catch("HistorySet2.Get(9)  symbol=\""+ symbol +"\""));
}


/**
 * Schlie�t das HistorySet mit dem angegebenen Handle.
 *
 * @param  int hSet - Set-Handle
 *
 * @return bool - success status
 */
bool HistorySet2.Close(int hSet) {
   // Validierung
   if (hSet <= 0)                     return(!catch("HistorySet2.Close(1)  invalid set handle "+ hSet, ERR_INVALID_PARAMETER));
   if (hSet != hs.hSet.lastValid) {
      if (hSet >= ArraySize(hs.hSet)) return(!catch("HistorySet2.Close(2)  invalid set handle "+ hSet, ERR_INVALID_PARAMETER));
      if (hs.hSet[hSet] == 0)         return(!catch("HistorySet2.Close(3)  unknown set handle "+ hSet +" (symbol="+ DoubleQuoteStr(hs.symbol[hSet]) +")", ERR_INVALID_PARAMETER));
   }
   else {
      hs.hSet.lastValid = NULL;
   }
   if (hs.hSet[hSet] < 0) return(true);                              // Handle wurde bereits geschlossen (kann ignoriert werden)

   int sizeOfPeriods = ArraySize(periods);

   for (int i=0; i < sizeOfPeriods; i++) {
      if (hs.hFile[hSet][i] > 0) {                                   // alle offenen Dateihandles schlie�en
         if (!HistoryFile2.Close(hs.hFile[hSet][i])) return(false);
         hs.hFile[hSet][i] = -1;
      }
   }
   hs.hSet[hSet] = -1;
   return(true);
}


/**
 * F�gt dem HistorySet eines Symbols einen Tick hinzu. Der Tick wird als letzter Tick (Close) der entsprechenden Bar gespeichert.
 *
 * @param  int      hSet  - Set-Handle des Symbols
 * @param  datetime time  - Zeitpunkt des Ticks
 * @param  double   value - Datenwert
 * @param  int      flags - zus�tzliche, das Schreiben steuernde Flags (default: keine)
 *                          � HST_BUFFER_TICKS: buffert aufeinanderfolgende Ticks und schreibt die Daten erst beim jeweils n�chsten
 *                            BarOpen-Event
 *                          � HST_FILL_GAPS:    f�llt entstehende Gaps mit dem letzten Schlu�kurs vor dem Gap
 *
 * @return bool - success status
 */
bool HistorySet2.AddTick(int hSet, datetime time, double value, int flags = NULL) {
   // Validierung
   if (hSet <= 0)                     return(!catch("HistorySet2.AddTick(1)  invalid parameter hSet: "+ hSet, ERR_INVALID_PARAMETER));
   if (hSet != hs.hSet.lastValid) {
      if (hSet >= ArraySize(hs.hSet)) return(!catch("HistorySet2.AddTick(2)  invalid parameter hSet: "+ hSet, ERR_INVALID_PARAMETER));
      if (hs.hSet[hSet] == 0)         return(!catch("HistorySet2.AddTick(3)  invalid parameter hSet: "+ hSet +" (unknown handle, symbol="+ DoubleQuoteStr(hs.symbol[hSet]) +")", ERR_INVALID_PARAMETER));
      if (hs.hSet[hSet] <  0)         return(!catch("HistorySet2.AddTick(4)  invalid parameter hSet: "+ hSet +" (closed handle, symbol="+ DoubleQuoteStr(hs.symbol[hSet]) +")", ERR_INVALID_PARAMETER));
      hs.hSet.lastValid = hSet;
   }
   if (time <= 0)                     return(!catch("HistorySet2.AddTick(5)  invalid parameter time: "+ time +" (symbol="+ DoubleQuoteStr(hs.symbol[hSet]) +")", ERR_INVALID_PARAMETER));

   // Dateihandles holen und jeweils Tick hinzuf�gen
   int hFile, sizeOfPeriods=ArraySize(periods);

   for (int i=0; i < sizeOfPeriods; i++) {
      hFile = hs.hFile[hSet][i];
      if (!hFile) {                                                  // noch unge�ffnete Dateien �ffnen
         hFile = HistoryFile2.Open(hs.symbol[hSet], periods[i], hs.description[hSet], hs.digits[hSet], hs.format[hSet], FILE_READ|FILE_WRITE, hs.directory[hSet]);
         if (!hFile) return(false);
         hs.hFile[hSet][i] = hFile;
      }
      if (!HistoryFile2.AddTick(hFile, time, value, flags)) return(false);
   }
   return(true);
}


/**
 * Open a history file using the specified access mode and return a handle to it.
 *
 * @param  string symbol               - symbol of the timeseries
 * @param  int    timeframe            - period of the timeseries
 * @param  string description          - symbol description           (used if a non-existing file is created)
 * @param  int    digits               - digits of the timeseries     (used if a non-existing file is created)
 * @param  int    format               - bar format of the timeseries (used if a non-existing file is created), one of
 *                                        400: compatible with all MetaTrader builds
 *                                        401: compatible with MetaTrader builds > 509 only
 * @param  int    mode                 - access mode, a combination of
 *                                        FILE_READ:  A non-existing file causes an error.
 *                                        FILE_WRITE: A non-existing is created. Without FILE_READ an existing file is reset
 *                                                    to a size of 0 (zero).
 * @param  string directory [optional] - directory of history file location
 *                                        if empty:            the current trade server directory (default)
 *                                        if a relative path:  relative to the MQL sandbox/files directory
 *                                        if an absolute path: as is
 *
 * @return int - file handle or -1 if FILE_READ was specified and the file doesn't exist;
 *               NULL (0) in case of all other errors
 */
int HistoryFile2.Open(string symbol, int timeframe, string description, int digits, int format, int mode, string directory = "") {
   if (!StringLen(symbol))                    return(!catch("HistoryFile2.Open(1)  invalid parameter symbol: "+ DoubleQuoteStr(symbol), ERR_INVALID_PARAMETER));
   if (StringLen(symbol) > MAX_SYMBOL_LENGTH) return(!catch("HistoryFile2.Open(2)  invalid parameter symbol: "+ DoubleQuoteStr(symbol) +" (max. "+ MAX_SYMBOL_LENGTH +" chars)", ERR_INVALID_PARAMETER));
   if (StrContains(symbol, " "))              return(!catch("HistoryFile2.Open(3)  invalid parameter symbol: "+ DoubleQuoteStr(symbol) +" (must not contain spaces)", ERR_INVALID_PARAMETER));
   string symbolU = StrToUpper(symbol);
   if (timeframe <= 0)                        return(!catch("HistoryFile2.Open(4)  invalid parameter timeframe: "+ timeframe +" ("+ symbol +")", ERR_INVALID_PARAMETER));
   if (!(mode & (FILE_READ|FILE_WRITE)))      return(!catch("HistoryFile2.Open(5)  invalid parameter mode: "+ mode +" (must be FILE_READ and/or FILE_WRITE) ("+ symbol +","+ PeriodDescription(timeframe) +")", ERR_INVALID_PARAMETER));
   mode &= (FILE_READ|FILE_WRITE);                                               // unset all other bits
   bool read_only  = !(mode & FILE_WRITE);
   bool write_only = !(mode & FILE_READ);
   bool read_write =  (mode & FILE_READ) && (mode & FILE_WRITE);
   if (directory == "0") directory = "";                                         // (string) NULL

   int hFile;
   string filename="", basename=symbol + timeframe +".hst";

   if (directory == "") {                                                        // current trade server, use MQL::FileOpenHistory()
      if (!read_only) /*&&*/ if (!UseTradeServerPath(GetAccountServerPath(), "HistoryFile2.Open(6)")) return(NULL);
      filename = basename;

      // open the file: read-only
      if (read_only) {
         if (!IsFile(filename, MODE_SYSTEM)) return(-1);                         // without the additional check FileOpenHistory(READ) logs a warning if the file doesn't exist
         hFile = FileOpenHistory(filename, mode|FILE_BIN);
         if (hFile <= 0) return(!catch("HistoryFile2.Open(7)->FileOpenHistory(\""+ filename +"\", FILE_READ) => "+ hFile, intOr(GetLastError(), ERR_RUNTIME_ERROR)));
      }
      // read-write
      else if (read_write) {
         hFile = FileOpenHistory(filename, mode|FILE_BIN);
         if (hFile <= 0) return(!catch("HistoryFile2.Open(8)->FileOpenHistory(\""+ filename +"\", FILE_READ|FILE_WRITE) => "+ hFile, intOr(GetLastError(), ERR_RUNTIME_ERROR)));
      }
      // write-only
      else if (write_only) {
         hFile = FileOpenHistory(filename, mode|FILE_BIN);
         if (hFile <= 0) return(!catch("HistoryFile2.Open(9)->FileOpenHistory(\""+ filename +"\", FILE_WRITE) => "+ hFile, intOr(GetLastError(), ERR_RUNTIME_ERROR)));
      }
   }

   else if (!IsAbsolutePath(directory)) {                                        // relative sandbox path, use MQL::FileOpen()
      // on write access make sure the directory exists
      if (!read_only) /*&&*/ if (!UseTradeServerPath(directory, "HistoryFile2.Open(10)")) return(NULL);
      filename = directory +"/"+ basename;

      // open the file: read-only
      if (read_only) {
         if (!IsFile(filename, MODE_MQL)) return(-1);                            // without the additional check FileOpen(READ) logs a warning if the file doesn't exist
         hFile = FileOpen(filename, mode|FILE_BIN);
         if (hFile <= 0) return(!catch("HistoryFile2.Open(11)->FileOpen(\""+ filename +"\", FILE_READ) => "+ hFile +" ("+ symbol +","+ PeriodDescription(timeframe) +")", intOr(GetLastError(), ERR_RUNTIME_ERROR)));
      }
      // read-write
      else if (read_write) {
         hFile = FileOpen(filename, mode|FILE_BIN);
         if (hFile <= 0) return(!catch("HistoryFile2.Open(12)->FileOpen(\""+ filename +"\", FILE_READ|FILE_WRITE) => "+ hFile +" ("+ symbol +","+ PeriodDescription(timeframe) +")", intOr(GetLastError(), ERR_RUNTIME_ERROR)));
      }
      // write-only
      else if (write_only) {
         hFile = FileOpen(filename, mode|FILE_BIN);
         if (hFile <= 0) return(!catch("HistoryFile2.Open(13)->FileOpen(\""+ filename +"\", FILE_WRITE) => "+ hFile +" ("+ symbol +","+ PeriodDescription(timeframe) +")", intOr(GetLastError(), ERR_RUNTIME_ERROR)));
      }
   }

   else {                                                                        // absolute path, use Expander
      return(!catch("HistoryFile2.Open(14)  accessing absolute path \""+ directory +"\" not yet implemented", ERR_NOT_IMPLEMENTED));
   }

   /*HISTORY_HEADER*/int hh[]; InitializeByteBuffer(hh, HISTORY_HEADER_size);
   int      bars=0, from.offset=-1, to.offset=-1, fileSize=FileSize(hFile), periodSecs=timeframe * MINUTES;
   datetime from.openTime=0, from.closeTime=0, from.nextCloseTime=0, to.openTime=0, to.closeTime=0, to.nextCloseTime=0;

   if (write_only || (read_write && fileSize < HISTORY_HEADER_size)) {
      // create and write new HISTORY_HEADER where appropriate
      if (StringLen(description) > 63) description = StrLeft(description, 63);   // shorten a too long description
      if (digits < 0)                 return(!catch("HistoryFile2.Open(15)  invalid parameter digits: "+ digits +" ("+ symbol +","+ PeriodDescription(timeframe) +")", ERR_INVALID_PARAMETER));
      if (format!=400 && format!=401) return(!catch("HistoryFile2.Open(16)  invalid parameter format: "+ format +" (must be 400 or 401, symbol="+ symbol +","+ PeriodDescription(timeframe) +")", ERR_INVALID_PARAMETER));

      hh_SetBarFormat  (hh, format     );
      hh_SetDescription(hh, description);
      hh_SetSymbol     (hh, symbol     );
      hh_SetPeriod     (hh, timeframe  );
      hh_SetDigits     (hh, digits     );
      FileWriteArray(hFile, hh, 0, HISTORY_HEADER_intSize);
   }

   else if (read_only || fileSize > 0) {
      // read existing HISTORY_HEADER where appropriate
      if (FileReadArray(hFile, hh, 0, HISTORY_HEADER_intSize) != HISTORY_HEADER_intSize) {
         FileClose(hFile);
         return(!catch("HistoryFile2.Open(17)  invalid history file \""+ filename +"\" (size="+ fileSize +")", intOr(GetLastError(), ERR_RUNTIME_ERROR)));
      }

      // read existing bar statistics
      if (fileSize > HISTORY_HEADER_size) {
         int barSize = ifInt(hh_BarFormat(hh)==400, HISTORY_BAR_400_size, HISTORY_BAR_401_size);
         bars        = (fileSize-HISTORY_HEADER_size) / barSize;
         if (bars > 0) {
            from.offset   = 0;
            from.openTime = FileReadInteger(hFile);
            to.offset     = bars-1; FileSeek(hFile, HISTORY_HEADER_size + to.offset*barSize, SEEK_SET);
            to.openTime   = FileReadInteger(hFile);

            if (timeframe <= PERIOD_W1) {
               from.closeTime     = from.openTime  + periodSecs;
               from.nextCloseTime = from.closeTime + periodSecs;
               to.closeTime       = to.openTime    + periodSecs;
               to.nextCloseTime   = to.closeTime   + periodSecs;
            }
            else if (timeframe == PERIOD_MN1) {
               from.closeTime     = DateTime1(TimeYearEx(from.openTime), TimeMonth(from.openTime)+1); // 00:00, 1st of the next month
               from.nextCloseTime = DateTime1(TimeYearEx(from.openTime), TimeMonth(from.openTime)+2); // 00:00, 1st of the next but one month
               to.closeTime       = DateTime1(TimeYearEx(to.openTime  ), TimeMonth(to.openTime  )+1); // 00:00, 1st of the next month
               to.nextCloseTime   = DateTime1(TimeYearEx(to.openTime  ), TimeMonth(to.openTime  )+2); // 00:00, 1st of the next but one month
            }
         }
      }
   }

   // store all metadata locally
   if (hFile >= ArraySize(hf.hFile))                                             // either reuse existing index or increase arrays
      __ResizeFileArrays(hFile+1);

   hf.hFile                      [hFile]        = hFile;
   hf.name                       [hFile]        = basename;
   hf.readAccess                 [hFile]        = !write_only;
   hf.writeAccess                [hFile]        = !read_only;

   ArraySetInts(hf.header,        hFile,          hh);                           // same as: hf.header[hFile] = hh;
   hf.format                     [hFile]        = hh_BarFormat(hh);
   hf.barSize                    [hFile]        = ifInt(hf.format[hFile]==400, HISTORY_BAR_400_size, HISTORY_BAR_401_size);
   hf.symbol                     [hFile]        = hh_Symbol(hh);
   hf.symbolU                    [hFile]        = symbolU;
   hf.period                     [hFile]        = timeframe;
   hf.periodSecs                 [hFile]        = periodSecs;
   hf.digits                     [hFile]        = hh_Digits(hh);
   hf.directory                  [hFile]        = directory;

   hf.stored.bars                [hFile]        = bars;                          // on empty history: 0
   hf.stored.from.offset         [hFile]        = from.offset;                   // ...              -1
   hf.stored.from.openTime       [hFile]        = from.openTime;                 // ...               0
   hf.stored.from.closeTime      [hFile]        = from.closeTime;                // ...               0
   hf.stored.from.nextCloseTime  [hFile]        = from.nextCloseTime;            // ...               0
   hf.stored.to.offset           [hFile]        = to.offset;                     // ...              -1
   hf.stored.to.openTime         [hFile]        = to.openTime;                   // ...               0
   hf.stored.to.closeTime        [hFile]        = to.closeTime;                  // ...               0
   hf.stored.to.nextCloseTime    [hFile]        = to.nextCloseTime;              // ...               0

   hf.total.bars                 [hFile]        = hf.stored.bars              [hFile];
   hf.total.from.offset          [hFile]        = hf.stored.from.offset       [hFile];
   hf.total.from.openTime        [hFile]        = hf.stored.from.openTime     [hFile];
   hf.total.from.closeTime       [hFile]        = hf.stored.from.closeTime    [hFile];
   hf.total.from.nextCloseTime   [hFile]        = hf.stored.from.nextCloseTime[hFile];
   hf.total.to.offset            [hFile]        = hf.stored.to.offset         [hFile];
   hf.total.to.openTime          [hFile]        = hf.stored.to.openTime       [hFile];
   hf.total.to.closeTime         [hFile]        = hf.stored.to.closeTime      [hFile];
   hf.total.to.nextCloseTime     [hFile]        = hf.stored.to.nextCloseTime  [hFile];

   hf.lastStoredBar.offset       [hFile]        = -1;                            // reset existing metadata: required because
   hf.lastStoredBar.openTime     [hFile]        =  0;                            // MQL may reuse closed file handle ids
   hf.lastStoredBar.closeTime    [hFile]        =  0;
   hf.lastStoredBar.nextCloseTime[hFile]        =  0;
   hf.lastStoredBar.data         [hFile][BAR_T] =  0;
   hf.lastStoredBar.data         [hFile][BAR_O] =  0;
   hf.lastStoredBar.data         [hFile][BAR_H] =  0;
   hf.lastStoredBar.data         [hFile][BAR_L] =  0;
   hf.lastStoredBar.data         [hFile][BAR_C] =  0;
   hf.lastStoredBar.data         [hFile][BAR_V] =  0;

   hf.bufferedBar.offset         [hFile]        = -1;
   hf.bufferedBar.openTime       [hFile]        =  0;
   hf.bufferedBar.closeTime      [hFile]        =  0;
   hf.bufferedBar.nextCloseTime  [hFile]        =  0;
   hf.bufferedBar.data           [hFile][BAR_T] =  0;
   hf.bufferedBar.data           [hFile][BAR_O] =  0;
   hf.bufferedBar.data           [hFile][BAR_H] =  0;
   hf.bufferedBar.data           [hFile][BAR_L] =  0;
   hf.bufferedBar.data           [hFile][BAR_C] =  0;
   hf.bufferedBar.data           [hFile][BAR_V] =  0;
   hf.bufferedBar.modified       [hFile]        = false;

   ArrayResize(hh, 0);

   int error = GetLastError();
   if (!error) return(hFile);
   return(!catch("HistoryFile2.Open(18)  "+ symbol +","+ PeriodDescription(timeframe), error));
}


/**
 * Schlie�t die Historydatei mit dem angegebenen Handle. Ungespeicherte Daten im Schreibpuffer werden geschrieben.
 * Die Datei mu� vorher mit HistoryFile2.Open() ge�ffnet worden sein.
 *
 * @param  int hFile - Dateihandle
 *
 * @return bool - success status
 */
bool HistoryFile2.Close(int hFile) {
   if (hFile <= 0)                      return(!catch("HistoryFile2.Close(1)  invalid file handle: "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(!catch("HistoryFile2.Close(2)  unknown file handle: "+ hFile, ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] == 0)         return(!catch("HistoryFile2.Close(3)  unknown file handle: "+ hFile +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
   }
   else hf.hFile.lastValid = NULL;

   if (hf.hFile[hFile] < 0) return(true);                            // Handle wurde bereits geschlossen (kann ignoriert werden)


   // (1) alle ungespeicherten Daten speichern
   if (hf.bufferedBar.offset[hFile] != -1) if (!HistoryFile2.WriteBufferedBar(hFile)) return(false);
   hf.bufferedBar.offset  [hFile] = -1;                              // BufferedBar sicherheitshalber zur�cksetzen
   hf.lastStoredBar.offset[hFile] = -1;                              // LastStoredBar sicherheitshalber zur�cksetzen


   // (2) Datei schlie�en
   int error = GetLastError();                                       // vor FileClose() alle Fehler abfangen
   if (IsError(error)) return(!catch("HistoryFile2.Close(4)  "+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]), error));

   hf.hFile[hFile] = -1;                                             // Handle vorm Schlie�en zur�cksetzen
   FileClose(hFile);

   error = GetLastError();
   if (!error)                         return(true);
   if (error == ERR_INVALID_PARAMETER) return(true);                 // Datei wurde bereits geschlossen (kann ignoriert werden)
   return(!catch("HistoryFile2.Close(5)  "+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]), error));
}


/**
 * Findet den Offset der Bar, die den angegebenen Zeitpunkt abdeckt oder abdecken w�rde, und signalisiert, ob diese Bar bereits existiert.
 * Die Bar existiert z.B. nicht, wenn die Zeitreihe am angegebenen Zeitpunkt eine L�cke aufweist (am zur�ckgegebenen Offset befindet sich
 * eine andere Bar) oder wenn der Zeitpunkt au�erhalb des von den vorhandenen Daten abgedeckten Bereichs liegt.
 *
 * @param  _In_  int      hFile          - Handle der Historydatei
 * @param  _In_  datetime time           - Zeitpunkt
 * @param  _Out_ bool     lpBarExists[1] - Variable, die nach R�ckkehr anzeigt, ob die Bar am zur�ckgegebenen Offset existiert
 *                                         (als Array implementiert, um Zeiger�bergabe an eine Library zu erm�glichen)
 *                                         � TRUE:  Bar existiert          @see  HistoryFile2.UpdateBar() und HistoryFile2.WriteBar()
 *                                         � FALSE: Bar existiert nicht    @see  HistoryFile2.InsertBar()
 *
 * @return int - Bar-Offset relativ zum Dateiheader (Offset 0 ist die �lteste Bar) oder EMPTY (-1), falls ein Fehler auftrat
 */
int HistoryFile2.FindBar(int hFile, datetime time, bool &lpBarExists[]) {
   // NOTE: Der Parameter lpBarExists ist f�r den externen Gebrauch implementiert (Aufruf der Funktion von au�erhalb der Library). Beim internen Gebrauch
   //       l��t sich �ber die Metadaten der Historydatei einfacher herausfinden, ob eine Bar an einem Offset existiert oder nicht.
   //       @see  int hf.total.bars[]
   if (hFile <= 0)                      return(_EMPTY(catch("HistoryFile2.FindBar(1)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER)));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(_EMPTY(catch("HistoryFile2.FindBar(2)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER)));
      if (hf.hFile[hFile] == 0)         return(_EMPTY(catch("HistoryFile2.FindBar(3)  invalid parameter hFile: "+ hFile +" (unknown handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER)));
      if (hf.hFile[hFile] <  0)         return(_EMPTY(catch("HistoryFile2.FindBar(4)  invalid parameter hFile: "+ hFile +" (closed handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER)));
      hf.hFile.lastValid = hFile;
   }
   if (time <= 0)                       return(_EMPTY(catch("HistoryFile2.FindBar(5)  invalid parameter time: "+ time +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER)));
   if (ArraySize(lpBarExists) == 0)
      ArrayResize(lpBarExists, 1);

   // History leer?
   if (!hf.total.bars[hFile]) {
      lpBarExists[0] = false;
      return(0);
   }

   datetime openTime = time;
   int      offset;

   // alle bekannten Daten abpr�fen
   if (hf.stored.bars[hFile] > 0) {
      // hf.stored.from
      if (openTime < hf.stored.from.openTime     [hFile]) { lpBarExists[0] = false;                      return(0); }   // Zeitpunkt liegt zeitlich vor der ersten Bar
      if (openTime < hf.stored.from.closeTime    [hFile]) { lpBarExists[0] = true;                       return(0); }   // Zeitpunkt liegt in der ersten Bar
      if (openTime < hf.stored.from.nextCloseTime[hFile]) { lpBarExists[0] = (hf.total.bars[hFile] > 1); return(1); }   // Zeitpunkt liegt in der zweiten Bar

      // hf.stored.to
      if      (openTime < hf.stored.to.openTime     [hFile]) {}
      else if (openTime < hf.stored.to.closeTime    [hFile]) { lpBarExists[0] = true;                                           return(hf.stored.to.offset[hFile]); }   // Zeitpunkt liegt in der letzten gespeicherten Bar
      else if (openTime < hf.stored.to.nextCloseTime[hFile]) { lpBarExists[0] = (hf.total.bars[hFile] > hf.stored.bars[hFile]); return(hf.stored.bars     [hFile]); }   // Zeitpunkt liegt in der darauf folgenden Bar
      else                                                   { lpBarExists[0] = false;                                          return(hf.total.bars      [hFile]); }   // Zeitpunkt liegt in der ersten neuen Bar

      // hf.lastStoredBar
      if (hf.lastStoredBar.offset[hFile] > 0) {                         // LastStoredBar ist definiert und entspricht nicht hf.stored.from (schon gepr�ft)
         if (hf.lastStoredBar.offset[hFile] != hf.stored.to.offset[hFile]) {
            if      (openTime < hf.lastStoredBar.openTime     [hFile]) {}
            else if (openTime < hf.lastStoredBar.closeTime    [hFile]) { lpBarExists[0] = true;                                  return(hf.lastStoredBar.offset[hFile]); }  // Zeitpunkt liegt in LastStoredBar
            else if (openTime < hf.lastStoredBar.nextCloseTime[hFile]) { offset         = hf.lastStoredBar.offset[hFile] + 1;
                                                                         lpBarExists[0] = (hf.total.to.offset[hFile] >= offset); return(offset); }                          // Zeitpunkt liegt in der darauf folgenden Bar
            else                                                       { offset = hf.lastStoredBar.offset[hFile] + 1 + (hf.total.to.offset[hFile] > hf.lastStoredBar.offset[hFile]);
                                                                         lpBarExists[0] = (hf.total.to.offset[hFile] >= offset); return(offset); }                          // Zeitpunkt liegt in der ersten neuen Bar
         }
      }
   }

   if (hf.bufferedBar.offset[hFile] >= 0) {                             // BufferedBar ist definiert
      // hf.total.from
      if (hf.total.from.offset[hFile] != hf.stored.from.offset[hFile]) {// bei Gleichheit identisch zu hf.stored.from (schon gepr�ft)
         if (openTime < hf.total.from.openTime     [hFile]) { lpBarExists[0] = false;                      return(0); }                         // Zeitpunkt liegt zeitlich vor der ersten Bar
         if (openTime < hf.total.from.closeTime    [hFile]) { lpBarExists[0] = true;                       return(0); }                         // Zeitpunkt liegt in der ersten Bar
         if (openTime < hf.total.from.nextCloseTime[hFile]) { lpBarExists[0] = (hf.total.bars[hFile] > 1); return(1); }                         // Zeitpunkt liegt in der zweiten Bar
      }

      // hf.total.to
      if (hf.total.to.offset[hFile] != hf.stored.to.offset[hFile]) {    // bei Gleichheit identisch zu hf.stored.to (schon gepr�ft)
         if      (openTime < hf.total.to.openTime [hFile]) {}
         else if (openTime < hf.total.to.closeTime[hFile]) { lpBarExists[0] = true;                      return(hf.total.to.offset[hFile]); }   // Zeitpunkt liegt in der letzten absoluten Bar
         else                                              { lpBarExists[0] = false;                     return(hf.total.bars     [hFile]); }   // Zeitpunkt liegt in der ersten neuen Bar
      }

      // hf.bufferedBar                                                 // eine definierte BufferedBar ist immer identisch zu hf.total.to (schon gepr�ft)
   }

   // bin�re Suche in der Datei                                         // TODO: implementieren
   return(_EMPTY(catch("HistoryFile2.FindBar(6)  bars="+ hf.total.bars[hFile] +", from='"+ TimeToStr(hf.total.from.openTime[hFile], TIME_FULL) +"', to='"+ TimeToStr(hf.total.to.openTime[hFile], TIME_FULL) +"')  time look-up in a timeseries not yet implemented ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_NOT_IMPLEMENTED)));
}


/**
 * Liest die Bar am angegebenen Offset einer Historydatei.
 *
 * @param  _In_  int    hFile  - Handle der Historydatei
 * @param  _In_  int    offset - Offset der zu lesenden Bar relativ zum Dateiheader (Offset 0 ist die �lteste Bar)
 * @param  _Out_ double bar[6] - Array zur Aufnahme der Bar-Daten (TOHLCV)
 *
 * @return bool - success status
 *
 * NOTE: Time und Volume der gelesenen Bar werden validert, nicht jedoch die Barform.
 */
bool HistoryFile2.ReadBar(int hFile, int offset, double &bar[]) {
   if (hFile <= 0)                      return(!catch("HistoryFile2.ReadBar(1)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(!catch("HistoryFile2.ReadBar(2)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] == 0)         return(!catch("HistoryFile2.ReadBar(3)  invalid parameter hFile: "+ hFile +" (unknown handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] <  0)         return(!catch("HistoryFile2.ReadBar(4)  invalid parameter hFile: "+ hFile +" (closed handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
      hf.hFile.lastValid = hFile;
   }
   if (offset < 0)                      return(!catch("HistoryFile2.ReadBar(5)  invalid parameter offset: "+ offset +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
   if (offset >= hf.total.bars[hFile])  return(!catch("HistoryFile2.ReadBar(6)  invalid parameter offset: "+ offset +" ("+ hf.total.bars[hFile] +" full bars, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
   if (ArraySize(bar) != 6) ArrayResize(bar, 6);

   // vorzugsweise bereits bekannte Bars zur�ckgeben                 // ACHTUNG: hf.lastStoredBar wird nur aktualisiert, wenn die Bar tats�chlich neu gelesen wurde.
   if (offset == hf.lastStoredBar.offset[hFile]) {
      bar[BAR_T] = hf.lastStoredBar.data[hFile][BAR_T];
      bar[BAR_O] = hf.lastStoredBar.data[hFile][BAR_O];
      bar[BAR_H] = hf.lastStoredBar.data[hFile][BAR_H];
      bar[BAR_L] = hf.lastStoredBar.data[hFile][BAR_L];
      bar[BAR_C] = hf.lastStoredBar.data[hFile][BAR_C];
      bar[BAR_V] = hf.lastStoredBar.data[hFile][BAR_V];
      return(true);
   }
   if (offset == hf.bufferedBar.offset[hFile]) {
      bar[BAR_T] = hf.bufferedBar.data[hFile][BAR_T];
      bar[BAR_O] = hf.bufferedBar.data[hFile][BAR_O];
      bar[BAR_H] = hf.bufferedBar.data[hFile][BAR_H];
      bar[BAR_L] = hf.bufferedBar.data[hFile][BAR_L];
      bar[BAR_C] = hf.bufferedBar.data[hFile][BAR_C];
      bar[BAR_V] = hf.bufferedBar.data[hFile][BAR_V];
      return(true);
   }

   // FilePointer positionieren, Bar lesen, normalisieren und validieren
   int position = HISTORY_HEADER_size + offset*hf.barSize[hFile], digits=hf.digits[hFile];
   if (!FileSeek(hFile, position, SEEK_SET)) return(!catch("HistoryFile2.ReadBar(7)  "+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile])));

   if (hf.format[hFile] == 400) {
      bar[BAR_T] =                 FileReadInteger(hFile);
      bar[BAR_O] = NormalizeDouble(FileReadDouble (hFile), digits);
      bar[BAR_L] = NormalizeDouble(FileReadDouble (hFile), digits);
      bar[BAR_H] = NormalizeDouble(FileReadDouble (hFile), digits);
      bar[BAR_C] = NormalizeDouble(FileReadDouble (hFile), digits);
      bar[BAR_V] =           Round(FileReadDouble (hFile));
   }
   else {               // 401
      bar[BAR_T] =                 FileReadInteger(hFile);           // int64
                                   FileReadInteger(hFile);
      bar[BAR_O] = NormalizeDouble(FileReadDouble (hFile), digits);
      bar[BAR_H] = NormalizeDouble(FileReadDouble (hFile), digits);
      bar[BAR_L] = NormalizeDouble(FileReadDouble (hFile), digits);
      bar[BAR_C] = NormalizeDouble(FileReadDouble (hFile), digits);
      bar[BAR_V] =                 FileReadInteger(hFile);           // uint64: ticks
   }
   datetime openTime = bar[BAR_T]; if (!openTime) return(!catch("HistoryFile2.ReadBar(8)  invalid bar["+ offset +"].time: "+ openTime +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_RUNTIME_ERROR));
   int      V        = bar[BAR_V]; if (!V)        return(!catch("HistoryFile2.ReadBar(9)  invalid bar["+ offset +"].volume: "+ V +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_RUNTIME_ERROR));

   // CloseTime/NextCloseTime ermitteln und hf.lastStoredBar aktualisieren
   datetime closeTime, nextCloseTime;
   if (hf.period[hFile] <= PERIOD_W1) {
      closeTime     = openTime  + hf.periodSecs[hFile];
      nextCloseTime = closeTime + hf.periodSecs[hFile];
   }
   else if (hf.period[hFile] == PERIOD_MN1) {
      closeTime     = DateTime1(TimeYearEx(openTime), TimeMonth(openTime)+1);    // 00:00, 1. des n�chsten Monats
      nextCloseTime = DateTime1(TimeYearEx(openTime), TimeMonth(openTime)+2);    // 00:00, 1. des �bern�chsten Monats
   }

   hf.lastStoredBar.offset       [hFile]        = offset;
   hf.lastStoredBar.openTime     [hFile]        = openTime;
   hf.lastStoredBar.closeTime    [hFile]        = closeTime;
   hf.lastStoredBar.nextCloseTime[hFile]        = nextCloseTime;
   hf.lastStoredBar.data         [hFile][BAR_T] = bar[BAR_T];
   hf.lastStoredBar.data         [hFile][BAR_O] = bar[BAR_O];
   hf.lastStoredBar.data         [hFile][BAR_H] = bar[BAR_H];
   hf.lastStoredBar.data         [hFile][BAR_L] = bar[BAR_L];
   hf.lastStoredBar.data         [hFile][BAR_C] = bar[BAR_C];
   hf.lastStoredBar.data         [hFile][BAR_V] = bar[BAR_V];

   int error = GetLastError();
   if (!error)
      return(true);
   return(!catch("HistoryFile2.ReadBar(10)  "+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]), error));
}


/**
 * Schreibt eine Bar am angegebenen Offset einer Historydatei. Eine dort vorhandene Bar wird �berschrieben. Ist die Bar noch nicht vorhanden,
 * mu� ihr Offset an die vorhandenen Bars genau anschlie�en. Sie darf kein physisches Gap verursachen.
 *
 * @param  int    hFile  - Handle der Historydatei
 * @param  int    offset - Offset der zu schreibenden Bar relativ zum Dateiheader (Offset 0 ist die �lteste Bar)
 * @param  double bar[]  - Bardaten (T-OHLCV):
 * @param  int    flags  - zus�tzliche, das Schreiben steuernde Flags (default: keine)
 *                         � HST_FILL_GAPS: beim Schreiben entstehende Gaps werden mit dem Schlu�kurs der letzten Bar vor dem Gap gef�llt
 *
 * @return bool - success status
 *
 * NOTE: Time und Volume der zu schreibenden Bar werden auf != NULL validert, alles andere nicht. Insbesondere wird nicht �berpr�ft, ob die
 *       Bar-Time eine normalisierte OpenTime f�r den Timeframe der Historydatei ist.
 */
bool HistoryFile2.WriteBar(int hFile, int offset, double bar[], int flags=NULL) {
   if (hFile <= 0)                      return(!catch("HistoryFile2.WriteBar(1)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(!catch("HistoryFile2.WriteBar(2)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] == 0)         return(!catch("HistoryFile2.WriteBar(3)  invalid parameter hFile: "+ hFile +" (unknown handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] <  0)         return(!catch("HistoryFile2.WriteBar(4)  invalid parameter hFile: "+ hFile +" (closed handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
      hf.hFile.lastValid = hFile;
   }
   if (offset < 0)                      return(!catch("HistoryFile2.WriteBar(5)  invalid parameter offset: "+ offset +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
   if (offset > hf.total.bars[hFile])   return(!catch("HistoryFile2.WriteBar(6)  invalid parameter offset: "+ offset +" ("+ hf.total.bars[hFile] +" full bars, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
   if (ArraySize(bar) != 6)             return(!catch("HistoryFile2.WriteBar(7)  invalid size of parameter bar[]: "+ ArraySize(bar) +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INCOMPATIBLE_ARRAY));

   // Bar validieren
   datetime openTime = Round(bar[BAR_T]); if (!openTime) return(!catch("HistoryFile2.WriteBar(8)  invalid bar["+ offset +"].time: "+ openTime +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
   int      V        = Round(bar[BAR_V]); if (!V)        return(!catch("HistoryFile2.WriteBar(9)  invalid bar["+ offset +"].volume: "+ V +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));

   // Sicherstellen, da� bekannte Bars nicht mit einer anderen Bar �berschrieben werden               // TODO: if-Tests reduzieren
   if (offset==hf.stored.from.offset  [hFile]) /*&&*/ if (openTime!=hf.stored.from.openTime  [hFile]) return(!catch("HistoryFile2.WriteBar(10)  bar["+ offset +"].time="+ TimeToStr(openTime, TIME_FULL) +" collides with hf.stored.from.time="                                        + TimeToStr(hf.stored.from.openTime  [hFile], TIME_FULL) +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_ILLEGAL_STATE));
   if (offset==hf.stored.to.offset    [hFile]) /*&&*/ if (openTime!=hf.stored.to.openTime    [hFile]) return(!catch("HistoryFile2.WriteBar(11)  bar["+ offset +"].time="+ TimeToStr(openTime, TIME_FULL) +" collides with hf.stored.to.time="                                          + TimeToStr(hf.stored.to.openTime    [hFile], TIME_FULL) +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_ILLEGAL_STATE));
   if (offset==hf.total.to.offset     [hFile]) /*&&*/ if (openTime!=hf.total.to.openTime     [hFile]) return(!catch("HistoryFile2.WriteBar(12)  bar["+ offset +"].time="+ TimeToStr(openTime, TIME_FULL) +" collides with hf.total.to.time="                                           + TimeToStr(hf.total.to.openTime     [hFile], TIME_FULL) +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_ILLEGAL_STATE));
   if (offset==hf.lastStoredBar.offset[hFile]) /*&&*/ if (openTime!=hf.lastStoredBar.openTime[hFile]) return(!catch("HistoryFile2.WriteBar(13)  bar["+ offset +"].time="+ TimeToStr(openTime, TIME_FULL) +" collides with hf.lastStoredBar["+ hf.lastStoredBar.offset[hFile] +"].time="+ TimeToStr(hf.lastStoredBar.openTime[hFile], TIME_FULL) +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_ILLEGAL_STATE));
   // hf.bufferedBar.offset: entspricht hf.total.to.offset (schon gepr�ft)

   // TODO: Sicherstellen, da� nach bekannten Bars keine �lteren Bars geschrieben werden              // TODO: if-Tests reduzieren
   if (offset==hf.stored.from.offset  [hFile]+1) {}
   if (offset==hf.stored.to.offset    [hFile]+1) {}
   if (offset==hf.total.to.offset     [hFile]+1) {}
   if (offset==hf.lastStoredBar.offset[hFile]+1) {}

   // L�st die Bar f�r eine BufferedBar ein BarClose-Event aus, zuerst die BufferedBar schreiben
   if (hf.bufferedBar.offset[hFile] >= 0) /*&&*/ if (offset > hf.bufferedBar.offset[hFile]) {
      if (!HistoryFile2.WriteBufferedBar(hFile, flags)) return(false);
      hf.bufferedBar.offset[hFile] = -1;                                                              // BufferedBar zur�cksetzen
   }

   // FilePointer positionieren, Bar normalisieren (Funktionsparameter nicht modifizieren) und schreiben
   int position = HISTORY_HEADER_size + offset*hf.barSize[hFile], digits=hf.digits[hFile];
   if (!FileSeek(hFile, position, SEEK_SET)) return(!catch("HistoryFile2.WriteBar(14)  "+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile])));

   double O = NormalizeDouble(bar[BAR_O], digits);
   double H = NormalizeDouble(bar[BAR_H], digits);
   double L = NormalizeDouble(bar[BAR_L], digits);
   double C = NormalizeDouble(bar[BAR_C], digits);

   if (hf.format[hFile] == 400) {
      FileWriteInteger(hFile, openTime);
      FileWriteDouble (hFile, O       );
      FileWriteDouble (hFile, L       );
      FileWriteDouble (hFile, H       );
      FileWriteDouble (hFile, C       );
      FileWriteDouble (hFile, V       );
   }
   else {               // 401
      FileWriteInteger(hFile, openTime);     // int64
      FileWriteInteger(hFile, 0       );
      FileWriteDouble (hFile, O       );
      FileWriteDouble (hFile, H       );
      FileWriteDouble (hFile, L       );
      FileWriteDouble (hFile, C       );
      FileWriteInteger(hFile, V       );     // uint64: ticks
      FileWriteInteger(hFile, 0       );
      FileWriteInteger(hFile, 0       );     // int:    spread
      FileWriteInteger(hFile, 0       );     // uint64: real_volume
      FileWriteInteger(hFile, 0       );
   }                                         // doesn't update last-modified timestamp even if the file size changes
   FileFlush(hFile);                         // @see  https://docs.microsoft.com/en-us/windows/win32/api/memoryapi/nf-memoryapi-flushviewoffile

   datetime closeTime=hf.lastStoredBar.closeTime[hFile], nextCloseTime=hf.lastStoredBar.nextCloseTime[hFile];

   // hf.lastStoredBar aktualisieren
   if (offset != hf.lastStoredBar.offset[hFile]) {
      if (hf.period[hFile] <= PERIOD_W1) {
         closeTime     = openTime  + hf.periodSecs[hFile];
         nextCloseTime = closeTime + hf.periodSecs[hFile];
      }
      else if (hf.period[hFile] == PERIOD_MN1) {
         closeTime     = DateTime1(TimeYearEx(openTime), TimeMonth(openTime)+1); // 00:00, 1. des n�chsten Monats
         nextCloseTime = DateTime1(TimeYearEx(openTime), TimeMonth(openTime)+2); // 00:00, 1. des �bern�chsten Monats
      }
      hf.lastStoredBar.offset       [hFile] = offset;
      hf.lastStoredBar.openTime     [hFile] = openTime;
      hf.lastStoredBar.closeTime    [hFile] = closeTime;
      hf.lastStoredBar.nextCloseTime[hFile] = nextCloseTime;
   }
   hf.lastStoredBar.data[hFile][BAR_T] = openTime;
   hf.lastStoredBar.data[hFile][BAR_O] = O;
   hf.lastStoredBar.data[hFile][BAR_H] = H;
   hf.lastStoredBar.data[hFile][BAR_L] = L;
   hf.lastStoredBar.data[hFile][BAR_C] = C;
   hf.lastStoredBar.data[hFile][BAR_V] = V;

   // Metadaten aktualisieren: - Die Bar kann (a) erste Bar einer leeren History sein, (b) mittendrin liegen oder (c) neue Bar am Ende sein.
   //                          - Die Bar kann auf einer ungespeicherten BufferedBar liegen, jedoch nicht j�nger als diese sein: siehe (3).
   //                          - Die Bar kann zwischen der letzten gespeicherten Bar und einer ungespeicherten BufferedBar liegen. Dazu mu� sie
   //                            mit HistoryFile2.InsertBar() eingef�gt worden sein, das die entsprechende L�cke zwischen beiden Bars einrichtet.
   //                            Ohne diese L�cke wurde oben bereits abgebrochen.
   //
   // Bar ist neue Bar: (a) erste Bar leerer History oder (c) neue Bar am Ende der gespeicherten Bars
   if (offset >= hf.stored.bars[hFile]) {
                         hf.stored.bars              [hFile] = offset + 1;

      if (offset == 0) { hf.stored.from.offset       [hFile] = 0;                hf.total.from.offset       [hFile] = hf.stored.from.offset       [hFile];
                         hf.stored.from.openTime     [hFile] = openTime;         hf.total.from.openTime     [hFile] = hf.stored.from.openTime     [hFile];
                         hf.stored.from.closeTime    [hFile] = closeTime;        hf.total.from.closeTime    [hFile] = hf.stored.from.closeTime    [hFile];
                         hf.stored.from.nextCloseTime[hFile] = nextCloseTime;    hf.total.from.nextCloseTime[hFile] = hf.stored.from.nextCloseTime[hFile]; }
                                                                                 //                ^                ^               ^
                         hf.stored.to.offset         [hFile] = offset;           // Wird die Bar wie in (6.3) eingef�gt, wurde der Offset der BufferedBar um eins
                         hf.stored.to.openTime       [hFile] = openTime;         // vergr��ert. Ist die History noch leer und die BufferedBar war die erste Bar, steht
                         hf.stored.to.closeTime      [hFile] = closeTime;        // hf.total.from bis zu dieser Zuweisung *�ber mir* auf 0 (Zeiten unbekannt, da die
                         hf.stored.to.nextCloseTime  [hFile] = nextCloseTime;    // neue Startbar gerade eingef�gt wird).
   }
   if (hf.stored.bars[hFile] > hf.total.bars[hFile]) {
      hf.total.bars            [hFile] = hf.stored.bars            [hFile];

      hf.total.to.offset       [hFile] = hf.stored.to.offset       [hFile];
      hf.total.to.openTime     [hFile] = hf.stored.to.openTime     [hFile];
      hf.total.to.closeTime    [hFile] = hf.stored.to.closeTime    [hFile];
      hf.total.to.nextCloseTime[hFile] = hf.stored.to.nextCloseTime[hFile];
   }

   // Ist die geschriebene Bar gleichzeitig die BufferedBar, wird deren ver�nderlicher Status aktualisiert.
   if (offset == hf.bufferedBar.offset[hFile]) {
      hf.bufferedBar.data    [hFile][BAR_O] = hf.lastStoredBar.data[hFile][BAR_O];
      hf.bufferedBar.data    [hFile][BAR_H] = hf.lastStoredBar.data[hFile][BAR_H];
      hf.bufferedBar.data    [hFile][BAR_L] = hf.lastStoredBar.data[hFile][BAR_L];
      hf.bufferedBar.data    [hFile][BAR_C] = hf.lastStoredBar.data[hFile][BAR_C];
      hf.bufferedBar.data    [hFile][BAR_V] = hf.lastStoredBar.data[hFile][BAR_V];
      hf.bufferedBar.modified[hFile]        = false;                             // Bar wurde gerade gespeichert
   }

   int error = GetLastError();
   if (!error)
      return(true);
   return(!catch("HistoryFile2.WriteBar(15)  "+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]), error));
}


/**
 * Aktualisiert den Schlu�kurs der Bar am angegebenen Offset einer Historydatei. Die Bar mu� existieren, entweder in der Datei (gespeichert)
 * oder im Barbuffer (ungespeichert).
 *
 * @param  int    hFile  - Handle der Historydatei
 * @param  int    offset - Offset der zu aktualisierenden Bar relativ zum Dateiheader (Offset 0 ist die �lteste Bar)
 * @param  double value  - neuer Schlu�kurs (z.B. ein weiterer Tick der j�ngsten Bar)
 *
 * @return bool - success status
 */
bool HistoryFile2.UpdateBar(int hFile, int offset, double value) {
   if (hFile <= 0)                      return(!catch("HistoryFile2.UpdateBar(1)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(!catch("HistoryFile2.UpdateBar(2)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] == 0)         return(!catch("HistoryFile2.UpdateBar(3)  invalid parameter hFile: "+ hFile +" (unknown handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] <  0)         return(!catch("HistoryFile2.UpdateBar(4)  invalid parameter hFile: "+ hFile +" (closed handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
      hf.hFile.lastValid = hFile;
   }
   if (offset < 0 )                     return(!catch("HistoryFile2.UpdateBar(5)  invalid parameter offset: "+ offset +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
   if (offset >= hf.total.bars[hFile])  return(!catch("HistoryFile2.UpdateBar(6)  invalid parameter offset: "+ offset +" ("+ hf.total.bars[hFile] +" full bars, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));

   // vorzugsweise bekannte Bars aktualisieren
   if (offset == hf.bufferedBar.offset[hFile]) {                                 // BufferedBar
      //.bufferedBar.data[hFile][BAR_T] = ...                                    // unver�ndert
      //.bufferedBar.data[hFile][BAR_O] = ...                                    // unver�ndert
      hf.bufferedBar.data[hFile][BAR_H] = MathMax(hf.bufferedBar.data[hFile][BAR_H], value);
      hf.bufferedBar.data[hFile][BAR_L] = MathMin(hf.bufferedBar.data[hFile][BAR_L], value);
      hf.bufferedBar.data[hFile][BAR_C] = value;
      hf.bufferedBar.data[hFile][BAR_V]++;
      return(HistoryFile2.WriteBufferedBar(hFile));
   }

   // ist die zu aktualisierende Bar nicht die LastStoredBar, gesuchte Bar einlesen und damit zur LastStoredBar machen
   if (offset != hf.lastStoredBar.offset[hFile]) {
      double bar[6];                                                             // bar[] wird in Folge nicht verwendet
      if (!HistoryFile2.ReadBar(hFile, offset, bar)) return(false);              // setzt LastStoredBar auf die gelesene Bar
   }

   // LastStoredBar aktualisieren und speichern
   //.lastStoredBar.data[hFile][BAR_T] = ...                                     // unver�ndert
   //.lastStoredBar.data[hFile][BAR_O] = ...                                     // unver�ndert
   hf.lastStoredBar.data[hFile][BAR_H] = MathMax(hf.lastStoredBar.data[hFile][BAR_H], value);
   hf.lastStoredBar.data[hFile][BAR_L] = MathMin(hf.lastStoredBar.data[hFile][BAR_L], value);
   hf.lastStoredBar.data[hFile][BAR_C] = value;
   hf.lastStoredBar.data[hFile][BAR_V]++;
   return(HistoryFile2.WriteLastStoredBar(hFile));
}


/**
 * F�gt eine Bar am angegebenen Offset einer Historydatei ein. Eine dort vorhandene Bar wird nicht �berschrieben, stattdessen werden die
 * vorhandene und alle folgenden Bars um eine Position nach vorn verschoben. Ist die einzuf�gende Bar die j�ngste Bar, mu� ihr Offset an die
 * vorhandenen Bars genau anschlie�en. Sie darf kein physisches Gap verursachen.
 *
 * @param  int    hFile  - Handle der Historydatei
 * @param  int    offset - Offset der einzuf�genden Bar relativ zum Dateiheader (Offset 0 ist die �lteste Bar)
 * @param  double bar[6] - Bardaten (T-OHLCV)
 * @param  int    flags  - zus�tzliche, das Schreiben steuernde Flags (default: keine)
 *                         � HST_FILL_GAPS: beim Schreiben entstehende Gaps werden mit dem Schlu�kurs der letzten Bar vor dem Gap gef�llt
 *
 * @return bool - success status
 *
 * NOTE: Time und Volume der einzuf�genden Bar werden auf != NULL validert, alles andere nicht. Insbesondere wird nicht �berpr�ft, ob die
 *       Bar-Time eine normalisierte OpenTime f�r den Timeframe der Historydatei ist.
 */
bool HistoryFile2.InsertBar(int hFile, int offset, double bar[], int flags = NULL) {
   if (hFile <= 0)                      return(!catch("HistoryFile2.InsertBar(1)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(!catch("HistoryFile2.InsertBar(2)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] == 0)         return(!catch("HistoryFile2.InsertBar(3)  invalid parameter hFile: "+ hFile +" (unknown handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] <  0)         return(!catch("HistoryFile2.InsertBar(4)  invalid parameter hFile: "+ hFile +" (closed handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
      hf.hFile.lastValid = hFile;
   }
   if (offset < 0)                      return(!catch("HistoryFile2.InsertBar(5)  invalid parameter offset: "+ offset +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
   if (offset > hf.total.bars[hFile])   return(!catch("HistoryFile2.InsertBar(6)  invalid parameter offset: "+ offset +" ("+ hf.total.bars[hFile] +" full bars, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
   if (ArraySize(bar) != 6)             return(!catch("HistoryFile2.InsertBar(7)  invalid size of parameter data[]: "+ ArraySize(bar) +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INCOMPATIBLE_ARRAY));

   // ggf. L�cke f�r einzuf�gende Bar schaffen
   if (offset < hf.total.bars[hFile])
      if (!HistoryFile2.MoveBars(hFile, offset, offset+1)) return(false);

   // Bar schreiben, HistoryFile2.WriteBar() f�hrt u.a. folgende Tasks aus: - validiert die Bar
   return(HistoryFile2.WriteBar(hFile, offset, bar, flags));             // - speichert eine durch die einzuf�gende Bar geschlossene BufferedBar
}                                                                        // - aktualisiert die Metadaten der Historydatei


/**
 * Schreibt die LastStoredBar in die Historydatei. Die Bar existiert in der Historydatei bereits.
 *
 * @param  int hFile - Handle der Historydatei
 * @param  int flags - zus�tzliche, das Schreiben steuernde Flags (default: keine)
 *                     � HST_FILL_GAPS: beim Schreiben entstehende Gaps werden mit dem Schlu�kurs der letzten Bar vor dem Gap gef�llt
 *
 * @return bool - success status
 *
 * @access private
 */
bool HistoryFile2.WriteLastStoredBar(int hFile, int flags = NULL) {
   if (hFile <= 0)                      return(!catch("HistoryFile2.WriteLastStoredBar(1)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(!catch("HistoryFile2.WriteLastStoredBar(2)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] == 0)         return(!catch("HistoryFile2.WriteLastStoredBar(3)  invalid parameter hFile: "+ hFile +" (unknown handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] <  0)         return(!catch("HistoryFile2.WriteLastStoredBar(4)  invalid parameter hFile: "+ hFile +" (closed handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
      hf.hFile.lastValid = hFile;
   }
   int offset = hf.lastStoredBar.offset[hFile];
   if (offset < 0)                      return(_true(logWarn("HistoryFile2.WriteLastStoredBar(5)  undefined lastStoredBar: hf.lastStoredBar.offset="+ offset +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")")));
   if (offset >= hf.stored.bars[hFile]) return(!catch("HistoryFile2.WriteLastStoredBar(6)  invalid hf.lastStoredBar.offset: "+ offset +" ("+ hf.stored.bars[hFile] +" stored bars, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));

   // Bar validieren
   datetime openTime = hf.lastStoredBar.openTime[hFile];         if (!openTime) return(!catch("HistoryFile2.WriteLastStoredBar(8)  invalid hf.lastStoredBar["+ offset +"].time: "+ openTime +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_RUNTIME_ERROR));
   int      V  = Round(hf.lastStoredBar.data    [hFile][BAR_V]); if (!V)        return(!catch("HistoryFile2.WriteLastStoredBar(9)  invalid hf.lastStoredBar["+ offset +"].volume: "+ V +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_RUNTIME_ERROR));

   // FilePointer positionieren, Daten normalisieren und schreiben
   int position = HISTORY_HEADER_size + offset*hf.barSize[hFile], digits=hf.digits[hFile];
   if (!FileSeek(hFile, position, SEEK_SET)) return(!catch("HistoryFile2.WriteLastStoredBar(7)  "+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile])));

   if (hf.format[hFile] == 400) {
      FileWriteInteger(hFile, openTime);
      FileWriteDouble (hFile, NormalizeDouble(hf.lastStoredBar.data[hFile][BAR_O], digits));
      FileWriteDouble (hFile, NormalizeDouble(hf.lastStoredBar.data[hFile][BAR_L], digits));
      FileWriteDouble (hFile, NormalizeDouble(hf.lastStoredBar.data[hFile][BAR_H], digits));
      FileWriteDouble (hFile, NormalizeDouble(hf.lastStoredBar.data[hFile][BAR_C], digits));
      FileWriteDouble (hFile, V);
   }
   else {               // 401
      FileWriteInteger(hFile, openTime);                                                     // int64
      FileWriteInteger(hFile, 0);
      FileWriteDouble (hFile, NormalizeDouble(hf.lastStoredBar.data[hFile][BAR_O], digits));
      FileWriteDouble (hFile, NormalizeDouble(hf.lastStoredBar.data[hFile][BAR_H], digits));
      FileWriteDouble (hFile, NormalizeDouble(hf.lastStoredBar.data[hFile][BAR_L], digits));
      FileWriteDouble (hFile, NormalizeDouble(hf.lastStoredBar.data[hFile][BAR_C], digits));
      FileWriteInteger(hFile, V);                                                            // uint64: ticks
      FileWriteInteger(hFile, 0);
      FileWriteInteger(hFile, 0);                                                            // int:    spread
      FileWriteInteger(hFile, 0);                                                            // uint64: volume
      FileWriteInteger(hFile, 0);
   }                                         // doesn't update last-modified timestamp even if the file size changes
   FileFlush(hFile);                         // @see  https://docs.microsoft.com/en-us/windows/win32/api/memoryapi/nf-memoryapi-flushviewoffile

   // Die Bar existierte bereits in der History, die Metadaten �ndern sich nicht.

   // Ist die LastStoredBar gleichzeitig die BufferedBar, wird deren ver�nderlicher Status auch aktualisiert.
   if (offset == hf.bufferedBar.offset[hFile])
      hf.bufferedBar.modified[hFile] = false;               // Bar wurde gerade gespeichert

   int error = GetLastError();
   if (!error)
      return(true);
   return(!catch("HistoryFile2.WriteLastStoredBar(8)  "+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]), error));
}


/**
 * Schreibt den Inhalt der BufferedBar in die Historydatei. Sie ist immer die j�ngste Bar und kann in der History bereits existieren, mu� es
 * aber nicht.
 *
 * @param  int hFile - Handle der Historydatei
 * @param  int flags - zus�tzliche, das Schreiben steuernde Flags (default: keine)
 *                     � HST_FILL_GAPS: beim Schreiben entstehende Gaps werden mit dem Schlu�kurs der letzten Bar vor dem Gap gef�llt
 *
 * @return bool - success status
 *
 * @access private
 */
bool HistoryFile2.WriteBufferedBar(int hFile, int flags = NULL) {
   if (hFile <= 0)                       return(!catch("HistoryFile2.WriteBufferedBar(1)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile))  return(!catch("HistoryFile2.WriteBufferedBar(2)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] == 0)          return(!catch("HistoryFile2.WriteBufferedBar(3)  invalid parameter hFile: "+ hFile +" (unknown handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] <  0)          return(!catch("HistoryFile2.WriteBufferedBar(4)  invalid parameter hFile: "+ hFile +" (closed handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
      hf.hFile.lastValid = hFile;
   }
   int offset = hf.bufferedBar.offset[hFile];
   if (offset < 0)                       return(_true(logWarn("HistoryFile2.WriteBufferedBar(5)  undefined bufferedBar: hf.bufferedBar.offset="+ offset +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")")));
   if (offset != hf.total.bars[hFile]-1) return(!catch("HistoryFile2.WriteBufferedBar(6)  invalid hf.bufferedBar.offset: "+ offset +" ("+ hf.total.bars[hFile] +" full bars, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_RUNTIME_ERROR));

   // Die Bar wird nur dann geschrieben, wenn sie sich seit dem letzten Schreiben ge�ndert hat.
   if (hf.bufferedBar.modified[hFile]) {
      // Bar validieren
      datetime openTime = hf.bufferedBar.openTime[hFile];         if (!openTime) return(!catch("HistoryFile2.WriteBufferedBar(7)  invalid hf.lastStoredBar["+ offset +"].time: "+ openTime +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_RUNTIME_ERROR));
      int      V  = Round(hf.bufferedBar.data    [hFile][BAR_V]); if (!V)        return(!catch("HistoryFile2.WriteBufferedBar(8)  invalid hf.lastStoredBar["+ offset +"].volume: "+ V +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_RUNTIME_ERROR));

      // FilePointer positionieren, Daten normalisieren und schreiben
      int position = HISTORY_HEADER_size + offset*hf.barSize[hFile], digits=hf.digits[hFile];
      if (!FileSeek(hFile, position, SEEK_SET)) return(!catch("HistoryFile2.WriteBufferedBar(9)  "+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile])));

      hf.bufferedBar.data[hFile][BAR_O] = NormalizeDouble(hf.bufferedBar.data[hFile][BAR_O], digits);
      hf.bufferedBar.data[hFile][BAR_H] = NormalizeDouble(hf.bufferedBar.data[hFile][BAR_H], digits);
      hf.bufferedBar.data[hFile][BAR_L] = NormalizeDouble(hf.bufferedBar.data[hFile][BAR_L], digits);
      hf.bufferedBar.data[hFile][BAR_C] = NormalizeDouble(hf.bufferedBar.data[hFile][BAR_C], digits);
      hf.bufferedBar.data[hFile][BAR_V] = V;

      if (hf.format[hFile] == 400) {
         FileWriteInteger(hFile, openTime);
         FileWriteDouble (hFile, hf.bufferedBar.data[hFile][BAR_O]);
         FileWriteDouble (hFile, hf.bufferedBar.data[hFile][BAR_L]);
         FileWriteDouble (hFile, hf.bufferedBar.data[hFile][BAR_H]);
         FileWriteDouble (hFile, hf.bufferedBar.data[hFile][BAR_C]);
         FileWriteDouble (hFile, V);
      }
      else {               // 401
         FileWriteInteger(hFile, openTime);                             // int64
         FileWriteInteger(hFile, 0);
         FileWriteDouble (hFile, hf.bufferedBar.data[hFile][BAR_O]);
         FileWriteDouble (hFile, hf.bufferedBar.data[hFile][BAR_H]);
         FileWriteDouble (hFile, hf.bufferedBar.data[hFile][BAR_L]);
         FileWriteDouble (hFile, hf.bufferedBar.data[hFile][BAR_C]);
         FileWriteInteger(hFile, V);                                    // uint64: ticks
         FileWriteInteger(hFile, 0);
         FileWriteInteger(hFile, 0);                                    // int:    spread
         FileWriteInteger(hFile, 0);                                    // uint64: volume
         FileWriteInteger(hFile, 0);
      }
      hf.bufferedBar.modified[hFile] = false;

      // Das Schreiben macht die BufferedBar zus�tzlich zur LastStoredBar.
      hf.lastStoredBar.offset       [hFile]        = hf.bufferedBar.offset       [hFile];
      hf.lastStoredBar.openTime     [hFile]        = hf.bufferedBar.openTime     [hFile];
      hf.lastStoredBar.closeTime    [hFile]        = hf.bufferedBar.closeTime    [hFile];
      hf.lastStoredBar.nextCloseTime[hFile]        = hf.bufferedBar.nextCloseTime[hFile];
      hf.lastStoredBar.data         [hFile][BAR_T] = hf.bufferedBar.data         [hFile][BAR_T];
      hf.lastStoredBar.data         [hFile][BAR_O] = hf.bufferedBar.data         [hFile][BAR_O];
      hf.lastStoredBar.data         [hFile][BAR_H] = hf.bufferedBar.data         [hFile][BAR_H];
      hf.lastStoredBar.data         [hFile][BAR_L] = hf.bufferedBar.data         [hFile][BAR_L];
      hf.lastStoredBar.data         [hFile][BAR_C] = hf.bufferedBar.data         [hFile][BAR_C];
      hf.lastStoredBar.data         [hFile][BAR_V] = hf.bufferedBar.data         [hFile][BAR_V];

      // Metadaten aktualisieren: - Die Bar kann (a) erste Bar einer leeren History sein, (b) existierende j�ngste Bar oder (c) neue j�ngste Bar sein.
      //                          - Die Bar ist immer die j�ngste (letzte) Bar.
      //                          - Die Metadaten von hf.total.* �ndern sich nicht.
      //                          - Nach dem Speichern stimmen hf.stored.* und hf.total.* �berein.
      hf.stored.bars              [hFile] = hf.total.bars              [hFile];

      hf.stored.from.offset       [hFile] = hf.total.from.offset       [hFile];
      hf.stored.from.openTime     [hFile] = hf.total.from.openTime     [hFile];
      hf.stored.from.closeTime    [hFile] = hf.total.from.closeTime    [hFile];
      hf.stored.from.nextCloseTime[hFile] = hf.total.from.nextCloseTime[hFile];

      hf.stored.to.offset         [hFile] = hf.total.to.offset         [hFile];
      hf.stored.to.openTime       [hFile] = hf.total.to.openTime       [hFile];
      hf.stored.to.closeTime      [hFile] = hf.total.to.closeTime      [hFile];
      hf.stored.to.nextCloseTime  [hFile] = hf.total.to.nextCloseTime  [hFile];
   }

   int error = GetLastError();
   if (!error)
      return(true);
   return(!catch("HistoryFile2.WriteBufferedBar(10)  "+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]), error));
}


/**
 * Verschiebt alle Bars beginnend vom angegebenen from-Offset bis zum Ende der Historydatei an den angegebenen Ziel-Offset.
 *
 * @param  int hFile      - Handle der Historydatei
 * @param  int fromOffset - Start-Offset
 * @param  int destOffset - Ziel-Offset: Ist dieser Wert kleiner als der Start-Offset, wird die Historydatei entsprechend gek�rzt.
 *
 * @return bool - success status                                            TODO: Implementieren
 */
bool HistoryFile2.MoveBars(int hFile, int fromOffset, int destOffset) {
   return(!catch("HistoryFile2.MoveBars(1)  "+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_NOT_IMPLEMENTED));
}


/**
 * F�gt einer Historydatei einen weiteren Tick hinzu. Der Tick mu� zur j�ngsten Bar der Datei geh�ren und wird als Close-Preis gespeichert.
 *
 * @param  int      hFile - Handle der Historydatei
 * @param  datetime time  - Zeitpunkt des Ticks
 * @param  double   value - Datenwert
 * @param  int      flags - zus�tzliche, das Schreiben steuernde Flags (default: keine)
 *                          � HST_BUFFER_TICKS: puffert aufeinanderfolgende Ticks und schreibt die Daten erst beim jeweils n�chsten
 *                            BarOpen-Event
 *                          � HST_FILL_GAPS:    f�llt entstehende Gaps mit dem letzten Schlu�kurs vor dem Gap
 *
 * @return bool - success status
 */
bool HistoryFile2.AddTick(int hFile, datetime time, double value, int flags = NULL) {
   if (hFile <= 0)                         return(!catch("HistoryFile2.AddTick(1)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile))    return(!catch("HistoryFile2.AddTick(2)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] == 0)            return(!catch("HistoryFile2.AddTick(3)  invalid parameter hFile: "+ hFile +" (unknown handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] <  0)            return(!catch("HistoryFile2.AddTick(4)  invalid parameter hFile: "+ hFile +" (closed handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
      hf.hFile.lastValid = hFile;
   }
   if (time <= 0)                          return(!catch("HistoryFile2.AddTick(5)  invalid parameter time: "+ time +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
   if (time < hf.total.to.openTime[hFile]) return(!catch("HistoryFile2.AddTick(6)  cannot add tick to a closed bar: tickTime="+ TimeToStr(time, TIME_FULL) +", last bar.time="+ TimeToStr(hf.total.to.openTime[hFile], TIME_FULL) +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));

   double bar[6];
   bool   barExists[1];

   // Offset und OpenTime der Tick-Bar bestimmen
   datetime tick.time=time, tick.openTime;
   int      tick.offset      = -1;                                                     // Offset der Bar, zu der der Tick geh�rt
   double   tick.value       = NormalizeDouble(value, hf.digits[hFile]);
   bool     bufferedBarClose = false;                                                  // ob der Tick f�r die BufferedBar ein BarClose-Event ausl�st

   // Vorzugsweise (h�ufigster Fall) BufferedBar benutzen (bevor diese ggf. durch ein BarClose-Event geschlossen wird).
   if (hf.bufferedBar.offset[hFile] >= 0) {                                            // BufferedBar ist definiert (und ist immer j�ngste Bar)
      if (tick.time < hf.bufferedBar.closeTime[hFile]) {
         tick.offset   = hf.bufferedBar.offset  [hFile];                               // Tick liegt in BufferedBar
         tick.openTime = hf.bufferedBar.openTime[hFile];
      }
      else {
         if (tick.time < hf.bufferedBar.nextCloseTime[hFile]) {
            tick.offset   = hf.bufferedBar.offset   [hFile] + 1;                       // Tick liegt in der BufferedBar folgenden Bar
            tick.openTime = hf.bufferedBar.closeTime[hFile];
         }
         bufferedBarClose = true;                                                      // und l�st f�r die BufferedBar ein BarClose-Event aus
      }
   }
   // Danach LastStoredBar benutzen (bevor diese ggf. von HistoryFile2._WriteBufferedBar() �berschrieben wird).
   if (tick.offset==-1) /*&&*/ if (hf.lastStoredBar.offset[hFile] >= 0) {              // LastStoredBar ist definiert
      if (time >= hf.lastStoredBar.openTime[hFile]) {
         if (tick.time < hf.lastStoredBar.closeTime[hFile]) {
            tick.offset   = hf.lastStoredBar.offset  [hFile];                          // Tick liegt in LastStoredBar
            tick.openTime = hf.lastStoredBar.openTime[hFile];
         }
         else if (tick.time < hf.lastStoredBar.nextCloseTime[hFile]) {
            tick.offset   = hf.lastStoredBar.offset   [hFile] + 1;                     // Tick liegt in der LastStoredBar folgenden Bar
            tick.openTime = hf.lastStoredBar.closeTime[hFile];
         }
      }
   }
   // eine geschlossene BufferedBar schreiben
   if (bufferedBarClose) {
      if (!HistoryFile2.WriteBufferedBar(hFile, flags)) return(false);
      hf.bufferedBar.offset[hFile] = -1;                                               // BufferedBar zur�cksetzen
   }

   // HST_BUFFER_TICKS = TRUE:  Tick buffern
   if (HST_BUFFER_TICKS & flags && 1) {
      // ist BufferedBar leer, Tickbar laden oder neue Bar beginnen und zur BufferedBar machen
      if (hf.bufferedBar.offset[hFile] < 0) {                                          // BufferedBar ist leer
         if (tick.offset == -1) {
            if      (hf.period[hFile] <= PERIOD_D1 ) tick.openTime = tick.time - tick.time%hf.periodSecs[hFile];
            else if (hf.period[hFile] == PERIOD_W1 ) tick.openTime = tick.time - tick.time%DAYS - (TimeDayOfWeekEx(tick.time)+6)%7*DAYS;        // 00:00, Montag
            else if (hf.period[hFile] == PERIOD_MN1) tick.openTime = tick.time - tick.time%DAYS - (TimeDayEx(tick.time)-1)*DAYS;                // 00:00, 1. des Monats
            tick.offset = HistoryFile2.FindBar(hFile, tick.openTime, barExists); if (tick.offset < 0) return(false);
         }
         if (tick.offset < hf.total.bars[hFile]) {                                     // Tickbar existiert, laden
            if (!HistoryFile2.ReadBar(hFile, tick.offset, bar)) return(false);         // ReadBar() setzt LastStoredBar auf die Tickbar
            hf.bufferedBar.offset       [hFile]        = hf.lastStoredBar.offset       [hFile];
            hf.bufferedBar.openTime     [hFile]        = hf.lastStoredBar.openTime     [hFile];
            hf.bufferedBar.closeTime    [hFile]        = hf.lastStoredBar.closeTime    [hFile];
            hf.bufferedBar.nextCloseTime[hFile]        = hf.lastStoredBar.nextCloseTime[hFile];
            hf.bufferedBar.data         [hFile][BAR_T] = hf.lastStoredBar.data         [hFile][BAR_T];
            hf.bufferedBar.data         [hFile][BAR_O] = hf.lastStoredBar.data         [hFile][BAR_O];
            hf.bufferedBar.data         [hFile][BAR_H] = hf.lastStoredBar.data         [hFile][BAR_H];
            hf.bufferedBar.data         [hFile][BAR_L] = hf.lastStoredBar.data         [hFile][BAR_L];
            hf.bufferedBar.data         [hFile][BAR_C] = hf.lastStoredBar.data         [hFile][BAR_C];
            hf.bufferedBar.data         [hFile][BAR_V] = hf.lastStoredBar.data         [hFile][BAR_V];
            hf.bufferedBar.modified     [hFile]        = false;
         }
         else {                                                                        // Tickbar existiert nicht, neue BufferedBar initialisieren
            datetime closeTime, nextCloseTime;
            if (hf.period[hFile] <= PERIOD_W1) {
               closeTime     = tick.openTime + hf.periodSecs[hFile];
               nextCloseTime = closeTime     + hf.periodSecs[hFile];
            }
            else if (hf.period[hFile] == PERIOD_MN1) {
               closeTime     = DateTime1(TimeYearEx(tick.openTime), TimeMonth(tick.openTime)+1);   // 00:00, 1. des n�chsten Monats
               nextCloseTime = DateTime1(TimeYearEx(tick.openTime), TimeMonth(tick.openTime)+2);   // 00:00, 1. des �bern�chsten Monats
            }
            hf.bufferedBar.offset       [hFile]        = tick.offset;
            hf.bufferedBar.openTime     [hFile]        = tick.openTime;
            hf.bufferedBar.closeTime    [hFile]        = closeTime;
            hf.bufferedBar.nextCloseTime[hFile]        = nextCloseTime;
            hf.bufferedBar.data         [hFile][BAR_T] = tick.openTime;
            hf.bufferedBar.data         [hFile][BAR_O] = tick.value;
            hf.bufferedBar.data         [hFile][BAR_H] = tick.value;
            hf.bufferedBar.data         [hFile][BAR_L] = tick.value;
            hf.bufferedBar.data         [hFile][BAR_C] = tick.value;
            hf.bufferedBar.data         [hFile][BAR_V] = 0;                                        // das Volume wird erst im n�chsten Schritt auf 1 gesetzt
            hf.bufferedBar.modified     [hFile]        = true;

            // Metadaten aktualisieren: - Die Bar kann (a) erste Bar einer leeren History oder (b) neue Bar am Ende sein.
            //                          - Die Bar ist immer die j�ngste (letzte) Bar.
            //                          - Die Bar existiert in der Historydatei nicht, die Metadaten von hf.stored.* �ndern sich daher nicht.
                                    hf.total.bars              [hFile] = tick.offset + 1;

            if (tick.offset == 0) { hf.total.from.offset       [hFile] = tick.offset;
                                    hf.total.from.openTime     [hFile] = tick.openTime;
                                    hf.total.from.closeTime    [hFile] = closeTime;
                                    hf.total.from.nextCloseTime[hFile] = nextCloseTime; }

                                    hf.total.to.offset         [hFile] = tick.offset;
                                    hf.total.to.openTime       [hFile] = tick.openTime;
                                    hf.total.to.closeTime      [hFile] = closeTime;
                                    hf.total.to.nextCloseTime  [hFile] = nextCloseTime;
         }
      }

      // BufferedBar aktualisieren
      //.bufferedBar.data    [hFile][BAR_T] = ...                                      // unver�ndert
      //.bufferedBar.data    [hFile][BAR_O] = ...                                      // unver�ndert
      hf.bufferedBar.data    [hFile][BAR_H] = MathMax(hf.bufferedBar.data[hFile][BAR_H], tick.value);
      hf.bufferedBar.data    [hFile][BAR_L] = MathMin(hf.bufferedBar.data[hFile][BAR_L], tick.value);
      hf.bufferedBar.data    [hFile][BAR_C] = tick.value;
      hf.bufferedBar.data    [hFile][BAR_V]++;
      hf.bufferedBar.modified[hFile]        = true;

      return(true);
   }// end if HST_BUFFER_TICKS = TRUE


   // HST_BUFFER_TICKS = FALSE:  Tick schreiben
   // ist BufferedBar definiert (HST_BUFFER_TICKS war beim letzten Tick ON und ist jetzt OFF), BufferedBar mit Tick aktualisieren, schreiben und zur�cksetzen
   if (hf.bufferedBar.offset[hFile] >= 0) {                                            // BufferedBar ist definiert, der Tick mu� dazu geh�ren
      //.bufferedBar.data[hFile][BAR_T] = ...                                          // unver�ndert
      //.bufferedBar.data[hFile][BAR_O] = ...                                          // unver�ndert
      hf.bufferedBar.data[hFile][BAR_H] = MathMax(hf.bufferedBar.data[hFile][BAR_H], tick.value);
      hf.bufferedBar.data[hFile][BAR_L] = MathMin(hf.bufferedBar.data[hFile][BAR_L], tick.value);
      hf.bufferedBar.data[hFile][BAR_C] = tick.value;
      hf.bufferedBar.data[hFile][BAR_V]++;
      if (!HistoryFile2.WriteBufferedBar(hFile, flags)) return(false);
      hf.bufferedBar.offset[hFile] = -1;                                               // BufferedBar zur�cksetzen
      return(true);
   }

   // BufferedBar ist leer: Tickbar mit Tick aktualisieren oder neue Bar mit Tick zu History hinzuf�gen
   if (tick.offset == -1) {
      if      (hf.period[hFile] <= PERIOD_D1 ) tick.openTime = tick.time - tick.time%hf.periodSecs[hFile];
      else if (hf.period[hFile] == PERIOD_W1 ) tick.openTime = tick.time - tick.time%DAYS - (TimeDayOfWeekEx(tick.time)+6)%7*DAYS;          // 00:00, Montag
      else if (hf.period[hFile] == PERIOD_MN1) tick.openTime = tick.time - tick.time%DAYS - (TimeDayEx(tick.time)-1)*DAYS;                  // 00:00, 1. des Monats
      tick.offset = HistoryFile2.FindBar(hFile, tick.openTime, barExists); if (tick.offset < 0) return(false);
   }
   if (tick.offset < hf.total.bars[hFile]) {
      if (!HistoryFile2.UpdateBar(hFile, tick.offset, tick.value)) return(false);      // existierende Bar aktualisieren
   }
   else {
      bar[BAR_T] = tick.openTime;                                                      // oder neue Bar einf�gen
      bar[BAR_O] = tick.value;
      bar[BAR_H] = tick.value;
      bar[BAR_L] = tick.value;
      bar[BAR_C] = tick.value;
      bar[BAR_V] = 1;
      if (!HistoryFile2.InsertBar(hFile, tick.offset, bar, flags|HST_TIME_IS_OPENTIME)) return(false);
   }
   return(true);
}


/**
 * Resize the arrays holding HistorySet metadata.
 *
 * @param  int size - new size
 *
 * @return int - the same size value
 *
 * @access private
 */
int __ResizeSetArrays(int size) {
   int oldSize = ArraySize(hs.hSet);

   if (size != oldSize) {
      ArrayResize(hs.hSet,        size);
      ArrayResize(hs.symbol,      size);
      ArrayResize(hs.symbolU,     size);
      ArrayResize(hs.description, size);
      ArrayResize(hs.digits,      size);
      ArrayResize(hs.directory,   size);
      ArrayResize(hs.hFile,       size);
      ArrayResize(hs.format,      size);
   }

   for (int i=oldSize; i < size; i++) {
      hs.symbol     [i] = "";                   // init new strings to prevent NULL pointer errors
      hs.symbolU    [i] = "";
      hs.description[i] = "";
      hs.directory  [i] = "";
   }
   return(size);
}


/**
 * Resize the arrays holding HistoryFile metadata.
 *
 * @param  int size - new size
 *
 * @return int - the same size value
 *
 * @access private
 */
int __ResizeFileArrays(int size) {
   int oldSize = ArraySize(hf.hFile);

   if (size != oldSize) {
      ArrayResize(hf.hFile,                       size);
      ArrayResize(hf.name,                        size);
      ArrayResize(hf.readAccess,                  size);
      ArrayResize(hf.writeAccess,                 size);

      ArrayResize(hf.header,                      size);
      ArrayResize(hf.format,                      size);
      ArrayResize(hf.barSize,                     size);
      ArrayResize(hf.symbol,                      size);
      ArrayResize(hf.symbolU,                     size);
      ArrayResize(hf.period,                      size);
      ArrayResize(hf.periodSecs,                  size);
      ArrayResize(hf.digits,                      size);
      ArrayResize(hf.directory,                   size);

      ArrayResize(hf.stored.bars,                 size);
      ArrayResize(hf.stored.from.offset,          size);
      ArrayResize(hf.stored.from.openTime,        size);
      ArrayResize(hf.stored.from.closeTime,       size);
      ArrayResize(hf.stored.from.nextCloseTime,   size);
      ArrayResize(hf.stored.to.offset,            size);
      ArrayResize(hf.stored.to.openTime,          size);
      ArrayResize(hf.stored.to.closeTime,         size);
      ArrayResize(hf.stored.to.nextCloseTime,     size);

      ArrayResize(hf.total.bars,                  size);
      ArrayResize(hf.total.from.offset,           size);
      ArrayResize(hf.total.from.openTime,         size);
      ArrayResize(hf.total.from.closeTime,        size);
      ArrayResize(hf.total.from.nextCloseTime,    size);
      ArrayResize(hf.total.to.offset,             size);
      ArrayResize(hf.total.to.openTime,           size);
      ArrayResize(hf.total.to.closeTime,          size);
      ArrayResize(hf.total.to.nextCloseTime,      size);

      ArrayResize(hf.lastStoredBar.offset,        size);
      ArrayResize(hf.lastStoredBar.openTime,      size);
      ArrayResize(hf.lastStoredBar.closeTime,     size);
      ArrayResize(hf.lastStoredBar.nextCloseTime, size);
      ArrayResize(hf.lastStoredBar.data,          size);

      ArrayResize(hf.bufferedBar.offset,          size);
      ArrayResize(hf.bufferedBar.openTime,        size);
      ArrayResize(hf.bufferedBar.closeTime,       size);
      ArrayResize(hf.bufferedBar.nextCloseTime,   size);
      ArrayResize(hf.bufferedBar.data,            size);
      ArrayResize(hf.bufferedBar.modified,        size);
   }

   for (int i=oldSize; i < size; i++) {
      hf.name     [i] = "";                     // init new strings to prevent NULL pointer errors
      hf.symbol   [i] = "";
      hf.symbolU  [i] = "";
      hf.directory[i] = "";

      hf.lastStoredBar.offset[i] = -1;          // init new bar offset fields
      hf.bufferedBar.offset  [i] = -1;
   }
   return(size);
}


/**
 * Clean up opened files and issue a warning if an unclosed file was found.
 *
 * @return bool - success status
 *
 * @access private
 */
bool __CheckFileHandles() {
   int error, size=ArraySize(hf.hFile);

   for (int i=0; i < size; i++) {
      if (hf.hFile[i] > 0) {
         logWarn("__CheckFileHandles(1)  open file handle #"+ hf.hFile[i] +" found ("+ hf.symbol[i] +","+ PeriodDescription(hf.period[i]) +")");
         if (!HistoryFile2.Close(hf.hFile[i]))
            error = last_error;
      }
   }
   return(!error);
}


/**
 * Custom handler called in tester from core/library::init() to reset global variables before the next test.
 */
void onLibraryInit() {
   __ResizeSetArrays(0);
   __ResizeFileArrays(0);
}


/**
 * Deinitialisierung
 *
 * @return int - error status
 */
int onDeinit() {
   __CheckFileHandles();
   return(last_error);
}
