//+------------------------------------------------------------------+
//|                                                       Turtle.mq4 |
//|                                          Copyright 2014, Ch-Wind |
//|                                               http://ch-wind.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Ch-Wind"
#property link      "http://ch-wind.com"
#property version   "1.00"
#property strict
#property description "海龟交易法则"
#property description "运行周期为当前窗口周期"

/*
   海龟交易法则
   -没有使用风险更高的双重损失止损策略
   -默认参数为长线[55|20]<<短线参数为[20,10]
*/
//
extern   int miMaxTks   = 4;       // 开仓上限
extern   int miSlip     = 0;       // 滑点容许
extern   int miRetry    = 10;      // 失败重试
extern   int miMagic    = 8010;    // 魔术数字

extern   int miS1P1     = 55;       // 长线系统开仓
extern   int miS1P2     = 20;       // 长线系统止盈
//
double   gdAtr = 0; // 平均波幅 | N
double   gdLot = 0; // 交易单位 | Unit

double   gdPValue = 0; // 每点价值 | 报价

int      giState = 0;   // 状态标识
string   msSVals[3] = {"等待突破","突破加仓","满仓持仓"};

int      errState = 0;  // 简易的错误提示
bool     mbErr = false; // 错误标记
string   msSErrs[2] = {"手数规模达到平台下限","手数规模超过平台上限"};

int      miTkCtn = 0;   // 交易数统计| 调试用
int      miTkNums = 0;  // 交易单统计| 加仓统计
int      miTkFck  = 0;  // 交易完毕的突破次数

bool     mbDiUp = false;   // 方向向上
bool     mbDiDn = false;   // 方向向下

double   gdPrice = 0;   // 下一次加仓价格
int      miTkLast = 0;   // 最后一笔开仓的订单号

double   SLL,TPP;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
{
   gdPValue = MarketInfo(Symbol(), MODE_TICKVALUE)/MarketInfo(Symbol(), MODE_TICKSIZE);
   return(0);
}
//---
//+------------------------------------------------------------------+
//| expert deinitialization function |
//+------------------------------------------------------------------+
int deinit()
{
	ObjectsDeleteAll(WindowFind(WindowExpertName()),OBJ_LABEL);
	Comment("");
	return(0);
}   
//+------------------------------------------------------------------+
//| expert start function |
//+------------------------------------------------------------------+
int start(){
   
   f_Center();
   f_ShowStatus();
   
   return(0);
}
//+------------------------------------------------------------------+
//| 以下为功能函数 |
//+------------------------------------------------------------------+
int f_Center(){
    f_KLCheck();
    switch(giState){
      case 0:     // 等待状态
      {
         f_TcCheck();
         f_VPCheck();
         break;
      }
      case 1:  // 开仓
      {
         f_CLCheck();   // 退出检测
         f_ATCheck();   // 加仓检测
         break;
      }
      case 2:  // 满仓状态
      {
         f_CLCheck();   // 退出检测
         break;
      }
   
   
   }  
   return(0);
}

void f_KLCheck(){    // 检查是否被止损|校验系统状态
	int tiTk = 0;
	
	double tdPrc = 0;

	for(int cnt=0; cnt<OrdersTotal(); cnt++)
	{
		if(!OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES))
		{
			Print("OrderSelect返回错误：",GetLastError());
			continue;
		}

		if(OrderSymbol()==Symbol())
		{
		   tiTk++;
		   if(miTkNums > 0) continue;   // 已在状态则不进行详细统计和恢复
		   
		   if(OrderType() == OP_BUY){
		      mbDiUp = true;
		      mbDiDn = false;
		      
		      if(OrderOpenPrice() > tdPrc){
		         tdPrc = OrderOpenPrice();
		         gdAtr = (tdPrc - OrderStopLoss())/2;   // 最高价格和止损线的距离始终是2N
		         gdPrice = tdPrc + gdAtr/2;
		         gdLot = OrderLots();
		      }
		   }else if(OrderType() == OP_SELL){
		      mbDiDn = true;
		      mbDiUp = false;
		      
		      if(OrderOpenPrice() < tdPrc){
		         tdPrc = OrderOpenPrice();
		         gdAtr = (OrderStopLoss()-tdPrc)/2;
		         gdPrice = tdPrc - gdAtr/2;
		         gdLot = OrderLots();
		      }		      
		   }
		}
	}   
	
	switch(tiTk){
	   case 0:
	   {
	      f_SQuit();
	      break;
	   }
	   default:
	   {
	      
	      if(miTkNums == 0) break;
	      if(tiTk == miMaxTks) giState = 2;
	      else giState = 1;
	      
	      miTkNums = tiTk;
	      
	      break;
	   }
	
	}
	
}

