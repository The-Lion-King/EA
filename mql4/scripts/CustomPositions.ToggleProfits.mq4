/**
 * Schickt dem ChartInfos-Indikator des aktuellen Charts die Nachricht, die Anzeige der PL-Betr�ge der Positionen von
 * "absolut" zu "prozentual" umzuschaltem.
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <core/script.mqh>
#include <stdfunctions.mqh>


/**
 * Main-Funktion
 *
 * @return int - error status
 */
int onStart() {
   SendChartCommand("ChartInfos.command", "toggle-profit-unit");
   return(catch("onStart(1)"));
}
