/**
 * Update a band's chart legend.
 *
 * @param  string   label          - chart label of the legend object
 * @param  string   name           - the band's name (usually the indicator name)
 * @param  string   status         - additional status info (if any)
 * @param  color    bandsColor     - the band color
 * @param  double   upperValue     - current upper band value
 * @param  double   lowerValue     - current lower band value
 * @param  int      digits         - digits of the values to display
 * @param  datetime barOpenTime    - current bar opentime
 */
void Bands.UpdateLegend(string label, string name, string status, color bandsColor, double upperValue, double lowerValue, int digits, datetime barOpenTime) {
   static double   lastUpperValue;
   static double   lastLowerValue;
   static datetime lastBarOpenTime;

   upperValue = NormalizeDouble(upperValue, 8);
   lowerValue = NormalizeDouble(lowerValue, 8);

   // update if values or bar changed
   if (upperValue!=lastUpperValue || lowerValue!=lastLowerValue || barOpenTime!=lastBarOpenTime) {
      string sUpperValue="", sLowerValue="";

      if (digits == Digits) {
         sUpperValue = NumberToStr(upperValue, PriceFormat);
         sLowerValue = NumberToStr(lowerValue, PriceFormat);
      }
      else {
         sUpperValue = DoubleToStr(upperValue, digits);
         sLowerValue = DoubleToStr(lowerValue, digits);
      }
      string text = StringConcatenate(name, "    ", sLowerValue, " / ", sUpperValue, "    ", status);
      color  textColor = bandsColor;
      if      (textColor == Aqua        ) textColor = DeepSkyBlue;
      else if (textColor == Gold        ) textColor = Orange;
      else if (textColor == LightSkyBlue) textColor = C'94,174,255';
      else if (textColor == Lime        ) textColor = LimeGreen;
      else if (textColor == Yellow      ) textColor = Orange;
      ObjectSetText(label, text, 9, "Arial Fett", textColor);

      int error = GetLastError();
      if (error && error!=ERR_OBJECT_DOES_NOT_EXIST)                    // on ObjectDrag or opened "Properties" dialog
         return(catch("Bands.UpdateLegend(1)", error));
   }

   lastUpperValue  = upperValue;
   lastLowerValue  = lowerValue;
   lastBarOpenTime = barOpenTime;
}
