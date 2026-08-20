//+------------------------------------------------------------------+
//| AurumPulse XAUUSD v6.49 INTEGRATED TEST                         |
//| Four-indicator closed-bar decision layer + v6.49 execution plan |
//| Branch: test/write-access-20260821                               |
//+------------------------------------------------------------------+
#property strict
#property version "6.49"

#include "AurumPulse_v6.49_ExecutionEngine.mqh"

input int    MagicNumber              = 64949;
input double Lots                     = 0.01;
input int    SlippagePoints           = 30;
input bool   EnableTrading            = false; // SAFE DEFAULT: enable only after compile/audit
input bool   EnableMarketEntry        = true;
input bool   EnablePendingOrders      = true;
input bool   EnableSmartTrailing      = true;
input bool   EnableDynamicTP           = true;
input double TrailLockATR              = 1.00;
input double TrailDistanceATR          = 1.20;
input double TPExtensionATR            = 2.00;
input int    ATRPeriodHost             = 14;
input double MinTrendScore             = 55.0;
input int    MinESPStrength             = 45;
input int    MaxESPAge                  = 6;
input bool   RequireFreshSTForMarket   = true;
input bool   UseDiagnostics             = true;

string g_stName = "Supertrend_Promax";
string g_haName = "HeikenAshi_Custom";
string g_espName = "Entry_Signal_Pro";
string g_srName = "SuperSR_6";
datetime g_lastBar = 0;

bool NewClosedBar()
{
   datetime t=iTime(Symbol(),Period(),0);
   if(t==0 || t==g_lastBar) return(false);
   g_lastBar=t;
   return(true);
}

double I(const string name,const int buffer,const int shift)
{
   return(iCustom(Symbol(),Period(),name,buffer,shift));
}

bool Valid(const double v)
{
   return(v!=EMPTY_VALUE && v!=0.0 && v==v);
}

int Sign(const double v)
{
   if(v>0.0) return(1);
   if(v<0.0) return(-1);
   return(0);
}

