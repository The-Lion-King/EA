//+------------------------------------------------------------------+
//|                                              mt4-liyingguang.mq4 |
//|                        Copyright 2021, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property strict
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
// #include <mine.mqh>

// 常量不修改
const string FIRST_COMMENT = "ea_just do it_"; // 第一单的comment
input int MAX_SPREAD = 30; // 点差大于多少不交易

double MINI_LOT = 0.01; // 最小仓位


// 起爆点策略
input double EACH_LOT = 0; // 开单大小
input double PROFIT_POINT = 0; // 盈利多少点开始追踪止损
input double CHASE_POINT = 0; // 追踪止损点数

// 为了防止EA意外盲目开单情况，做此限制。当停止开单确认无误后，再提高此数量
input int SYMBOLLIMIT_TOTAL = 10; // 每个品种最多开多少单


string companyName = ""; // 外汇平台是哪家
string eaSymbol = "";


string sendText = "init text";
string buttonID_buy="buySymbol";
string buttonID_sell="sellSymbol";
string buttonID_log="logSymbol";

int IS_SHOW_PRICE_OBJECT = 1; // 是否显示自定义面板

double flag_EARunningDays = 0;
double EARunningDays = 0;

 /*
 爆点策略辅助工具

 每天一单，追踪止损

 **/


int OnInit()
  { 
    companyName = AccountCompany();
    StringToLower(companyName);
    eaSymbol = Symbol();

    // 初始化
    MINI_LOT = MarketInfo(eaSymbol, MODE_MINLOT); // 最小仓位


   if(IS_SHOW_PRICE_OBJECT == 1) {
      InitPriceShowObject();
   }


   printf("init event");

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
    if(PROFIT_POINT == 0 || PROFIT_POINT == 0 || EACH_LOT == 0) {
       ObjectSetString(0, buttonID_log, OBJPROP_TEXT, "NO PARAMS, please SET!======");  
       Print("NO PARAMS, please SET!========================");
       return;
     }

    int total = OrdersTotal();
    if(total > SYMBOLLIMIT_TOTAL) {
      ObjectSetString(0, buttonID_log, OBJPROP_TEXT, "exceed the max ..."); 
      return;
    }

    PrintEARunningDays();
    modifyOrder(); 
    ObjectSetString(0, buttonID_log, OBJPROP_TEXT, MarketInfo(eaSymbol, MODE_SPREAD));  
  }


void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {

    if(id==CHARTEVENT_OBJECT_CLICK)
     {
      string clickedChartObject=sparam;
      //--- If you click on the object with the name buttonID
      double sl = 0.0;
      if(clickedChartObject == buttonID_buy){
          sl = SymbolInfoDouble(eaSymbol, SYMBOL_ASK) - CHASE_POINT;  // 买价
     //     Comment("buy_sl=" + sl);
          openOrder(eaSymbol, 0, EACH_LOT, sl, 0, FIRST_COMMENT + eaSymbol); // buy
        
        //  printf( "I am in buy the order event....");
      }else if(clickedChartObject == buttonID_sell) {
          sl = SymbolInfoDouble(eaSymbol, SYMBOL_BID) + CHASE_POINT;
      //    Comment("sell_sl=" + sl);
          openOrder(eaSymbol, 1, EACH_LOT, sl, 0, FIRST_COMMENT + eaSymbol); // sell
          
      }
     } else {


     }
  }



void InitPriceShowObject() {
   initObject(buttonID_buy, "开多", 50, 30);
   initObject(buttonID_sell, "开空", 240, 30);
   initObject(buttonID_log, "言出法随", 430, 30);
  //  initObject(buttonID4, 430, 30);
  //  initObject(buttonID5, 630, 30);
  //  initObject(buttonID6, 830, 30);
}

void initObject(string objectId, string text = "",  int x = 50, int y = 30, int bx = 150, int by = 50) {

  ObjectCreate(0,objectId,OBJ_BUTTON,0,1,1);
  ObjectSetInteger(0,objectId,OBJPROP_COLOR,clrWhite);
  ObjectSetInteger(0,objectId,OBJPROP_BGCOLOR,clrBlue);
  ObjectSetInteger(0,objectId,OBJPROP_XDISTANCE, x);
  ObjectSetInteger(0,objectId,OBJPROP_YDISTANCE, y);
  ObjectSetInteger(0,objectId,OBJPROP_XSIZE, bx);
  ObjectSetInteger(0,objectId,OBJPROP_YSIZE, by);
  ObjectSetString(0,objectId,OBJPROP_FONT,"Arial");
  ObjectSetString(0,objectId,OBJPROP_TEXT, text);
  ObjectSetInteger(0,objectId,OBJPROP_FONTSIZE,8);
  ObjectSetInteger(0,objectId,OBJPROP_SELECTABLE,0);
}

//+-------------------------订单修改-----------------------------------------+
void modifyOrder(){
 int total=OrdersTotal();

  for(int pos=0;pos<total;pos++)
    {
   if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
   if(StringFind(OrderSymbol(), eaSymbol) == -1) continue;
     double openPrice =  OrderOpenPrice();
     int orderType = OrderType(); // 0:buy，1:sell
     double order_sl = OrderStopLoss();

     // 计算止损。buy ASK, sell BID
     double sl = SymbolInfoDouble(eaSymbol, SYMBOL_ASK) - CHASE_POINT; // buy
     double currentPrice = SymbolInfoDouble(eaSymbol, SYMBOL_ASK);
     if(orderType == 1) {
        sl = SymbolInfoDouble(eaSymbol, SYMBOL_BID) + CHASE_POINT;
        currentPrice =  SymbolInfoDouble(eaSymbol, SYMBOL_BID);
     }

     bool tooMuchStopLoss = false;
     bool startChasing = false;
     double orderProfit = OrderProfit() + OrderSwap();
    
     if(orderProfit < 0 && MathAbs(NormalizeDouble(openPrice - order_sl, 5))  > CHASE_POINT) {
       tooMuchStopLoss = true;
     }

     if(orderProfit > 0 && MathAbs(NormalizeDouble(openPrice - currentPrice, 5)) > PROFIT_POINT && MathAbs(NormalizeDouble(order_sl - currentPrice, 5)) > CHASE_POINT) { // 开始追踪止损
       startChasing = true;
     }
    //  if(orderType == 1) {
    //      string textLog = "much=" + tooMuchStopLoss + ",chaseing=" + startChasing;
    //      ObjectSetString(0, buttonID_log, OBJPROP_TEXT, textLog);
    //  }
   
     if(tooMuchStopLoss != true && startChasing != true ) continue;
     bool res=OrderModify(OrderTicket(),OrderOpenPrice(), sl, OrderTakeProfit(),0);
      if(!res)
               Print("Error in OrderModify. Error code=",GetLastError());
            else
               Print("Order modified successfully.");
    }
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

     double spread = MarketInfo(eaSymbol, MODE_SPREAD);
     if(spread > MAX_SPREAD) { // 点差扩大不开仓
       return;
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
