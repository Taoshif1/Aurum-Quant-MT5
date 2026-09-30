# Strategy implementation

The active research baseline is specified in [STRATEGY-V1.md](STRATEGY-V1.md). It replaces the original trend-only scaffold following the owner's request to continue the multi-asset product. Parameters have not been fitted or performance-validated.

`BreakoutPullback` is a pure closed-bar state machine. `StrategyEngine` loads the prior channel and closed ATR and feeds that machine. `OrderPlanner` builds ATR stops and targets and sizes with broker profit/margin calculations. The EA applies entry guards and the isolated trade manager enforces execution locks.

Candlestick helper functions, market-regime labels and signal-quality interfaces remain research utilities. They are not active additional entry rules. No ML, optimizer or exchange API is included. Any change to the frozen baseline needs a documented new research version with separate test results.
