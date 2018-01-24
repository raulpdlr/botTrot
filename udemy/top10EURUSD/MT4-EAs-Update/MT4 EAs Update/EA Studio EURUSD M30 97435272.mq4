//+------------------------------------------------------------------+
//|                                         EA Studio Expert Advisor |
//|                              Copyright 2016, Forex Software Ltd. |
//+------------------------------------------------------------------+
#property copyright "Forex Software Ltd."
#property version   "1.00"
#property strict

static input string StrategyProperties__ = "------------"; // ------ Expert Properties ------
static input double Entry_Amount = 0.01; // Entry lots
input int Stop_Loss   = 60; // Stop Loss (pips)
input int Take_Profit = 200; // Take Profit (pips)
static input string Ind0 = "------------";// ----- RVI Signal -----
input int Ind0Param0 = 46; // Period
static input string Ind1 = "------------";// ----- Bollinger Bands -----
input int Ind1Param0 = 20; // Period
input double Ind1Param1 = 3.00; // Deviation

static input string ExpertSettings__ = "------------"; // ------ Expert Settings ------
static input int Magic_Number = 97435272; // Magic Number

#define TRADE_RETRY_COUNT 4
#define TRADE_RETRY_WAIT  100
#define OP_FLAT           -1

// Session time is set in seconds from 00:00
int sessionSundayOpen           = 0;     // 00:00
int sessionSundayClose          = 86400; // 24:00
int sessionMondayThursdayOpen   = 0;     // 00:00
int sessionMondayThursdayClose  = 86400; // 24:00
int sessionFridayOpen           = 0;     // 00:00
int sessionFridayClose          = 86400; // 24:00
bool sessionIgnoreSunday        = false;
bool sessionCloseAtSessionClose = false;
bool sessionCloseAtFridayClose  = false;

const double sigma   = 0.000001;

double posType   = OP_FLAT;
int    posTicket = 0;
double posLots   = 0;

