//+------------------------------------------------------------------+
//|                                                     FTSystem.mq4 |
//|                                             Forex Trading System |
//|                                          http://www.ftsystem.org |
//+------------------------------------------------------------------+

#property copyright "ftsystem.org"
#property link      "http://www.ftsystem.org"

//---- Includes
#include <stdlib.mqh>

//--- Indicator settings
extern string    Options1 = "------------------------------ Optimization ------------------------------"; 
extern int       Var = 24; 

//---- Money Management
extern string    Options2 = "------------------------------ Money Management ------------------------------"; 
extern double    TakeProfit = 300;
extern double    TrailingStop = 300;
extern double    StopLoss = 300;
extern double    Lots = 0.1;
extern int       Slippage = 5;

//--- Advanced Money Management
extern string    Options3 = "------------------------------ Advanced Money Management ------------------------------"; 
extern int       CurrentBar = 1;
extern int       HedgeLevel = 6;
extern double    Expiration = 7200;
extern int       Size = 4;
extern int       Step = 1;
extern bool      UseClose = true;


//--- Global variables
int      MagicNumber = 101090;
string   ExpertComment = "FTSystem";

bool     LimitPairs = false;
bool     LimitFrame = false;
int      TimeFrame = 60;
string   LP[] = {"EURUSD","USDCHF","GBPUSD","USDJPY"}; // add/remove the paris you want to limit.
bool     Optimize = true;
int      NumberOfTries = 5;
//+------------------------------------------------------------------
int init()
{
   return(0);
}

int deinit() 
{
   return(0);
}
//+------------------------------------------------------------------

bool isNewSymbol(string current_symbol)
  {
   //loop through all the opened order and compare the symbols
   int total  = OrdersTotal();
   for(int cnt = 0 ; cnt < total ; cnt++)
   {
      OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
      string selected_symbol = OrderSymbol();
      if (current_symbol == selected_symbol && OrderMagicNumber()==MagicNumber)
      return (False);
    }
    return (True);
}

//+------------------------------------------------------------------+
int start()
  {
   int cnt, ticket, total,n;
   double trend ;
   
   if(Bars<100) {Print("bars less than 100"); return(0);}
   
   
   if(LimitFrame)
   { 
      if(Period()!=TimeFrame) {Print("This EA is not working with this TimeFrame!"); return(0);}
   }
   if(LimitPairs)
   { 
      if(AllowedPair(Symbol()) == false) {Print("This EA is not working with this Currency!"); return(0);}
   }   
   
   trend = iCustom(NULL,0,"FTSystem-indicator",Var,100,0,0,CurrentBar);
   
   //--- Trading conditions
   bool BuyCondition = false , SellCondition = false , CloseBuyCondition = false , CloseSellCondition = false ; 
   
   if (Open[1]<trend && Close[1]>trend)
       BuyCondition = true;
       
   if (Open[1]>trend && Close[1]<trend)
      SellCondition = true;
  
   if (Open[1]>trend && Close[1]<trend)
      CloseBuyCondition = true;
      
   if (Open[1]<trend && Close[1]>trend)
      CloseSellCondition = true;   
      
   
   total  = OrdersTotal();
   
   if(total < 1 || isNewSymbol(Symbol())) 
     {
       if(BuyCondition) //<-- BUY condition
         {
           ticket = OpenOrder(OP_BUY); //<-- Open BUY order
           CheckError(ticket,"BUY");
            
            for(n=0 ; n< Size ; n++)
            {            
               ticket = OpenPendingOrder(OP_BUYSTOP,Lots,HedgeLevel+(n*Step+1),Slippage,StopLoss,TakeProfit,ExpertComment,MagicNumber,CurTime() + Expiration);
            }
            return(0);
         }
         if(SellCondition) //<-- SELL condition
         {
            ticket = OpenOrder(OP_SELL); //<-- Open SELL order
            CheckError(ticket,"SELL");
            
            for(n=0 ; n < Size ; n++)
            {
               ticket = OpenPendingOrder(OP_SELLSTOP,Lots,HedgeLevel+(n*Step+1),Slippage,StopLoss,TakeProfit,ExpertComment,MagicNumber,CurTime() + Expiration);
            }
            return(0);
         }
         return(0);
     }
     
      for(cnt=0;cnt<total;cnt++) 
      {
         OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);

         if(OrderType()<=OP_SELL && OrderSymbol()==Symbol())
         {
            if(OrderType()==OP_BUY)   //<-- Long position is opened
            {
               if(UseClose)
               {
                  if(CloseBuyCondition) //<-- Close the order and exit! 
                  {
                     CloseOrder(OrderType()); return(0);
                  } 
               }
               
               TrailOrder(OrderType()); return(0); //<-- Trailling the order
            }
            if(OrderType()==OP_SELL) //<-- Go to short position
            {
               if(UseClose)
               {
                  if(CloseSellCondition) //<-- Close the order and exit! 
                  {
                     CloseOrder(OP_SELL); return(0);
                  } 
               }
               
               TrailOrder(OrderType()); return(0); //<-- Trailling the order
            }
         }
      }

   return(0);
  }
//+------------------------------------------------------------------+

