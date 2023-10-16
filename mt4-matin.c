//+------------------------------------------------------------------+
//|                                              mt4-liyingguang.mq4 |
//|                        Copyright 2021, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property strict
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

// 常量不修改
const string FIRST_COMMENT = "ea_start_1_"; // 第一单的comment
const string DIVIDE_FLAG_COMMENT = "DIVIDE_FLAG_";

double floatProfit = 0.0; // 浮盈&浮亏
double historyProfit = 0.0; // 此轮历史盈利
double maxLossPoint = 0; // 首单浮亏多少点
double MINI_LOT = 0.01; // 最小仓位

// 换账户的话，下面这几个个常量需要修改
input double TACKPROFIT_POINT = 0; // 止盈点数
input double WAVE_POINT = 0; // 波动多大开始加仓
input double SOLVE_POINT = 0; // 首单波动多大开始对冲
input double STARTLOT = 0.05; // 第一单手数大小
input double SEPLOT = 0.05; // 间隔手数
input int divideHolding = 30; // 分隔单持仓多久(s)


string companyName = ""; // 外汇平台是哪家
string eaSymbol = "";
double flag_EARunningDays = 0;
double EARunningDays = 0;

// 当前订单总数
int total = 0;

// 当等于true时不交易
bool isSleeping = false;
bool divideOnceFlag = false;

// 半小时内波动多大所使用变量
double prePrice = 0.0;
double postPrice = 0.0;
int preTime = 0;
int postTime = 0;

string sendText = "init text";


string buttonID2="昨日日最高";
string buttonID3="昨日最低";
string buttonID4="今日开盘";
string buttonID5="今日最高";
string buttonID6="今日最低";

int IS_SHOW_PRICE_OBJECT = 1; // 是否显示自定义面板



 /*
单向马丁策略


 第一单随机开仓0.05
 间隔20点加仓，止盈13个点

 平仓：
 正常止盈
 此轮平仓盈利>首单浮亏绝对值的2倍, 平仓首单
 此轮平仓盈利>整体浮亏绝对值的2倍, 清仓所有


 重要时间节点不开仓：
 20:30 前后十分钟（冬令时是21:30）
 22:00 前后五分钟
 02:00 前后十分钟（冬令时是03:00）

 其他：
 本来是挂单作为开始标识，但是exness竟然删我历史挂单。以防万一，特以0.01作为开始标识
 
 **/


int OnInit()
  { 
    companyName = AccountCompany();
    StringToLower(companyName);

    MINI_LOT = MarketInfo(eaSymbol, MODE_MINLOT); // 最小仓位


    eaSymbol = Symbol();

    // 初始化
    prePrice = SymbolInfoDouble(eaSymbol, SYMBOL_BID); // 卖价
    preTime = TimeCurrent();


   if(IS_SHOW_PRICE_OBJECT == 1) {
      InitPriceShowObject();
   }

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
     if(WAVE_POINT == 0 || TACKPROFIT_POINT == 0 || SOLVE_POINT == 0) {
       Print("NO WAVE_POINT AND TACKPROFIT_POINT, please SET!========================");
       return;
     }
     PrintEARunningDays();
    
    int eaSymboltotal = GetEaSymbolTotal();
   //  Print(eaSymbol, ":", "eaSymboltotal=", eaSymboltotal);
  
    if(eaSymboltotal == 0) {
       int orderType = GetRandomOrderType();
       double tp = SymbolInfoDouble(eaSymbol, SYMBOL_ASK) + TACKPROFIT_POINT;  // 买价
       if(orderType == 1) { // sell
         tp = SymbolInfoDouble(eaSymbol, SYMBOL_BID) - TACKPROFIT_POINT;
       }
       if(divideOnceFlag) {
          openOrder(eaSymbol, orderType, STARTLOT, 0, tp, FIRST_COMMENT + eaSymbol); // buy
          divideOnceFlag = false;
       } else {
           openOrder(eaSymbol, 0, MINI_LOT, 0, 0, DIVIDE_FLAG_COMMENT + eaSymbol); // buy limit挂单作为开始标识
           divideOnceFlag = true;
       }
    }

  //  if(maxLossPoint > SOLVE_POINT  && historyProfit > MathAbs(floatProfit * 2)) { // 盈利大于亏损的2倍，则清仓
  //    CloseOrder("SYMBOL", 323434, eaSymbol);
  //  }

   IsWaveTooMuch();
   CheckOrders();
   CheckHistoryOrders();
   CheckRecentDay();
 
   Print("historyProfit=", DoubleToStr(historyProfit, 4), ", floatProfit=", DoubleToStr(floatProfit, 4), ", isSleeping=", isSleeping, ", targetLossPoint=", SOLVE_POINT,  ", maxLossPoint=", DoubleToStr(maxLossPoint, 4));
  }

