//+------------------------------------------------------------------+
//| AurumPulse XAUUSD v6.49 - Integration Test Host                  |
//|                                                                  |
//| Purpose: controlled host for the v6.49 execution engine.         |
//| This file is intentionally a test-stage scaffold.               |
//| It does NOT replace the v6.48 baseline on main.                  |
//+------------------------------------------------------------------+
#property strict
#property version "6.49"

#include "AurumPulse_v6.49_ExecutionEngine.mqh"

input bool InpEnableMarketEntry = true;
input bool InpEnablePendingOrders = true;
input bool InpEnableSmartTrailing = true;
input bool InpEnableDynamicTP = true;
input int  InpMagic = 64949;
input int  InpSlippage = 30;

// Integration boundary: indicator values are supplied by the host EA.
// The current scaffold deliberately does not call custom indicators on
// every tick. The real adapter must populate this context once per bar.
AP49_MarketContext g_ctx;
datetime g_lastBar = 0;

bool IsNewBar()
{
   datetime t = iTime(Symbol(), Period(), 0);
   if(t == 0 || t == g_lastBar) return false;
   g_lastBar = t;
   return true;
}

void BuildHostContext()
{
   // Conservative defaults until the existing v6.48 indicator cache is
   // mapped field-by-field. This prevents accidental live execution from
   // fabricated signals during the integration stage.
   ZeroMemory(g_ctx);
   g_ctx.bid = Bid;
   g_ctx.ask = Ask;
   g_ctx.atr = iATR(Symbol(), Period(), 14, 1);
   g_ctx.barClosed = IsNewBar();
   g_ctx.marketReady = (g_ctx.atr > 0.0);
   g_ctx.trendAligned = false;
   g_ctx.momentumFresh = false;
   g_ctx.exhaustion = false;
   g_ctx.reversalConfirmed = false;
   g_ctx.breakoutConfirmed = false;
}

int OnInit()
{
   Print("=== AurumPulse v6.49 TEST HOST INIT ===");
   Print("Execution engine loaded; live signal mapping remains fail-closed.");
   return(INIT_SUCCEEDED);
}

void OnTick()
{
   // Fast path: do not recalculate the signal stack on every tick.
   // Position protection can be inserted here later, provided it performs
   // only necessary intrabar work and never redraws indicator panels.
   if(!IsNewBar()) return;

   BuildHostContext();

   AP49_ExecutionPlan buyPlan;
   AP49_ExecutionPlan sellPlan;
   ZeroMemory(buyPlan);
   ZeroMemory(sellPlan);

   AP49_BuildPlan(g_ctx, true,  buyPlan);
   AP49_BuildPlan(g_ctx, false, sellPlan);

   // Fail-closed test stage: no broker order is sent from this scaffold.
   PrintFormat("[v6.49 TEST] bar=%s ATR=%.2f BUY=%d SELL=%d", TimeToString(g_lastBar), g_ctx.atr, buyPlan.route, sellPlan.route);
}
//+------------------------------------------------------------------+