int f_TcCheck(){   // 基础变量的检测和生成
   gdAtr = iATR(NULL,0,20,0);
  
   gdLot = (AccountFreeMargin()/100)/(gdAtr*gdPValue);
   gdLot = NormalizeDouble(gdLot,2);
   
   if(gdLot < MarketInfo(Symbol(),MODE_MINLOT)){
      mbErr = true;
      gdLot = MarketInfo(Symbol(),MODE_MINLOT);
      errState = 0;
   }else if(gdLot > MarketInfo(Symbol(),MODE_MAXLOT))
   {
      mbErr = true;
      gdLot = MarketInfo(Symbol(),MODE_MAXLOT);
      errState = 1;
   }else{
      mbErr = false;
   }
   gdLot = NormalizeDouble(gdLot,2);
   
   return(0);
}

int f_VPCheck(){  // 等待突破的价格监测
   int      tiH      = iHighest(NULL,0,MODE_HIGH,miS1P1,1);
   double   tdHigh   = iHigh(NULL,0,tiH);
   
   int      tiL      = iLowest(NULL,0,MODE_HIGH,miS1P1,1);
   double   tdLow   = iLow(NULL,0,tiL);  
   
   if(Ask > tdHigh){
      mbDiUp = true;
      mbDiDn = false;
   }
   
   if(Bid < tdLow){
      mbDiDn = true;
      mbDiUp = false;
   }
   
   if(mbDiDn || mbDiUp){
      f_VPHandle();  
   }

   return(0);
}

void f_VPHandle(){   // 第一次突破
   giState = 1;
   miTkNums = 0;
   
   if(mbDiUp){
      f_BuyMe();
      return;
   }
   
   if(mbDiDn){
      f_SellMe();
      return;
   }
}

void f_ATCheck(){    // 加仓检测
   if(mbDiUp){
      if(Ask > gdPrice){
         f_FixTkSLL();
         f_BuyMe();
      }
      return;
   }
   
   if(mbDiDn){
      if(Bid < gdPrice){
         f_FixTkSLL();
         f_SellMe();
      }
      return;
   }
}

void f_CLCheck(){    // 是否符合退出条件
   bool tbQuit = false;
   
   if(mbDiUp){
      int      tiL      = iLowest(NULL,0,MODE_HIGH,miS1P2,1);
      double   tdLow   = iLow(NULL,0,tiL); 
      
      if(Bid < tdLow){  // 价格低于监测周期低点
         tbQuit = true;
      }   
   }
   
   if(mbDiDn){
      int      tiH      = iHighest(NULL,0,MODE_HIGH,miS1P2,1);
      double   tdHigh   = iHigh(NULL,0,tiH);  
      
      if(Ask > tdHigh){ // 价格高于监测周期高点
         tbQuit = true; 
      } 
   }

   if(tbQuit){
      f_CloseAllTks();
      f_SQuit();
   } 
}

