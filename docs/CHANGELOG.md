# Changelog

## 1.24 research preview — 2026-09-30

- Add original-R trailing: TrailingValue is multiplied by the persisted original entry-to-SL risk distance.
- Read persisted original risk before attempting to derive it from a stop that may already have moved beyond break-even.
- Add BUY/SELL R-trailing regressions and fail closed when original risk is unavailable.
- Extend the shared deterministic suite to 78 assertions; portable position-management coverage is now 16 assertions.
- Swing trailing remains intentionally unsupported until a swing-window/pivot rule is explicitly specified.

## 1.23 research preview — 2026-09-30

- Add optional break-even by persisted original-R or favorable broker-point distance.
- Add tighten-only fixed-distance and closed-ATR trailing for owned symbol+magic positions.
- Persist original entry-to-SL risk before automated stop changes so R-based break-even remains stable after trailing and terminal/EA restarts.
- Keep all stop mutations behind DEMO/LIVE account-type checks, the master submission lock, fresh symbol data, ownership checks, tick normalization, and broker stop/freeze validation.
- Keep SWING and R trailing blocked rather than silently approximating them.
- Extend the shared deterministic suite to 76 assertions; portable CI now covers 14 position-management policy cases and locked management paths.
- Native MetaEditor compilation and broker/demo modification validation remain pending.

## 1.2.0 research preview — 2026-09-30

- Implement documented closed-candle breakout/retest v1 with symmetric BUY/SELL rules, frozen breakout level, timeout and invalid-data cancellation.
- Add ATR stop/target order plans using broker account-currency loss and margin estimates.
- Add daily entry limits, bar cooldown, pending-order/netting protection and persistent submission identity.
- Add silver, Ethereum, EURUSD and Generic presets; default risk is now 0.25% and all presets retain OBSERVE with order submission off.
- Add on-chart new-entry pause/resume, installer backups, stricter compile-helper artifact checks, preset validation and portable CI.
- Isolate Strategy Tester daily baselines and submission identities from terminal globals.
- Extend shared MQL validation to 52 assertions; portable suite includes 15 strategy assertions and order-planner regressions.
- Native compilation, Windows scripts, MT5 tests and performance evaluation remain pending.

## Safety maintenance — 2026-09-30

- Share execution locks across entry, position modification, and position closing.
- Correct fractional lot-step precision and cap-before-floor volume normalization.
- Reject non-finite numeric inputs, unknown directions, and unsupported normalization precision.
- Extend deterministic MQL assertions from 23 to 37 and add portable production-header regression checks.
- Portable regression checks passed; native MetaEditor compilation and MT5 execution are pending.

## 1.1.0 — 2026-08-30

- Compiled with official MetaEditor build 6140 at zero errors and warnings.
- Hardened symbol economics, price/volume normalization, directional stop/freeze checks, execution locks, duplicate signal identity, broker retcode handling, and EA-owned persistent daily loss accounting.
- Added self-diagnostics, data freshness, explicit news states, tester-statistics, regime/strategy/signal-quality interfaces, deterministic MQL validation harness, compile harness, and Phase 1.1 research protocols.

## 0.1.0 — 2026-08-30

- Established modular multi-asset MT5 research foundation.
- Added OBSERVE/DEMO/LIVE safety gates, dynamic broker symbol validation, new-bar processing, research trend/state engines, risk and daily guards, filters, execution boundary, dashboard, logs, presets, and research documentation.
- Intentionally omitted candidate-producing breakout/pullback entry rules and all optimization.
