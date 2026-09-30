# Risk model

The research default is 0.25% per proposed trade, configurable and not a recommendation. Cash risk is `account equity × risk percent / 100`. For a valid entry and stop, the active order planner asks `OrderCalcProfit` for the loss at the broker minimum lot, expressed in account currency:

`raw volume = cash risk / abs(minimum-lot loss) × broker minimum lot`

The normalized volume is then priced again and rejected if estimated loss exceeds budget. `OrderCalcMargin` must return a finite amount within free margin. The execution boundary repeats the margin check. These are estimates: commission, swap, slippage and gaps can increase realized losses. The older tick-value `CalculateVolume` helper remains available and tested, but is not used for active order planning.

Volume is capped at the broker maximum before rounding down on the grid anchored at minimum volume. This avoids returning an off-grid maximum. Eight-decimal normalization preserves fractional steps such as 0.25 and 0.125; unsupported finer grids fail closed. Floating-point tolerance is at most 1e-12 lots. It is never rounded upward into added risk. Prices are rounded to the nearest broker tick size and then to broker digits. Invalid point, digits, tick size/value, contract economics, volume grid, distances, equity, trading mode, or normalization produces no trade. No cross-asset lot equivalence is assumed.

Directional stop validation uses Bid for BUY protection and Ask for SELL protection. BUY requires SL below Bid and TP above Bid; SELL is inverse. New orders honor `SYMBOL_TRADE_STOPS_LEVEL`. Modifications honor the larger of stop and freeze levels. Prices not aligned to tick size are blocked before submission.

## Stops and targets

Only the ATR model is implemented in v1. ATR(14) on closed entry bars times ATRMultiplier (default 2.0) determines stop distance. Stops round outward to the broker tick. TP uses actual rounded entry-to-stop distance times RewardRiskRatio (default 2.0), then rounds outward. Selecting swing/fixed stops while the research strategy is enabled blocks initialization. These settings are not validated performance parameters.

## Daily guard

The denominator is account equity captured on the first initialization of this symbol+magic on a broker-server day. Measurement start time and matching-position floating P/L are captured with it. Outside Strategy Tester, all three are persisted as MT5 terminal Global Variables keyed by account, magic, symbol, and day, so chart/EA restarts reuse them. The numerator is only this EA's symbol+magic realized deal profit, commission, swap, and fee since that measurement start plus the change in matching open-position profit/swap from its captured baseline. Subtracting the starting floating value prevents an overnight position's pre-existing P/L from becoming a new-day loss.

`daily loss % = max(0, -owned EA P/L / persisted day-start equity × 100)`

Profit produces zero loss. The exact configured limit blocks new entries, remains latched for that EA instance, and never closes an existing trade. A new broker day creates a new key at the first initialization/tick on that day. If the EA was not running at midnight, measurement begins when it is first initialized rather than reconstructing unknown earlier account state. Manual and other-EA activity is excluded from the numerator.

Positions are counted only when both symbol and magic number match. Manual and other-EA positions are not managed. Default maximum is one.

Deterministic cases are in `Tests/AurumQuantValidation.mq5`: equity/risk/SL variations, invalid and zero economics, below-minimum and above-maximum volume, unusual steps, price alignment, directional/freeze stops, profit/small loss/exact/exceeded daily loss, new day, same-day restart identity, OBSERVE, and LIVE-with-lock-off.

Break-even and trailing are separate, default-off features. Future break-even triggers may use R or distance; trailing may use fixed, ATR, swing, or R methods. If both are later enabled, the approved precedence must only tighten risk, never loosen a stop. Spread, commission, slippage, and minimum stop/freeze distance can make nominal break-even economically negative.

All position modification and close requests use the same execution policy as entries. The position manager starts in OBSERVE with its master lock off, including when initialized through its legacy two-argument interface. Account type is checked at every mutation. These checks are independent of future break-even or trailing feature switches.

Tester baselines remain in memory to avoid contamination between passes. The guard is per symbol/magic and is not an account-wide portfolio limit.
