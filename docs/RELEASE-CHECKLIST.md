# Release evidence and remaining work

A price target is not a quality metric. This source preview must not be marketed as proven profitable or as a completed commercial MT5 release.

| Gate | Current evidence |
|---|---|
| Volume normalization and mode policy | Portable production-header tests passed: 6,000 budgets and 24 policy combinations |
| Strategy state transitions | 15 shared assertions passed in portable harness |
| Broker loss/margin order plan | Deterministic stub-based success and failure cases passed |
| Presets | Six files match all 48 EA inputs, share one reserved portfolio magic range, and retain OBSERVE/submission-off |
| Portfolio risk guard | Implemented source-side: combined SL risk and exposure count include grouped open positions and active orders; missing-SL exposures fail closed |
| Cross-chart execution serialization | Implemented source-side with an atomic terminal Global Variable mutex and final risk recheck before synchronous submission; native multi-chart stress testing pending |
| Official MetaEditor compilation | Pending for v1.2; require zero errors and warnings for EA and validation script |
| Native self-test | Pending; require passed=62 and failed=0 |
| Windows install/compile tools | Written; execution on Windows pending |
| Broker integration | Pending for each intended broker and account mode |
| Historical real-tick testing | Pending; no performance data claimed |
| Out-of-sample and demo forward tests | Pending |
| Compiled EX5 distribution | Not produced in this environment |

## Native validation matrix

For each target broker, record symbol name/suffix, account currency, contract size, tick size/value, min/max/step lot, stop/freeze levels and execution mode. Test gold, silver and Bitcoin separately. Additional EURUSD/Ethereum presets require their own evidence.

Test locked OBSERVE even with the master switch requested; demo-account mismatch; minimum-lot rejection; excessive spread; disabled algorithmic trading; unavailable news/history; netting conflict; cooldown/daily cap; rejected requests; reconnect/history gaps; terminal restart and duplicate signal identity. Confirm stop and target were actually attached to each filled demo position. Check manual/other-EA exposure is not altered.

Use real ticks where available, realistic costs, held-out dates and multiple market regimes. Record net result, drawdown, trade count and cost assumptions. Do not infer expected performance from passing logic tests.

## Explicitly unfinished product capabilities

Break-even/trailing automation, licensing, signed installers and storefront delivery are not implemented. Their inputs/features are not represented as working. Invalid attempts to enable the existing break-even/trailing placeholders block initialization. Production support requires broker reports and a native test environment.
