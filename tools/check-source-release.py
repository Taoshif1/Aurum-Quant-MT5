"""Verify Aurum Quant deterministic source-release outputs."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / "dist"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def one(pattern: str) -> Path:
    matches = sorted(DIST.glob(pattern))
    if len(matches) != 1:
        raise RuntimeError(f"expected exactly one {pattern}, found {len(matches)}")
    return matches[0]


def main() -> None:
    zip_path = one("AurumQuant-MT5-source-v*.zip")
    manifest_path = one("AurumQuant-MT5-source-v*.manifest.json")
    checksum_path = one("AurumQuant-MT5-source-v*.sha256")

    external_manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    version = external_manifest["ea_version"]
    if zip_path.name != f"AurumQuant-MT5-source-v{version}.zip":
        raise RuntimeError("package filename/version mismatch")
    if external_manifest.get("package_kind") != "source-research-preview":
        raise RuntimeError("package must remain labeled source-research-preview")
    if external_manifest.get("native_mt5_compilation_included") is not False:
        raise RuntimeError("manifest falsely claims native compilation")
    if external_manifest.get("compiled_ex5_included") is not False:
        raise RuntimeError("manifest falsely claims compiled EX5")
    if external_manifest.get("profitability_claim") is not False:
        raise RuntimeError("manifest profitability flag must remain false")
    defaults = external_manifest.get("execution_defaults", {})
    if defaults != {"operating_mode": "OBSERVE", "order_submission": False}:
        raise RuntimeError("unsafe release execution defaults")

    expected_digest = checksum_path.read_text(encoding="utf-8").strip().split()[0]
    actual_digest = sha256(zip_path.read_bytes())
    if not re.fullmatch(r"[0-9a-f]{64}", expected_digest) or expected_digest != actual_digest:
        raise RuntimeError("ZIP SHA256 mismatch")

    root = f"AurumQuant-MT5-source-v{version}/"
    listed = {row["path"]: row for row in external_manifest["files"]}
    with zipfile.ZipFile(zip_path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise RuntimeError("duplicate ZIP entries")
        if any(not name.startswith(root) for name in names):
            raise RuntimeError("ZIP contains path outside package root")
        if any(".." in Path(name).parts for name in names):
            raise RuntimeError("ZIP contains path traversal")
        if any(name.lower().endswith(".ex5") for name in names):
            raise RuntimeError("compiled EX5 found in source package")
        if any("/.github/" in name or "/Tests/portable/" in name or name.endswith("/AGENTS.md") for name in names):
            raise RuntimeError("internal development files leaked into source package")

        embedded_name = root + "RELEASE-MANIFEST.json"
        embedded = json.loads(archive.read(embedded_name).decode("utf-8"))
        if embedded != external_manifest:
            raise RuntimeError("embedded and external manifests differ")

        packaged_paths = {
            name[len(root):]
            for name in names
            if name != embedded_name and not name.endswith("/")
        }
        if packaged_paths != set(listed):
            raise RuntimeError(
                f"manifest/ZIP file-set mismatch: missing={set(listed)-packaged_paths}, "
                f"extra={packaged_paths-set(listed)}"
            )

        for path, row in listed.items():
            data = archive.read(root + path)
            if len(data) != row["bytes"] or sha256(data) != row["sha256"]:
                raise RuntimeError(f"manifest hash/size mismatch: {path}")

    print(
        f"PASS: verified {zip_path.name} "
        f"({len(listed)} source files, sha256={actual_digest})"
    )


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        raise
