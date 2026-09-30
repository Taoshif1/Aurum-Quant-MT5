# Operator guide

## Broker setup

Use desktop MT5 with the broker's own symbol. Gold may be XAUUSD, GOLD, XAUUSDm or another name. Never rename a preset to guess a contract size. Leave TradeSymbol blank and attach to the intended chart; mismatched chart/symbol configuration is blocked. Use the appropriate preset, with a unique magic number per chart instance. Profile names are labels and preset choices, not symbol detectors.

The spread limit is in broker **points**, not dollars or pips. Example: Ask minus Bid divided by SYMBOL_POINT. Observe typical and stressed spreads before setting a cap. The Generic preset deliberately requires a positive cap before the engine can initialize.

Sessions use broker server time. Gold/silver presets use 07:00–20:00; this is a research choice, not an exchange timetable. Missing enabled calendar data blocks new entries. The built-in calendar may be unavailable in the Strategy Tester: explicitly disable it for a calendar-free test and label that test accordingly. Do not describe such results as news-filtered.

## OBSERVE

Load an OBSERVE preset and inspect the on-chart engine, market data, spread and decision fields. Strategy enabled means candidates may appear; it does not mean orders are enabled. CANDIDATE logs record proposed entry, stop, target and volume. If inputs are invalid, correct them and reattach/reinitialize. Indicator data unavailability during bar evaluation cancels the pending setup.

The pause button prevents new entries while the EA stays attached. It does not close trades or cancel broker-held stops. If break-even/trailing are enabled and execution is armed, pause does not disable that existing-position protection. It resets on reinitialization. A candidate blocked during pause is discarded, not queued for resumption.

## Demo and tester activation

After native compilation and self-tests pass, use an MT5 demo account. Set OperatingMode to MODE_DEMO and EnableOrderSubmission to true deliberately. Keep the research strategy enabled. Use a tester configuration associated with a demo account because the account-type policy remains enforced in tester runs. Archive each set of inputs and the real-tick report.

The current implementation exposes a LIVE mode but supplied presets never select or arm it. Native validation and a documented demo history remain outstanding; the research preview is not a live-release certification.

## Multiple assets

Open a separate broker chart for each asset and apply its preset. Unique preset magic numbers are supplied, but copies of the same preset need a different magic. Never run two instances with the same symbol/magic. Use separate terminals/accounts for independent experiments. Existing positions or pending orders on netting symbols block new entries to avoid mixing manual or other-EA exposure.

Daily loss, entry count and cooldown are scoped to symbol/magic. Cross-symbol Aurum instances additionally share the configured portfolio stop-risk and exposure cap through the reserved magic range. This controller limits grouped estimated stop risk, but it does not model asset correlation.

## Troubleshooting

| Status | Action |
|---|---|
| Spread limit must be positive | Set a broker-specific cap and reinitialize. |
| Calendar unavailable | Check broker calendar access; do not silently assume news is clear. |
| Market data stale | Check connection, symbol session and tick activity. |
| Risk budget below minimum lot | The broker minimum exceeds this risk budget; do not force a larger lot. |
| Netting symbol already has a position | Use an isolated symbol/account; the EA will not merge exposure. |
| Entry cooldown/daily count reached | Wait for the specified bars/day; restart will not erase history. |
| Strategy data invalid | Allow history/indicators to load and inspect the Experts log. |
| Break-even/trailing blocked | Check the configured method/value. Break-even supports R or distance. Trailing v1 supports FIXED or ATR only; SWING and R trailing remain unsupported. |

Keep the `AURUM|` entries from the Experts journal when reporting an issue, together with broker symbol properties, terminal build, inputs and the time of the event. Do not share account passwords.
