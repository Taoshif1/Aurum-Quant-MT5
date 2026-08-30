# Research protocol

Research begins with a frozen rule-based baseline and an explicit hypothesis. Data partitions, permissible changes, cost assumptions, metrics, minimum sample size, and rejection criteria must be recorded before evaluation.

Candidate selection must consider expectancy, drawdown, trade count, profit factor, recovery, consecutive losses, stability across chronological folds/regimes, and parameter surfaces. Net profit alone is insufficient. Failed and abandoned variants remain in the experiment ledger.

Robustness work proceeds through development, validation, untouched out-of-sample, walk-forward, Monte Carlo perturbations, demo forward testing, and only then a separately approved small live operational test. There is no authorization for optimization or live trading in Phase 1.1.

Optional ONNX work is deferred until the baseline is stable. If approved later, use official MQL5 ONNX APIs for regime classification or calibrated setup-quality probability, version the feature pipeline/model, prevent data leakage, compare against the rule baseline, test in Strategy Tester, define confidence/fallback behavior, and keep execution/risk gates independent. Direct price prediction requires a separate research case.
