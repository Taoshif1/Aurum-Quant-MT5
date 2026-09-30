"""Independently verify an Aurum Quant native-validation evidence directory."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path
import re
import tempfile

EXPECTED_SELF_TEST = "AURUM|SELF_TEST|RESULT|passed=78|failed=0"
CLEAN_COMPILE = "Result: 0 errors, 0 warnings"
REQUIRED_COMPILE_LOGS = {
    "AurumQuantEA.log",
    "AurumQuantValidation.log",
    "AurumQuantBrokerProbe.log",
}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def verify(directory: Path) -> None:
    root = directory.resolve()
    manifest_path = root / "evidence-manifest.json"
    require(manifest_path.is_file(), "evidence-manifest.json is missing")
    data = json.loads(manifest_path.read_text(encoding="utf-8-sig"))

    require(data.get("schema_version") == 1, "unsupported evidence schema")
    require(data.get("product") == "Aurum Quant MT5", "unexpected product")
    require(data.get("evidence_kind") == "native-validation-evidence", "unexpected evidence kind")
    require(data.get("required_native_self_test") == "passed=78|failed=0", "native self-test target drift")
    require(data.get("compile_result") == "0 errors, 0 warnings", "compile result metadata is not clean")
    commit = str(data.get("source_commit", "")).strip()
    require(bool(re.fullmatch(r"[0-9a-fA-F]{40}", commit)), "source_commit must be a 40-character Git SHA")

    rows = data.get("files")
    require(isinstance(rows, list) and rows, "manifest file list missing or empty")
    seen: set[str] = set()
    copied: list[Path] = []
    for row in rows:
        name = row.get("file")
        require(isinstance(name, str) and name != "", "manifest file name missing")
        rel = Path(name)
        require(not rel.is_absolute() and len(rel.parts) == 1 and ".." not in rel.parts, f"unsafe evidence path: {name}")
        require(name not in seen, f"duplicate evidence file: {name}")
        seen.add(name)
        path = root / name
        require(path.is_file(), f"evidence file missing: {name}")
        require(path.stat().st_size == row.get("bytes"), f"size mismatch: {name}")
        digest = sha256(path)
        require(re.fullmatch(r"[0-9a-f]{64}", digest) is not None, f"invalid computed SHA256: {name}")
        require(digest == str(row.get("sha256", "")).lower(), f"SHA256 mismatch: {name}")
        copied.append(path)

    compile_hits: set[str] = set()
    self_test_found = False
    csv_candidates: list[Path] = []
    for path in copied:
        original = path.name
        for required in REQUIRED_COMPILE_LOGS:
            if original.endswith(required):
                compile_hits.add(required)
                text = path.read_text(encoding="utf-8", errors="replace")
                require(CLEAN_COMPILE in text, f"compile log is not clean: {path.name}")
        if path.suffix.lower() in {".log", ".txt"}:
            text = path.read_text(encoding="utf-8", errors="replace")
            if EXPECTED_SELF_TEST in text:
                self_test_found = True
        if path.suffix.lower() == ".csv" and "BrokerProbe-" in path.name:
            csv_candidates.append(path)

    require(compile_hits == REQUIRED_COMPILE_LOGS, f"required compiler logs missing: {sorted(REQUIRED_COMPILE_LOGS-compile_hits)}")
    require(self_test_found, "native validation 78/0 result not found")
    require(len(csv_candidates) == 1, f"expected exactly one broker-probe CSV, found {len(csv_candidates)}")

    with csv_candidates[0].open("r", encoding="utf-8-sig", newline="") as handle:
        broker_rows = list(csv.DictReader(handle))
    require(broker_rows, "broker probe contains no rows")
    require(all(row.get("status") == "OK" for row in broker_rows), "broker probe contains non-OK rows")
    symbols = [row.get("symbol", "") for row in broker_rows]
    require(all(symbols), "broker probe contains an empty symbol")
    require(symbols == data.get("broker_probe_symbols"), "broker symbol list differs from manifest")

    for key in ("tester_report_included", "tester_journal_included"):
        require(isinstance(data.get(key), bool), f"{key} must be boolean")

    print(
        "PASS: native evidence verified "
        f"commit={commit} files={len(copied)} broker_symbols={len(symbols)}"
    )


def write_fixture(root: Path) -> None:
    files: list[tuple[str, bytes]] = []
    for i, name in enumerate(sorted(REQUIRED_COMPILE_LOGS), start=1):
        files.append((f"{i:02d}-{name}", f"header\n{CLEAN_COMPILE}\n".encode()))
    files.append(("04-validation-journal.log", f"x\n{EXPECTED_SELF_TEST}\n".encode()))
    probe = (
        "captured_gmt,symbol,status,error\n"
        "2026.09.30 10:00:00,XAUUSD,OK,\n"
        "2026.09.30 10:00:00,BTCUSD,OK,\n"
    ).encode()
    files.append(("05-BrokerProbe-test.csv", probe))

    manifest_files = []
    for name, content in files:
        path = root / name
        path.write_bytes(content)
        manifest_files.append(
            {"source": f"fixture/{name}", "file": name, "bytes": len(content), "sha256": sha256(path)}
        )
    manifest = {
        "schema_version": 1,
        "product": "Aurum Quant MT5",
        "evidence_kind": "native-validation-evidence",
        "captured_utc": "2026-09-30T10:00:00Z",
        "source_commit": "a" * 40,
        "terminal_data": "fixture",
        "required_native_self_test": "passed=78|failed=0",
        "compile_result": "0 errors, 0 warnings",
        "broker_probe_symbols": ["XAUUSD", "BTCUSD"],
        "tester_report_included": False,
        "tester_journal_included": False,
        "files": manifest_files,
    }
    (root / "evidence-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def self_test() -> None:
    with tempfile.TemporaryDirectory(prefix="aurum-native-evidence-") as tmp:
        root = Path(tmp)
        write_fixture(root)
        verify(root)
        target = root / "01-AurumQuantBrokerProbe.log"
        target.write_text(target.read_text(encoding="utf-8") + "tamper\n", encoding="utf-8")
        rejected = False
        try:
            verify(root)
        except RuntimeError:
            rejected = True
        require(rejected, "tampered evidence was not rejected")
    print("PASS: native evidence verifier self-test rejected tampering")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("evidence_dir", nargs="?", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    if args.evidence_dir is None:
        parser.error("evidence_dir is required unless --self-test is used")
    verify(args.evidence_dir)


if __name__ == "__main__":
    main()
