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
const string UP_COMMENT = "ea_UP_"; // 第一单的comment
const string DOWN_COMMENT = "ea_DOWN_"; // 第一单的comment
const string DIVIDE_FLAG_UP_COMMENT = "DIVIDE_FLAG_UP_";
const string DIVIDE_FLAG_DOWN_COMMENT = "DIVIDE_FLAG_DOWN_";
const string DIVIDE_FLAG = "DIVIDE_FLAG";


double floatProfit = 0.0; // 浮盈&浮亏
// double historyProfit = 0.0; // 此轮历史盈利

double upHistoryProfit = 0.0;
double downHistoryProfit = 0.0;

double maxLossPoint = 0; // 首单浮亏多少点
double MINI_LOT = 0.01; // 最小仓位


input string SYMBOL_TEXT = "黄金"; // 品种描述
// 换账户的话，下面这几个个常量需要修改
input double TACKPROFIT_POINT = 2.6; // 止损点数
input double WAVE_POINT = 4; // 波动多大开始加仓
double SOLVE_POINT = 500; // 首单波动多大开始对冲。黄金不再对冲
input double STARTLOT = 0.05; // 第一单手数大小
input double SEPLOT = 0.05; // 间隔手数
input int divideHolding = 5; // 分隔单持仓多久(s)
// 为了防止EA意外盲目开单情况，做此限制。当停止开单确认无误后，再提高此数量
input int SYMBOLLIMIT_TOTAL = 50; // 每个品种最多开多少单
extern int INIT_EQUITY_LIMIT = 5000; // 首次净值是多少
input int PROFIT_REOVER = 700; // 每盈利多少重新来过
input int WAIT_HOURS= 5; // 清仓后等待多久重新开始(小时)
input int MAX_SPREAD = 60; // 点差大于多少不交易
input int BEFORE_WEEK = 3; // 周几之前达成目标可以重新来过
input int SEND_EMAIL = 0; // 达到目标后是否发送邮件
input double LEFT_EQUITY = 50; // 爆仓剩余多少时邮件通知
input int OPEN_CLOSE_LOGIC = 1; // 此品种是否开启平仓逻辑
int targetEquity = 0.0;


string companyName = ""; // 外汇平台是哪家
string eaSymbol = "";
double flag_EARunningDays = 0;
double EARunningDays = 0;

// 当前订单总数
int total = 0;

// 当等于true时不交易
bool isSleeping = false;
bool divideOnceFlag = false;

bool divideUpOnceFlag = false;
bool divideDownOnceFlag = false;

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

input int IS_SHOW_PRICE_OBJECT = 0; // 是否显示自定义价格面板

int eaSymbolUpTotal = 0;
int eaSymbolDownTotal = 0;

int lastTime = 0;