int BuildContext(AP49_MarketContext &c)
{
   ZeroMemory(c);
   c.bid=Bid;
   c.ask=Ask;
   c.atr=iATR(Symbol(),Period(),ATRPeriodHost,1);
   if(c.atr<=0.0) return(0);

   // Supertrend contract: buffer 4 trend (+1/-1), 5/6 precise BUY/SELL,
   // 9 trend score, 10 grade, 11 chop, 12 TP suggestion, 13 pending hint.
   double stNow=I(g_stName,4,1);
   double stPrev=I(g_stName,4,2);
   double stBuy=I(g_stName,5,1);
   double stSell=I(g_stName,6,1);
   double trendScore=I(g_stName,9,1);
   double trendGrade=I(g_stName,10,1);
   double chop=I(g_stName,11,1);
   double pendingHint=I(g_stName,13,1);

   c.direction=Sign(stNow);
   c.freshSTFlip=(c.direction!=0 && c.direction!=Sign(stPrev)) ? c.direction : 0;
   if(c.direction==0) return(0);

   // HA contract: buffer 6 = confirmed direction.
   double haDir=I(g_haName,6,1);
   c.haDirection=Sign(haDir);

   // ESP contract: buffer 0/1 arrows, 2 strength, 3 persistent direction,
   // 4 age, 5 veto.
   double espBuy=I(g_espName,0,1);
   double espSell=I(g_espName,1,1);
   double espStrength=I(g_espName,2,1);
   double espDir=I(g_espName,3,1);
   double espAge=I(g_espName,4,1);
   double espVeto=I(g_espName,5,1);
   c.espDirection=Sign(espDir);

   // SuperSR contract: 0 resistance, 1 support. The two distance/strength
   // buffers are optional in older builds, so the primary levels are used.
   double resistance=I(g_srName,0,1);
   double support=I(g_srName,1,1);

   c.resistanceZone=(Valid(resistance) && resistance>Ask && (resistance-Ask)<=c.atr*1.00);
   c.supportZone=(Valid(support) && support<Bid && (Bid-support)<=c.atr*1.00);

   // Structure direction: price above support / below resistance. A neutral
   // middle is deliberately not treated as directional confirmation.
   if(c.supportZone && Bid>support) c.structureDirection=1;
   else if(c.resistanceZone && Ask<resistance) c.structureDirection=-1;
   else c.structureDirection=0;

   // Reversal direction is confirmed only by an actual ESP arrow on the
   // closed bar. This prevents a stale persistent ESP direction from being
   // mistaken for a fresh reversal.
   if(Valid(espBuy) && espStrength>=MinESPStrength && espAge<=MaxESPAge && espVeto<0.5)
      c.reversalDirection=1;
   else if(Valid(espSell) && espStrength>=MinESPStrength && espAge<=MaxESPAge && espVeto<0.5)
      c.reversalDirection=-1;
   else c.reversalDirection=0;

   // Exhaustion: strong trend, but price is entering the opposing S/R wall,
   // or a fresh counter-direction ESP reversal is present. This is the gate
   // that converts a late market chase into a LIMIT setup.
   bool strongTrend=(trendScore>=MinTrendScore && trendGrade>=2.0 && chop<70.0);
   c.exhaustion=false;
   if(strongTrend)
     {
      if(c.direction>0 && (c.resistanceZone || c.reversalDirection<0)) c.exhaustion=true;
      if(c.direction<0 && (c.supportZone || c.reversalDirection>0)) c.exhaustion=true;
     }

   // Breakout is based on a closed-bar close crossing the S/R boundary.
   double close1=iClose(Symbol(),Period(),1);
   double close2=iClose(Symbol(),Period(),2);
   c.breakoutUp=(Valid(resistance) && close2<=resistance && close1>resistance);
   c.breakoutDown=(Valid(support) && close2>=support && close1<support);

   // A breakout must be aligned with the current HA/ESP direction.
   if(c.breakoutUp && !(c.haDirection>0 && c.espDirection>0)) c.breakoutUp=false;
   if(c.breakoutDown && !(c.haDirection<0 && c.espDirection<0)) c.breakoutDown=false;

   // Chase protection: if trend is already mature and price is far from the
   // nearest structural level, do not market-enter. Pending/retest only.
   double nearestGap=1.0e10;
   if(Valid(resistance) && resistance>Ask) nearestGap=MathMin(nearestGap,resistance-Ask);
   if(Valid(support) && support<Bid) nearestGap=MathMin(nearestGap,Bid-support);
   c.chase=(trendScore>=75.0 && nearestGap>c.atr*1.50);
   c.sideways=(trendScore<MinTrendScore || chop>=70.0 || trendGrade<=0.0);
   c.riskBlocked=false;

   // Structure price is the level used for a pending LIMIT/STOP. For a BUY
   // LIMIT use support; for SELL LIMIT use resistance. For STOP use the
   // crossed structural boundary. In a market setup it is only a risk anchor.
   if(c.direction>0)
     {
      if(Valid(support)) c.structurePrice=support;
      else c.structurePrice=Bid-c.atr;
      c.invalidationPrice=c.structurePrice-c.atr*0.25;
     }
   else
     {
      if(Valid(resistance)) c.structurePrice=resistance;
      else c.structurePrice=Ask+c.atr;
      c.invalidationPrice=c.structurePrice+c.atr*0.25;
     }

   // Pending hint is intentionally diagnostic only; the route engine remains
   // the authority. A malformed hint can never create an order by itself.
   if(UseDiagnostics)
      PrintFormat("[v6.49 CTX] ST=%d flip=%d score=%.1f grade=%.0f chop=%.1f HA=%d ESP=%d/%d age=%.0f rev=%d SR=%d/%d hint=%.0f",
                  c.direction,c.freshSTFlip,trendScore,trendGrade,chop,c.haDirection,
                  c.espDirection,(int)espStrength,espAge,c.reversalDirection,
                  c.supportZone,c.resistanceZone,pendingHint);
   return(c.direction);
}

bool HasOurPosition(const int dir)
{
   for(int i=OrdersTotal()-1;i>=0;i--)
     if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
       if(OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber &&
          ((dir>0 && OrderType()==OP_BUY)||(dir<0 && OrderType()==OP_SELL))) return(true);
   return(false);
}