void f_FixTkSLL(){      // 修正订单止损|上推
	Alert("<FixTkSLL>");
	for(int cnt=OrdersTotal();cnt>=0;cnt--)
	{
		if(!OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES)) continue;
		if(OrderSymbol()==Symbol() && OrderMagicNumber()==miMagic)
		{   
		   if(OrderType() == OP_BUY){
		      while(!OrderModify(OrderTicket(),OrderOpenPrice(),OrderStopLoss() + gdAtr/2,OrderTakeProfit(),0,Blue));
		   }
		   if(OrderType() == OP_SELL){
		      while(!OrderModify(OrderTicket(),OrderOpenPrice(),OrderStopLoss() - gdAtr/2,OrderTakeProfit(),0,Blue));
		   }
		   
		}
   }   
}

void f_CloseAllTks(){   // 关闭所有订单
	Alert("<CloseAllTks>");
	for(int cnt=OrdersTotal();cnt>=0;cnt--)
	{
		if(!OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES)) continue;
		if(OrderSymbol()==Symbol() && OrderMagicNumber()==miMagic)
		{   
		   if(OrderType() == OP_BUY){
		      while(!OrderClose(OrderTicket(),OrderLots(),Bid,miSlip));
		   }
		   if(OrderType() == OP_SELL){
		      while(!OrderClose(OrderTicket(),OrderLots(),Ask,miSlip));
		   }
		   
		}
   }
}

void f_SQuit(){      // 退出系统交易状态用清理
   if(miTkNums>0) miTkFck++;
   mbDiDn = false;
   mbDiUp = false;
   miTkNums = 0;
   giState = 0;
}

//
int f_BuyMe(){   // 现价多单

	Alert("<BuyMe>");
	int ctn_i = -1;
	int ti = miRetry;
   while(true){
      SLL = Bid - 2 * gdAtr;
	   TPP = 0;
      ctn_i=i_OrderSend(Symbol(),OP_BUY,gdLot,Ask,miSlip,SLL,TPP,"M"+StringConcatenate(Period())+"",miMagic,0,Red);
      if(ctn_i>0){
		   f_TKoped();
		   miTkLast = ctn_i;
		   break;
	   }
	   ti--;
	   if(ti<=0) break;
   }
	
	gdPrice = Ask + (gdAtr/2);
	return(ctn_i);
}

int f_SellMe(){   // 现价空单

	Alert("<SellMe>");
	int ctn_i = -1;
	int ti = miRetry;
   while(true){
      SLL = Ask + 2 * gdAtr;
	   TPP = 0;
      ctn_i=i_OrderSend(Symbol(),OP_SELL,gdLot,Bid,miSlip,SLL,TPP,"M"+StringConcatenate(Period())+"",miMagic,0,Blue);
      if(ctn_i>0){
		   f_TKoped();
		   miTkLast = ctn_i;
		   break;
	   }
	   ti--;
	   if(ti<=0) break;
   }
	
	gdPrice = Bid - (gdAtr/2);
	return(ctn_i);
}

void f_TKoped(){
   ++miTkCtn;
   ++miTkNums;
   
   if(miTkNums>=miMaxTks){
      giState = 2;
   }
}

