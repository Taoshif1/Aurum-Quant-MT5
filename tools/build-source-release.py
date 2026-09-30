"""Build a deterministic, research-only Aurum Quant source distribution."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / "dist"
EA = ROOT / "Experts" / "AurumQuantEA.mq5"

EXACT_FILES = (
    Path("README.md"),
    Path("Experts/AurumQuantEA.mq5"),
    Path("Tests/AurumQuantValidation.mq5"),
    Path("Tests/AurumQuantBrokerProbe.mq5"),
    Path("tools/Compile-MQL5.ps1"),
    Path("tools/Install-MQL5.ps1"),
    Path("tools/Collect-Native-Evidence.ps1"),
    Path("tools/check-presets.py"),
    Path("tools/build-source-release.py"),
    Path("tools/check-source-release.py"),
    Path("tools/check-native-evidence.py"),
    Path("tools/parse-tester-stats.py"),
    Path("tools/release-audit.py"),
)
GLOBS = (
    "Include/AurumQuant/**/*.mqh",
    "Presets/*.set",
    "docs/*.md",
)
FORBIDDEN_SUFFIXES = {".ex5", ".env", ".key", ".pfx", ".p12"}
FIXED_ZIP_TIME = (1980, 1, 1, 0, 0, 0)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def source_commit() -> str:
    env_sha = os.environ.get("GITHUB_SHA", "").strip()
    if re.fullmatch(r"[0-9a-fA-F]{40}", env_sha):
        return env_sha.lower()
    try:
        value = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True, stderr=subprocess.DEVNULL
        ).strip()
        if re.fullmatch(r"[0-9a-fA-F]{40}", value):
            return value.lower()
    except (OSError, subprocess.SubprocessError):
        pass
    return "unknown"


def ea_version() -> str:
    text = EA.read_text(encoding="utf-8")
    match = re.search(r'^#property\s+version\s+"([^"]+)"', text, re.MULTILINE)
    if not match:
        raise RuntimeError("EA version property not found")
    version = match.group(1)
    if not re.fullmatch(r"\d+\.\d+", version):
        raise RuntimeError(f"unexpected EA version: {version}")
    return version


def distribution_files() -> list[Path]:
    paths = set(EXACT_FILES)
    for pattern in GLOBS:
        paths.update(p.relative_to(ROOT) for p in ROOT.glob(pattern) if p.is_file())

    missing = [str(path) for path in EXACT_FILES if not (ROOT / path).is_file()]
    if missing:
        raise RuntimeError(f"required distribution files missing: {missing}")

    result = sorted(paths, key=lambda p: p.as_posix())
    if not result:
        raise RuntimeError("distribution file list is empty")

    for rel in result:
        if rel.is_absolute() or ".." in rel.parts:
            raise RuntimeError(f"unsafe distribution path: {rel}")
        if rel.suffix.lower() in FORBIDDEN_SUFFIXES:
            raise RuntimeError(f"forbidden file in source package: {rel}")
        if any(part.startswith(".") for part in rel.parts):
            raise RuntimeError(f"hidden path must not enter source package: {rel}")
    return result


def manifest(version: str, commit: str, paths: list[Path]) -> dict:
    files = []
    for rel in paths:
        data = (ROOT / rel).read_bytes()
        files.append(
            {
                "path": rel.as_posix(),
                "bytes": len(data),
                "sha256": sha256_bytes(data),
            }
        )
    return {
        "schema_version": 1,
        "package_kind": "source-research-preview",
        "product": "Aurum Quant MT5",
        "ea_version": version,
        "source_commit": commit,
        "execution_defaults": {
            "operating_mode": "OBSERVE",
            "order_submission": False,
        },
        "native_mt5_compilation_included": False,
        "compiled_ex5_included": False,
        "profitability_claim": False,
        "files": files,
    }


def zip_entry(archive: zipfile.ZipFile, name: str, data: bytes) -> None:
    info = zipfile.ZipInfo(name, FIXED_ZIP_TIME)
    info.compress_type = zipfile.ZIP_DEFLATED
    info.create_system = 3
    info.external_attr = 0o100644 << 16
    archive.writestr(info, data, compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)


def build() -> tuple[Path, Path, Path]:
    version = ea_version()
    commit = source_commit()
    paths = distribution_files()
    data = manifest(version, commit, paths)

    DIST.mkdir(exist_ok=True)
    stem = f"AurumQuant-MT5-source-v{version}"
    zip_path = DIST / f"{stem}.zip"
    manifest_path = DIST / f"{stem}.manifest.json"
    checksum_path = DIST / f"{stem}.sha256"

    manifest_bytes = (json.dumps(data, indent=2, sort_keys=True) + "\n").encode("utf-8")
    manifest_path.write_bytes(manifest_bytes)

    package_root = f"{stem}/"
    with zipfile.ZipFile(zip_path, "w") as archive:
        for rel in paths:
            zip_entry(archive, package_root + rel.as_posix(), (ROOT / rel).read_bytes())
        zip_entry(archive, package_root + "RELEASE-MANIFEST.json", manifest_bytes)

    digest = sha256_bytes(zip_path.read_bytes())
    checksum_path.write_text(f"{digest}  {zip_path.name}\n", encoding="utf-8")

    # Fail if packaging logic ever starts shipping compiled binaries.
    with zipfile.ZipFile(zip_path) as archive:
        names = archive.namelist()
        if any(name.lower().endswith(".ex5") for name in names):
            raise RuntimeError("compiled EX5 unexpectedly present in source release")

    return zip_path, manifest_path, checksum_path


if __name__ == "__main__":
    zip_path, manifest_path, checksum_path = build()
    print(f"PASS: deterministic source bundle {zip_path.relative_to(ROOT)}")
    print(f"PASS: manifest {manifest_path.relative_to(ROOT)}")
    print(f"PASS: checksum {checksum_path.relative_to(ROOT)}")
