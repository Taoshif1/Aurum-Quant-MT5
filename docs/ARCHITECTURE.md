# Architecture

## Data flow

`Market → MarketData/SymbolProfile → StrategyEngine → Filters → RiskManager/Guards → Decision → TradeManager → PositionManager`

The asset profile selects policy defaults; it never replaces actual broker specifications. `TradeSymbol=""` resolves to the attached chart symbol. A supplied value is selected and queried dynamically.

## Responsibilities

- `Core`: settings/enums, transition logging, broker symbol snapshot, new-bar detection.
- `Strategy`: experimental EMA trend state, pattern research functions, and breakout/pullback state interfaces. No candidate-producing rules exist yet.
- `Risk`: broker-aware volume calculation, start-of-day equity guard, and symbol-plus-magic position counting.
- `Filters`: point-based spread threshold, server-time session window, configurable weekend policy, and MT5 Economic Calendar high-impact currency window.
- `Trading`: the only order boundary. OBSERVE and the master safety lock are enforced here. Position management is scoped to future caller-selected EA tickets.
- `UI`: chart diagnostic dashboard.

`OnTick` refreshes market/filter/guard/dashboard state and is the future home of enabled open-position management. Strategy entry evaluation runs only when `iTime(symbol, EntryTimeframe, 0)` changes, preventing repeated same-bar decisions.

## Operating modes

- `OBSERVE`: market reading, strategy state, filters, risk readiness, dashboard, and structured logs; order submission is prohibited inside `TradeManager`.
- `DEMO`: can execute only on an MT5 demo account and only when the separate master switch is explicitly enabled.
- `LIVE`: can execute only on a real account and only when the separate master switch is explicitly enabled. It is not to be enabled in this research phase.

## Fail-closed conditions

Initialization or decision flow blocks on invalid point/tick/volume data, disabled symbol trading, invalid configuration, unavailable enabled calendar data, filter rejection, daily limit, or position limit. A configured spread filter requires a positive per-symbol threshold.

