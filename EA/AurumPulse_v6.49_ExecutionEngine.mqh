//+------------------------------------------------------------------+
//| AurumPulse v6.49 - Isolated Execution Decision Engine            |
//+------------------------------------------------------------------+
#ifndef __AURUMPULSE_V649_EXECUTION_ENGINE_MQH__
#define __AURUMPULSE_V649_EXECUTION_ENGINE_MQH__

enum AP49_ENTRY_ROUTE { AP49_ROUTE_NONE=0, AP49_ROUTE_MARKET=1, AP49_ROUTE_BUY_LIMIT=2, AP49_ROUTE_SELL_LIMIT=3, AP49_ROUTE_BUY_STOP=4, AP49_ROUTE_SELL_STOP=5 };
enum AP49_SETUP_STATE { AP49_SETUP_IDLE=0, AP49_SETUP_CREATED=1, AP49_SETUP_CONFIRMED=2, AP49_SETUP_EXECUTABLE=3, AP49_SETUP_INVALIDATED=4, AP49_SETUP_EXPIRED=5 };

struct AP49_MarketContext
  {
   int direction; int freshSTFlip; int haDirection; int espDirection;
   int structureDirection; int reversalDirection;
   bool exhaustion; bool supportZone; bool resistanceZone;
   bool breakoutUp; bool breakoutDown; bool chase; bool sideways; bool riskBlocked;
   double atr; double bid; double ask; double structurePrice; double invalidationPrice;
  };

struct AP49_ExecutionPlan
  {
   AP49_ENTRY_ROUTE route; AP49_SETUP_STATE state; int direction; int votes;
   double entry; double sl; double tp; double riskDistance; bool valid;
  };

#define AP49_MARKET_VOTES 3

bool AP49_DirectionalSetup(const AP49_MarketContext &c,int dir)
  {
   if(c.riskBlocked || c.sideways || c.chase || c.atr<=0.0) return(false);
   if(dir==0 || c.direction!=dir) return(false);
   if(c.haDirection!=dir || c.espDirection!=dir || c.structureDirection!=dir) return(false);
   return(true);
  }

AP49_ENTRY_ROUTE AP49_SelectRoute(const AP49_MarketContext &c,int dir,int &votes)
  {
   votes=0;
   if(!AP49_DirectionalSetup(c,dir)) return(AP49_ROUTE_NONE);
   if(c.haDirection==dir) votes++;
   if(c.espDirection==dir) votes++;
   if(c.structureDirection==dir) votes++;
   if(c.freshSTFlip==dir) votes++;

   // Exhaustion + validated S/R = LIMIT. This avoids chasing an exhausted move.
   if(c.exhaustion)
     {
      if(dir<0 && c.resistanceZone && c.reversalDirection<=0) return(AP49_ROUTE_SELL_LIMIT);
      if(dir>0 && c.supportZone && c.reversalDirection>=0) return(AP49_ROUTE_BUY_LIMIT);
     }

   // Confirmed structural reversal = STOP, not a premature market entry.
   if(dir>0 && c.breakoutUp && c.reversalDirection>0) return(AP49_ROUTE_BUY_STOP);
   if(dir<0 && c.breakoutDown && c.reversalDirection<0) return(AP49_ROUTE_SELL_STOP);

   // Market is reserved for a fresh, aligned momentum event.
   if(c.freshSTFlip==dir && votes>=AP49_MARKET_VOTES) return(AP49_ROUTE_MARKET);
   return(AP49_ROUTE_NONE);
  }

// Validate the conceptual pending price before the host calls OrderSend.
bool AP49_ValidEntryPrice(AP49_ENTRY_ROUTE route,double entry,double bid,double ask,double point)
  {
   if(entry<=0.0 || point<=0.0) return(false);
   if(route==AP49_ROUTE_BUY_LIMIT)  return(entry < ask-point);
   if(route==AP49_ROUTE_SELL_LIMIT) return(entry > bid+point);
   if(route==AP49_ROUTE_BUY_STOP)   return(entry > ask+point);
   if(route==AP49_ROUTE_SELL_STOP)  return(entry < bid-point);
   return(route==AP49_ROUTE_MARKET);
  }

