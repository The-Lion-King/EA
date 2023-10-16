//+------------------------------------------------------------------+
//|                                              mt4-liyingguang.mq4 |
//|                        Copyright 2021, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property strict
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

double floatProfit = 0.0;

bool sentNoticeFlag = false;
bool sendFloatProfitNoticeFlag = false;

double oldBalance = 0.00;

string sendText = "";
double EARunningDays = 0;
double flag_EARunningDays = 0;
int sentFlag = 0;

input int SEND_EMAIL = 1; // 是否发送邮件
input int SEND_EMAIL_GOLD = 1; // 是否发送黄金高低值邮件
input int SEND_EMAIL_BALANCE = 1; // 是否发送余额变动邮件
input double AMMOUNT_BALANCE_HINT = 0; // 余额变动多大才会提醒
input int SEND_EMAIL_FLOAT_PROFIT = 1; // 是否发送浮动盈亏变动邮件
input double FLOAT_PROFIT_HINT = 0; // 浮动盈亏多大才会提醒

int SL_FOREX_POINT = 37; // 外汇止损点数
int SL_GOLD_POINT = 55; // 黄金止损点数
int AUTO_CHANGE_SLED = 1; // 是否改动已经设置的止损
string CLOSE_SIGNAL = "AUSUSD"; // 平仓品种信号


