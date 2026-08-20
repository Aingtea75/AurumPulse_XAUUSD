# AurumPulse XAUUSD MT4 EA

Development repository for the AurumPulse XAUUSD Expert Advisor (MT4).

## Current Baseline

- EA baseline: v6.48 EXECUTION RECOVERY
- Symbol: XAUUSD.m
- Timeframe tested: H1
- Test period: 1 month
- Initial deposit: 1000
- Spread: 10
- Total trades: 13
- Net profit: -587.36
- Profit factor: 0.46
- Maximal drawdown: 65.43%

## Development Objectives

1. Improve entry timing and trend detection.
2. Reduce entries during sideways/choppy conditions.
3. Implement intelligent pending-order logic:
   - Buy Limit
   - Sell Limit
   - Buy Stop
   - Sell Stop
4. Improve market-entry precision.
5. Implement adaptive Smart Trailing Stop.
6. Implement dynamic TP management.
7. Prevent unnecessary tick-by-tick heavy processing.
8. Preserve indicator-panel stability and responsiveness.
9. Maintain reproducible backtesting and diagnostic evidence.

## Important Rule

v6.48 remains an evidence baseline.

Do not modify the baseline merely to improve its historical test result.
Future changes must be developed as a new version and compared against the baseline.
