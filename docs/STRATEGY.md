# Strategy research specification

The candidate narrative is higher-timeframe trend → breakout → pullback → closed-candle confirmation → entry candidate. It is not a mathematical strategy yet. The current engine only reports `NO_SETUP` or `TREND_READY`; transition interfaces reserve `BREAKOUT_DETECTED`, `WAITING_PULLBACK`, `WAITING_CONFIRMATION`, `BUY_CANDIDATE`, `SELL_CANDIDATE`, and `BLOCKED`.

## Experimental trend method

The research implementation compares the last closed H1 fast EMA with the last closed H1 slow EMA. Defaults are EMA(50) and EMA(200): fast above slow is `BULLISH`, below is `BEARISH`, equality is `NEUTRAL`, and insufficient buffers are `DATA_NOT_READY`. These are experimental defaults, not validated rules.

## Pattern research formulas

Patterns operate on closed `MqlRates` supplied by a future approved confirmation rule.

- Bullish engulfing: prior candle bearish, current bullish, current open ≤ prior close, current close ≥ prior open, and current absolute body ≥ prior absolute body × `min_body_ratio`.
- Bearish engulfing is the exact directional inverse.
- Bullish pin bar: positive range/body; lower wick ≥ body × `wick_body_ratio`; upper wick ≤ full range × `max_opposite_fraction`; bullish close.
- Bearish pin bar is the directional inverse.

Threshold arguments are configurable at the function boundary but are not exposed as active EA inputs until confirmation rules are approved.

## Unanswered decisions — approval required

1. Exact H1 trend definition
2. Exact breakout definition
3. Breakout lookback
4. Breakout buffer
5. Candle close vs wick breakout
6. Pullback definition
7. Pullback tolerance
8. Pullback timeout
9. Engulfing definition
10. Pin-bar ratios
11. Confirmation candle closure requirement
12. SL model
13. ATR period/multiplier if used
14. Initial TP model
15. Break-even rule
16. Trailing rule
17. Maximum trades per day
18. Re-entry rules
19. BTC session policy
20. Gold session policy
21. News policy
22. Weekend BTC policy
23. Friday/market-close policy
24. Broker-specific restrictions

No item above is silently decided by the scaffolding or presets.

## Future modular research

`IAQStrategy` is the common plugin boundary. BreakoutPullback remains the only scaffold; TrendContinuation, VolatilityBreakout, and MeanReversion are named future candidates, not implementations. Market regime states are `TREND_UP`, `TREND_DOWN`, `RANGE`, `HIGH_VOLATILITY`, `LOW_VOLATILITY`, `TRANSITION`, `UNSAFE`, and `DATA_NOT_READY`. Candidate inputs include normalized ATR, trend slope, later-approved ADX-style strength, and compression/expansion.

`AQSignalQuality` stores independent evidence fields without weights. No aggregate score or trading threshold exists. A rule-based baseline must be established before any optional ML work. A later MQL5 ONNX research path may classify regimes or setup-quality probability, with frozen datasets, out-of-sample evaluation, calibration, and fallback behavior; direct price prediction is outside scope without a separate approved case.
