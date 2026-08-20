//+------------------------------------------------------------------+
//| AurumPulse XAUUSD v6.49 - Integration Test Host                  |
//|                                                                  |
//| Fail-closed host for the isolated v6.49 decision engine.         |
//| The v6.48 baseline on main is intentionally untouched.           |
//+------------------------------------------------------------------+
#property strict
#property version "6.49"

#include "AurumPulse_v6.49_ExecutionEngine.mqh"

input bool InpEnableMarketEntry  = true;
input bool InpEnablePendingOrders = true;
input bool InpEnableSmartTrailing = true;
input bool InpEnableDynamicTP = true;
input int  InpMagic = 64949;
input int  InpSlippage = 30;

AP49_MarketContext g_ctx;
datetime g_lastClosedBar = 0;

bool IsNewClosedBar()
{
   datetime t = iTime(Symbol(), Period(), 1);
   if(t <= 0 || t == g_lastClosedBar) return false;
   g_lastClosedBar = t;
   return true;
}

void BuildHostContext()
{
   ZeroMemory(g_ctx);

   // Only fields that actually exist in AP49_MarketContext are populated.
   // Indicator-specific values are deliberately fail-closed until the
   // v6.48 Smart Core adapter maps the existing indicator cache here.
   g_ctx.direction          = 0;
   g_ctx.freshSTFlip        = 0;
   g_ctx.haDirection        = 0;
   g_ctx.espDirection       = 0;
   g_ctx.structureDirection = 0;
   g_ctx.reversalDirection  = 0;
   g_ctx.exhaustion          = false;
   g_ctx.supportZone        = false;
   g_ctx.resistanceZone     = false;
   g_ctx.breakoutUp         = false;
   g_ctx.breakoutDown       = false;
   g_ctx.chase              = false;
   g_ctx.sideways            = false;
   g_ctx.riskBlocked         = false;

   // Closed-bar ATR only. No custom indicator is called from the tick path.
   g_ctx.atr = iATR(Symbol(), Period(), 14, 1);
   g_ctx.bid = Bid;
   g_ctx.ask = Ask;
   g_ctx.structurePrice = 0.0;
   g_ctx.invalidationPrice = 0.0;
}

int OnInit()
{
   Print("=== AurumPulse v6.49 TEST HOST INIT ===");
   Print("Engine loaded. Context adapter is fail-closed; no broker orders are sent.");
   return(INIT_SUCCEEDED);
}

void OnTick()
{
   // Performance boundary: signal construction is bar-driven, not tick-driven.
   if(!IsNewClosedBar()) return;

   BuildHostContext();

   AP49_ExecutionPlan buyPlan;
   AP49_ExecutionPlan sellPlan;
   ZeroMemory(buyPlan);
   ZeroMemory(sellPlan);

   AP49_BuildPlan(g_ctx, 1, buyPlan);
   AP49_BuildPlan(g_ctx, -1, sellPlan);

   // Intentionally no OrderSend here. This stage verifies the engine contract
   // and compile path before connecting the real v6.48 Smart Core values.
   PrintFormat("[v6.49 TEST] closed=%s ATR=%.2f BUY_ROUTE=%d BUY_VALID=%s SELL_ROUTE=%d SELL_VALID=%s",
               TimeToString(g_lastClosedBar),
               g_ctx.atr,
               buyPlan.route,
               buyPlan.valid ? "true" : "false",
               sellPlan.route,
               sellPlan.valid ? "true" : "false");
}
//+------------------------------------------------------------------+
