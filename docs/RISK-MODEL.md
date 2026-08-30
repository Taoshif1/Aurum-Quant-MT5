# Risk model

The research default is 1% per proposed trade, configurable and not a recommendation. Cash risk is `account equity × risk percent / 100`. For a valid entry and stop:

`ticks to stop = abs(entry - stop) / broker tick size`

`loss per lot = ticks to stop × broker tick value`

`raw volume = cash risk / loss per lot`

Volume is rounded down to broker volume step and checked against broker minimum and maximum. Invalid tick economics, distances, equity, or normalized volume produce no trade. Contract size is logged for diagnosis but no cross-asset lot equivalence is assumed. Broker stop levels are validated separately.

## Stops and targets

The architecture enumerates `SWING`, `ATR`, and `FIXED_DISTANCE`. The preset selects ATR only as an experimental configuration marker; no entry/stop builder is active. ATR defaults (14, 2.0) are not validated. A future R target uses `target distance = initial stop risk distance × RewardRiskRatio`; default 2.0 means 2R and does not imply profitability.

## Daily guard

The initial definition is equity drawdown from a snapshot of account equity at broker-server midnight: `(start-of-day equity - current equity) / start-of-day equity`. This includes realized and unrealized P/L from the whole account, making the guard conservative rather than EA-realized-P/L-only. At 3% it blocks new EA entries and does not close existing trades. Restarting the EA after midnight captures the then-current equity; persistence across restarts is a future design decision.

Positions are counted only when both symbol and magic number match. Manual and other-EA positions are not managed. Default maximum is one.

Break-even and trailing are separate, default-off features. Future break-even triggers may use R or distance; trailing may use fixed, ATR, swing, or R methods. If both are later enabled, the approved precedence must only tighten risk, never loosen a stop. Spread, commission, slippage, and minimum stop/freeze distance can make nominal break-even economically negative.

