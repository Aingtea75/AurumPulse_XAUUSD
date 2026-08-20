//+------------------------------------------------------------------+
//| AurumPulse v6.49 - Isolated Execution Decision Engine            |
//| Strategy-only module. No indicator calls, drawing, or tick loop.  |
//+------------------------------------------------------------------+
#ifndef __AURUMPULSE_V649_EXECUTION_ENGINE_MQH__
#define __AURUMPULSE_V649_EXECUTION_ENGINE_MQH__

enum AP49_ENTRY_ROUTE
  {
   AP49_ROUTE_NONE       = 0,
   AP49_ROUTE_MARKET     = 1,
   AP49_ROUTE_BUY_LIMIT  = 2,
   AP49_ROUTE_SELL_LIMIT = 3,
   AP49_ROUTE_BUY_STOP   = 4,
   AP49_ROUTE_SELL_STOP  = 5
  };

enum AP49_SETUP_STATE
  {
   AP49_SETUP_IDLE        = 0,
   AP49_SETUP_CREATED     = 1,
   AP49_SETUP_CONFIRMED   = 2,
   AP49_SETUP_EXECUTABLE  = 3,
   AP49_SETUP_INVALIDATED = 4,
   AP49_SETUP_EXPIRED     = 5
  };

struct AP49_MarketContext
  {
   int    direction;
   int    freshSTFlip;
   int    haDirection;
   int    espDirection;
   int    structureDirection;
   int    reversalDirection;
   bool   exhaustion;
   bool   supportZone;
   bool   resistanceZone;
   bool   breakoutUp;
   bool   breakoutDown;
   bool   chase;
   bool   sideways;
   bool   riskBlocked;
   double atr;
   double bid;
   double ask;
   double structurePrice;
   double invalidationPrice;
  };

struct AP49_ExecutionPlan
  {
   AP49_ENTRY_ROUTE route;
   AP49_SETUP_STATE state;
   int    direction;
   int    votes;
   double entry;
   double sl;
   double tp;
   double riskDistance;
   bool   valid;
  };

#define AP49_MARKET_VOTES 3

bool AP49_DirectionalSetup(const AP49_MarketContext &c, int dir)
  {
   if(c.riskBlocked || c.sideways || c.chase || c.atr <= 0.0)
      return(false);
   if(dir == 0 || c.direction != dir)
      return(false);
   if(c.haDirection != dir || c.espDirection != dir)
      return(false);
   if(c.structureDirection != dir)
      return(false);
   return(true);
  }

AP49_ENTRY_ROUTE AP49_SelectRoute(const AP49_MarketContext &c, int dir, int &votes)
  {
   votes = 0;
   if(!AP49_DirectionalSetup(c,dir))
      return(AP49_ROUTE_NONE);

   if(c.haDirection == dir) votes++;
   if(c.espDirection == dir) votes++;
   if(c.structureDirection == dir) votes++;
   if(c.freshSTFlip == dir) votes++;

   // LIMIT = exhaustion/retest at a validated S/R zone.
   if(c.exhaustion)
     {
      if(dir < 0 && c.resistanceZone && c.reversalDirection <= 0)
         return(AP49_ROUTE_SELL_LIMIT);
      if(dir > 0 && c.supportZone && c.reversalDirection >= 0)
         return(AP49_ROUTE_BUY_LIMIT);
     }

   // STOP = reversal already confirmed by a fresh structural break.
   if(dir > 0 && c.breakoutUp && c.reversalDirection > 0)
      return(AP49_ROUTE_BUY_STOP);
   if(dir < 0 && c.breakoutDown && c.reversalDirection < 0)
      return(AP49_ROUTE_SELL_STOP);

   // MARKET = only a fresh, fully aligned momentum event.
   if(c.freshSTFlip == dir && votes >= AP49_MARKET_VOTES)
      return(AP49_ROUTE_MARKET);

   return(AP49_ROUTE_NONE);
  }