int OpenOrder(int type)
{
   int ticket=0;
   int err=0;
   int c = 0;
   
   if(type==OP_BUY)
   {
      for(c = 0 ; c < NumberOfTries ; c++)
      {
         ticket=OrderSend(Symbol(),OP_BUY,Lots,Ask,Slippage,Ask-StopLoss*Point,Ask+TakeProfit*Point,ExpertComment,MagicNumber,0,Green);
         err=GetLastError();
         if(err==0)
         { 
            break;
         }
         else
         {
            if(err==4 || err==137 ||err==146 || err==136) //Busy errors
            {
               Sleep(5000);
               continue;
            }
            else //normal error
            {
               break;
            }  
         }
      }   
   }
   if(type==OP_SELL)
   {   
      for(c = 0 ; c < NumberOfTries ; c++)
      {
         ticket=OrderSend(Symbol(),OP_SELL,Lots,Bid,Slippage,Bid+StopLoss*Point,Bid-TakeProfit*Point,ExpertComment,MagicNumber,0,Red);
         err=GetLastError();
         if(err==0)
         { 
            break;
         }
         else
         {
            if(err==4 || err==137 ||err==146 || err==136) //Busy errors
            {
               Sleep(5000);
               continue;
            }
            else //normal error
            {
               break;
            }  
         }
      }   
   }  
   return(ticket);
}

int OpenPendingOrder(int pType=OP_BUYLIMIT,double pLots=1,double pLevel=5,int sp=0, double sl=0,double tp=0,string pComment="",int pMagic=123,datetime pExpiration=0,color pColor=Yellow)
{
  int ticket=0;
  int err=0;
  int c = 0;
  
  switch (pType)
  {
      case OP_BUYLIMIT:
         for(c = 0 ; c < NumberOfTries ; c++)
         {
            ticket=OrderSend(Symbol(),OP_BUYLIMIT,pLots,Ask-pLevel*Point,sp,(Ask-pLevel*Point)-sl*Point,(Ask-pLevel*Point)+tp*Point,pComment,pMagic,pExpiration,pColor);
            err=GetLastError();
            if(err==0)
            { 
               break;
            }
            else
            {
               if(err==4 || err==137 ||err==146 || err==136) //Busy errors
               {
                  Sleep(5000);
                  continue;
               }
               else //normal error
               {
                  break;
               }  
            }
         }   
         break;
      case OP_BUYSTOP:
         for(c = 0 ; c < NumberOfTries ; c++)
         {
            ticket=OrderSend(Symbol(),OP_BUYSTOP,pLots,Ask+pLevel*Point,sp,(Ask+pLevel*Point)-sl*Point,(Ask+pLevel*Point)+tp*Point,pComment,pMagic,pExpiration,pColor);
            err=GetLastError();
            if(err==0)
            { 
               break;
            }
            else
            {
               if(err==4 || err==137 ||err==146 || err==136) //Busy errors
               {
                  Sleep(5000);
                  continue;
               }
               else //normal error
               {
                  break;
               }  
            }
         } 
         break;
      case OP_SELLLIMIT:
         for(c = 0 ; c < NumberOfTries ; c++)
         {
            ticket=OrderSend(Symbol(),OP_SELLLIMIT,pLots,Bid+pLevel*Point,sp,(Bid+pLevel*Point)+sl*Point,(Bid+pLevel*Point)-tp*Point,pComment,pMagic,pExpiration,pColor);
            err=GetLastError();
            if(err==0)
            { 
               break;
            }
            else
            {
               if(err==4 || err==137 ||err==146 || err==136) //Busy errors
               {
                  Sleep(5000);
                  continue;
               }
               else //normal error
               {
                  break;
               }  
            }
         } 
         break;
      case OP_SELLSTOP:
         for(c = 0 ; c < NumberOfTries ; c++)
         {
            ticket=OrderSend(Symbol(),OP_SELLSTOP,pLots,Bid-pLevel*Point,sp,(Bid-pLevel*Point)+sl*Point,(Bid-pLevel*Point)-tp*Point,pComment,pMagic,pExpiration,pColor);
            err=GetLastError();
            if(err==0)
            { 
               break;
            }
            else
            {
               if(err==4 || err==137 ||err==146 || err==136) //Busy errors
               {
                  Sleep(5000);
                  continue;
               }
               else //normal error
               {
                  break;
               }  
            }
         } 
         break;
  } 
  
  return(ticket);
}

bool CloseOrder(int type)
{
   if(OrderMagicNumber() == MagicNumber)
   {
      if(type==OP_BUY)
         return (OrderClose(OrderTicket(),OrderLots(),Bid,Slippage,Violet));
      if(type==OP_SELL)   
         return (OrderClose(OrderTicket(),OrderLots(),Ask,Slippage,Violet));
   }
}
void TrailOrder(int type)
{
   if(TrailingStop>0)
   {
      if(OrderMagicNumber() == MagicNumber)
      {
         if(type==OP_BUY)
         {
            if(Bid-OrderOpenPrice()>Point*TrailingStop)
            {
               if(OrderStopLoss()<Bid-Point*TrailingStop)
               {
                  OrderModify(OrderTicket(),OrderOpenPrice(),Bid-Point*TrailingStop,OrderTakeProfit(),0,Green);
               }
            }
         }
         if(type==OP_SELL)
         {
            if((OrderOpenPrice()-Ask)>(Point*TrailingStop))
            {
               if((OrderStopLoss()>(Ask+Point*TrailingStop)) || (OrderStopLoss()==0))
               {
                  OrderModify(OrderTicket(),OrderOpenPrice(),Ask+Point*TrailingStop,OrderTakeProfit(),0,Red);
               }
            }
         }
      }
   }
}

void CheckError(int ticket, string Type)
{
    if(ticket>0)
    {
      if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES)) Print(Type + " order opened : ",OrderOpenPrice());
    }   
    else Print("Error opening " + Type + " order : ", ErrorDescription(GetLastError()));
}

bool AllowedPair(string pair)
{
   bool result=false;
   for (int n = 0 ; n < ArraySize(LP); n++)
   {
      if(Symbol() == LP[n])
      {
         result = true;
      }
   }
   return (result);
}


