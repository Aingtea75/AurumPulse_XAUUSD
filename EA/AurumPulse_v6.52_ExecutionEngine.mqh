//+------------------------------------------------------------------+
//| AurumPulse v6.52 - Execution Decision Engine                     |
//| TEST6: Dynamic TP guarded by live SL risk/reward                  |
//+------------------------------------------------------------------+
#ifndef __AURUMPULSE_V652_EXECUTION_ENGINE_MQH__
#define __AURUMPULSE_V652_EXECUTION_ENGINE_MQH__

enum AP52_ENTRY_ROUTE { AP52_ROUTE_NONE=0, AP52_ROUTE_MARKET=1, AP52_ROUTE_BUY_LIMIT=2, AP52_ROUTE_SELL_LIMIT=3, AP52_ROUTE_BUY_STOP=4, AP52_ROUTE_SELL_STOP=5 };
enum AP52_SETUP_STATE { AP52_SETUP_IDLE=0, AP52_SETUP_CREATED=1, AP52_SETUP_CONFIRMED=2, AP52_SETUP_EXECUTABLE=3, AP52_SETUP_INVALIDATED=4, AP52_SETUP_EXPIRED=5 };
struct AP52_MarketContext { int direction; int freshSTFlip; int haDirection; int espDirection; int structureDirection; int reversalDirection; bool exhaustion; bool supportZone; bool resistanceZone; bool breakoutUp; bool breakoutDown; bool chase; bool sideways; bool riskBlocked; double atr; double bid; double ask; double structurePrice; double invalidationPrice; };
struct AP52_ExecutionPlan { AP52_ENTRY_ROUTE route; AP52_SETUP_STATE state; int direction; int votes; double entry; double sl; double tp; double riskDistance; bool valid; };
#define AP52_MARKET_VOTES 3

bool AP52_DirectionalSetup(const AP52_MarketContext &c,int dir){
 if(c.riskBlocked||c.sideways||c.chase||c.atr<=0.0||dir==0||c.direction!=dir)return(false);
 if(c.haDirection!=dir||c.espDirection!=dir)return(false);
 if(c.structureDirection!=0&&c.structureDirection!=dir)return(false);
 return(true);
}

AP52_ENTRY_ROUTE AP52_SelectRoute(const AP52_MarketContext &c,int dir,int &votes){
 votes=0;if(!AP52_DirectionalSetup(c,dir))return(AP52_ROUTE_NONE);
 if(c.haDirection==dir)votes++;if(c.espDirection==dir)votes++;if(c.structureDirection==dir)votes++;if(c.freshSTFlip==dir)votes++;
 if(c.exhaustion){
  if(dir<0&&c.resistanceZone&&c.reversalDirection<=0)return(AP52_ROUTE_SELL_LIMIT);
  if(dir>0&&c.supportZone&&c.reversalDirection>=0)return(AP52_ROUTE_BUY_LIMIT);
 }
 if(dir>0&&c.breakoutUp&&c.reversalDirection>0)return(AP52_ROUTE_BUY_STOP);
 if(dir<0&&c.breakoutDown&&c.reversalDirection<0)return(AP52_ROUTE_SELL_STOP);
 if(c.freshSTFlip==dir&&votes>=AP52_MARKET_VOTES)return(AP52_ROUTE_MARKET);
 return(AP52_ROUTE_NONE);
}

bool AP52_ValidEntryPrice(AP52_ENTRY_ROUTE route,double entry,double bid,double ask,double point){
 if(entry<=0.0||point<=0.0)return(false);
 if(route==AP52_ROUTE_BUY_LIMIT)return(entry<ask-point);
 if(route==AP52_ROUTE_SELL_LIMIT)return(entry>bid+point);
 if(route==AP52_ROUTE_BUY_STOP)return(entry>ask+point);
 if(route==AP52_ROUTE_SELL_STOP)return(entry<bid-point);
 return(route==AP52_ROUTE_MARKET);
}