bool AP49_BuildPlan(const AP49_MarketContext &c, int dir, AP49_ExecutionPlan &p)
  {
   p.route = AP49_ROUTE_NONE;
   p.state = AP49_SETUP_IDLE;
   p.direction = dir;
   p.votes = 0;
   p.entry = 0.0;
   p.sl = 0.0;
   p.tp = 0.0;
   p.riskDistance = 0.0;
   p.valid = false;

   AP49_ENTRY_ROUTE route = AP49_SelectRoute(c,dir,p.votes);
   if(route == AP49_ROUTE_NONE)
      return(false);

   double structuralRisk = MathAbs(c.invalidationPrice - c.structurePrice);
   double risk = MathMax(c.atr * 1.50, structuralRisk);
   if(risk <= 0.0) risk = c.atr * 1.50;

   p.route = route;
   p.state = AP49_SETUP_EXECUTABLE;
   p.riskDistance = risk;

   if(route == AP49_ROUTE_MARKET)
      p.entry = (dir > 0 ? c.ask : c.bid);
   else if(route == AP49_ROUTE_BUY_LIMIT || route == AP49_ROUTE_SELL_LIMIT)
      p.entry = c.structurePrice;
   else if(route == AP49_ROUTE_BUY_STOP)
      p.entry = MathMax(c.ask,c.structurePrice);
   else if(route == AP49_ROUTE_SELL_STOP)
      p.entry = MathMin(c.bid,c.structurePrice);

   if(p.entry <= 0.0)
      return(false);

   p.sl = (dir > 0 ? p.entry-risk : p.entry+risk);
   p.tp = (dir > 0 ? p.entry+risk*1.50 : p.entry-risk*1.50);
   p.valid = true;
   return(true);
  }

// SL may only move in the direction that reduces risk.
bool AP49_ImprovesSL(int direction, double oldSL, double proposedSL, double point)
  {
   double eps = MathMax(point,0.00000001);
   if(direction > 0) return(proposedSL > oldSL + eps);
   if(direction < 0) return(proposedSL < oldSL - eps);
   return(false);
  }

// TP may only extend while the trend remains justified.
bool AP49_ExtendTP(int direction, double currentTP, double proposedTP, double point)
  {
   double eps = MathMax(point,0.00000001);
   if(direction > 0) return(proposedTP > currentTP + eps);
   if(direction < 0) return(proposedTP < currentTP - eps);
   return(false);
  }

// Smart trailing candidate. The host supplies the latest structural level,
// ATR and current price once per closed bar. A tight intrabar emergency lock
// may be supplied separately by the host, but it must still pass
// AP49_ImprovesSL() before OrderModify is attempted.
bool AP49_ComputeSmartTrail(int direction,
                            double openPrice,
                            double currentPrice,
                            double currentSL,
                            double structuralLevel,
                            double atr,
                            double point,
                            double lockATR,
                            double trailATR,
                            double &proposedSL)
  {
   proposedSL = currentSL;
   if(direction == 0 || atr <= 0.0 || point <= 0.0)
      return(false);

   double profitDistance = (direction > 0) ? (currentPrice-openPrice)
                                           : (openPrice-currentPrice);
   if(profitDistance <= atr*lockATR)
      return(false);

   double atrTrail = (direction > 0) ? currentPrice-atr*trailATR
                                     : currentPrice+atr*trailATR;
   double candidate = atrTrail;

   // Structural protection is preferred when it is valid on the correct side.
   if(structuralLevel > 0.0)
     {
      if(direction > 0) candidate = MathMax(candidate,structuralLevel);
      else              candidate = MathMin(candidate,structuralLevel);
     }

   // Never place the proposed SL on the wrong side of the current price.
   if(direction > 0 && candidate >= currentPrice-point) candidate = currentPrice-point;
   if(direction < 0 && candidate <= currentPrice+point) candidate = currentPrice+point;

   if(!AP49_ImprovesSL(direction,currentSL,candidate,point))
      return(false);

   proposedSL = candidate;
   return(true);
  }

// Dynamic TP extension. It is deliberately closed-bar driven by the host.
// Strong trend can move TP farther; weak/reversing trend leaves TP unchanged.
bool AP49_ComputeDynamicTP(int direction,
                           double currentPrice,
                           double currentTP,
                           double atr,
                           double structuralTarget,
                           bool trendStrong,
                           double point,
                           double extensionATR,
                           double &proposedTP)
  {
   proposedTP = currentTP;
   if(direction == 0 || atr <= 0.0 || point <= 0.0 || !trendStrong)
      return(false);

   double candidate = (direction > 0) ? currentPrice+atr*extensionATR
                                      : currentPrice-atr*extensionATR;

   if(structuralTarget > 0.0)
     {
      if(direction > 0) candidate = MathMax(candidate,structuralTarget);
      else              candidate = MathMin(candidate,structuralTarget);
     }

   if(!AP49_ExtendTP(direction,currentTP,candidate,point))
      return(false);

   proposedTP = candidate;
   return(true);
  }

#endif
//+------------------------------------------------------------------+
