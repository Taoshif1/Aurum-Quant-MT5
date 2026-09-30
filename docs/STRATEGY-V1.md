# Breakout/retest v1 research specification

The owner authorized continued product implementation on 2026-09-30. This document fixes the baseline rules before implementation. Parameters are engineering defaults, not fitted or performance-validated. Default mode remains OBSERVE and order submission remains off. One EA instance runs on one broker symbol/chart; use different magic numbers per instance.

## Rules

- Entry bars: M15 by default; higher-timeframe trend: last closed H1 EMA(50) versus EMA(200).
- Reference channel: highest high and lowest low of the 20 entry bars preceding the evaluated closed bar. The evaluated bar and forming bar are excluded.
- ATR: last closed entry-timeframe ATR(14). All indicators and OHLC values must be available and valid.
- Bullish breakout: a closed bar crosses from at/below the prior channel high to above that high plus 0.10 ATR. Bearish is inverse at the channel low.
- Freeze the breakout level and ATR at detection. No entry is permitted on the breakout candle.
- Retest: within the next six closed entry bars, a bullish candle's low intersects level ± 0.25 frozen ATR, closes above the level, and closes above its open. Bearish uses high, close below level, and a bearish body. This candle is the confirmation. A close beyond the wrong side of the tolerance cancels the setup.
- Trend becoming neutral/unavailable or changing direction cancels an active setup. A bar cannot both cancel and start a new setup.
- A signal is eligible only on its first evaluation. If spread, session, news, daily loss, position, history, margin, or execution checks fail, discard it. Never queue a stale candidate for later ticks.
- Stop: current entry quote ± 2.0 current closed-bar ATR, rounded outward to the broker tick. Target: 2.0 times actual rounded entry-to-stop distance, rounded outward. Only ATR stops are implemented in v1; selecting inactive alternatives blocks initialization.
- Volume: size from OrderCalcProfit at the broker minimum lot in account currency, round down, then recalculate loss and margin for the chosen lot. Maximum estimated loss is equity × RiskPercent. Commission, swap and gaps are not included in that estimate.
- At most three entry deals per broker day per symbol/magic (partial fills conservatively count separately); at least four entry bars since the last entry deal. History is re-read, so chart restart does not reset these limits.
- Netting accounts: any existing position on the symbol blocks entry. Matching pending orders block new entries. Hedging accounts enforce the configured owned-position maximum.
- Duplicate submission: consume the closed-bar identity before calling the broker, including rejected requests. Persist identity per account/magic/symbol across terminal restarts. Use only one instance for each symbol/magic pair.

## Operational defaults

Gold and silver: weekdays only, broker-server session 07:00–20:00, USD high-impact news filter enabled. Bitcoin/Ethereum: no intraday session filter, weekends disabled unless explicitly enabled, news filter off. Forex: weekdays, USD calendar filter for the EURUSD example. No cross-symbol portfolio scheduler is provided. Independent charts can accumulate risk; per-trade and daily guards are per instance, not portfolio limits.

Break-even and trailing remain unimplemented and default off. Enabling them fails initialization rather than silently pretending they work. There is no Friday automatic liquidation. Broker stops remain responsible for protection while disconnected. Existing positions are never automatically closed merely because a filter blocks new entries.

## Acceptance

Deterministic tests must exercise both directions, no breakout-bar entries, duplicate timestamps, timeout, invalid data, trend change, and cancelled retests. Native MetaEditor compilation and MT5 tester runs with real ticks are mandatory before a release can be labeled commercially ready. Separate in-sample and out-of-sample periods, document spreads/commission/slippage, and keep gold, silver and crypto results separate. No positive expectancy is assumed.
