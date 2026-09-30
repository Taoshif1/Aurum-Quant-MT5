"""Parse Aurum Quant Strategy Tester statistics from an MT5 journal."""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import tempfile

MARKER = "AURUM|TESTER_STATS|"
FLOAT_KEYS = (
    "net",
    "gross_profit",
    "gross_loss",
    "pf",
    "expected",
    "equity_dd",
    "equity_dd_pct",
    "recovery",
    "sharpe",
)
INT_KEYS = ("trades", "wins", "losses", "max_consecutive_losses")
REQUIRED = set(FLOAT_KEYS + INT_KEYS)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def parse_record(line: str) -> dict:
    pos = line.find(MARKER)
    require(pos >= 0, "tester statistics marker missing")
    payload = line[pos + len(MARKER) :].strip()
    values: dict[str, str] = {}
    for part in payload.split("|"):
        require("=" in part, f"malformed tester field: {part!r}")
        key, value = part.split("=", 1)
        require(key and key not in values, f"duplicate/empty tester field: {key!r}")
        values[key] = value
    require(set(values) == REQUIRED, f"tester fields mismatch: missing={sorted(REQUIRED-set(values))}, extra={sorted(set(values)-REQUIRED)}")

    metrics: dict[str, float | int] = {}
    for key in FLOAT_KEYS:
        value = float(values[key])
        require(math.isfinite(value), f"non-finite tester metric: {key}")
        metrics[key] = value
    for key in INT_KEYS:
        raw = values[key]
        require(raw.lstrip("-").isdigit(), f"non-integer tester metric: {key}")
        value = int(raw)
        require(value >= 0, f"negative tester metric: {key}")
        metrics[key] = value

    require(metrics["wins"] + metrics["losses"] <= metrics["trades"], "wins + losses exceeds total trades")
    require(metrics["max_consecutive_losses"] <= metrics["losses"] or metrics["losses"] == 0, "max consecutive losses exceeds losses")
    require(metrics["equity_dd"] >= 0 and metrics["equity_dd_pct"] >= 0, "drawdown metrics must be non-negative")
    return metrics


def parse_journal(path: Path) -> tuple[list[dict], dict]:
    require(path.is_file(), f"journal not found: {path}")
    records = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if MARKER in line:
            records.append(parse_record(line))
    require(records, "no AURUM|TESTER_STATS record found")
    return records, records[-1]


def build_summary(path: Path, metadata: dict | None = None) -> dict:
    records, final = parse_journal(path)
    return {
        "schema_version": 1,
        "product": "Aurum Quant MT5",
        "evidence_kind": "strategy-tester-metrics",
        "source_journal": path.name,
        "records_found": len(records),
        "selection": "last_record",
        "metadata": metadata or {},
        "metrics": final,
    }


def load_metadata(path: Path | None) -> dict:
    if path is None:
        return {}
    require(path.is_file(), f"metadata JSON not found: {path}")
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    require(isinstance(data, dict), "metadata JSON must be an object")
    return data


def self_test() -> None:
    valid = (
        "2026.09.30 log AURUM|TESTER_STATS|"
        "net=125.50|gross_profit=300.00|gross_loss=-174.50|pf=1.7192|expected=2.5100|"
        "equity_dd=80.25|equity_dd_pct=4.12|recovery=1.5639|sharpe=0.8123|"
        "trades=50|wins=24|losses=20|max_consecutive_losses=4\n"
    )
    with tempfile.TemporaryDirectory(prefix="aurum-tester-stats-") as tmp:
        root = Path(tmp)
        journal = root / "tester.log"
        journal.write_text(valid, encoding="utf-8")
        summary = build_summary(journal, {"symbol": "XAUUSD", "stage": "fixture"})
        require(summary["records_found"] == 1, "valid fixture record count")
        require(summary["metrics"]["trades"] == 50, "valid fixture trades")
        require(abs(summary["metrics"]["pf"] - 1.7192) < 1e-12, "valid fixture profit factor")

        journal.write_text(valid.replace("pf=1.7192", "pf=nan"), encoding="utf-8")
        rejected = False
        try:
            build_summary(journal)
        except RuntimeError:
            rejected = True
        require(rejected, "non-finite metric was not rejected")

        journal.write_text(valid.replace("wins=24|losses=20", "wins=40|losses=20"), encoding="utf-8")
        rejected = False
        try:
            build_summary(journal)
        except RuntimeError:
            rejected = True
        require(rejected, "inconsistent trade counts were not rejected")
    print("PASS: Strategy Tester stats parser self-test")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("journal", nargs="?", type=Path)
    parser.add_argument("--metadata-json", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return
    if args.journal is None:
        parser.error("journal is required unless --self-test is used")

    summary = build_summary(args.journal, load_metadata(args.metadata_json))
    encoded = json.dumps(summary, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded, encoding="utf-8")
        print(f"PASS: tester metrics written to {args.output}")
    else:
        print(encoded, end="")


if __name__ == "__main__":
    main()