int GetEaSymbolTotal(){
   int total=OrdersTotal();
   int eaTotal = 0;
  for(int i=0;i<total;i++)
  {
   if(OrderSelect(i,SELECT_BY_POS)==false) continue;
   string symbol = OrderSymbol();
   if(StringFind(symbol, eaSymbol) == -1) continue;
     eaTotal ++ ;
   }
   return eaTotal;
}
  

//+----------------------检查开仓单子--------------------------------------------+
void CheckOrders(){
   int total=OrdersTotal();
   floatProfit = 0.0;
   int y = -1;
   double newOpenPrice = 0.0;
   double newOpenVolume = 0.0;
   double newOpenProfit = 0.0;
   double newOpenOrderType = 0;
   double currentPrice =  SymbolInfoDouble(eaSymbol, SYMBOL_BID); // 卖价
  for(int i=0;i<total;i++)
    {
   if(OrderSelect(i,SELECT_BY_POS)==false) continue;
   string symbol = OrderSymbol();
   if(StringFind(symbol, eaSymbol) == -1) continue;
     y ++;
     string comment =  OrderComment();
     if(StringFind(comment, "ea") > -1) {
        floatProfit = floatProfit + OrderProfit() + OrderSwap();
     }
   
     newOpenOrderType = OrderType();
     newOpenVolume = OrderLots();
     newOpenPrice = OrderOpenPrice();
     newOpenProfit = OrderProfit() + OrderSwap();

     int holdingTime = TimeCurrent() - OrderOpenTime(); // 秒
     if(StringFind(comment, DIVIDE_FLAG_COMMENT + eaSymbol) > -1 && holdingTime > divideHolding) { // 开始标识: 挂单，则delete； 1分钟
       CloseOrder("PART", OrderTicket());
       continue;
     }

     if(y == 0) { // 首单浮亏绝对值的2倍<平仓盈利 ; 5分钟
       maxLossPoint = MathAbs(NormalizeDouble(currentPrice - newOpenPrice, 4));
       if(newOpenProfit < 0 && maxLossPoint > SOLVE_POINT && historyProfit > MathAbs(newOpenProfit) * 2) {
           CloseOrder("PART", OrderTicket());
           continue;
       }
     }
    }

    if(isSleeping) { // 半小时内涨跌太多，停止做单
      return;
    }

    if(newOpenProfit < 0 &&  MathAbs(NormalizeDouble(currentPrice - newOpenPrice, 4)) > WAVE_POINT ) { //如果当前价格与最近交易单子，亏损大于20个点
        double tp = SymbolInfoDouble(eaSymbol, SYMBOL_ASK) + TACKPROFIT_POINT;  // buy
        if(newOpenOrderType == 1) { // sell
          tp = SymbolInfoDouble(eaSymbol, SYMBOL_BID) - TACKPROFIT_POINT;
        }
        openOrder(eaSymbol, newOpenOrderType, newOpenVolume + SEPLOT, 0, tp, "ea_"  + MathCeil(newOpenVolume / SEPLOT + 1) + "_" +  eaSymbol); //  13个点止盈
    }
}

//+-----------------------检查历史单子-------------------------------------------+
void CheckHistoryOrders(){
  int total=OrdersHistoryTotal();
  historyProfit = 0.0;
  for(int i = total-1; i >= 0; i --)
    {
   if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)==false) continue;
   string symbol = OrderSymbol();
   if(StringFind(symbol, eaSymbol) == -1) continue;
     string comment =  OrderComment();
     int orderType = OrderType();
     if(StringFind(comment, DIVIDE_FLAG_COMMENT + eaSymbol) > -1) { //找到开始标识，则停止计算历史盈利
       break;
     } else if(StringFind(symbol, eaSymbol) > -1 && StringFind(comment, "ea", 0) > -1) {
        historyProfit = historyProfit + OrderProfit() + OrderSwap();
     }
    }
}

