# Backtesting protocol

No optimization is authorized in this phase. A smoke test is operational validation, not a profitability backtest.

For each broker symbol, use MT5 Strategy Tester with broker-appropriate history and symbol specification. Prefer **Every tick based on real ticks** where reliable. Verify date coverage, digits, point/tick size and value, contract size, volume constraints, stop/freeze levels, trading sessions, variable spread, commission schedule, swap/financing, leverage, slippage assumptions, execution latency sensitivity, and broker execution model. Save the exact preset, broker/server, terminal build, date range, data-quality report, and contract specification with any result.

For broker Bitcoin CFDs also check weekend tick coverage and spread expansion, whether the broker actually quotes 24/7, maintenance and broker gaps, CFD financing, trading-hour differences, extreme spread periods, and how the CFD differs from spot or perpetual markets. Never fill missing weekends with an assumed 24/7 series.

Gold tests must use that broker's XAUUSD variant and session/calendar behavior, not copied Forex or BTC assumptions.

## Tester statistics and custom criterion

`OnTester()` captures net profit, gross profit/loss, profit factor, expected payoff, equity drawdown and relative drawdown, recovery factor, platform Sharpe ratio, trade/win/loss counts, and maximum consecutive losses. It logs them and returns `0.0`: the custom score is intentionally inert until a research criterion is approved. Raw net profit must never be the sole objective.

`tools/parse-tester-stats.py` extracts the final `AURUM|TESTER_STATS|...` record from a tester journal into JSON. It requires the complete metric field set, finite numeric values, non-negative counts/drawdown, and internally consistent win/loss totals. Optional metadata can be supplied as a JSON object via `--metadata-json`. The parser deliberately does not rank, score, or label performance.

A future composite robustness criterion should penalize excessive drawdown, inadequate trade count, poor profit factor, unstable returns, and sharp parameter dependence; it may reward positive expectancy, adequate sample size, consistency across folds/assets/regimes, and reasonable drawdown. No weights or final formula are approved.

## Strict future protocol

A. Development/in-sample: specify hypotheses and allowed parameters before inspection.

B. Validation: select among predeclared candidates without rewriting rules around every failure.

C. Completely untouched out-of-sample: one final estimate, not another development set.

D. Walk-forward: repeat chronologically ordered train/validation windows with fixed procedures.

E. Monte Carlo stress: quantify sequence and cost uncertainty without changing original outcomes.

F. Demo forward test: broker feed, sessions, calendar, and execution behavior with no capital at risk.

G. Small live test: only after explicit approval, operational acceptance criteria, and separate capital/risk authorization.

Using the same observations to invent, select, and finally evaluate rules leaks information and overstates generalization. Every stage must preserve chronological boundaries and record rejected variants.

## Parameter surfaces

Test broad, predeclared ranges and inspect neighborhoods, plateaus, fold-to-fold consistency, and interactions. A robust candidate should not depend on one isolated EMA, ATR, buffer, or timeout value. Report full surfaces and nearby degradation rather than the single best coordinate.

## Monte Carlo architecture

Future simulations should randomize trade order, probabilistically skip trades, perturb spread, perturb adverse/beneficial slippage with broker-plausible distributions, and shift starting dates. Preserve dependencies where possible and report distributions, tail drawdown, failure probability, and sample limitations. No Monte Carlo result exists yet.

## Manual tester workflow

1. Compile in MetaEditor and confirm zero errors.
2. Open Strategy Tester, select AurumQuantEA and the exact broker symbol.
3. Load the matching research preset, keep `OBSERVE`, and choose M15 with real ticks.
4. Select a documented date range and confirm the H1 warm-up history exists.
5. Run Visual mode to verify dashboard, new-bar logs, filters, and no trades.
6. Export the tester report and journal alongside the test metadata.
7. Run `AurumQuantBrokerProbe` for the exact broker symbols used, then call `tools/Collect-Native-Evidence.ps1` with the exported report/journal so hashes and source commit are captured together.
8. Parse the tester journal with `python3 tools/parse-tester-stats.py TESTER_JOURNAL.log --metadata-json RUN_METADATA.json --output tester-summary.json`; keep that JSON beside the original report/journal.

Economic Calendar functions use broker-server time and may be unavailable or behave differently in Strategy Tester/offline agents. An enabled unavailable calendar is a fail-closed condition; test runs must record whether calendar data was actually supplied.