bool AP52_BuildPlan(const AP52_MarketContext &c,int dir,AP52_ExecutionPlan &p){
 p.route=AP52_ROUTE_NONE;p.state=AP52_SETUP_IDLE;p.direction=dir;p.votes=0;p.entry=0;p.sl=0;p.tp=0;p.riskDistance=0;p.valid=false;
 AP52_ENTRY_ROUTE route=AP52_SelectRoute(c,dir,p.votes);if(route==AP52_ROUTE_NONE)return(false);
 double structuralRisk=MathAbs(c.invalidationPrice-c.structurePrice);double risk=MathMax(c.atr*1.50,structuralRisk);if(risk<=0)risk=c.atr*1.50;
 p.route=route;p.state=AP52_SETUP_EXECUTABLE;p.riskDistance=risk;
 if(route==AP52_ROUTE_MARKET)p.entry=dir>0?c.ask:c.bid;
 else if(route==AP52_ROUTE_BUY_LIMIT||route==AP52_ROUTE_SELL_LIMIT)p.entry=c.structurePrice;
 else if(route==AP52_ROUTE_BUY_STOP)p.entry=MathMax(c.ask,c.structurePrice);
 else if(route==AP52_ROUTE_SELL_STOP)p.entry=MathMin(c.bid,c.structurePrice);
 double point=MathMax(MarketInfo(Symbol(),MODE_POINT),0.00000001);if(!AP52_ValidEntryPrice(route,p.entry,c.bid,c.ask,point))return(false);
 p.sl=dir>0?p.entry-risk:p.entry+risk;p.tp=dir>0?p.entry+risk*1.50:p.entry-risk*1.50;p.valid=true;return(true);
}

bool AP52_ImprovesSL(int d,double oldSL,double newSL,double point){double e=MathMax(point,0.00000001);return d>0?newSL>oldSL+e:d<0&&newSL<oldSL-e;}
bool AP52_ExtendTP(int d,double oldTP,double newTP,double point){double e=MathMax(point,0.00000001);return d>0?newTP>oldTP+e:d<0&&newTP<oldTP-e;}
bool AP52_ComputeSmartTrail(int d,double open,double cur,double oldSL,double structural,double atr,double point,double lockATR,double trailATR,double &outSL){outSL=oldSL;if(d==0||atr<=0||point<=0)return(false);double pd=d>0?cur-open:open-cur;if(pd<=atr*lockATR)return(false);double c=d>0?cur-atr*trailATR:cur+atr*trailATR;if(structural>0){if(d>0)c=MathMax(c,structural);else c=MathMin(c,structural);}if(d>0&&c>=cur-point)c=cur-point;if(d<0&&c<=cur+point)c=cur+point;if(!AP52_ImprovesSL(d,oldSL,c,point))return(false);outSL=c;return(true);}

// Dynamic TP guard: target may extend only if it improves the existing TP,
// remains in the profitable direction, and preserves the configured minimum RR
// against the CURRENT stop loss. Structural levels are candidates, not authority.
bool AP52_ComputeDynamicTP(int d,double cur,double oldTP,double currentSL,double atr,double structural,bool strong,double point,double ext,double minRR,double &outTP){
 outTP=oldTP;
 if(d==0||atr<=0||point<=0||!strong||oldTP<=0||currentSL<=0)return(false);
 double c=d>0?cur+atr*ext:cur-atr*ext;
 if(structural>0){if(d>0)c=MathMax(c,structural);else c=MathMin(c,structural);}
 if(!AP52_ExtendTP(d,oldTP,c,point))return(false);
 double refRisk=MathAbs(cur-currentSL);
 if(refRisk<=point)return(false);
 double reward=MathAbs(c-cur);
 if(reward < refRisk*minRR)return(false);
 outTP=c;return(true);
}
#endif
//+------------------------------------------------------------------+