//+-----------------------开仓-------------------------------------------+
void openOrder(string symbol, int orderType = 0, double volume = 0.01, double st = 0, double tp = 0, string comment = ""){
    
     // string symbol = Symbol();
    //  int orderType = orderType; // 0:buy，1:sell
     double openPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);// 买价
     if(orderType == 1) { // sell
        openPrice = SymbolInfoDouble(symbol, SYMBOL_BID); // 卖价
     }else if(orderType == 2) { // 挂单
        openPrice = openPrice - 0.02;
     }


     bool res =  OrderSend(symbol, orderType, volume, openPrice, 30, st, tp, comment , 0, 0 );
      if(!res)
          Print("Error in OrderSend. Error code=",GetLastError());
      else {
          Print("OrderSend  successfully.");
      }      
    
}

//+-----------------------平仓-------------------------------------------+
void CloseOrder(string closeType = "11111", ulong ticket = 10000, string symbol = "init")
{
   // Update the exchange rates before closing the orders.
   RefreshRates();
   // Log in the terminal the total of orders, current and past.
   Print(OrdersTotal());
      
   // Start a loop to scan all the orders.
   // The loop starts from the last order, proceeding backwards; Otherwise it would skip some orders.
   for (int i = (OrdersTotal() - 1); i >= 0; i--)
   {
      // If the order cannot be selected, throw and log an error.
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == false)
          {
         Print("ERROR - Unable to select the order - ", GetLastError());
         break;
      } 


      // Create the required variables.
      // Result variable - to check if the operation is successful or not.
      bool res = false;
      
      // Allowed Slippage - the difference between current price and close price.
      int Slippage = 0;
      int closeTicket = OrderTicket();
      string orderSymbol = OrderSymbol();
      if(closeType == "ALL") {
        closeTicket = OrderTicket();
      } else if (closeType == "PART" && closeTicket != ticket) {
       continue;
      }else if(closeType == "SYMBOL" && orderSymbol != symbol) {
        continue;
      }
      // Bid and Ask prices for the instrument of the order.
      double BidPrice = MarketInfo(orderSymbol, MODE_BID);
      double AskPrice = MarketInfo(orderSymbol, MODE_ASK);

      // double BidPrice = MarketInfo(OrderSymbol(), MODE_BID);

      // Closing the order using the correct price depending on the type of order.
      if (OrderType() == OP_BUY)
          {
         res = OrderClose(closeTicket, OrderLots(), BidPrice, Slippage);
      }
      else if (OrderType() == OP_SELL)
          {
         res = OrderClose(closeTicket, OrderLots(), AskPrice, Slippage);
      }
      
      // If there was an error, log it.
      if (res == false) Print("ERROR - Unable to close the order - ", OrderTicket(), " - ", GetLastError());
   }
}
//+--------------------------30分钟之内逆势涨跌超过20点------------------------------------------+
//+--------------------------接下来30分钟则不开仓-------------------------------------------+
void IsWaveTooMuch() {
  int orderType = GetOpenOrderType();
  postTime = TimeCurrent();
  postPrice = SymbolInfoDouble(eaSymbol, SYMBOL_BID); // 卖价
  // Print(eaSymbol, ":", "WAVE_POINT: ",WAVE_POINT);
  Print("time: ", postTime - preTime, ", or " + DoubleToStr((postTime - preTime)/ 60.0, 1), " mins, prePrice: ", prePrice, ", postPrice",  postPrice, ", diffPrice: ", DoubleToStr(MathAbs(postPrice - prePrice), 4));
  // 30分钟之内逆势涨跌超过WAVE_POINT点，则接下来1小时不开仓
  if(postTime - preTime < 60*30 && ((orderType == 0 && NormalizeDouble(prePrice - postPrice, 4) > WAVE_POINT ) || (orderType == 1 && NormalizeDouble(postPrice - prePrice, 4) > WAVE_POINT))) {
     isSleeping = true;
     preTime = postTime;
     prePrice = postPrice;
     Print(eaSymbol, ":", "Attention=========up and down is too much==============", MathAbs(postPrice - prePrice));
  } 
  if(postTime - preTime > 60*60){
    isSleeping = false;
    preTime = postTime;
    prePrice = postPrice;
  }

}
//+--------------------------获取EA开仓的方向-------------------------------------------+
int GetOpenOrderType() {
  for(int i=0;i<total;i++)
    {
     if(OrderSelect(i,SELECT_BY_POS)==false) continue;
     string comment =  OrderComment();
     if(StringFind(comment, eaSymbol) > -1) {
       return OrderType();
     }
  }
  return 0;
}

