/**
 * Update a trendline's indicator buffers for trend direction and coloring.
 *
 * @param  _In_  double values[]                  - Trendline values (a timeseries).
 * @param  _In_  int    offset                    - Bar offset to update.
 * @param  _Out_ double trend[]                   - Buffer for trend direction and length: -n...-1 ... +1...+n.
 * @param  _Out_ double uptrend[]                 - Buffer for rising trendline values.
 * @param  _Out_ double downtrend[]               - Buffer for falling trendline values.
 * @param  _Out_ double uptrend2[]                - Additional buffer for single-bar uptrends. Must overlay uptrend[] and downtrend[] to be visible.
 * @param  _In_  bool   enableColoring [optional] - Whether to update the up/downtrend buffers for trend coloring (default: no).
 * @param  _In_  bool   enableUptrend2 [optional] - Whether to update the single-bar uptrend buffer (if enableColoring=On, default: no).
 * @param  _In_  int    lineStyle      [optional] - Trendline drawing style: If set to DRAW_LINE a line is drawn immediately at the start of a trend.
 *                                                  Otherwise MetaTrader needs at least two data points to draw a line (default: draw data points only).
 * @param  _In_  int    digits         [optional] - If set, trendline values are normalized to the specified number of digits (default: no normalization).
 *
 * @return bool - success status
 */
