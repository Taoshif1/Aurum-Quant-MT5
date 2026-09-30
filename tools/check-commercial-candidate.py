"""Verify an Aurum Quant commercial release candidate package."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
import tempfile
import zipfile

DEFAULT_DIST = Path(__file__).resolve().parents[1] / "dist-commercial"
REQUIRED_BINARIES = {
    "Experts/AurumQuantEA.ex5",
    "Scripts/AurumQuantValidation.ex5",
    "Scripts/AurumQuantBrokerProbe.ex5",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def one(root: Path, pattern: str) -> Path:
    matches = sorted(root.glob(pattern))
    require(len(matches) == 1, f"expected exactly one {pattern}, found {len(matches)}")
    return matches[0]


def verify(root_dir: Path) -> None:
    zip_path = one(root_dir, "AurumQuant-MT5-commercial-candidate-v*.zip")
    manifest_path = one(root_dir, "AurumQuant-MT5-commercial-candidate-v*.manifest.json")
    checksum_path = one(root_dir, "AurumQuant-MT5-commercial-candidate-v*.sha256")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    version = manifest.get("ea_version")
    require(bool(re.fullmatch(r"\d+\.\d+", str(version))), "invalid candidate version")
    require(manifest.get("package_kind") == "commercial-release-candidate", "wrong package kind")
    require(manifest.get("native_evidence_verified") is True, "native evidence not verified")
    require(manifest.get("compiled_ex5_included") is True, "EX5 flag missing")
    require(manifest.get("commercial_ready") is False, "candidate must not claim commercial-ready")
    require(manifest.get("license_client_boundary_complete") is True, "candidate must declare license client boundary")
    require(manifest.get("license_service_source_complete") is True, "candidate must declare license service source state")
    require(manifest.get("profitability_claim") is False, "candidate must not claim profitability")
    require(manifest.get("execution_defaults") == {"operating_mode":"OBSERVE","order_submission":False}, "unsafe candidate defaults")
    for key in ("performance_validation_complete","license_enforcement_complete","code_signing_complete"):
        require(manifest.get(key) is False, f"candidate unexpectedly claims {key}")
    commit = str(manifest.get("source_commit", ""))
    require(bool(re.fullmatch(r"[0-9a-f]{40}", commit)), "invalid source commit")
    require(bool(re.fullmatch(r"[0-9a-f]{64}", str(manifest.get("native_evidence_manifest_sha256", "")))), "invalid native evidence manifest hash")

    expected = checksum_path.read_text(encoding="utf-8").strip().split()[0]
    require(expected == sha256(zip_path.read_bytes()), "candidate ZIP SHA256 mismatch")

    rows = manifest.get("files")
    require(isinstance(rows, list) and rows, "candidate manifest file list missing")
    listed = {row["path"]: row for row in rows}
    require(len(listed) == len(rows), "duplicate candidate manifest path")
    require(REQUIRED_BINARIES <= set(listed), "compiled binaries missing from candidate manifest")
    require("Install-AurumQuant.ps1" in listed, "compiled installer missing")
    presets = [p for p in listed if p.startswith("Presets/") and p.endswith(".set")]
    require(len(presets) == 6, "candidate must contain six presets")

    package_root = f"AurumQuant-MT5-commercial-candidate-v{version}/"
    with zipfile.ZipFile(zip_path) as archive:
        names = archive.namelist()
        require(len(names) == len(set(names)), "duplicate candidate ZIP entries")
        require(all(name.startswith(package_root) for name in names), "candidate ZIP path escaped package root")
        embedded_name = package_root + "COMMERCIAL-CANDIDATE-MANIFEST.json"
        embedded = json.loads(archive.read(embedded_name).decode("utf-8"))
        require(embedded == manifest, "embedded/external candidate manifests differ")
        packaged = {
            name[len(package_root):]
            for name in names
            if name != embedded_name and not name.endswith("/")
        }
        require(packaged == set(listed), "candidate ZIP/manifest membership mismatch")
        require(not any(name.lower().endswith(".mq5") or name.lower().endswith(".mqh") for name in packaged), "MQL source leaked into compiled candidate")
        for path, row in listed.items():
            data = archive.read(package_root + path)
            require(len(data) == row["bytes"], f"candidate size mismatch: {path}")
            require(sha256(data) == row["sha256"], f"candidate hash mismatch: {path}")
        for preset in presets:
            values = {}
            for line in archive.read(package_root + preset).decode("utf-8").splitlines():
                line=line.strip()
                if not line or line.startswith(";"):
                    continue
                key,value=line.split("=",1)
                values[key]=value
            require(values.get("OperatingMode") == "0", f"unsafe operating mode in {preset}")
            require(values.get("EnableOrderSubmission") == "false", f"submission armed in {preset}")
            require(values.get("RequireCommercialLicense") == "false", f"license enforcement unexpectedly armed in {preset}")

    print(f"PASS: commercial candidate verified {zip_path.name} files={len(listed)}")


def self_test() -> None:
    with tempfile.TemporaryDirectory(prefix="aurum-commercial-check-") as tmp:
        root = Path(tmp)
        version = "1.24"
        stem = f"AurumQuant-MT5-commercial-candidate-v{version}"
        files = {
            "Experts/AurumQuantEA.ex5": b"ea",
            "Scripts/AurumQuantValidation.ex5": b"validation",
            "Scripts/AurumQuantBrokerProbe.ex5": b"probe",
            "Install-AurumQuant.ps1": b"installer",
        }
        for name in ("BTCUSD","ETHUSD","EURUSD","Generic","XAGUSD","XAUUSD"):
            files[f"Presets/{name}-Research.set"] = b"OperatingMode=0\nEnableOrderSubmission=false\nRequireCommercialLicense=false\n"
        manifest = {
            "schema_version":1,
            "package_kind":"commercial-release-candidate",
            "product":"Aurum Quant MT5",
            "ea_version":version,
            "source_commit":"a"*40,
            "native_evidence_manifest_sha256":"b"*64,
            "native_evidence_verified":True,
            "compiled_ex5_included":True,
            "execution_defaults":{"operating_mode":"OBSERVE","order_submission":False},
            "performance_validation_complete":False,
            "license_client_boundary_complete":True,
            "license_service_source_complete":True,
            "license_enforcement_complete":False,
            "code_signing_complete":False,
            "commercial_ready":False,
            "profitability_claim":False,
            "files":[{"path":p,"bytes":len(d),"sha256":sha256(d)} for p,d in sorted(files.items())],
        }
        manifest_bytes=(json.dumps(manifest,indent=2,sort_keys=True)+"\n").encode()
        (root/f"{stem}.manifest.json").write_bytes(manifest_bytes)
        zip_path=root/f"{stem}.zip"
        with zipfile.ZipFile(zip_path,"w") as archive:
            for p,d in sorted(files.items()):
                archive.writestr(stem+"/"+p,d)
            archive.writestr(stem+"/COMMERCIAL-CANDIDATE-MANIFEST.json",manifest_bytes)
        (root/f"{stem}.sha256").write_text(f"{sha256(zip_path.read_bytes())}  {zip_path.name}\n",encoding="utf-8")
        verify(root)
        with zip_path.open("ab") as handle:
            handle.write(b"tamper")
        rejected=False
        try:
            verify(root)
        except RuntimeError:
            rejected=True
        require(rejected,"tampered commercial candidate was not rejected")
    print("PASS: commercial candidate verifier self-test rejected tampering")


def main() -> None:
    parser=argparse.ArgumentParser()
    parser.add_argument("candidate_dir",nargs="?",type=Path,default=DEFAULT_DIST)
    parser.add_argument("--self-test",action="store_true")
    args=parser.parse_args()
    if args.self_test:
        self_test()
    else:
        verify(args.candidate_dir)


if __name__=="__main__":
    main()