bool AP49_BuildPlan(const AP49_MarketContext &c,int dir,AP49_ExecutionPlan &p)
  {
   p.route=AP49_ROUTE_NONE; p.state=AP49_SETUP_IDLE; p.direction=dir; p.votes=0;
   p.entry=0.0; p.sl=0.0; p.tp=0.0; p.riskDistance=0.0; p.valid=false;

   AP49_ENTRY_ROUTE route=AP49_SelectRoute(c,dir,p.votes);
   if(route==AP49_ROUTE_NONE) return(false);

   double structuralRisk=MathAbs(c.invalidationPrice-c.structurePrice);
   double risk=MathMax(c.atr*1.50,structuralRisk);
   if(risk<=0.0) risk=c.atr*1.50;

   p.route=route; p.state=AP49_SETUP_EXECUTABLE; p.riskDistance=risk;
   if(route==AP49_ROUTE_MARKET) p.entry=(dir>0?c.ask:c.bid);
   else if(route==AP49_ROUTE_BUY_LIMIT || route==AP49_ROUTE_SELL_LIMIT) p.entry=c.structurePrice;
   else if(route==AP49_ROUTE_BUY_STOP) p.entry=MathMax(c.ask,c.structurePrice);
   else if(route==AP49_ROUTE_SELL_STOP) p.entry=MathMin(c.bid,c.structurePrice);

   // The host supplies actual broker point and stop/freeze constraints.
   // A basic geometry check prevents a LIMIT/STOP from being inverted.
   double point=MathMax(MarketInfo(Symbol(),MODE_POINT),0.00000001);
   if(!AP49_ValidEntryPrice(route,p.entry,c.bid,c.ask,point)) return(false);

   p.sl=(dir>0?p.entry-risk:p.entry+risk);
   p.tp=(dir>0?p.entry+risk*1.50:p.entry-risk*1.50);
   p.valid=true;
   return(true);
  }

bool AP49_ImprovesSL(int direction,double oldSL,double proposedSL,double point)
  {
   double eps=MathMax(point,0.00000001);
   if(direction>0) return(proposedSL>oldSL+eps);
   if(direction<0) return(proposedSL<oldSL-eps);
   return(false);
  }

bool AP49_ExtendTP(int direction,double currentTP,double proposedTP,double point)
  {
   double eps=MathMax(point,0.00000001);
   if(direction>0) return(proposedTP>currentTP+eps);
   if(direction<0) return(proposedTP<currentTP-eps);
   return(false);
  }

bool AP49_ComputeSmartTrail(int direction,double openPrice,double currentPrice,double currentSL,
                            double structuralLevel,double atr,double point,double lockATR,double trailATR,
                            double &proposedSL)
  {
   proposedSL=currentSL;
   if(direction==0 || atr<=0.0 || point<=0.0) return(false);
   double profitDistance=(direction>0)?(currentPrice-openPrice):(openPrice-currentPrice);
   if(profitDistance<=atr*lockATR) return(false);

   double candidate=(direction>0)?currentPrice-atr*trailATR:currentPrice+atr*trailATR;
   if(structuralLevel>0.0)
     {
      if(direction>0) candidate=MathMax(candidate,structuralLevel);
      else candidate=MathMin(candidate,structuralLevel);
     }
   if(direction>0 && candidate>=currentPrice-point) candidate=currentPrice-point;
   if(direction<0 && candidate<=currentPrice+point) candidate=currentPrice+point;
   if(!AP49_ImprovesSL(direction,currentSL,candidate,point)) return(false);
   proposedSL=candidate;
   return(true);
  }

bool AP49_ComputeDynamicTP(int direction,double currentPrice,double currentTP,double atr,
                           double structuralTarget,bool trendStrong,double point,double extensionATR,
                           double &proposedTP)
  {
   proposedTP=currentTP;
   if(direction==0 || atr<=0.0 || point<=0.0 || !trendStrong) return(false);
   double candidate=(direction>0)?currentPrice+atr*extensionATR:currentPrice-atr*extensionATR;
   if(structuralTarget>0.0)
     {
      if(direction>0) candidate=MathMax(candidate,structuralTarget);
      else candidate=MathMin(candidate,structuralTarget);
     }
   if(!AP49_ExtendTP(direction,currentTP,candidate,point)) return(false);
   proposedTP=candidate;
   return(true);
  }

#endif
//+------------------------------------------------------------------+
