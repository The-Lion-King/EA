/**
 * Ruft den Kontextmen�-Befehl Chart->Refresh auf.
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>


/**
 * Main-Funktion
 *
 * @return int - error status
 */
int onStart() {
   return(Chart.Refresh());
}
