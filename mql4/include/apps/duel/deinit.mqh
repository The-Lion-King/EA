/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   if (__isTesting) {
      if (!last_error && sequence.status!=STATUS_STOPPED) {
         if (IsLogInfo()) logInfo("onDeinit(1)  "+ sequence.name +" test stopped in status \""+ StatusDescription(sequence.status) +"\", profit: "+ sSequenceTotalPL +" "+ StrReplace(sSequencePlStats, " ", ""));
         SaveStatus();
      }
      return(last_error);
   }
   return(NO_ERROR);
}


/**
 * Called before input parameters are changed.
 *
 * @return int - error status
 *
 * @see  mql4/experts/Duel.mq4
 */
int onDeinitParameters() {
   BackupInputs();
   return(-1);                                                       // -1: skip all other deinit tasks
}


/**
 * Called before the current chart symbol or timeframe are changed.
 *
 * @return int - error status
 */
int onDeinitChartChange() {
   BackupInputs();
   return(-1);                                                       // -1: skip all other deinit tasks
}


/**
 * Online: Called in terminal builds <= 509 when a new chart template is applied.
 *         Called when the chart profile changes.
 *         Called when the chart is closed.
 *         Called in terminal builds <= 509 when the terminal shuts down.
 * Tester: Called when the chart is closed with VisualMode="On".
 *         Called if the test was explicitly stopped by using the "Stop" button (manually or by code). Global scalar variables
 *         may contain invalid values (strings are ok).
 *
 * @return int - error status
 */
int onDeinitChartClose() {
   if (!__isTesting && sequence.status!=STATUS_STOPPED) {
      logInfo("onDeinitChartClose(1)  "+ sequence.name +" expert unloaded in status \""+ StatusDescription(sequence.status) +"\", profit: "+ sSequenceTotalPL +" "+ StrReplace(sSequencePlStats, " ", ""));
   }
   return(NO_ERROR);
}


/**
 * Online: Called in terminal builds > 509 when a new chart template is applied.
 * Tester: ???
 *
 * @return int - error status
 */
int onDeinitTemplate() {
   if (!__isTesting && sequence.status!=STATUS_STOPPED) {
      logInfo("onDeinitTemplate(1)  "+ sequence.name +" expert unloaded in status \""+ StatusDescription(sequence.status) +"\", profit: "+ sSequenceTotalPL +" "+ StrReplace(sSequencePlStats, " ", ""));
   }
   return(NO_ERROR);
}


/**
 * Called when the expert is manually removed (Chart->Expert->Remove) or replaced.
 *
 * @return int - error status
 */
int onDeinitRemove() {
   if (sequence.status != STATUS_STOPPED) {
      logInfo("onDeinitRemove(1)  "+ sequence.name +" expert removed in status \""+ StatusDescription(sequence.status) +"\", profit: "+ sSequenceTotalPL +" "+ StrReplace(sSequencePlStats, " ", ""));
   }
   RemoveSequenceId();                                               // remove a stored sequence id
   return(NO_ERROR);
}


/**
 * Called in terminal builds > 509 when the terminal shuts down.
 *
 * @return int - error status
 */
int onDeinitClose() {
   if (sequence.status != STATUS_STOPPED) {
      logInfo("onDeinitClose(1)  "+ sequence.name +" terminal shutdown in status \""+ StatusDescription(sequence.status) +"\", profit: "+ sSequenceTotalPL +" "+ StrReplace(sSequencePlStats, " ", ""));
   }
   return(NO_ERROR);
}
