
//https://xueqiu.com/1227896389/263712310
#property strict
input double INIT_LOSS_POINT = 0.3;
input double INIT_HIGH_POINT = 0.5;
input double INIT_PROFIT_BACK_POINT = 0.4;
input double LOT = 0.05; // 一单手数大小
string eaSymbol = "";
input int MAX_SPREAD = 50; // 点差大于多少不交易
const string FIRST_COMMENT = "ea_start_1_"; // 第一单的comment

int OnInit()
{
    eaSymbol = Symbol();

    return(INIT_SUCCEEDED);
}

void OnTick(){
    int eaSymbolTotal = GetEaSymbolTotal();
    if(eaSymbolTotal == 0){
        int orderType = GetRandomOrderType();
        openOrder(eaSymbol, orderType, LOT, 0, 0, FIRST_COMMENT + eaSymbol);
    }
    checkOrders();
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

void checkOrders(){
    int total = OrdersTotal();
    double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double openPrice = 0.0;
    double openProfit = 0.0;
    double openOrderType = 0;
    double orderSt = 0.0;
    double orderLots = 0.0;
    double maxLossPoint = 0.0;
    double ticket = 0.0;
    string orderSymbol = OrderSymbol();
    for(int i = 0; i< total; i++) {
        if(OrderSelect(i,SELECT_BY_POS) == false) continue;
        openPrice = OrderOpenPrice();
        openOrderType = OrderType();
        openProfit = OrderProfit() + OrderSwap();
        maxLossPoint = MathAbs(NormalizeDouble(currentPrice - openPrice, 4));
        ticket = OrderTicket();
        orderSt = OrderStopLoss();
        orderLots = OrderLots();
        if(openProfit < 0 && maxLossPoint >= INIT_LOSS_POINT){
            double price = MarketInfo(orderSymbol, MODE_BID);
            if(openOrderType == 1) {
                price = MarketInfo(orderSymbol, MODE_ASK);
            }
            // 关闭订单
            closeOrder(ticket, orderLots, price);
        }
        if(openProfit > 0 && maxLossPoint > INIT_HIGH_POINT){
            //上移止损点位 INIT_HIGH_POINT - INIT_PROFIT_BACK_POINT  OrderModify
            double st = NormalizeDouble(currentPrice - INIT_HIGH_POINT - INIT_PROFIT_BACK_POINT, 4);
            if(openOrderType == 1){
                st = NormalizeDouble(currentPrice +( INIT_HIGH_POINT - INIT_PROFIT_BACK_POINT ), 4);
            }
            modifyOrder(ticket, openPrice, st);
        }
    }
}

void modifyOrder(ulong ticket, double price, double st = 0, double tp = 0){
    OrderModify(ticket, price, st, tp, 0);
}

void closeOrder(int ticket, double vol, double price, int slippage = 0) {
    OrderClose(ticket, vol, price, slippage);
}