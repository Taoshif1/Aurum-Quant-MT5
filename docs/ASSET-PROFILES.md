# Asset profiles

Profiles are explicit configuration: `CRYPTO`, `GOLD`, `FOREX`, `INDEX`, or `GENERIC`. Symbol strings are not a reliable asset-class classifier and are never used to infer the profile. Profiles describe intended policy defaults—sessions, calendar usage, weekend policy, spread interpretation, and volatility expectations—while all sizing and constraints use the broker-reported symbol specification.

## Broker-provided Bitcoin

An MT5 Bitcoin instrument is broker-defined. It might be named `BTCUSD`, `BTCUSDm`, `BTCUSD.a`, `BTCUSDT`, or something else, but the code assumes none of these and does not represent spot-exchange trading. The BTC preset disables session and news filtering initially, blocks weekend trading until broker hours are verified, and contains an unvalidated spread placeholder.

Before research, obtain from Shawon:

- broker name and account type;
- exact Bitcoin symbol;
- contract size/specification;
- trading hours and weekend availability;
- commission and spread behavior;
- swap/financing;
- minimum lot, maximum lot, and volume step;
- leverage;
- stop-distance and freeze restrictions.

Do not guess them. Compare the MT5 Specification dialog with the EA's `SYMBOL_VALID` initialization log.

The MT5 Economic Calendar is macroeconomic, not a complete crypto-event feed. It cannot protect Bitcoin research from exchange, protocol, regulatory, liquidation, or crypto-industry events.

Spread is displayed exclusively in broker points: `(Ask-Bid)/Point`. It is not labelled dollars or pips. BTC weekend spreads, financing, maintenance gaps, quote pauses, and broker trading hours require direct observation.

## Gold / XAUUSD

Gold uses the same EA and modules. Its preset demonstrates different point-spread limits, a server-time session window, weekday policy, and enabled USD high-impact calendar filtering. Exact symbol suffix, hours, point size, tick economics, commissions, and thresholds must still be validated with the broker. No separate Gold EA exists.

Future Forex, index, Gold, and crypto presets should configure policy without copying core code.

Session windows use `TimeTradeServer()`, support same-hour/all-day and overnight wraparound windows, and do not perform automatic daylight-saving conversion. Presets must be reviewed when the broker changes server offset or DST policy. The BTC preset intentionally has no Forex-session assumption.

## v1.2 preset additions

Silver has its own `PROFILE_SILVER=5` label without changing the existing enum values. XAGUSD, ETHUSD, EURUSD and Generic presets join BTCUSD and XAUUSD. All six contain every input, use distinct magic numbers, and enable candidate research under OBSERVE with submission off. Profile names do not assert broker compatibility; symbol validation and account-currency calculations remain required. See QUICKSTART for suffixes, session time and placeholder spread limits.
