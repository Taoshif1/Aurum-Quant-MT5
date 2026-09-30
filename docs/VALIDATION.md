# Engineering validation

## Compilation gate

Use only official MetaEditor. `tools/Compile-MQL5.ps1` stages the installed official standard library under ignored `.build/` and compiles the EA and deterministic test script. Both logs must end in `Result: 0 errors, 0 warnings`.

## Initialization checklist

The EA checks symbol selection/economics, timeframe validity, EMA handles, risk limits, spread threshold, session hours, calendar configuration, operating mode, execution lock assertion, tick freshness limit, and persistent daily baseline. Critical failures set Engine `BLOCKED`, preserve the diagnostic dashboard, and cannot bypass `TradeManager`.

## Safety invariants

1. OBSERVE is rejected inside both order-entry and position-mutation boundaries even if the master switch is requested.
2. LIVE requires LIVE mode, master switch true, and an MT5 real account; supplied presets remain OBSERVE/false.
3. A closed entry bar is evaluated once. The execution boundary consumes a unique signal-bar identity before the broker call, including rejected calls.
4. Invalid symbol economics, stale ticks, unavailable enabled calendar, invalid risk/volume/stops, daily guard, filters, per-symbol limits, or portfolio risk/position limits block submission.
5. Positions, active orders, history orders, and deals are owned only when both symbol and magic match.
6. A `CTrade` call is successful only with an accepted broker retcode.
7. Armed cross-chart candidates serialize the final portfolio snapshot and submission through one account/range lock; a busy lock discards the candidate instead of queueing it; accepted submissions keep the shared gate closed until expiry so trade-state propagation cannot reopen a stale portfolio window.

## Deterministic cases

The shared suite invoked by both EA initialization and `Tests/AurumQuantValidation.mq5` contains 78 assertions covering risk equations and boundaries, normalization, directional/freeze stops, daily loss transitions and restart identity, OBSERVE, and LIVE without the master lock. Compile success proves type/API validity; execution in MT5 must report all passes before the harness is accepted operationally.

## Smoke acceptance

On a broker/demo terminal, attach with OBSERVE and master lock false. Confirm READY or a precise safe diagnostic, dashboard refresh, one `NEW_BAR` record per entry bar, no crashes, no repeated signal identity, and zero orders/deals carrying the EA magic. A lack of broker account/history is a blocked smoke test, not a pass.

## Portable regression coverage

`Tests/portable/regression.cpp` includes unchanged production headers with small test-only MQL API substitutes. It verifies quarter-lot precision, off-grid maximum flooring, volume-budget bounds across six step sizes, NaN/infinity rejection, unknown direction rejection, all 24 combinations of operating mode/master switch/account type, and zero position access or broker calls on locked modification/close/management paths.

Run the C++ command in README. This is a logic regression check, **not** an MQL compilation result. The new MQL suite expects `passed=78|failed=0`; its terminal execution and native compilation remain required.

## v1.24 validation coverage

The shared strategy suite adds 15 assertions for both directions, duplicate timestamps, timeout, wrong-side cancellation, trend change and invalid OHLC/ATR. Six portfolio-budget assertions cover magic grouping, exact-cap behavior, excess risk and position limits. Four lock-policy assertions cover free, exact-expiry, future-held and invalid lock states. Sixteen position-management assertions cover BUY/SELL break-even, original-risk persistence semantics, distance triggers, fixed/ATR trailing, tighten-only precedence and unsupported-method rejection. Portable order-plan cases test successful BUY/SELL plans and rejection for missing profit/margin calculations, insufficient free margin, zero ATR and a budget below minimum lot. Six preset files must match all 48 actual EA input names, have distinct magic numbers, and retain OBSERVE/submission-off locks.

The Linux CI additionally builds and independently verifies the deterministic research source bundle, including exact file membership, SHA-256 values, safe execution metadata and reproducible ZIP bytes. This does not compile MQL. Windows installer and compile-helper execution are pending in this environment, and no v1.24 `.ex5` or official compiler result is supplied.
