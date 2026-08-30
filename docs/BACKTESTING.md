# Backtesting protocol

No optimization is authorized in this phase.

For each broker symbol, use MT5 Strategy Tester with broker-appropriate history and symbol specification. Prefer **Every tick based on real ticks** where reliable. Verify date coverage, digits, point/tick size and value, contract size, volume constraints, stop/freeze levels, trading sessions, variable spread assumptions, commissions, swaps/financing, leverage effects, and execution model. Save the exact preset, broker/server, terminal build, date range, and data-quality report with any result.

For broker Bitcoin CFDs also check weekend tick coverage, whether the broker actually quotes 24/7, maintenance gaps, synthetic gaps, financing, extreme spread periods, and how the CFD differs from spot or perpetual markets. Never fill missing weekends with an assumed 24/7 series.

Gold tests must use that broker's XAUUSD variant and session/calendar behavior, not copied Forex or BTC assumptions.

When rules are approved, separate research into in-sample training, untouched out-of-sample validation, and forward demo testing. Parameter sweeps create selection bias and overfitting; report the search space and all trials, not only the best curve. Stress test costs, spread, slippage, delayed entries, and nearby parameter values. A historical result is not a profitability guarantee.

## Manual tester workflow

1. Compile in MetaEditor and confirm zero errors.
2. Open Strategy Tester, select AurumQuantEA and the exact broker symbol.
3. Load the matching research preset, keep `OBSERVE`, and choose M15 with real ticks.
4. Select a documented date range and confirm the H1 warm-up history exists.
5. Run Visual mode to verify dashboard, new-bar logs, filters, and no trades.
6. Export the tester report and journal alongside the test metadata.