bool SendPlan(const AP49_ExecutionPlan &p)
{
   if(!p.valid || !EnableTrading) return(false);
   if(p.route==AP49_ROUTE_MARKET && !EnableMarketEntry) return(false);
   if(p.route!=AP49_ROUTE_MARKET && !EnablePendingOrders) return(false);
   if(HasOurPosition(p.direction)) return(false);

   RefreshRates();
   double point=MarketInfo(Symbol(),MODE_POINT);
   int digits=(int)MarketInfo(Symbol(),MODE_DIGITS);
   int stopLevel=(int)MarketInfo(Symbol(),MODE_STOPLEVEL);
   double minDist=MathMax(point,(double)stopLevel*point);
   int type=-1;
   double price=p.entry;

   if(p.route==AP49_ROUTE_MARKET) type=(p.direction>0?OP_BUY:OP_SELL);
   if(p.route==AP49_ROUTE_BUY_LIMIT) type=OP_BUYLIMIT;
   if(p.route==AP49_ROUTE_SELL_LIMIT) type=OP_SELLLIMIT;
   if(p.route==AP49_ROUTE_BUY_STOP) type=OP_BUYSTOP;
   if(p.route==AP49_ROUTE_SELL_STOP) type=OP_SELLSTOP;
   if(type<0) return(false);

   if(type==OP_BUY) price=Ask;
   if(type==OP_SELL) price=Bid;

   if(type==OP_BUYLIMIT && price>=Ask-minDist) return(false);
   if(type==OP_SELLLIMIT && price<=Bid+minDist) return(false);
   if(type==OP_BUYSTOP && price<=Ask+minDist) return(false);
   if(type==OP_SELLSTOP && price>=Bid-minDist) return(false);

   double sl=p.sl, tp=p.tp;
   if(p.direction>0)
     {
      sl=MathMin(sl,price-minDist);
      tp=MathMax(tp,price+minDist);
     }
   else
     {
      sl=MathMax(sl,price+minDist);
      tp=MathMin(tp,price-minDist);
     }
   price=NormalizeDouble(price,digits);
   sl=NormalizeDouble(sl,digits);
   tp=NormalizeDouble(tp,digits);

   ResetLastError();
   int ticket=OrderSend(Symbol(),type,Lots,price,SlippagePoints,sl,tp,"AurumPulse v6.49",MagicNumber,0,clrNONE);
   if(ticket<0)
     {
      PrintFormat("[v6.49 ORDER ERROR] route=%d err=%d",p.route,GetLastError());
      return(false);
     }
   PrintFormat("[v6.49 ORDER] ticket=%d route=%d dir=%d entry=%.*f SL=%.*f TP=%.*f",
               ticket,p.route,p.direction,digits,price,digits,sl,digits,tp);
   return(true);
}

void ManagePositions()
{
   if(!EnableTrading || (!EnableSmartTrailing && !EnableDynamicTP)) return;
   double atr=iATR(Symbol(),Period(),ATRPeriodHost,1);
   if(atr<=0.0) return;
   double point=MarketInfo(Symbol(),MODE_POINT);
   int digits=(int)MarketInfo(Symbol(),MODE_DIGITS);

   // Intrabar work is limited to open positions only; indicators are NOT
   // recalculated here. This avoids the tick-load/panel-flicker problem.
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber) continue;
      int type=OrderType();
      if(type!=OP_BUY && type!=OP_SELL) continue;
      int dir=(type==OP_BUY?1:-1);
      double current=(dir>0?Bid:Ask);
      double structural=0.0;
      if(dir>0) structural=I(g_srName,1,1);
      else structural=I(g_srName,0,1);

      double proposedSL=OrderStopLoss();
      if(EnableSmartTrailing && AP49_ComputeSmartTrail(dir,OrderOpenPrice(),current,OrderStopLoss(),
                                                        structural,atr,point,TrailLockATR,TrailDistanceATR,proposedSL))
        {
         proposedSL=NormalizeDouble(proposedSL,digits);
         if(!OrderModify(OrderTicket(),OrderOpenPrice(),proposedSL,OrderTakeProfit(),0,clrNONE))
            PrintFormat("[v6.49 TRAIL ERROR] ticket=%d err=%d",OrderTicket(),GetLastError());
        }

      if(EnableDynamicTP && OrderTakeProfit()>0.0)
        {
         double target=(dir>0?I(g_srName,0,1):I(g_srName,1,1));
         bool strong=(I(g_stName,10,1)>=2.0 && I(g_stName,9,1)>=MinTrendScore && I(g_stName,11,1)<70.0);
         double newTP=OrderTakeProfit();
         if(AP49_ComputeDynamicTP(dir,current,OrderTakeProfit(),atr,target,strong,point,TPExtensionATR,newTP))
           {
            newTP=NormalizeDouble(newTP,digits);
            if(!OrderModify(OrderTicket(),OrderOpenPrice(),OrderStopLoss(),newTP,0,clrNONE))
               PrintFormat("[v6.49 TP ERROR] ticket=%d err=%d",OrderTicket(),GetLastError());
           }
        }
     }
}

int OnInit()
{
   Print("=== AurumPulse XAUUSD v6.49 INTEGRATED TEST ===");
   Print("SAFE DEFAULT: EnableTrading=false. Compile and validate before enabling.");
   return(INIT_SUCCEEDED);
}

void OnTick()
{
   // Position protection is lightweight and does not recalculate the four
   // indicators on every tick.
   ManagePositions();

   if(!NewClosedBar()) return;

   AP49_MarketContext c;
   if(BuildContext(c)==0) return;

   AP49_ExecutionPlan plan;
   ZeroMemory(plan);
   if(AP49_BuildPlan(c,c.direction,plan))
     {
      if(UseDiagnostics)
         PrintFormat("[v6.49 PLAN] route=%d state=%d dir=%d votes=%d entry=%.2f SL=%.2f TP=%.2f valid=%d",
                     plan.route,plan.state,plan.direction,plan.votes,plan.entry,plan.sl,plan.tp,plan.valid);
      SendPlan(plan);
     }
}
//+------------------------------------------------------------------+