//+--------------------------限制停止开仓时间-------------------------------------------+
bool IsOpenOrderStop() {
     int gtc = 0;

     // 时区兼容
     if(StringFind(companyName, "xm") > -1) { 
       gtc = 5;
     } else if(StringFind(companyName, "exness") > -1) {
       gtc = 8;
     }
     int realHour = Hour() + gtc;
     if(DayOfWeek() == 5 && realHour == 20 && Day() < 8) { //  当月第一周的周五，非农20点不交易
       return true;
     }
     if(DayOfWeek() == 4 && realHour == 20) { // 每周四的20点不交易
       return true;
     }
     
     // 特殊时间节点，不开仓
    if((realHour == 20) && Minute() > 20 && Minute() < 40) { // 20:30 21:30
      return true;
    } else if((realHour == 22) && (Minute() > 55 || Minute() < 5)) { // 22:00 23:00
      return true;
    } else if((realHour == 26) && (Minute() > 50 || Minute() < 10)) { // 02:00 03:00
      return true;
    }
    return false;
}

//+--------------------------随机获取做单方向-------------------------------------------+
int GetRandomOrderType() {
   int random = MathRand(); // 用来确定方向的随机数，是多少无所谓。随机游走
   int orderType = 0; // 0:buy，1:sell
   if(random % 2 == 0) {
      orderType = 0;
    }else {
      orderType = 1;
    }
  return orderType;
}


//+--------------------------获取账户类型-------------------------------------------+
string GetAccountType() {
     string last = "";
     if(StringFind(eaSymbol, "m") > -1) {
         last = "m";
       } else if(StringFind(eaSymbol, "c") > -1) {
         last = "c";
       } else if(StringFind(eaSymbol, "#") > -1) {
         last = "#";
       } else if(StringFind(eaSymbol, "micro") > -1) {
         last = "micro";
       } else if(StringFind(eaSymbol, "m#") > -1) {
         last = "m#";
       }
    return last;
}

//+--------------------------EA运行天数-------------------------------------------+
void PrintEARunningDays() {
    if(Hour() == 2 && flag_EARunningDays == 0) {
      EARunningDays++;
      flag_EARunningDays = 1;
    } else if(Hour() != 2) {
      flag_EARunningDays = 0;
    }
   Print("account#",  AccountNumber() , ", EA is runing ", EARunningDays + " days");
}



void CheckRecentDay() {
  double iHigh1 = iHigh(eaSymbol, PERIOD_D1, 1);
  double iLow1 = iLow(eaSymbol, PERIOD_D1, 1);
  double iOpen = iOpen(eaSymbol, PERIOD_D1, 0);
  double iHigh = iHigh(eaSymbol, PERIOD_D1, 0);
  double iLow = iLow(eaSymbol, PERIOD_D1, 0);
  ObjectSetString(0, buttonID2, OBJPROP_TEXT,"昨日最高: " + DoubleToStr(iHigh1, 5));
  ObjectSetString(0, buttonID3, OBJPROP_TEXT,"昨日最低: " + DoubleToStr(iLow1, 5));
  ObjectSetString(0, buttonID4, OBJPROP_TEXT,"今日开盘: " + DoubleToStr(iOpen, 5) );
  ObjectSetString(0, buttonID5, OBJPROP_TEXT,"今日最高: " + DoubleToStr(iHigh, 5) );
  ObjectSetString(0, buttonID6, OBJPROP_TEXT,"今日最低: " + DoubleToStr(iLow, 5) );
}

void InitPriceShowObject() {
   initObject(buttonID2, 50, 30);
   initObject(buttonID3, 240, 30);
   initObject(buttonID4, 430, 30);
   initObject(buttonID5, 630, 30);
   initObject(buttonID6, 830, 30);
}

void initObject(string objectId, int x, int y, int bx = 150, int by = 50) {

  ObjectCreate(0,objectId,OBJ_BUTTON,0,1,1);
  ObjectSetInteger(0,objectId,OBJPROP_COLOR,clrWhite);
  ObjectSetInteger(0,objectId,OBJPROP_BGCOLOR,clrBlue);
  ObjectSetInteger(0,objectId,OBJPROP_XDISTANCE, x);
  ObjectSetInteger(0,objectId,OBJPROP_YDISTANCE, y);
  ObjectSetInteger(0,objectId,OBJPROP_XSIZE, bx);
  ObjectSetInteger(0,objectId,OBJPROP_YSIZE, by);
  ObjectSetString(0,objectId,OBJPROP_FONT,"Arial");
  ObjectSetString(0,objectId,OBJPROP_TEXT,"--");
  ObjectSetInteger(0,objectId,OBJPROP_FONTSIZE,8);
  ObjectSetInteger(0,objectId,OBJPROP_SELECTABLE,0);
}