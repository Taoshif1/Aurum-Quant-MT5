# Engineering validation

## Compilation gate

Use only official MetaEditor. `tools/Compile-MQL5.ps1` stages the installed official standard library under ignored `.build/` and compiles the EA and deterministic test script. Both logs must end in `Result: 0 errors, 0 warnings`.

## Initialization checklist

The EA checks symbol selection/economics, timeframe validity, EMA handles, risk limits, spread threshold, session hours, calendar configuration, operating mode, execution lock assertion, tick freshness limit, and persistent daily baseline. Critical failures set Engine `BLOCKED`, preserve the diagnostic dashboard, and cannot bypass `TradeManager`.

## Safety invariants

1. OBSERVE is rejected inside the execution boundary even if the master switch is requested.
2. LIVE requires LIVE mode, master switch true, and an MT5 real account; supplied presets remain OBSERVE/false.
3. A closed entry bar is evaluated once. The execution boundary consumes a unique signal-bar identity before the broker call, including rejected calls.
4. Invalid symbol economics, stale ticks, unavailable enabled calendar, invalid risk/volume/stops, daily guard, filters, or position limits block submission.
5. Positions, active orders, history orders, and deals are owned only when both symbol and magic match.
6. A `CTrade` call is successful only with an accepted broker retcode.

## Deterministic cases

The shared suite invoked by both EA initialization and `Tests/AurumQuantValidation.mq5` contains 23 assertions covering risk equations and boundaries, normalization, directional/freeze stops, daily loss transitions and restart identity, OBSERVE, and LIVE without the master lock. Compile success proves type/API validity; execution in MT5 must report all passes before the harness is accepted operationally.

## Smoke acceptance

On a broker/demo terminal, attach with OBSERVE and master lock false. Confirm READY or a precise safe diagnostic, dashboard refresh, one `NEW_BAR` record per entry bar, no crashes, no repeated signal identity, and zero orders/deals carrying the EA magic. A lack of broker account/history is a blocked smoke test, not a pass.
