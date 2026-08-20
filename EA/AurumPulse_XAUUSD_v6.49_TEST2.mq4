//+------------------------------------------------------------------+
//| AurumPulse XAUUSD v6.49 TEST2                                   |
//| Execution test + live diagnostic dashboard                        |
//| Branch: test/write-access-20260821                               |
//+------------------------------------------------------------------+
#property strict
#property version "6.49"
#include "AurumPulse_v6.49_ExecutionEngine.mqh"

input int MagicNumber=64949;
input double Lots=0.01;
input int SlippagePoints=30;
input bool EnableTrading=true;
input bool EnableMarketEntry=true;
input bool EnablePendingOrders=true;
input bool EnableSmartTrailing=true;
input bool EnableDynamicTP=true;
input double TrailLockATR=1.00;
input double TrailDistanceATR=1.20;
input double TPExtensionATR=2.00;
input int ATRPeriodHost=14;
input double MinTrendScore=55.0;
input int MinESPStrength=45;
input int MaxESPAge=6;
input bool RequireFreshSTForMarket=true;
input bool UseDiagnostics=true;
input bool ShowDashboard=true;

string ST="Supertrend_Promax", HA="HeikenAshi_Custom", ESP="Entry_Signal_Pro", SR="SuperSR_6";
datetime lastBar=0; string lastReason="START"; int lastRoute=0; int lastDir=0; int lastVotes=0; double lastScore=0; double lastESP=0;

bool NewBar(){datetime t=iTime(Symbol(),Period(),0);if(t==0||t==lastBar)return false;lastBar=t;return true;}
double IC(string n,int b,int s){return iCustom(Symbol(),Period(),n,b,s);}
bool V(double x){return(x!=EMPTY_VALUE&&x!=0.0&&x==x);}
int S(double x){return x>0?1:(x<0?-1:0);}

void Dash(string text){
 if(!ShowDashboard)return;
 string p="AP49_";
 if(ObjectFind(0,p+"PANEL")<0){ObjectCreate(0,p+"PANEL",OBJ_RECTANGLE_LABEL,0,0,0);ObjectSetInteger(0,p+"PANEL",OBJPROP_CORNER,CORNER_LEFT_UPPER);ObjectSetInteger(0,p+"PANEL",OBJPROP_XDISTANCE,8);ObjectSetInteger(0,p+"PANEL",OBJPROP_YDISTANCE,18);ObjectSetInteger(0,p+"PANEL",OBJPROP_XSIZE,365);ObjectSetInteger(0,p+"PANEL",OBJPROP_YSIZE,185);ObjectSetInteger(0,p+"PANEL",OBJPROP_BACK,false);}
 string lines[9];
 lines[0]="AurumPulse v6.49 TEST2";
 lines[1]=StringFormat("Trading=%s  Symbol=%s",EnableTrading?"ON":"OFF",Symbol());
 lines[2]=StringFormat("ST=%d  HA=%d  ESP=%d  SR=%d",lastDir,S(IC(HA,6,1)),S(IC(ESP,3,1)),(V(IC(SR,1,1))?1:0));
 lines[3]=StringFormat("ST Score=%.1f  ESP Strength=%.1f",lastScore,lastESP);
 lines[4]=StringFormat("Route=%d  Votes=%d",lastRoute,lastVotes);
 lines[5]="Last decision: "+lastReason;
 lines[6]=StringFormat("Spread=%.1f pts  ATR=%.2f",(Ask-Bid)/MarketInfo(Symbol(),MODE_POINT),iATR(Symbol(),Period(),ATRPeriodHost,1));
 lines[7]="Closed-bar engine / tick-light management";
 lines[8]="TEST2: execution enabled for Strategy Tester";
 for(int i=0;i<9;i++){
   string n=p+"L"+IntegerToString(i);
   if(ObjectFind(0,n)<0){ObjectCreate(0,n,OBJ_LABEL,0,0,0);ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);ObjectSetInteger(0,n,OBJPROP_XDISTANCE,18);ObjectSetInteger(0,n,OBJPROP_YDISTANCE,24+i*18);ObjectSetInteger(0,n,OBJPROP_FONTSIZE,9);}
   ObjectSetString(0,n,OBJPROP_TEXT,lines[i]);
 }
}

void DeleteDash(){for(int i=0;i<9;i++)ObjectDelete(0,"AP49_L"+IntegerToString(i));ObjectDelete(0,"AP49_PANEL");}