datetime barTime;
int      digits;
double   pip;
double   stopLevel;
bool     setProtectionSeparately=false;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   barTime   = Time[0];
   digits    = (int) MarketInfo(_Symbol, MODE_DIGITS);
   stopLevel = MarketInfo(_Symbol, MODE_STOPLEVEL);

   if(digits==4 || digits==5)
      pip=0.0001;
   else if(digits==2 || digits==3)
      pip=0.01;
   else if(digits==1)
      pip=0.1;
   else
      pip=1;

   return (INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(Time[0]>barTime)
     {
      barTime=Time[0];
      OnBar();
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnBar()
  {
   UpdatePosition();

   if(posType!=OP_FLAT && IsForceSessionClose())
     {
      ClosePosition();
      return;
     }

   if(IsOutOfSession())
     {
      return;
     }

   if(posType!=OP_FLAT)
     {
      ManageClose();
      UpdatePosition();
     }

   if(posType==OP_FLAT)
     {
      ManageOpen();
      UpdatePosition();
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdatePosition()
  {
   posType   = OP_FLAT;
   posTicket = 0;
   posLots   = 0;
   int total = OrdersTotal();

   for(int pos=total-1; pos>=0; pos--)
     {
      if(OrderSelect(pos,SELECT_BY_POS) &&
         OrderSymbol()==_Symbol &&
         OrderMagicNumber()==Magic_Number)
        {
         posType   = OrderType();
         posLots   = OrderLots();
         posTicket = OrderTicket();
         break;
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageOpen()
  {
   double ind0val1 = iRVI(NULL,0,Ind0Param0,MODE_MAIN,1) - iRVI(NULL,0,Ind0Param0,MODE_SIGNAL,1);
   bool ind0long  = ind0val1 > 0 + sigma;
   bool ind0short = ind0val1 < 0 - sigma;

   bool canOpenLong  = ind0long;
   bool canOpenShort = ind0short;

   if(canOpenLong && canOpenShort)
      return;

   if(canOpenLong)
      OpenPosition(OP_BUY);
   else if(canOpenShort)
      OpenPosition(OP_SELL);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageClose()
  {
   double ind1upBand1 = iBands(NULL,0,Ind1Param0,Ind1Param1,0,PRICE_CLOSE,MODE_UPPER,1);
   double ind1dnBand1 = iBands(NULL,0,Ind1Param0,Ind1Param1,0,PRICE_CLOSE,MODE_LOWER,1);
   bool ind1long  = Open[0] < ind1dnBand1 - sigma;
   bool ind1short = Open[0] > ind1upBand1 + sigma;

   if(posType==OP_BUY && ind1long)
      ClosePosition();
   else if(posType==OP_SELL && ind1short)
      ClosePosition();
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OpenPosition(int command)
  {
   for(int attempt=0; attempt<TRADE_RETRY_COUNT; attempt++)
     {
      int    ticket     = 0;
      int    lastError  = 0;
      bool   modified   = false;
      double stopLoss   = GetStopLoss(command);
      double takeProfit = GetTakeProfit(command);
      string comment    = IntegerToString(Magic_Number);
      color  arrowColor = command==OP_BUY ? clrGreen : clrRed;

      if(IsTradeContextFree())
        {
         double price=MarketInfo(_Symbol,command==OP_BUY ? MODE_ASK : MODE_BID);
         if(setProtectionSeparately)
           {
            ticket=OrderSend(_Symbol,command,Entry_Amount,price,10,0,0,comment,Magic_Number,0,arrowColor);
            if(ticket>0 && (Stop_Loss>0 || Take_Profit>0))
               modified=OrderModify(ticket,0,stopLoss,takeProfit,0,clrBlue);
           }
         else
           {
            ticket=OrderSend(_Symbol,command,Entry_Amount,price,10,stopLoss,takeProfit,comment,Magic_Number,0,arrowColor);
            lastError=GetLastError();
            if(ticket<=0 && lastError==130)
              {
               ticket=OrderSend(_Symbol,command,Entry_Amount,price,10,0,0,comment,Magic_Number,0,arrowColor);
               if(ticket>0 && (Stop_Loss>0 || Take_Profit>0))
                  modified=OrderModify(ticket,0,stopLoss,takeProfit,0,clrBlue);
               if(ticket>0 && modified)
                 {
                  setProtectionSeparately=true;
                  Print("Detected ECN type position protection.");
                 }
              }
           }
        }

      if(ticket>0)
         break;

      lastError=GetLastError();
      if(lastError!=135 && lastError!=136 && lastError!=137 && lastError!=138)
         break;

      Sleep(TRADE_RETRY_WAIT);
      Print("Open Position retry no: "+IntegerToString(attempt+2));
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ClosePosition()
  {
   for(int attempt=0; attempt<TRADE_RETRY_COUNT; attempt++)
     {
      bool closed;
      int lastError=0;

      if(IsTradeContextFree())
        {
         double price=MarketInfo(_Symbol,posType==OP_BUY ? MODE_BID : MODE_ASK);
         closed=OrderClose(posTicket,posLots,price,10,clrYellow);
         lastError=GetLastError();
        }

      if(closed)
         break;

      if(lastError==4108)
         break;

      Sleep(TRADE_RETRY_WAIT);
      Print("Close Position retry no: "+IntegerToString(attempt+2));
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetStopLoss(int command)
  {
   if(Stop_Loss==0)
      return (0);

   double delta    = MathMax(pip*Stop_Loss, _Point*stopLevel);
   double price    = MarketInfo(_Symbol, command==OP_BUY ? MODE_BID : MODE_ASK);
   double stopLoss = command==OP_BUY ? price-delta : price+delta;
   return (NormalizeDouble(stopLoss, digits));
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetTakeProfit(int command)
  {
   if(Take_Profit==0)
      return (0);

   double delta      = MathMax(pip*Take_Profit, _Point*stopLevel);
   double price      = MarketInfo(_Symbol, command==OP_BUY ? MODE_BID : MODE_ASK);
   double takeProfit = command==OP_BUY ? price+delta : price-delta;
   return (NormalizeDouble(takeProfit, digits));
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsTradeContextFree()
  {
   if(IsTradeAllowed())
      return (true);

   uint startWait=GetTickCount();
   Print("Trade context is busy! Waiting...");

   while(true)
     {
      if(IsStopped())
         return (false);

      uint diff=GetTickCount()-startWait;
      if(diff>30*1000)
        {
         Print("The waiting limit exceeded!");
         return (false);
        }

      if(IsTradeAllowed())
        {
         RefreshRates();
         return (true);
        }
      Sleep(TRADE_RETRY_WAIT);
     }
   return (true);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsOutOfSession()
  {
   MqlDateTime time0; TimeToStruct(Time[0],time0);
   int weekDay           = time0.day_of_week;
   long timeFromMidnight = Time[0]%86400;
   int periodLength      = PeriodSeconds(_Period);
   bool skipTrade        = false;

   if(weekDay==0)
     {
      if(sessionIgnoreSunday) return true;
      int lastBarFix=sessionCloseAtSessionClose ? periodLength : 0;
      skipTrade=timeFromMidnight<sessionSundayOpen || timeFromMidnight+lastBarFix>sessionSundayClose;
     }
   else if(weekDay<5)
     {
      int lastBarFix=sessionCloseAtSessionClose ? periodLength : 0;
      skipTrade=timeFromMidnight<sessionMondayThursdayOpen || timeFromMidnight+lastBarFix>sessionMondayThursdayClose;
     }
   else
     {
      int lastBarFix=sessionCloseAtFridayClose || sessionCloseAtSessionClose ? periodLength : 0;
      skipTrade=timeFromMidnight<sessionFridayOpen || timeFromMidnight+lastBarFix>sessionFridayClose;
     }

   return (skipTrade);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsForceSessionClose()
  {
   if(!sessionCloseAtFridayClose && !sessionCloseAtSessionClose)
      return (false);

   MqlDateTime time0; TimeToStruct(Time[0],time0);
   int weekDay           = time0.day_of_week;
   long timeFromMidnight = Time[0]%86400;
   int periodLength      = PeriodSeconds(_Period);
   int lastBarFix        = sessionCloseAtSessionClose ? periodLength : 0;

   bool forceExit=false;
   if(weekDay==0)
     {
      forceExit=timeFromMidnight+lastBarFix>sessionSundayClose;
     }
   else if(weekDay<5)
     {
      forceExit=timeFromMidnight+lastBarFix>sessionMondayThursdayClose;
     }
   else
     {
      int fridayBarFix=sessionCloseAtFridayClose || sessionCloseAtSessionClose ? periodLength : 0;
      forceExit=timeFromMidnight+fridayBarFix>sessionFridayClose;
     }

   return (forceExit);
  }
//+------------------------------------------------------------------+
/*STRATEGY MARKET MetaTrader-Demo; EURUSD; M30 */
/*STRATEGY CODE {"openFilters":[{"listIndexes":[2,0,0,0,0],"numValues":[46,0,0,0,0,0],"name":"RVI Signal"}],"closeFilters":[{"listIndexes":[1,3,0,0,0],"numValues":[20,3,0,0,0,0],"name":"Bollinger Bands"}],"properties":{"entryLots":0.01,"stopLoss":60,"takeProfit":200,"useStopLoss":true,"useTakeProfit":true}} */