int nowTime = 0;



 /*
 反马丁策略
 双马丁策略
 默认是黄金的配置，外汇品种需要更改配置
 双开，止损2.6美金。总体净值目标盈利Z
 间隔4美金加仓
 

注意: 切换周期的时候竟然也会重新初始化
enable EA的时候不会重新初始化
*/
int OnInit()
  { 
    companyName = AccountCompany();
    StringToLower(companyName);

    MINI_LOT = MarketInfo(eaSymbol, MODE_MINLOT); // 最小仓位

    Print("？？？？？？？？？？？====================");

    eaSymbol = Symbol();

    // 初始化
    prePrice = SymbolInfoDouble(eaSymbol, SYMBOL_BID); // 卖价
    preTime = TimeCurrent();
    divideUpOnceFlag = false;
    divideDownOnceFlag = false;
    isSleeping = false;
    
   // GlobalVariableSet("BACKWARD_CLOSE_ALL_FLAG", 0);


   if(IS_SHOW_PRICE_OBJECT == 1) {
      InitPriceShowObject();
   } else {
      ObjectsDeleteAll(); 
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
     if(WAVE_POINT == 0 || TACKPROFIT_POINT == 0) {
       Print("NO WAVE_POINT AND TACKPROFIT_POINT, please SET!========================");
       return;
     }

     // 检查环境
    if(CheckTheEnv(MAX_SPREAD) == false) {
      return;
    }
    
    
    GetEaSymbolTotal();
    Print("eaSymbolUpTotal=", eaSymbolUpTotal, ",eaSymbolDownTotal=", eaSymbolDownTotal);
    if(eaSymbolDownTotal > SYMBOLLIMIT_TOTAL || eaSymbolUpTotal > SYMBOLLIMIT_TOTAL) {
      Print("eaSymboltotal exceed the max, please SET!========================eaSymbolDownTotal=", eaSymbolDownTotal, ",eaSymbolUpTotal=", eaSymbolUpTotal);
      return;
    }


    nowTime =  TimeCurrent() - lastTime;
    int closeAllFlag = GlobalVariableGet("BACKWARD_CLOSE_ALL_FLAG");
     // 打印
    Print("closeAllFlag=", closeAllFlag, ", nextTarget=============", DoubleToStr(INIT_EQUITY_LIMIT + PROFIT_REOVER, 2), ", wait ", DoubleToStr(nowTime / 60.0, 1), " mins");
    //  if(closeAllFlag == 1 && nowTime > 60 * 60 * WAIT_HOURS) { // 平仓60*8分钟之后再重置
    if(closeAllFlag == 1) {
      if(DayOfWeek() >= BEFORE_WEEK) {
         Print("today is week ", DayOfWeek(), ", I am waitting.......................................");
      }else if(nowTime > 60 * 60 * WAIT_HOURS) {
         GlobalVariableSet("BACKWARD_CLOSE_ALL_FLAG", 0);
      }
      return;
    }

    if(eaSymbolUpTotal + eaSymbolDownTotal == 0) {
     //  INIT_EQUITY_LIMIT = AccountEquity(); // 重新初始化
      eaSymbolDownTotal = 1; //非0就可以。解决初始化时方向单子只有一个方向问题
    }
  
    if(eaSymbolUpTotal == 0 || eaSymbolDownTotal == 0) {
       int orderType = 0;
       if(eaSymbolDownTotal == 0) {
         orderType = 1;
       }

      if(eaSymbolUpTotal == 0) {
         orderType = 0;
       }
       

       double sl = SymbolInfoDouble(eaSymbol, SYMBOL_ASK) - TACKPROFIT_POINT;  // 买价
       if(orderType == 1) { // sell
         sl = SymbolInfoDouble(eaSymbol, SYMBOL_BID) + TACKPROFIT_POINT;
       }
        Print("eaSymbolUpTotal=", eaSymbolUpTotal, ", eaSymbolDownTotal=", eaSymbolDownTotal, ", orderType=", orderType, ",divideUpOnceFlag=", divideUpOnceFlag, ",divideDownOnceFlag=",divideDownOnceFlag);

       if(eaSymbolUpTotal == 0 && divideUpOnceFlag == true) {
          openOrder(eaSymbol, orderType, STARTLOT, sl, 0, UP_COMMENT + "1_" + eaSymbol); // buy
          divideUpOnceFlag = false;
       } else if(eaSymbolUpTotal == 0 && divideUpOnceFlag == false) {
          // Print("===========1111111111==============");
           openOrder(eaSymbol, orderType, MINI_LOT, 0, 0, DIVIDE_FLAG_UP_COMMENT + eaSymbol); // buy limit挂单作为开始标识
           divideUpOnceFlag = true;
       }

       if(eaSymbolDownTotal == 0 && divideDownOnceFlag == true) {
          openOrder(eaSymbol, orderType, STARTLOT, sl, 0, DOWN_COMMENT + "1_" + eaSymbol); // sell
          divideDownOnceFlag = false;
       } else if(eaSymbolDownTotal == 0 && divideDownOnceFlag == false) {
         // Print("=========2222222222222==========");
          openOrder(eaSymbol, orderType, MINI_LOT, 0, 0, DIVIDE_FLAG_DOWN_COMMENT + eaSymbol); // buy limit挂单作为开始标识
          divideDownOnceFlag = true;
       }
    }

    if(OPEN_CLOSE_LOGIC == 1) {
       IsStartOver();
    }

   // IsWaveTooMuch(); // 反向跟单策略时，保护措施其实可以去掉了
   upHistoryProfit = GetHistoryProfit(0);
   downHistoryProfit = GetHistoryProfit(1);
   CheckOrders(0);
   CheckOrders(1);
   CheckRecentDay();
   // Print("===============upHistoryProfit=", DoubleToStr(upHistoryProfit, 4), ",downHistoryProfit=",  DoubleToStr(downHistoryProfit, 4));
  }

void IsStartOver() {
    double equity = AccountEquity();
    int closeAllFlag = GlobalVariableGet("BACKWARD_CLOSE_ALL_FLAG");
    targetEquity = INIT_EQUITY_LIMIT + PROFIT_REOVER;
    if(closeAllFlag == 0 && equity > targetEquity) {
      CloseOrder("ALL");
      INIT_EQUITY_LIMIT = AccountEquity(); // 重新初始化
      Print("accomplished!!!!====================================================");
      GlobalVariableSet("BACKWARD_CLOSE_ALL_FLAG", 1);
      lastTime =  TimeCurrent();
      if(SEND_EMAIL == 1) {
        string sendText = "下个目标金额是" + DoubleToStr(INIT_EQUITY_LIMIT + PROFIT_REOVER, 2) + "\n\n账户余额是 " +  DoubleToStr(AccountBalance() + AccountCredit(), 2) + "\n\n账户净值是" + DoubleToStr(AccountEquity(), 2);
        SendMail(SYMBOL_TEXT + "止盈通知",  sendText);
      }
      //  ExpertRemove();
      //  Print(TimeCurrent(),": ",__FUNCTION__," expert advisor will be unloaded");
    } else if(closeAllFlag == 0 && equity < LEFT_EQUITY) {
        CloseOrder("ALL");
        if(SEND_EMAIL == 1) {
           string sendText = "账户余额是" +  DoubleToStr(AccountBalance() + AccountCredit(), 2) + "\n\n账户净值是" + DoubleToStr(AccountEquity(), 2);
           SendMail(SYMBOL_TEXT + "爆仓通知",  sendText);
        }
        ExpertRemove();
    }
}


void GetEaSymbolTotal(){
   int total = OrdersTotal();
   eaSymbolUpTotal = 0;
   eaSymbolDownTotal = 0;
  for(int i=0;i<total;i++)
  {
    if(OrderSelect(i,SELECT_BY_POS)==false) continue;
    string symbol = OrderSymbol();
    int orderType = OrderType();
    if(StringFind(symbol, eaSymbol) == -1) continue;
    if(orderType == 0) { // up
        eaSymbolUpTotal ++;
    } else if (orderType == 1){
        eaSymbolDownTotal ++;
    }
   }
}
  

//+----------------------检查开仓单子--------------------------------------------+
void CheckOrders(int inOrderType = 0){
   int total=OrdersTotal();
   floatProfit = 0.0;
   int y = -1;
   double newOpenPrice = 0.0;
   double newOpenVolume = 0.0;
   double newOpenProfit = 0.0;
   int newOpenOrderType = 0;
   double currentPrice =  SymbolInfoDouble(eaSymbol, SYMBOL_BID); // 卖价
   if(inOrderType == 0) {
     currentPrice =  SymbolInfoDouble(eaSymbol, SYMBOL_ASK); // 买价
   }
   double maxLossPoint = 0.0;
   string targetComment = inOrderType == 0 ? UP_COMMENT : DOWN_COMMENT;
   string newComment = "";
   string newSymbol = "";
   double historyProfit = inOrderType == 0 ? upHistoryProfit : downHistoryProfit;
  for(int i=0;i<total;i++)
    {
   if(OrderSelect(i,SELECT_BY_POS)==false) continue;
   newSymbol = OrderSymbol();
   newOpenOrderType = OrderType();
   if(StringFind(newSymbol, eaSymbol) == -1 || newOpenOrderType != inOrderType) continue;
    newOpenOrderType = OrderType();
    newOpenVolume = OrderLots();
    newOpenPrice = OrderOpenPrice();
    newOpenProfit = OrderProfit() + OrderSwap();
    newComment =  OrderComment();
 
     y ++;
     if(StringFind(newComment, "ea") > -1) {
        floatProfit = floatProfit + OrderProfit() + OrderSwap();
     }
     int holdingTime = TimeCurrent() - OrderOpenTime(); // 秒
     if(StringFind(newComment, DIVIDE_FLAG) > -1 && holdingTime > divideHolding) { // 开始标识: 挂单，则delete； 1分钟
       CloseOrder("PART", OrderTicket());
       continue;
     }

     if(y == 0) { // 首单浮亏绝对值的2倍<平仓盈利 ; 5分钟
       maxLossPoint = MathAbs(NormalizeDouble(currentPrice - newOpenPrice, 5));
       if(newOpenProfit < 0 && maxLossPoint > SOLVE_POINT && historyProfit > MathAbs(newOpenProfit) * 2) {
        //   CloseOrder("PART", OrderTicket());
           continue;
       }
     }
    }

    Print(targetComment, "maxLossPoint=", DoubleToStr(maxLossPoint, 4));
   // Print(targetComment, "floatProfit=", DoubleToStr(floatProfit, 4));
    Print(targetComment, "historyProfit=", DoubleToStr(historyProfit, 4));
   // Print(targetComment, "isSleeping=", isSleeping);


    if(isSleeping) { // 半小时内涨跌太多，停止做单
      return;
    }
    Print(y + ": LossPoint=", MathAbs(NormalizeDouble(currentPrice - newOpenPrice, 5)));

  // Print("==================orderType=", inOrderType, ", newOpenPrice=", newOpenPrice, ", currentPrice=", currentPrice, ", diffPrice=", MathAbs(NormalizeDouble(currentPrice - newOpenPrice, 5)));

    if(newOpenProfit > 0 &&  MathAbs(NormalizeDouble(currentPrice - newOpenPrice, 5)) > WAVE_POINT ) { //如果当前价格与最近交易单子，亏损大于20个点
        double sl = SymbolInfoDouble(eaSymbol, SYMBOL_ASK) - TACKPROFIT_POINT;  // buy
        Print("**************************orderType=", inOrderType, ", newOpenProfit=", newOpenPrice, ", currentPrice=", currentPrice, ", diffPrice=", MathAbs(NormalizeDouble(currentPrice - newOpenPrice, 5)));
        if(inOrderType == 1) { // sell
          sl = SymbolInfoDouble(eaSymbol, SYMBOL_BID) + TACKPROFIT_POINT;
        }
     openOrder(eaSymbol, inOrderType, newOpenVolume + SEPLOT, sl, 0, targetComment + MathCeil(newOpenVolume / SEPLOT + 1) + "_" +  eaSymbol); //  13个点止盈
    }
}

//+-----------------------检查历史单子-------------------------------------------+
double GetHistoryProfit(int inOrderType = 0){
  int total = OrdersHistoryTotal();
  double historyProfit = 0.0;
  string stopFLag = inOrderType == 0 ? DIVIDE_FLAG_UP_COMMENT : DIVIDE_FLAG_DOWN_COMMENT;
  string targetComment = inOrderType == 0 ? UP_COMMENT : DOWN_COMMENT;
  // Print("=========", targetComment, "=========", stopFLag);
  // up
  for(int i = total-1; i >= 0; i --)
  {
   if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)==false) continue;
   string symbol = OrderSymbol();
   int orderType = OrderType();
   string comment =  OrderComment();
  
   if(StringFind(symbol, eaSymbol) == -1 || orderType != inOrderType) continue;
   if(StringFind(comment, stopFLag) > -1) { //找到开始标识，则停止计算历史盈利
   //  Print("orderTicked stop=====================================", OrderTicket());
     break;
    }else if(StringFind(comment, targetComment) > -1) {
      historyProfit = historyProfit + OrderProfit() + OrderSwap();
     } 
  }
  return historyProfit;

}