bool UpdateTrendDirection(double values[], int offset, double &trend[], double &uptrend[], double &downtrend[], double &uptrend2[], bool enableColoring=false, bool enableUptrend2=false, int lineStyle=EMPTY, int digits=EMPTY_VALUE) {
   enableColoring = enableColoring!=0;
   enableUptrend2 = enableColoring && enableUptrend2!=0;

   if (offset >= Bars-1) {
      if (offset >= Bars) return(!catch("UpdateTrendDirection(1)  illegal parameter offset: "+ offset +" (Bars="+ Bars +")", ERR_INVALID_PARAMETER));
      trend[offset] = 0;

      if (enableColoring) {
         uptrend  [offset] = EMPTY_VALUE;
         downtrend[offset] = EMPTY_VALUE;
         if (enableUptrend2)
            uptrend2[offset] = EMPTY_VALUE;
      }
      return(true);
   }

   double curValue  = values[offset];
   double prevValue = values[offset+1];

   // normalization has the affect of reversal smoothing and can prevent jitter of a seemingly flat line
   if (digits != EMPTY_VALUE) {
      curValue  = NormalizeDouble(curValue,  digits);
      prevValue = NormalizeDouble(prevValue, digits);
   }

   // trend direction
   if (prevValue == EMPTY_VALUE) {
      trend[offset] = 0;
   }
   else if (trend[offset+1] == 0) {
      trend[offset] = 0;

      if (offset < Bars-2) {
         double pre2Value = values[offset+2];
         if      (pre2Value == EMPTY_VALUE)                       trend[offset] =  0;
         else if (pre2Value <= prevValue && prevValue > curValue) trend[offset] = -1;  // curValue is a change of direction
         else if (pre2Value >= prevValue && prevValue < curValue) trend[offset] =  1;  // curValue is a change of direction
      }
   }
   else {
      int prevTrend = trend[offset+1];
      if      (curValue > prevValue) trend[offset] = Max(prevTrend, 0) + 1;
      else if (curValue < prevValue) trend[offset] = Min(prevTrend, 0) - 1;
      else   /*curValue== prevValue*/trend[offset] = prevTrend + Sign(prevTrend);
   }

   // trend coloring
   if (!enableColoring) return(true);

   if (trend[offset] > 0) {                                                      // now uptrend
      uptrend  [offset] = values[offset];
      downtrend[offset] = EMPTY_VALUE;

      if (lineStyle == DRAW_LINE) {                                              // if DRAW_LINE...
         if      (trend[offset+1] < 0) uptrend  [offset+1] = values[offset+1];   // and downtrend before, set another data point to make the terminal draw the line
         else if (trend[offset+1] > 0) downtrend[offset+1] = EMPTY_VALUE;
      }
   }
   else if (trend[offset] < 0) {                                                 // now downtrend
      uptrend  [offset] = EMPTY_VALUE;
      downtrend[offset] = values[offset];

      if (lineStyle == DRAW_LINE) {                                              // if DRAW_LINE...
         if (trend[offset+1] > 0) {                                              // and uptrend before, set another data point to make the terminal draw the line
            downtrend[offset+1] = values[offset+1];
            if (enableUptrend2) {
               if (Bars > offset+2) {
                  if (trend[offset+2] < 0) {                                     // if that uptrend was a 1-bar reversal, copy it to uptrend2 (to overlay),
                     uptrend2[offset+2] = values[offset+2];                      // otherwise the visual gets lost through the just added data point
                     uptrend2[offset+1] = values[offset+1];
                  }
               }
            }
         }
         else if (trend[offset+1] < 0) {
            uptrend[offset+1] = EMPTY_VALUE;
         }
      }
   }
   else if (values[offset] != EMPTY_VALUE) {                                     // trend length is 0 (still undefined during the first visible swing)
      if (prevValue == EMPTY_VALUE) {
         uptrend  [offset] = EMPTY_VALUE;
         downtrend[offset] = EMPTY_VALUE;
      }
      else if (curValue > prevValue) {
         uptrend  [offset] = values[offset];
         downtrend[offset] = EMPTY_VALUE;
      }
      else /*curValue < prevValue*/ {
         uptrend  [offset] = EMPTY_VALUE;
         downtrend[offset] = values[offset];
      }
   }
   return(true);

   /*                  [4] [3] [2] [1] [0]
   onBarOpen()  trend: -5  -6  -7  -8  -9
   onBarOpen()  trend: -5  -6  -7  -8   1     after a downtrend of 8 bars trend turns up
   onBarOpen()  trend: -6  -7  -8   1   2
   onBarOpen()  trend: -7  -8   1   2   3
   onBarOpen()  trend: -8   1   2   3  -1     after an uptrend of 3 bars trend turns down
   */

   // dummy call
   UpdateTrendLegend(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
}


/**
 * Update a trendline's chart legend.
 *
 * @param  string   legendName     - the legend's chart object name
 * @param  string   indicatorName  - displayed indicator name
 * @param  string   status         - additional status info (if any)
 * @param  color    uptrendColor   - the uptrend color
 * @param  color    downtrendColor - the downtrend color
 * @param  double   value          - indicator value to display
 * @param  int      digits         - digits of the value to display
 * @param  double   dTrend         - trend direction of the value to display (type double allows passing of non-normalized values)
 * @param  datetime time           - bar time of the value to display
 */
void UpdateTrendLegend(string legendName, string indicatorName, string status, color uptrendColor, color downtrendColor, double value, int digits, double dTrend, datetime time) {
   static string   lastName = "";
   static double   lastValue;
   static int      lastTrend;
   static datetime lastTime;
   string sValue="", sTrend="", sOnTrendChange="";

   value = NormalizeDouble(value, digits);
   int trend = MathRound(dTrend);

   // update if name, value, trend direction or bar changed
   if (indicatorName!=lastName || value!=lastValue || trend!=lastTrend || time!=lastTime) {
      if (digits == Digits) sValue = NumberToStr(value, PriceFormat);
      else                  sValue = DoubleToStr(value, digits);

      if (trend  != 0)  sTrend = StringConcatenate("  (", trend, ")");
      if (status != "") status = StringConcatenate("  ", status);

      if (uptrendColor != downtrendColor) {
         if      (trend ==  1) sOnTrendChange = "  turns up";           // intra-bar trend change
         else if (trend == -1) sOnTrendChange = "  turns down";         // ...
      }

      string text = StringConcatenate(indicatorName, "    ", sValue, sTrend, sOnTrendChange, status);
      color  textColor = ifInt(trend > 0, uptrendColor, downtrendColor);
      if      (textColor == Aqua        ) textColor = DeepSkyBlue;
      else if (textColor == Gold        ) textColor = Orange;
      else if (textColor == LightSkyBlue) textColor = C'94,174,255';
      else if (textColor == Lime        ) textColor = LimeGreen;
      else if (textColor == Yellow      ) textColor = Orange;

      ObjectSetText(legendName, text, 9, "Arial Fett", textColor);
      int error = GetLastError();
      if (error && error!=ERR_OBJECT_DOES_NOT_EXIST)                    // on ObjectDrag or opened "Properties" dialog
         return(catch("UpdateTrendLegend(1)", error));
   }

   lastName  = indicatorName;
   lastValue = value;
   lastTrend = trend;
   lastTime  = time;
   return;

   /*                  [3] [2] [1] [0]
   onBarOpen()  trend: -6  -7  -8  -9
   onBarOpen()  trend: -6  -7  -8   1     after a downtrend of 8 bars trend turns up
   onBarOpen()  trend: -7  -8   1   2
   onBarOpen()  trend: -8   1   2   3
   onBarOpen()  trend:  1   2   3  -1     after an uptrend of 3 bars trend turns down
   */

   // dummy call
   double dNull[];
   UpdateTrendDirection(dNull, NULL, dNull, dNull, dNull, dNull, NULL);
}