int BuildContext(AP49_MarketContext &c){
 ZeroMemory(c);c.bid=Bid;c.ask=Ask;c.atr=iATR(Symbol(),Period(),ATRPeriodHost,1);if(c.atr<=0)return 0;
 double st=IC(ST,4,1),stp=IC(ST,4,2),score=IC(ST,9,1),grade=IC(ST,10,1),chop=IC(ST,11,1);
 double eb=IC(ESP,0,1),es=IC(ESP,1,1),estr=IC(ESP,2,1),edir=IC(ESP,3,1),age=IC(ESP,4,1),veto=IC(ESP,5,1);
 double res=IC(SR,0,1),sup=IC(SR,1,1);
 c.direction=S(st);c.freshSTFlip=(c.direction!=0&&c.direction!=S(stp))?c.direction:0;c.haDirection=S(IC(HA,6,1));c.espDirection=S(edir);
 c.resistanceZone=V(res)&&res>Ask&&(res-Ask)<=c.atr;c.supportZone=V(sup)&&sup<Bid&&(Bid-sup)<=c.atr;
 c.structureDirection=c.supportZone?1:(c.resistanceZone?-1:0);
 c.reversalDirection=0;
 if(V(eb)&&estr>=MinESPStrength&&age<=MaxESPAge&&veto<0.5)c.reversalDirection=1;
 else if(V(es)&&estr>=MinESPStrength&&age<=MaxESPAge&&veto<0.5)c.reversalDirection=-1;
 bool strong=score>=MinTrendScore&&grade>=2&&chop<70;
 c.exhaustion=strong&&((c.direction>0&&(c.resistanceZone||c.reversalDirection<0))||(c.direction<0&&(c.supportZone||c.reversalDirection>0)));
 double cl1=iClose(Symbol(),Period(),1),cl2=iClose(Symbol(),Period(),2);
 c.breakoutUp=V(res)&&cl2<=res&&cl1>res;c.breakoutDown=V(sup)&&cl2>=sup&&cl1<sup;
 if(c.breakoutUp&&!(c.haDirection>0&&c.espDirection>0))c.breakoutUp=false;
 if(c.breakoutDown&&!(c.haDirection<0&&c.espDirection<0))c.breakoutDown=false;
 double gap=1e10;if(V(res)&&res>Ask)gap=MathMin(gap,res-Ask);if(V(sup)&&sup<Bid)gap=MathMin(gap,Bid-sup);
 c.chase=score>=75&&gap>c.atr*1.5;c.sideways=score<MinTrendScore||chop>=70||grade<=0;c.riskBlocked=false;
 if(c.direction>0){c.structurePrice=V(sup)?sup:Bid-c.atr;c.invalidationPrice=c.structurePrice-c.atr*.25;}else{c.structurePrice=V(res)?res:Ask+c.atr;c.invalidationPrice=c.structurePrice+c.atr*.25;}
 lastDir=c.direction;lastScore=score;lastESP=estr;
 if(UseDiagnostics)PrintFormat("[v6.49 TEST2 CTX] ST=%d flip=%d score=%.1f grade=%.0f chop=%.1f HA=%d ESP=%d strength=%.1f age=%.0f SRsup=%d SRres=%d rev=%d chase=%d sideways=%d",c.direction,c.freshSTFlip,score,grade,chop,c.haDirection,c.espDirection,estr,age,c.supportZone,c.resistanceZone,c.reversalDirection,c.chase,c.sideways);
 return c.direction;
}

string Reason(const AP49_MarketContext &c,int dir){
 if(c.riskBlocked)return "RISK_BLOCK";if(c.sideways)return "SIDEWAYS";if(c.chase)return "CHASE_PROTECTION";if(dir==0)return "NO_DIRECTION";
 if(c.haDirection!=dir)return "HA_MISMATCH";if(c.espDirection!=dir)return "ESP_MISMATCH";if(c.structureDirection!=dir)return "STRUCTURE_MISMATCH";
 if(RequireFreshSTForMarket&&c.freshSTFlip!=dir&&!c.exhaustion&&!c.breakoutUp&&!c.breakoutDown)return "WAIT_FRESH_ST_OR_PENDING_SETUP";
 return "ALIGNED_NO_ROUTE";
}

bool HasPos(int d){for(int i=OrdersTotal()-1;i>=0;i--)if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))if(OrderSymbol()==Symbol()&&OrderMagicNumber()==MagicNumber&&((d>0&&OrderType()==OP_BUY)||(d<0&&OrderType()==OP_SELL)))return true;return false;}