void f_ShowStatus(){ // 状态显示
   i_DisPlayInfo("LableSplit","----------海龟系统-----------",0,15,15,10,"黑体",SteelBlue);
   i_DisPlayInfo("LableLot","交易单位::"+DoubleToStr(gdLot,2),0,15,30,10,"黑体",SteelBlue);
   i_DisPlayInfo("LableN","平均波幅::"+DoubleToStr(gdAtr),0,15,48,10,"黑体",SteelBlue);

	i_DisPlayInfo("Acc87lance","账面资金::"+DoubleToStr(AccountBalance(),2),0,15,66,10,"黑体",SteelBlue);
	i_DisPlayInfo("LableC5rice6","净值资金::"+DoubleToStr(AccountEquity(),2),0,15,84,10,"黑体",SteelBlue);
	i_DisPlayInfo("Labl456rice6","保证资金::"+DoubleToStr(AccountMargin(),2),0,15,102,10,"黑体",SteelBlue);
	i_DisPlayInfo("Labl4hcjce6","可用资金::"+DoubleToStr(AccountFreeMargin(),2),0,15,120,10,"黑体",SteelBlue);
	i_DisPlayInfo("Labl4hcjde6","账面盈亏::"+DoubleToStr(AccountProfit(),2),0,15,138,10,"黑体",SteelBlue);
	i_DisPlayInfo("Labl4hcjde7","交易统计::"+DoubleToStr(miTkNums,0)+"/" + DoubleToStr(miTkCtn,0)+">>" + DoubleToStr(miTkFck,0),0,15,156,10,"黑体",SteelBlue);
	i_DisPlayInfo("Labl4hcjde8","系统状态::"+msSVals[giState],0,15,174,10,"黑体",SteelBlue);
	if(mbErr){
	   i_DisPlayInfo("Labl4hcjde9","警示信息::"+msSErrs[errState],0,15,192,10,"黑体",Red);
	}
   
}

//+------------------------------------------------------------------+
//| 以下为接口函数 |
//+------------------------------------------------------------------+
// 文本显示
void i_DisPlayInfo(string LableName,string LableDoc,int Corner,int LableX,int LableY,int DocSize,string DocStyle,color DocColor)
{
	if(Corner == -1) return;

	ObjectCreate(LableName,OBJ_LABEL,0,0,0);  //建立标签对象
	ObjectSetText(LableName,LableDoc,DocSize,DocStyle,DocColor);  //定义对象属性
	ObjectSet(LableName,OBJPROP_CORNER,Corner);   //设定坐标原点， 0-左上|1-右上|2-左下|3-右下|-1-不显示
	ObjectSet(LableName,OBJPROP_XDISTANCE,LableX);
	ObjectSet(LableName,OBJPROP_YDISTANCE,LableY);
}

// 下订单
int  i_OrderSend(string symbol,int cmd,double volume,double price,int slippage,double stoploss,double takeprofit,string comment,int magic,datetime expiration,color arrow_color)
{
	int t_tid=0;
	Alert("下单："+symbol+DoubleToStr(price)+ "|Lot:" + DoubleToStr(volume,2) + "|SL:"+DoubleToStr(stoploss)+"|TP:"+DoubleToStr(takeprofit));
	while(true)
	{
		t_tid=OrderSend(symbol,cmd,volume,price,slippage,stoploss,takeprofit,comment,magic,expiration,arrow_color);  
		//-------------------------------------------------------------------- 7 --
		if(t_tid>0) // 交易成功
		{
			Alert("下单成功..");
			break;                                 // 退出循环
		}
		//-------------------------------------------------------------------- 8 --
		int Error=GetLastError();                 // 失败
		switch(Error)                             // Overcomable errors
		{
			case 135:Alert("报价已经改变，请重试..");
			RefreshRates();                     // Update data
			continue;                           // At the next iteration
			case 136:Alert("没有报价，请等待更新..");
			while(RefreshRates()==false)        // Up to a new tick
			Sleep(1);                        // Cycle delay
			continue;                           // At the next iteration
			case 146:Alert("交易系统繁忙，请重试..");
			Sleep(500);                         // Simple solution
			RefreshRates();                     // Update data
			continue;                           // At the next iteration
		}

		switch(Error) // Critical errors
		{
			case 2 : Alert("通用错误.");
			break;                              // Exit 'switch'
			case 5 : Alert("客户端版本过低.");
			break;                              // Exit 'switch'
			case 64: Alert("账号被屏蔽.");
			break;                              // Exit 'switch'
			case 133:Alert("禁止交易");
			break;                              // Exit 'switch'
			default:
			Alert("发生错误",Error);// Other alternatives   
			break;
		}
		break;
	}
	return(t_tid);
}