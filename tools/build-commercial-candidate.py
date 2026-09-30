"""Build a deterministic Aurum Quant compiled commercial release candidate."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
EA = ROOT / "Experts" / "AurumQuantEA.mq5"
DIST = ROOT / "dist-commercial"
FIXED_ZIP_TIME = (1980, 1, 1, 0, 0, 0)
EX5_NAMES = ("AurumQuantEA.ex5", "AurumQuantValidation.ex5", "AurumQuantBrokerProbe.ex5")
DOCS = (
    Path("README.md"),
    Path("docs/QUICKSTART.md"),
    Path("docs/RISK-MODEL.md"),
    Path("docs/VALIDATION.md"),
    Path("docs/RELEASE-CHECKLIST.md"),
    Path("docs/COMMERCIAL-RELEASE.md"),
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def source_commit() -> str:
    env_sha = os.environ.get("GITHUB_SHA", "").strip()
    if re.fullmatch(r"[0-9a-fA-F]{40}", env_sha):
        return env_sha.lower()
    value = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    require(bool(re.fullmatch(r"[0-9a-fA-F]{40}", value)), "cannot determine current Git commit")
    return value.lower()


def ea_version() -> str:
    text = EA.read_text(encoding="utf-8")
    match = re.search(r'^#property\s+version\s+"([^"]+)"', text, re.MULTILINE)
    require(match is not None, "EA version property not found")
    version = match.group(1)
    require(bool(re.fullmatch(r"\d+\.\d+", version)), f"unexpected EA version: {version}")
    return version


def verify_native_evidence(evidence: Path) -> dict:
    subprocess.run(
        [sys.executable, str(ROOT / "tools/check-native-evidence.py"), str(evidence)],
        cwd=ROOT,
        check=True,
    )
    manifest_path = evidence / "evidence-manifest.json"
    data = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    require(data.get("compiled_ex5_included") is True, "native evidence does not include EX5")
    require(set(data.get("compiled_ex5_files", [])) == set(EX5_NAMES), "native EX5 list mismatch")
    return data


def find_evidence_file(evidence: Path, suffix: str) -> Path:
    matches = [p for p in evidence.iterdir() if p.is_file() and p.name.endswith(suffix)]
    require(len(matches) == 1, f"expected exactly one evidence file ending {suffix}, found {len(matches)}")
    return matches[0]


def zip_entry(archive: zipfile.ZipFile, name: str, data: bytes) -> None:
    info = zipfile.ZipInfo(name, FIXED_ZIP_TIME)
    info.compress_type = zipfile.ZIP_DEFLATED
    info.create_system = 3
    info.external_attr = 0o100644 << 16
    archive.writestr(info, data, compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)


def build(evidence: Path, output: Path = DIST) -> tuple[Path, Path, Path]:
    evidence = evidence.resolve()
    require(evidence.is_dir(), f"native evidence directory not found: {evidence}")
    native = verify_native_evidence(evidence)
    commit = source_commit()
    require(str(native.get("source_commit", "")).lower() == commit, "native evidence source_commit does not match current source commit")
    version = ea_version()

    package_files: dict[str, bytes] = {}
    package_files["Experts/AurumQuantEA.ex5"] = find_evidence_file(evidence, "AurumQuantEA.ex5").read_bytes()
    package_files["Scripts/AurumQuantValidation.ex5"] = find_evidence_file(evidence, "AurumQuantValidation.ex5").read_bytes()
    package_files["Scripts/AurumQuantBrokerProbe.ex5"] = find_evidence_file(evidence, "AurumQuantBrokerProbe.ex5").read_bytes()
    package_files["Install-AurumQuant.ps1"] = (ROOT / "tools/Install-Commercial.ps1").read_bytes()

    presets = sorted((ROOT / "Presets").glob("*.set"))
    require(len(presets) == 6, f"expected six shipped presets, found {len(presets)}")
    for path in presets:
        package_files[f"Presets/{path.name}"] = path.read_bytes()
    for rel in DOCS:
        path = ROOT / rel
        require(path.is_file(), f"commercial candidate documentation missing: {rel}")
        package_files[rel.as_posix()] = path.read_bytes()

    for name in EX5_NAMES:
        require(any(path.endswith(name) and data for path, data in package_files.items()), f"compiled binary missing: {name}")

    manifest_files = [
        {"path": path, "bytes": len(data), "sha256": sha256_bytes(data)}
        for path, data in sorted(package_files.items())
    ]
    manifest = {
        "schema_version": 1,
        "package_kind": "commercial-release-candidate",
        "product": "Aurum Quant MT5",
        "ea_version": version,
        "source_commit": commit,
        "native_evidence_manifest_sha256": sha256_file(evidence / "evidence-manifest.json"),
        "native_evidence_verified": True,
        "compiled_ex5_included": True,
        "execution_defaults": {"operating_mode": "OBSERVE", "order_submission": False},
        "performance_validation_complete": False,
        "license_enforcement_complete": False,
        "code_signing_complete": False,
        "commercial_ready": False,
        "profitability_claim": False,
        "files": manifest_files,
    }
    manifest_bytes = (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode("utf-8")

    output.mkdir(parents=True, exist_ok=True)
    stem = f"AurumQuant-MT5-commercial-candidate-v{version}"
    zip_path = output / f"{stem}.zip"
    manifest_path = output / f"{stem}.manifest.json"
    checksum_path = output / f"{stem}.sha256"
    manifest_path.write_bytes(manifest_bytes)

    root = f"{stem}/"
    with zipfile.ZipFile(zip_path, "w") as archive:
        for path, data in sorted(package_files.items()):
            zip_entry(archive, root + path, data)
        zip_entry(archive, root + "COMMERCIAL-CANDIDATE-MANIFEST.json", manifest_bytes)

    digest = sha256_file(zip_path)
    checksum_path.write_text(f"{digest}  {zip_path.name}\n", encoding="utf-8")
    return zip_path, manifest_path, checksum_path


def self_test() -> None:
    # The commercial builder cannot truthfully simulate official MetaEditor output.
    # Self-test therefore proves it fails closed when native evidence is absent.
    with tempfile.TemporaryDirectory(prefix="aurum-commercial-gate-") as tmp:
        missing = Path(tmp) / "missing-evidence"
        rejected = False
        try:
            build(missing, Path(tmp) / "out")
        except (RuntimeError, subprocess.CalledProcessError):
            rejected = True
        require(rejected, "commercial candidate builder did not fail closed without native evidence")
    print("PASS: commercial candidate builder fails closed without verified native evidence")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("native_evidence", nargs="?", type=Path)
    parser.add_argument("--output-dir", type=Path, default=DIST)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    if args.native_evidence is None:
        parser.error("native_evidence is required unless --self-test is used")
    paths = build(args.native_evidence, args.output_dir)
    for path in paths:
        print(f"PASS: {path}")


if __name__ == "__main__":
    main()