//+----------------------检查环境(包括点差、时间)--------------------------------------------+
bool CheckTheEnv(int maxSpread = 30) {
  // 打印EA运行天数
  PrintEARunningDays();

  //点差扩大不开仓
  double spread = MarketInfo(eaSymbol, MODE_SPREAD);
  if(spread > maxSpread) { 
    Print("the spread exceed the max================maxSpread=", maxSpread, ", now=", spread);
    return false;
  }

  return true;
}

//+-----------------------开仓-------------------------------------------+
void openOrder(string symbol, int orderType = 0, double volume = 0.01, double sl = 0, double tp = 0, string comment = ""){
    
     // string symbol = Symbol();
    //  int orderType = orderType; // 0:buy，1:sell
     double openPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);// 买价
     if(orderType == 1) { // sell
        openPrice = SymbolInfoDouble(symbol, SYMBOL_BID); // 卖价
     }else if(orderType == 2) { // 挂单
        openPrice = openPrice - 0.02;
     }

    //  double spread = MarketInfo(eaSymbol, MODE_SPREAD);
    //  if(spread > MAX_SPREAD) { // 点差扩大不开仓
    //    return;
    //  }


     bool res =  OrderSend(symbol, orderType, volume, openPrice, 30, sl, tp, comment , 0, 0 );
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
  // int orderType = GetOpenOrderType();
  postTime = TimeCurrent();
  postPrice = SymbolInfoDouble(eaSymbol, SYMBOL_BID); // 卖价
  // Print(eaSymbol, ":", "WAVE_POINT: ",WAVE_POINT);
  Print("time: ", postTime - preTime, ", or " + DoubleToStr((postTime - preTime)/ 60.0, 1), " mins, prePrice: ", prePrice, ", postPrice",  postPrice, ", diffPrice: ", DoubleToStr(MathAbs(postPrice - prePrice), 5));
  // 30分钟之内逆势涨跌超过WAVE_POINT点，则接下来1小时不开仓
  if(postTime - preTime < 60*30 && MathAbs(NormalizeDouble(prePrice - postPrice, 5))  > WAVE_POINT ) {
     isSleeping = true;
     preTime = postTime;
     prePrice = postPrice;
     Print(eaSymbol, ":", "Attention=========up and down is too much==============", MathAbs(postPrice - prePrice));
  } 
  if(postTime - preTime > 60 * 30){
    isSleeping = false;
    preTime = postTime;
    prePrice = postPrice;
  }

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
      if(SEND_EMAIL == 1) {
        string sendText = "目标金额是" + DoubleToStr(INIT_EQUITY_LIMIT + PROFIT_REOVER, 2) + "\n\n账户余额是" +  DoubleToStr(AccountBalance() + AccountCredit(), 2) + "\n\n账户净值是" + DoubleToStr(AccountEquity(), 2);
        SendMail(SYMBOL_TEXT + "日常通知",  sendText);
      }
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