int OnInit()
  { 
   

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
/*------------------------------------------------------------------+
提醒EA

++                            |
*/
void OnTick()
  {
   double account = AccountInfoDouble(ACCOUNT_BALANCE);
  // int total=OrdersTotal();
 
  // Print("Account #",AccountNumber(), " leverage is ",  AccountInfoInteger(ACCOUNT_LEVERAGE), " accountProfit=", AccountProfit());
  // int leverage = AccountLeverage();
  

    PrintEARunningDays();
    if(SEND_EMAIL == 1 && SEND_EMAIL_BALANCE == 1) {
      NoticeBalanceChanged();
    }

   if(SEND_EMAIL == 1 && SEND_EMAIL_FLOAT_PROFIT == 1) {
      NoticeFloatProfit();
   }
   
  //  modifyOrder();   
  //  CheckOrders();

    if( Hour() == 23 && Minute() == 50 && sentFlag == 0 && SEND_EMAIL == 1 && SEND_EMAIL_GOLD == 1) { // 早上5点发送邮件
      SendGoldHighAndLow();
      sentFlag = 1;
    }else if(Hour() != 23) {
      sentFlag = 0;
    } 

    Print("Account #",AccountNumber(), ", accountProfit=", AccountProfit());
  }

//+------------------------------------------------------------------+
void CheckOrders(){
 int total=OrdersTotal();
  // write open orders
 // floatProfit = 0.0;
  for(int pos=0;pos<total;pos++)
    {
    if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
     string symbol = OrderSymbol();
    // if(StringFind(symbol, CLOSE_SIGNAL) > -1) { // 手动平仓有时太慢了，自动平仓信号
    //    CloseOrder("ALL");
    // }
    floatProfit = floatProfit + OrderProfit();
    // double volume = OrderLots();
    // totalVolume = totalVolume + volume;
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

//+------------------------------------------------------------------+
void modifyOrder(){
 int total=OrdersTotal();
 if(total == 0) return;
  // write open orders

  for(int pos=0;pos<total;pos++)
    {
   if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
    // printf( OrderOpenPrice() +" " + OrderOpenTime() +" "  + OrderSymbol() +" " + OrderLots());
     double TrailingStop=0;
     string symbol = OrderSymbol();
     double point = 1;
    // printf(pos + ": symbol=" + symbol);
    if(StringFind(symbol, "BTCUSD") > -1){
         TrailingStop = 1000 ;
     }else if(StringFind(symbol, "GBPUSD") > -1 || StringFind(symbol, "EURUSD") > -1){
       TrailingStop = SL_FOREX_POINT * 0.0001; // 点数是倒数第一位；如果是倒数第二位，TrailingStop=1000
     }else if(StringFind(symbol, "EURGBP") > -1 || StringFind(symbol, "AUDCHF") > -1 ){
        TrailingStop = SL_FOREX_POINT * 0.0001;
     }else if(StringFind(symbol, "CAD") > -1) {
         TrailingStop = SL_FOREX_POINT * 0.0001;
     }else if(StringFind(symbol, "JPY") > -1)
     {
         TrailingStop = SL_FOREX_POINT * 0.01;
     } else if(StringFind(symbol, "GOLD") > -1 || StringFind(symbol, "XAUUSD") > -1) {
        TrailingStop = SL_GOLD_POINT * 0.1;
     } else {
       continue; 
     }

     // printf("OrderSymbol=" + OrderSymbol() + ",Point*TrailingStop=" + point*TrailingStop);
     int orderType = OrderType(); // 0:buy，1:sell
 
     double stopLoss = OrderOpenPrice() - TrailingStop;
     double sl = OrderStopLoss();
     
     // 如果超出最大止损，则更改止损
     bool tooMuchStopLoss = false;

     if(orderType == 1) {
       stopLoss = OrderOpenPrice() + TrailingStop;
       if( NormalizeDouble(sl-stopLoss, 4) > 0) {
       tooMuchStopLoss = true;
       }
     }else {
       if(NormalizeDouble(sl-stopLoss, 4) < 0) {
       tooMuchStopLoss = true;
       }
     }

     if(AUTO_CHANGE_SLED != 1) {
        tooMuchStopLoss = false;
     }

     if((OrderStopLoss() != 0 && tooMuchStopLoss == false)  || TrailingStop == 0 ) continue;
     bool res=OrderModify(OrderTicket(),OrderOpenPrice(),stopLoss, OrderTakeProfit(),0);
      if(!res)
               Print("Error in OrderModify. Error code=",GetLastError());
            else
               Print("Order modified successfully.");
    }
}

void NoticeBalanceChanged() {
   // when the balance is change, notice me!
    double account = AccountInfoDouble(ACCOUNT_BALANCE);
    if(oldBalance != account) {
        if(MathAbs(account-oldBalance) < AMMOUNT_BALANCE_HINT) {
          return;
        }
        sendText = "The balance is changed: " + DoubleToStr(NormalizeDouble(account-oldBalance, 2), 2) + "\n\nNow your balance: " + account + "\n\njust follow the DAO";
       // SendNotification(sendText);
        SendMail("账户余额变动",  sendText);
        oldBalance = account; 
    }
}


void NoticeFloatProfit() {
  if(MathAbs(AccountProfit())  > MathAbs(FLOAT_PROFIT_HINT)  && sendFloatProfitNoticeFlag == false) {
    sendText = "The float profit exceed the max, now the float profit is " + AccountProfit();
    SendMail("浮动盈亏警告",  sendText);
    sendFloatProfitNoticeFlag = true;
  }
}

void SendGoldHighAndLow() {
  // string symbol = Symbol();
   string symbol = "GOLDmicro";
   sendText = "";
   double valHigh;
   double valLow;
  //  int val_index=iHighest(symbol, PERIOD_D1,MODE_HIGH,5,0);
  //  if(val_index!=-1) val=High[val_index];
  //  printf("val_index=" +  val_index + ", high=" + val);

   for(int pos=0; pos< 45;pos++)
    {
     int val_index=iHighest(symbol, PERIOD_D1, MODE_HIGH, 1, pos);
     if(val_index!=-1) valHigh=High[val_index];
     int val_index2=iLowest(symbol, PERIOD_D1, MODE_LOW, 1, pos);
    if(val_index2!=-1) valLow=Low[val_index2];
     datetime barTime = iTime(symbol,PERIOD_D1, pos);
     string barTimeStr = TimeToStr(barTime,TIME_DATE);
     sendText = sendText + "\n\n" + barTimeStr + "_" + valHigh + "_" + valLow + ", 相差" + MathAbs( NormalizeDouble(valHigh-valLow, 2)) + "美金";
    // printf("sendText=" + sendText );
    }
   SendMail("GOLD HIGH and LOW",  sendText);
}


void PrintEARunningDays() {
    if(Hour() == 2 && flag_EARunningDays == 0) {
      EARunningDays++;
      flag_EARunningDays = 1;
    } else if(Hour() != 2) {
      flag_EARunningDays = 0;
    }
   Print("account#",  AccountNumber() , ", EA is runing ", EARunningDays + " days", ",AccountProfit=", AccountProfit());
}


void CloseOrder(string closeType = "11111", ulong ticket = 10000, string symbol = "init")
{
   if(OrdersTotal() == 0) return ;
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