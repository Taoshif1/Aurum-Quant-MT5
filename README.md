# Aurum Quant MT5 · 1.24 research preview

An MQL5 Expert Advisor for broker-provided gold, silver, Bitcoin, Ethereum, forex and other compatible instruments. One chart runs one symbol. Contract sizes, tick values and lot constraints come from the broker.

**Status: source research preview. Native MetaEditor compilation, MT5 integration, and strategy performance validation for this revision are pending. This is not yet a commercially validated trading product.**

## What works in the implementation

- Closed-candle higher-timeframe EMA trend and channel breakout/retest state machine.
- ATR stops, reward/risk targets, and broker-calculated account-currency loss and margin estimates.
- Spread, session, weekend and optional high-impact news filters.
- Per-instance daily loss guard, plus a cross-symbol Aurum portfolio guard that prices open positions and active orders to their stops, caps combined stop risk, and serializes the final risk recheck plus broker submission across charts and retains the shared gate after accepted requests until its expiry.
- Duplicate request identity persisted across terminal restarts; no per-tick retries after a rejected candidate.
- Optional break-even management by original R or fixed distance, plus fixed-distance, closed-ATR, or original-R trailing. Stop changes only tighten owned positions and still pass the same execution and broker stop/freeze gates.
- On-chart status and pause/resume button for new entries. Entry pause does not disable already-enabled position protection.
- Six OBSERVE presets, source installer with backups, compile helper, portable regression CI, and a deterministic checksummed source-release bundle.

OBSERVE and a separate submission lock are enforced inside entry and position-mutation boundaries. Presets enable research signals while keeping `OperatingMode=0` and `EnableOrderSubmission=false`. No exchange API, martingale, grid averaging or optimization is implemented. No profitability claim is made.

## Install

1. Download the repository. In desktop MT5 choose **File → Open Data Folder** and copy the folder path.
2. In PowerShell, from this repository, run:

```powershell
.\tools\Install-MQL5.ps1 -TerminalData 'YOUR_MT5_DATA_FOLDER'
.\tools\Compile-MQL5.ps1 -TerminalData 'YOUR_MT5_DATA_FOLDER'
```

The installer backs up existing project files and copies source, includes, the validation script, broker probe, and presets. The compile helper builds the EA plus both native scripts. All three compile logs must report zero errors and warnings.

3. Run **Scripts → AurumQuantValidation**. Require `AURUM|SELF_TEST|RESULT|passed=78|failed=0`.
4. Attach the EA to the exact broker symbol chart, such as `XAUUSDm`, and load `Presets/AurumQuant/XAUUSD-Research.set`. A blank `TradeSymbol` uses that chart's symbol.
5. Calibrate `MaxSpreadPoints` against the exact broker symbol. Preset spread values are placeholders. Generic intentionally starts with zero and blocks until configured.
6. Start in OBSERVE and check diagnostics. Follow [QUICKSTART](docs/QUICKSTART.md) before demo execution.
7. Run **Scripts → AurumQuantBrokerProbe** with the exact broker symbols you plan to validate. Then use `tools/Collect-Native-Evidence.ps1` to collect clean compiler logs, the 78/0 validation journal, the probe CSV, and optional tester artifacts into one checksummed evidence folder. Verify that folder independently with `python3 tools/check-native-evidence.py PATH_TO_EVIDENCE_FOLDER`.
8. For Strategy Tester journals, convert the structured `AURUM|TESTER_STATS|...` record into strict JSON with `python3 tools/parse-tester-stats.py TESTER_JOURNAL.log --output tester-summary.json`. The parser reports raw metrics only and does not assign a performance verdict.

## Presets

| File | Instrument example | Profile | Session / USD news |
|---|---|---|---|
| XAUUSD-Research.set | Gold | Gold | Enabled / enabled |
| XAGUSD-Research.set | Silver | Silver | Enabled / enabled |
| BTCUSD-Research.set | Bitcoin CFD | Crypto | Disabled / disabled |
| ETHUSD-Research.set | Ethereum CFD | Crypto | Disabled / disabled |
| EURUSD-Research.set | EUR/USD | Forex | Enabled / enabled |
| Generic-Research.set | Other broker instrument | Generic | Disabled / disabled |

All presets use 0.25% nominal risk per proposed trade, a three-entry daily cap and a four-bar cooldown. These are unvalidated research defaults, not recommendations. The presets reserve magic range 26093000–26093099 and share a 1.0% maximum stop-risk budget with a three-exposure portfolio cap. The daily guard remains per symbol/magic.

## Research source bundle

Build and independently verify the deterministic source handoff with:

```sh
python3 tools/check-presets.py
python3 tools/build-source-release.py
python3 tools/check-source-release.py
```

Outputs go to ignored `dist/`: a versioned source ZIP, JSON manifest, and ZIP SHA-256 file. GitHub Actions rebuilds the ZIP twice, requires byte-identical output, verifies the manifest and hashes, then uploads the research source bundle as a 14-day run artifact. This is **source packaging only**. It is not an EX5 build, signed installer, broker certification, or profitability evidence. See [source release packaging](docs/SOURCE-RELEASE.md).

## Commercial release candidate gate

After official MetaEditor compilation and native evidence collection, `tools/Collect-Native-Evidence.ps1` also binds the exact three compiled EX5 files into the verified evidence bundle. A compiled candidate can then be built only from evidence whose `source_commit` matches the current checkout:

```sh
python3 tools/check-native-evidence.py PATH_TO_NATIVE_EVIDENCE
python3 tools/build-commercial-candidate.py PATH_TO_NATIVE_EVIDENCE
python3 tools/check-commercial-candidate.py
```

The candidate ZIP contains compiled EX5 files, six locked presets, operator docs, and a compiled-package installer. Its manifest intentionally keeps `commercial_ready=false`, `performance_validation_complete=false`, `license_enforcement_complete=false`, and `code_signing_complete=false` until those separate gates exist. See [commercial release process](docs/COMMERCIAL-RELEASE.md).

## Privacy-safe support bundle

For customer troubleshooting, `tools/Collect-Support-Bundle.ps1` creates a local ZIP containing a sanitized broker probe, only Aurum-specific log lines, and an optional redacted preset. Raw MT5 account login IDs, local terminal paths, emails in retained logs, and secret-like preset values are excluded or redacted by default. Nothing is uploaded automatically.

Verify before sharing:

```sh
python3 tools/check-support-bundle.py support/support-YYYYMMDD-HHMMSS
```

See [support diagnostics and privacy](docs/SUPPORT.md).

## Portable regression checks

```sh
g++ -std=c++17 -Wall -Wextra -Werror -I Tests/portable -I Include Tests/portable/regression.cpp -o /tmp/aurum-regression
/tmp/aurum-regression
python3 tools/check-presets.py
```

Tests execute production headers using test-only API substitutes: 6,000 volume budgets, 24 execution policies, 15 strategy assertions, six portfolio-budget assertions, four execution-lock policy assertions, 16 position-management assertions, broker-order-plan cases, and locked mutation paths. They do not validate MQL compiler compatibility, broker fills, or profitability. GitHub Actions runs these logic checks automatically.

See [strategy rules](docs/STRATEGY-V1.md), [risk model](docs/RISK-MODEL.md), [validation](docs/VALIDATION.md), and [release checklist](docs/RELEASE-CHECKLIST.md).