bool SendPlan(const AP49_ExecutionPlan &p){
 if(!p.valid){lastReason="PLAN_INVALID";return false;}if(!EnableTrading){lastReason="TRADING_DISABLED";return false;}if(p.route==AP49_ROUTE_MARKET&&!EnableMarketEntry){lastReason="MARKET_DISABLED";return false;}if(p.route!=AP49_ROUTE_MARKET&&!EnablePendingOrders){lastReason="PENDING_DISABLED";return false;}if(HasPos(p.direction)){lastReason="DUPLICATE_POSITION";return false;}
 RefreshRates();double pt=MarketInfo(Symbol(),MODE_POINT);int dg=(int)MarketInfo(Symbol(),MODE_DIGITS);int slv=(int)MarketInfo(Symbol(),MODE_STOPLEVEL);double md=MathMax(pt,slv*pt);int type=-1;double pr=p.entry;
 if(p.route==AP49_ROUTE_MARKET)type=p.direction>0?OP_BUY:OP_SELL;if(p.route==AP49_ROUTE_BUY_LIMIT)type=OP_BUYLIMIT;if(p.route==AP49_ROUTE_SELL_LIMIT)type=OP_SELLLIMIT;if(p.route==AP49_ROUTE_BUY_STOP)type=OP_BUYSTOP;if(p.route==AP49_ROUTE_SELL_STOP)type=OP_SELLSTOP;if(type<0){lastReason="NO_ROUTE";return false;}
 if(type==OP_BUY)pr=Ask;if(type==OP_SELL)pr=Bid;
 if(type==OP_BUYLIMIT&&pr>=Ask-md){lastReason="BUY_LIMIT_DISTANCE";return false;}if(type==OP_SELLLIMIT&&pr<=Bid+md){lastReason="SELL_LIMIT_DISTANCE";return false;}if(type==OP_BUYSTOP&&pr<=Ask+md){lastReason="BUY_STOP_DISTANCE";return false;}if(type==OP_SELLSTOP&&pr>=Bid-md){lastReason="SELL_STOP_DISTANCE";return false;}
 double sl=p.sl,tp=p.tp;if(p.direction>0){sl=MathMin(sl,pr-md);tp=MathMax(tp,pr+md);}else{sl=MathMax(sl,pr+md);tp=MathMin(tp,pr-md);}pr=NormalizeDouble(pr,dg);sl=NormalizeDouble(sl,dg);tp=NormalizeDouble(tp,dg);
 ResetLastError();int tk=OrderSend(Symbol(),type,Lots,pr,SlippagePoints,sl,tp,"AurumPulse v6.49 TEST2",MagicNumber,0,clrNONE);
 if(tk<0){int e=GetLastError();lastReason="ORDERSEND_ERR_"+IntegerToString(e);PrintFormat("[v6.49 TEST2 ORDER ERROR] route=%d err=%d",p.route,e);return false;}
 lastReason="ORDER_SENT";PrintFormat("[v6.49 TEST2 ORDER] ticket=%d route=%d dir=%d entry=%.*f SL=%.*f TP=%.*f",tk,p.route,p.direction,dg,pr,dg,sl,dg,tp);return true;
}

void Manage(){if(!EnableTrading||(!EnableSmartTrailing&&!EnableDynamicTP))return;double atr=iATR(Symbol(),Period(),ATRPeriodHost,1);if(atr<=0)return;double pt=MarketInfo(Symbol(),MODE_POINT);int dg=(int)MarketInfo(Symbol(),MODE_DIGITS);
 for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(OrderSymbol()!=Symbol()||OrderMagicNumber()!=MagicNumber)continue;int ty=OrderType();if(ty!=OP_BUY&&ty!=OP_SELL)continue;int d=ty==OP_BUY?1:-1;double cur=d>0?Bid:Ask;double st=d>0?IC(SR,1,1):IC(SR,0,1),nsl=OrderStopLoss();
  if(EnableSmartTrailing&&AP49_ComputeSmartTrail(d,OrderOpenPrice(),cur,OrderStopLoss(),st,atr,pt,TrailLockATR,TrailDistanceATR,nsl)){nsl=NormalizeDouble(nsl,dg);ResetLastError();if(!OrderModify(OrderTicket(),OrderOpenPrice(),nsl,OrderTakeProfit(),0,clrNONE))PrintFormat("[v6.49 TEST2 TRAIL ERROR] %d",GetLastError());}
  if(EnableDynamicTP&&OrderTakeProfit()>0){double target=d>0?IC(SR,0,1):IC(SR,1,1);bool strong=IC(ST,10,1)>=2&&IC(ST,9,1)>=MinTrendScore&&IC(ST,11,1)<70;double ntp=OrderTakeProfit();if(AP49_ComputeDynamicTP(d,cur,OrderTakeProfit(),atr,target,strong,pt,TPExtensionATR,ntp)){ntp=NormalizeDouble(ntp,dg);ResetLastError();if(!OrderModify(OrderTicket(),OrderOpenPrice(),OrderStopLoss(),ntp,0,clrNONE))PrintFormat("[v6.49 TEST2 TP ERROR] %d",GetLastError());}}
 }
}

int OnInit(){Print("=== AurumPulse v6.49 TEST2 ===");Print("Execution enabled for Strategy Tester; use demo/test only.");Dash("INIT");return INIT_SUCCEEDED;}
void OnDeinit(const int reason){DeleteDash();}
void OnTick(){Manage();if(!NewBar()){if(ShowDashboard)Dash(lastReason);return;}AP49_MarketContext c;if(BuildContext(c)==0){lastReason="NO_CONTEXT";Dash(lastReason);return;}AP49_ExecutionPlan p;ZeroMemory(p);if(AP49_BuildPlan(c,c.direction,p)){lastRoute=p.route;lastVotes=p.votes;if(UseDiagnostics)PrintFormat("[v6.49 TEST2 PLAN] route=%d state=%d dir=%d votes=%d entry=%.2f SL=%.2f TP=%.2f valid=%d",p.route,p.state,p.direction,p.votes,p.entry,p.sl,p.tp,p.valid);SendPlan(p);}else{lastRoute=0;lastVotes=0;lastReason=Reason(c,c.direction);PrintFormat("[v6.49 TEST2 NO TRADE] %s",lastReason);}Dash(lastReason);}
//+------------------------------------------------------------------+
