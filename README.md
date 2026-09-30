# Aurum Quant MT5

A research-first, multi-asset MetaTrader 5 Expert Advisor framework written in MQL5. The first research target is a broker-provided Bitcoin instrument; XAUUSD is the secondary profile proving the same engine can support another asset without a separate EA.

This repository is a foundation, not a profitable strategy. It performs no optimization, makes no performance claim, and has no approved breakout/pullback entry mathematics. It does not connect to Binance, Bybit, OKX, or any other crypto exchange.

## Safety status

- Default mode: `OBSERVE`.
- `OBSERVE` cannot submit orders, modify stops, or close positions.
- `EnableOrderSubmission=false` is a separate master lock in every supplied preset.
- Essential broker symbol data and risk inputs fail closed.
- The foundation Strategy Engine reports trend readiness but never produces buy/sell candidates.
- Every request path rechecks operating mode, the master lock, account type, and unique closed-bar identity; LIVE is never enabled by supplied presets.

## Install in MetaTrader 5

1. In MT5 choose **File → Open Data Folder**.
2. Copy `Experts/AurumQuantEA.mq5` to `MQL5/Experts/`.
3. Copy `Include/AurumQuant/` to `MQL5/Include/AurumQuant/`.
4. Copy the `.set` files to `MQL5/Presets/` (or the Strategy Tester preset folder).
5. Open `AurumQuantEA.mq5` in MetaEditor and compile with **F7**.
6. Attach only in `OBSERVE` while validating broker specifications and logs.

## Compile and validation harness

`tools/Compile-MQL5.ps1` stages the installed official MQL5 standard library in ignored `.build/`, overlays the project includes, and compiles both the EA and `Tests/AurumQuantValidation.mq5`. It accepts alternate MetaEditor and terminal-data paths. Success requires the literal compiler result `0 errors, 0 warnings` for both targets.

The shared validation suite contains deterministic synthetic risk, normalization, stop, daily-guard, and execution-lock cases. It runs during EA initialization by default and can also run from `Tests/AurumQuantValidation.mq5`. Require `AURUM|SELF_TEST|RESULT|passed=37|failed=0` in the Experts log. It never calls an order method.

The example spread limits are conspicuous research placeholders, expressed in broker points. Replace them only after observing the exact broker symbol. Leaving a configured spread filter at zero causes initialization to fail.

## Layout

The thin EA entrypoint orchestrates reusable modules under `Include/AurumQuant`: broker market data and symbol specifications, experimental trend and strategy state, risk guards, configurable filters, isolated execution, position management hooks, logging, and dashboard.

See [ARCHITECTURE](docs/ARCHITECTURE.md), [STRATEGY](docs/STRATEGY.md), [ASSET PROFILES](docs/ASSET-PROFILES.md), [RISK MODEL](docs/RISK-MODEL.md), and [BACKTESTING](docs/BACKTESTING.md).

## Portable regression checks

With a C++17 compiler, run from the repository root:

```sh
g++ -std=c++17 -Wall -Wextra -Werror -I Tests/portable -I Include Tests/portable/regression.cpp -o /tmp/aurum-regression
/tmp/aurum-regression
```

These tests execute the production risk, normalization, execution-policy, and position-manager headers against test-only API substitutes. They cover 6,000 volume budgets, 24 mode/lock/account combinations, invalid numeric inputs, and blocked mutation paths. They do **not** replace official MetaEditor compilation or MT5 integration tests.
