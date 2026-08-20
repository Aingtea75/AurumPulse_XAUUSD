//+------------------------------------------------------------------+
//| AurumPulse v6.49 - Isolated Execution Decision Engine            |
//| Strategy-only module. No indicator calls, drawing, or tick loop.  |
//| Integration into the v6.48 EA must be done after compile review.  |
//+------------------------------------------------------------------+
#ifndef __AURUMPULSE_V649_EXECUTION_ENGINE_MQH__
#define __AURUMPULSE_V649_EXECUTION_ENGINE_MQH__

// Entry route selected by the decision engine.
enum AP49_ENTRY_ROUTE
  {
   AP49_ROUTE_NONE       = 0,
   AP49_ROUTE_MARKET     = 1,
   AP49_ROUTE_BUY_LIMIT  = 2,
   AP49_ROUTE_SELL_LIMIT = 3,
   AP49_ROUTE_BUY_STOP   = 4,
   AP49_ROUTE_SELL_STOP  = 5
  };

// Lifecycle of a setup/order. The host EA owns actual broker orders.
enum AP49_SETUP_STATE
  {
   AP49_SETUP_IDLE        = 0,
   AP49_SETUP_CREATED     = 1,
   AP49_SETUP_CONFIRMED   = 2,
   AP49_SETUP_EXECUTABLE  = 3,
   AP49_SETUP_INVALIDATED = 4,
   AP49_SETUP_EXPIRED     = 5
  };

// Snapshot supplied by the host EA once per closed bar.
struct AP49_MarketContext
  {
   int    direction;          // +1 bullish, -1 bearish, 0 neutral
   int    freshSTFlip;        // +1/-1 only on a fresh closed-bar flip
   int    haDirection;        // +1/-1/0
   int    espDirection;       // +1/-1/0
   int    structureDirection; // +1/-1/0
   int    reversalDirection;  // +1/-1/0
   bool   exhaustion;          // extension/exhaustion condition
   bool   supportZone;         // validated downside support zone
   bool   resistanceZone;      // validated upside resistance zone
   bool   breakoutUp;          // fresh bullish structure break
   bool   breakoutDown;        // fresh bearish structure break
   bool   chase;               // price already materially extended
   bool   sideways;            // low-quality compression/chop
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

// Conservative vote requirement for direct market execution.
#define AP49_MARKET_VOTES 3

// Validate the minimum common evidence for a directional setup.
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

// Select the route. This deliberately separates exhaustion/reversal logic
// from fresh momentum logic so LIMIT and STOP orders have distinct meaning.
AP49_ENTRY_ROUTE AP49_SelectRoute(const AP49_MarketContext &c, int dir, int &votes)
  {
   votes = 0;
   if(!AP49_DirectionalSetup(c,dir))
      return(AP49_ROUTE_NONE);

   if(c.haDirection == dir) votes++;
   if(c.espDirection == dir) votes++;
   if(c.structureDirection == dir) votes++;
   if(c.freshSTFlip == dir) votes++;

   // Exhaustion at the end of an established move: use a LIMIT to enter
   // on the expected pullback/reversal zone, never a market chase.
   if(c.exhaustion)
     {
      if(dir < 0 && c.resistanceZone && c.reversalDirection <= 0)
         return(AP49_ROUTE_SELL_LIMIT);
      if(dir > 0 && c.supportZone && c.reversalDirection >= 0)
         return(AP49_ROUTE_BUY_LIMIT);
     }

   // Reversal confirmation after the old trend: STOP confirms that the new
   // direction actually breaks structure instead of guessing the bottom/top.
   if(dir > 0 && c.breakoutUp && c.reversalDirection > 0)
      return(AP49_ROUTE_BUY_STOP);
   if(dir < 0 && c.breakoutDown && c.reversalDirection < 0)
      return(AP49_ROUTE_SELL_STOP);

   // Market entry is reserved for fresh, aligned momentum and never for a
   // stale trend flip. A fresh flip alone is insufficient.
   if(c.freshSTFlip == dir && votes >= AP49_MARKET_VOTES)
      return(AP49_ROUTE_MARKET);

   return(AP49_ROUTE_NONE);
  }

// Build a normalized conceptual plan. The host EA is responsible for broker
// stop/freeze checks and the actual OrderSend call.
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

   double risk = MathMax(c.atr * 1.50, MathAbs(c.invalidationPrice - c.structurePrice));
   if(risk <= 0.0)
      risk = c.atr * 1.50;

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

// Ratchet rule for BUY/SELL. Returns true only when protection improves.
bool AP49_ImprovesSL(int direction, double oldSL, double proposedSL, double point)
  {
   double eps = MathMax(point,0.00000001);
   if(direction > 0)
      return(proposedSL > oldSL + eps);
   if(direction < 0)
      return(proposedSL < oldSL - eps);
   return(false);
  }

// Dynamic TP can only extend in the favorable direction. The host EA calls
// this once per closed bar after a new structural/momentum justification.
bool AP49_ExtendTP(int direction, double currentTP, double proposedTP, double point)
  {
   double eps = MathMax(point,0.00000001);
   if(direction > 0)
      return(proposedTP > currentTP + eps);
   if(direction < 0)
      return(proposedTP < currentTP - eps);
   return(false);
  }

#endif
//+------------------------------------------------------------------+
