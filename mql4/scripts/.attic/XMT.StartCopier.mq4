/**
 * XMT.StartCopier
 *
 * Send a command to a virtual XMT-Scalper to start the trade copier.
 *
 * @see  mql4/experts/.attic/XMT-Scalper.mq4
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];
#include <core/script.mqh>
#include <stdfunctions.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   // A running XMT-Scalper maintains a chart object holding the instance id and the trading mode.
   string sid="", mode="", label="XMT-Scalper.status";
   bool isStartable = false;

   // check chart for a matching XMT-Scalper instance
   if (ObjectFind(label) == 0) {
      string text = StrTrim(ObjectDescription(label));                  // format: {sid}|{trading-mode}
      sid  = StrLeftTo(text, "|");
      mode = StrToLower(StrLeftTo(StrRightFrom(text, "|"), "|"));

      if (mode == "virtual")        isStartable = true;
      if (mode == "virtual-mirror") isStartable = true;
   }

   if (isStartable) {
      if (__isTesting) Tester.Pause();

      PlaySoundEx("Windows Notify.wav");                                // confirm sending the command
      int button = MessageBoxEx(ProgramName(), ifString(IsDemoFix(), "", "- Real Account -\n\n") +"Do you really want to start the XMT trade copier (sid "+ sid +")?", MB_ICONQUESTION|MB_OKCANCEL);
      if (button != IDOK) return(catch("onStart(1)"));
      SendChartCommand("EA.command", "virtual-copier");
   }
   else {
      PlaySoundEx("Windows Chord.wav");
      MessageBoxEx(ProgramName(), "No virtual XMT-Scalper found.", MB_ICONEXCLAMATION|MB_OK);
   }
   return(catch("onStart(2)"));
}
