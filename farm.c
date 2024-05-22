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

double MINI_LOT = 0.01; // 最小仓位

// 换账户的话，下面这几个个常量需要修改
input double TACKPROFIT_POINT = 0; // 止盈点数
input double SL_POINT = 0.004;
input int MAX_SPREAD = 30; // 点差大于多少不交易
input int SYMBOLLIMIT_TOTAL = 6;

input double VOL = 0.01;
input int divideHolding = 30;


string companyName = ""; // 外汇平台是哪家
string eaSymbol = "";
double flag_EARunningDays = 0;
double EARunningDays = 0;

// // 当前订单总数
// int total = 0;

// 当等于true时不交易
bool isSleeping = false;
bool divideOnceFlag = false;

// 半小时内波动多大所使用变量
double prePrice = 0.0;
double postPrice = 0.0;
int preTime = 0;
int postTime = 0;


int IS_SHOW_PRICE_OBJECT = 1; // 是否显示自定义面板
bool isOpen = false;

int OnInit()
{
    companyName = AccountCompany();
    StringToLower(companyName);
    eaSymbol = Symbol();

    // 初始化
    prePrice = SymbolInfoDouble(eaSymbol, SYMBOL_BID); // 卖价
    preTime = TimeCurrent();
    divideOnceFlag = false;
    isSleeping = false;
    MINI_LOT = MarketInfo(eaSymbol, MODE_MINLOT); // 最小仓位

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
    int total = OrdersTotal();
    int hour = Hour();
    if(hour == 0){
        isOpen = true;
    }


    if(total == 0 ){
        CheckOrders();
    }
}

int GetEaSymbolTotal(){
    int total=OrdersTotal();
    int eaTotal = 0;
    for(int i=0;i<total;i++)
    {
        if(OrderSelect(i,SELECT_BY_POS)==false) continue;
        string symbol = OrderSymbol();
        if(StringFind(symbol, eaSymbol) == -1) continue;
        string comment =  OrderComment();
        eaTotal ++ ;
    }
    return eaTotal;
}


//+----------------------检查开仓单子--------------------------------------------+
void CheckOrders(){
    //int total=OrdersTotal();
  int orderType = GetRandomOrderType();
    isOpen = false;
   int total = SYMBOLLIMIT_TOTAL;
    double signMain = iBands(eaSymbol,0,20,2,0,PRICE_CLOSE,MODE_MAIN,0);
    double signLow = iBands(eaSymbol,0,20,2,0,PRICE_CLOSE,MODE_LOWER,0);
    double signUpper = iBands(eaSymbol,0,20,2,0,PRICE_CLOSE,MODE_UPPER,0);
    double currentPrice = SymbolInfoDouble(eaSymbol, SYMBOL_BID);
    if(currentPrice - signMain > 0.001){
        orderType = 0;
    } else if(signMain - currentPrice > 0.001){
        orderType = 1;
    } else {
        return;
    }
   for(int i = 0;i<total;i++){
        double tp = SymbolInfoDouble(eaSymbol, SYMBOL_ASK) + TACKPROFIT_POINT;  // buy
        double sl = SymbolInfoDouble(eaSymbol, SYMBOL_ASK) - SL_POINT;
        if(orderType == 1) { // sell
           tp = SymbolInfoDouble(eaSymbol, SYMBOL_BID) - TACKPROFIT_POINT;
           sl = SymbolInfoDouble(eaSymbol, SYMBOL_BID) + SL_POINT;
        }
        openOrder(eaSymbol, orderType, VOL, sl, tp, "ea_" +  eaSymbol);
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
//+--------------------------获取EA开仓的方向-------------------------------------------+
int GetOpenOrderType() {
    int total = OrdersTotal();
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
