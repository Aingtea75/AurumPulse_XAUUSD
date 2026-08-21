//+------------------------------------------------------------------+
//| AurumPulse v6.50 - Execution Decision Engine                     |
//| TEST4: neutral S/R is not a veto; ST-sync drives fresh event     |
//+------------------------------------------------------------------+
#ifndef __AURUMPULSE_V650_EXECUTION_ENGINE_MQH__
#define __AURUMPULSE_V650_EXECUTION_ENGINE_MQH__

enum AP50_ENTRY_ROUTE { AP50_ROUTE_NONE=0, AP50_ROUTE_MARKET=1, AP50_ROUTE_BUY_LIMIT=2, AP50_ROUTE_SELL_LIMIT=3, AP50_ROUTE_BUY_STOP=4, AP50_ROUTE_SELL_STOP=5 };
enum AP50_SETUP_STATE { AP50_SETUP_IDLE=0, AP50_SETUP_CREATED=1, AP50_SETUP_CONFIRMED=2, AP50_SETUP_EXECUTABLE=3, AP50_SETUP_INVALIDATED=4, AP50_SETUP_EXPIRED=5 };
struct AP50_MarketContext { int direction; int freshSTFlip; int haDirection; int espDirection; int structureDirection; int reversalDirection; bool exhaustion; bool supportZone; bool resistanceZone; bool breakoutUp; bool breakoutDown; bool chase; bool sideways; bool riskBlocked; double atr; double bid; double ask; double structurePrice; double invalidationPrice; };
struct AP50_ExecutionPlan { AP50_ENTRY_ROUTE route; AP50_SETUP_STATE state; int direction; int votes; double entry; double sl; double tp; double riskDistance; bool valid; };
#define AP50_MARKET_VOTES 3

bool AP50_DirectionalSetup(const AP50_MarketContext &c,int dir){
 if(c.riskBlocked||c.sideways||c.chase||c.atr<=0.0||dir==0||c.direction!=dir)return(false);
 if(c.haDirection!=dir||c.espDirection!=dir)return(false);
 // S/R is contextual: neutral (0) means no nearby level, not a directional veto.
 if(c.structureDirection!=0&&c.structureDirection!=dir)return(false);
 return(true);
}

AP50_ENTRY_ROUTE AP50_SelectRoute(const AP50_MarketContext &c,int dir,int &votes){
 votes=0;if(!AP50_DirectionalSetup(c,dir))return(AP50_ROUTE_NONE);
 if(c.haDirection==dir)votes++;if(c.espDirection==dir)votes++;if(c.structureDirection==dir)votes++;if(c.freshSTFlip==dir)votes++;
 if(c.exhaustion){
  if(dir<0&&c.resistanceZone&&c.reversalDirection<=0)return(AP50_ROUTE_SELL_LIMIT);
  if(dir>0&&c.supportZone&&c.reversalDirection>=0)return(AP50_ROUTE_BUY_LIMIT);
 }
 if(dir>0&&c.breakoutUp&&c.reversalDirection>0)return(AP50_ROUTE_BUY_STOP);
 if(dir<0&&c.breakoutDown&&c.reversalDirection<0)return(AP50_ROUTE_SELL_STOP);
 // Market entry requires the indicator's actual EA-SYNC event, not a fabricated trend flip.
 if(c.freshSTFlip==dir&&votes>=AP50_MARKET_VOTES)return(AP50_ROUTE_MARKET);
 return(AP50_ROUTE_NONE);
}

bool AP50_ValidEntryPrice(AP50_ENTRY_ROUTE route,double entry,double bid,double ask,double point){
 if(entry<=0.0||point<=0.0)return(false);
 if(route==AP50_ROUTE_BUY_LIMIT)return(entry<ask-point);
 if(route==AP50_ROUTE_SELL_LIMIT)return(entry>bid+point);
 if(route==AP50_ROUTE_BUY_STOP)return(entry>ask+point);
 if(route==AP50_ROUTE_SELL_STOP)return(entry<bid-point);
 return(route==AP50_ROUTE_MARKET);
}

bool AP50_BuildPlan(const AP50_MarketContext &c,int dir,AP50_ExecutionPlan &p){
 p.route=AP50_ROUTE_NONE;p.state=AP50_SETUP_IDLE;p.direction=dir;p.votes=0;p.entry=0;p.sl=0;p.tp=0;p.riskDistance=0;p.valid=false;
 AP50_ENTRY_ROUTE route=AP50_SelectRoute(c,dir,p.votes);if(route==AP50_ROUTE_NONE)return(false);
 double structuralRisk=MathAbs(c.invalidationPrice-c.structurePrice);double risk=MathMax(c.atr*1.50,structuralRisk);if(risk<=0)risk=c.atr*1.50;
 p.route=route;p.state=AP50_SETUP_EXECUTABLE;p.riskDistance=risk;
 if(route==AP50_ROUTE_MARKET)p.entry=dir>0?c.ask:c.bid;
 else if(route==AP50_ROUTE_BUY_LIMIT||route==AP50_ROUTE_SELL_LIMIT)p.entry=c.structurePrice;
 else if(route==AP50_ROUTE_BUY_STOP)p.entry=MathMax(c.ask,c.structurePrice);
 else if(route==AP50_ROUTE_SELL_STOP)p.entry=MathMin(c.bid,c.structurePrice);
 double point=MathMax(MarketInfo(Symbol(),MODE_POINT),0.00000001);if(!AP50_ValidEntryPrice(route,p.entry,c.bid,c.ask,point))return(false);
 p.sl=dir>0?p.entry-risk:p.entry+risk;p.tp=dir>0?p.entry+risk*1.50:p.entry-risk*1.50;p.valid=true;return(true);
}

bool AP50_ImprovesSL(int d,double oldSL,double newSL,double point){double e=MathMax(point,0.00000001);return d>0?newSL>oldSL+e:d<0&&newSL<oldSL-e;}
bool AP50_ExtendTP(int d,double oldTP,double newTP,double point){double e=MathMax(point,0.00000001);return d>0?newTP>oldTP+e:d<0&&newTP<oldTP-e;}
bool AP50_ComputeSmartTrail(int d,double open,double cur,double oldSL,double structural,double atr,double point,double lockATR,double trailATR,double &outSL){outSL=oldSL;if(d==0||atr<=0||point<=0)return(false);double pd=d>0?cur-open:open-cur;if(pd<=atr*lockATR)return(false);double c=d>0?cur-atr*trailATR:cur+atr*trailATR;if(structural>0){if(d>0)c=MathMax(c,structural);else c=MathMin(c,structural);}if(d>0&&c>=cur-point)c=cur-point;if(d<0&&c<=cur+point)c=cur+point;if(!AP50_ImprovesSL(d,oldSL,c,point))return(false);outSL=c;return(true);}
bool AP50_ComputeDynamicTP(int d,double cur,double oldTP,double atr,double structural,bool strong,double point,double ext,double &outTP){outTP=oldTP;if(d==0||atr<=0||point<=0||!strong)return(false);double c=d>0?cur+atr*ext:cur-atr*ext;if(structural>0){if(d>0)c=MathMax(c,structural);else c=MathMin(c,structural);}if(!AP50_ExtendTP(d,oldTP,c,point))return(false);outTP=c;return(true);}
#endif
//+------------------------------------------------------------------+
