# Architecture

## Data flow

`Market → MarketData/SymbolProfile → StrategyEngine → Filters → RiskManager/Guards → Decision → TradeManager → PositionManager`

The asset profile selects policy defaults; it never replaces actual broker specifications. `TradeSymbol=""` resolves to the attached chart symbol. A supplied value is selected and queried dynamically.

## Responsibilities

- `Core`: settings/enums, transition logging, broker symbol snapshot, new-bar detection.
- `Strategy`: closed-bar EMA trend plus the documented breakout/retest v1 candidate state machine; pattern/regime/quality helpers remain non-triggering research utilities.
- `Strategy/IStrategy`: plugin boundary. The current BreakoutPullback v1 state machine can later coexist with TrendContinuation, VolatilityBreakout, or MeanReversion without changing risk/execution modules.
- `Strategy/MarketRegime`: inert interface returning `DATA_NOT_READY` or `TRANSITION` until ATR/normalized volatility, slope, ADX-style strength, and compression thresholds are approved.
- `Strategy/SignalQuality`: unweighted evidence container for trend, breakout, pullback, confirmation, volatility, execution quality, and risk quality. It cannot trigger trades.
- `Risk`: broker-aware sizing, per-instance start-of-day loss guard, symbol-plus-magic position counting, cross-symbol stop-risk/exposure limits over a reserved magic range, and a terminal-wide execution mutex for the final cross-chart recheck.
- `Filters`: point-based spread threshold, server-time session window, configurable weekend policy, and MT5 Economic Calendar high-impact currency window.
- `Trading`: the only order boundary. OBSERVE and the master safety lock are enforced here. Position management is scoped to future caller-selected EA tickets.
- `UI`: chart diagnostic dashboard.

`OnTick` refreshes market/filter/guard/dashboard state and is the future home of enabled open-position management. A new current-bar timestamp exposes exactly one newly closed bar identity. The identity must differ from the last evaluated bar; the execution boundary independently refuses a repeated signal-bar identity and marks it consumed before contacting the broker. Therefore a rejection cannot be retried on every tick.

Initialization runs a checklist for symbol economics, timeframes, indicator handles, risk inputs, spread/session/news configuration, mode, freshness threshold, persistent daily baseline, and the OBSERVE assertion. Unsafe failures keep the EA loaded for dashboard diagnosis while every execution gate remains closed.

## Operating modes

- `OBSERVE`: market reading, strategy state, filters, risk readiness, dashboard, and structured logs; order submission is prohibited inside `TradeManager`.
- `DEMO`: can execute only on an MT5 demo account and only when the separate master switch is explicitly enabled.
- `LIVE`: can execute only on a real account and only when the separate master switch is explicitly enabled. It is not to be enabled in this research phase.

`CTrade` calls are synchronous. A true function return is insufficient: accepted results are restricted to `TRADE_RETCODE_DONE`, `DONE_PARTIAL`, or `PLACED`. Request type, symbol, volume, intended entry, SL, TP, call result, retcode, broker price, and description are logged once per request.

## Fail-closed conditions

Initialization or decision flow blocks on invalid point/tick/volume data, disabled symbol trading, invalid configuration, unavailable enabled calendar data, filter rejection, daily limit, or position limit. A configured spread filter requires a positive per-symbol threshold.

## v1.2 candidate path

Closed bar → StrategyEngine (prior channel + closed ATR) → BreakoutPullback → filters/daily/position guards → EntryLimits history → OrderPlanner → PortfolioGuard → PortfolioExecutionLock → final PortfolioGuard recheck → TradeManager.

`OrderPlan` handles broker account-currency loss and margin estimates. `EntryLimits` reads entry-deal history for daily counts and bar cooldown. Candidates are consumed only during the new-bar evaluation and never deferred. A chart must match the configured symbol so tick dispatch follows the traded market. Strategy state resets when evaluation bars are skipped.
