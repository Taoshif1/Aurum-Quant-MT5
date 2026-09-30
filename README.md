# Aurum Quant MT5 · 1.22 research preview

An MQL5 Expert Advisor for broker-provided gold, silver, Bitcoin, Ethereum, forex and other compatible instruments. One chart runs one symbol. Contract sizes, tick values and lot constraints come from the broker.

**Status: source research preview. Native MetaEditor compilation, MT5 integration, and strategy performance validation for this revision are pending. This is not yet a commercially validated trading product.**

## What works in the implementation

- Closed-candle higher-timeframe EMA trend and channel breakout/retest state machine.
- ATR stops, reward/risk targets, and broker-calculated account-currency loss and margin estimates.
- Spread, session, weekend and optional high-impact news filters.
- Per-instance daily loss guard, plus a cross-symbol Aurum portfolio guard that prices open positions and active orders to their stops, caps combined stop risk, and serializes the final risk recheck plus broker submission across charts.
- Duplicate request identity persisted across terminal restarts; no per-tick retries after a rejected candidate.
- On-chart status and pause/resume button for new entries. Existing positions remain unchanged by pause.
- Six OBSERVE presets, source installer with backups, compile helper and portable regression CI.

OBSERVE and a separate submission lock are enforced inside entry and position-mutation boundaries. Presets enable research signals while keeping `OperatingMode=0` and `EnableOrderSubmission=false`. No exchange API, martingale, grid averaging or optimization is implemented. No profitability claim is made.

## Install

1. Download the repository. In desktop MT5 choose **File → Open Data Folder** and copy the folder path.
2. In PowerShell, from this repository, run:

```powershell
.\tools\Install-MQL5.ps1 -TerminalData 'YOUR_MT5_DATA_FOLDER'
.\tools\Compile-MQL5.ps1 -TerminalData 'YOUR_MT5_DATA_FOLDER'
```

The installer backs up existing project files and copies source, includes, the validation script and presets. The compile helper builds repository targets. Compile the installed `AurumQuantEA.mq5` and `AurumQuantValidation.mq5` in MetaEditor as well before using the installed copies. Both require zero errors and warnings.

3. Run **Scripts → AurumQuantValidation**. Require `AURUM|SELF_TEST|RESULT|passed=62|failed=0`.
4. Attach the EA to the exact broker symbol chart, such as `XAUUSDm`, and load `Presets/AurumQuant/XAUUSD-Research.set`. A blank `TradeSymbol` uses that chart's symbol.
5. Calibrate `MaxSpreadPoints` against the exact broker symbol. Preset spread values are placeholders. Generic intentionally starts with zero and blocks until configured.
6. Start in OBSERVE and check diagnostics. Follow [QUICKSTART](docs/QUICKSTART.md) before demo execution.

## Presets

| File | Instrument example | Profile | Session / USD news |
|---|---|---|---|
| XAUUSD-Research.set | Gold | Gold | Enabled / enabled |
| XAGUSD-Research.set | Silver | Silver | Enabled / enabled |
| BTCUSD-Research.set | Bitcoin CFD | Crypto | Disabled / disabled |
| ETHUSD-Research.set | Ethereum CFD | Crypto | Disabled / disabled |
| EURUSD-Research.set | EUR/USD | Forex | Enabled / enabled |
| Generic-Research.set | Other broker instrument | Generic | Disabled / disabled |

All presets use 0.25% nominal risk per proposed trade, a three-entry daily cap and a four-bar cooldown. These are unvalidated research defaults, not recommendations. The presets reserve magic range 26093000–26093099 and share a 1.0% maximum stop-risk budget with a three-position portfolio cap. The daily guard remains per symbol/magic.

## Portable regression checks

```sh
g++ -std=c++17 -Wall -Wextra -Werror -I Tests/portable -I Include Tests/portable/regression.cpp -o /tmp/aurum-regression
/tmp/aurum-regression
python3 tools/check-presets.py
```

Tests execute production headers using test-only API substitutes: 6,000 volume budgets, 24 execution policies, 15 strategy assertions, six portfolio-budget assertions, four execution-lock policy assertions, broker-order-plan cases, and locked mutation paths. They do not validate MQL compiler compatibility, broker fills, or profitability. GitHub Actions runs these logic checks automatically.

See [strategy rules](docs/STRATEGY-V1.md), [risk model](docs/RISK-MODEL.md), [validation](docs/VALIDATION.md), and [release checklist](docs/RELEASE-CHECKLIST.md).
