# Aurum Quant MT5 contributor rules

- Preserve the separation between asset profiles, strategy, risk, filters, and execution.
- Default to `MODE_OBSERVE`; never weaken its no-order guarantee.
- Never hardcode symbol contract assumptions. Use broker-reported symbol properties.
- Treat missing or invalid market/risk data as a fail-closed condition.
- Do not add or tune entry rules without an approved, documented research specification.
- Do not claim profitability. Do not add exchange APIs, ML, web dashboards, or optimizers.
- Keep reusable code under `Include/AurumQuant`; keep the EA entrypoint thin.
- Update documentation and presets whenever an input or formula changes.

