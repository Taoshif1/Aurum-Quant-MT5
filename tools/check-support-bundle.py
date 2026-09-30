"""Verify privacy and integrity of an Aurum Quant customer support bundle."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path
import re
import tempfile

FORBIDDEN_HEADER = "account_login"
SECRET_KEY = re.compile(r"(?i)(password|secret|token|license(?:key)?|api[_-]?key|credential)")
RAW_LOGIN = re.compile(r"(?i)(account[_ ]?login|login)\s*[=:]\s*\d+")
EMAIL = re.compile(r"(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify(root: Path) -> None:
    root=root.resolve()
    manifest_path=root/"support-manifest.json"
    require(manifest_path.is_file(),"support-manifest.json missing")
    data=json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    require(data.get("schema_version")==1,"unsupported support schema")
    require(data.get("product")=="Aurum Quant MT5","unexpected product")
    require(data.get("bundle_kind")=="customer-support-diagnostics","unexpected support bundle kind")
    require(data.get("sanitized") is True,"support bundle not marked sanitized")
    require(data.get("raw_account_login_included") is False,"support bundle claims raw account login")
    require(data.get("raw_terminal_path_included") is False,"support bundle claims raw terminal path")
    commit=str(data.get("source_commit","")).strip()
    require(bool(re.fullmatch(r"[0-9a-fA-F]{40}",commit)),"invalid source commit")

    rows=data.get("files")
    require(isinstance(rows,list) and rows,"support manifest file list missing")
    listed={}
    for row in rows:
        name=row.get("file")
        require(isinstance(name,str) and name and "/" not in name and "\\" not in name and name!="support-manifest.json",f"unsafe support file name: {name}")
        require(name not in listed,f"duplicate support file: {name}")
        path=root/name
        require(path.is_file(),f"support file missing: {name}")
        require(path.stat().st_size==row.get("bytes"),f"support size mismatch: {name}")
        require(sha256(path)==str(row.get("sha256","")).lower(),f"support hash mismatch: {name}")
        listed[name]=path

    probe=listed.get("broker-probe-sanitized.csv")
    require(probe is not None,"sanitized broker probe missing")
    with probe.open("r",encoding="utf-8-sig",newline="") as handle:
        reader=csv.DictReader(handle)
        require(reader.fieldnames is not None,"broker probe headers missing")
        require(FORBIDDEN_HEADER not in reader.fieldnames,"raw account_login column present")
        probe_rows=list(reader)
    require(probe_rows,"sanitized broker probe has no rows")

    log=listed.get("aurum-log-sanitized.txt")
    if data.get("aurum_log_included"):
        require(log is not None,"manifest says Aurum log included but file missing")
        text=log.read_text(encoding="utf-8-sig",errors="replace")
        require(all("AURUM|" in line for line in text.splitlines() if line.strip()),"support log contains non-Aurum lines")
        require(RAW_LOGIN.search(text) is None,"raw account login found in support log")
        require(EMAIL.search(text) is None,"email address found in support log")

    preset=listed.get("preset-sanitized.set")
    if data.get("preset_included"):
        require(preset is not None,"manifest says preset included but file missing")
        for line in preset.read_text(encoding="utf-8-sig",errors="replace").splitlines():
            if "=" not in line:
                continue
            key,value=line.split("=",1)
            if SECRET_KEY.search(key):
                require(value.strip()=="[redacted]",f"secret-like preset field not redacted: {key}")
            require(RAW_LOGIN.search(line) is None,"raw login found in preset")
            require(EMAIL.search(line) is None,"email found in preset")

    print(f"PASS: privacy-safe support bundle verified files={len(listed)}")


def write_fixture(root: Path, raw_login: bool=False) -> None:
    probe=(
        "captured_gmt,terminal_build,account_server,broker_company,account_currency,symbol,status\n"
        "2026.09.30 10:00:00,6000,Demo-Server,Broker,USD,XAUUSD,OK\n"
    )
    (root/"broker-probe-sanitized.csv").write_text(probe,encoding="utf-8")
    login="12345678" if raw_login else "[redacted]"
    (root/"aurum-log-sanitized.txt").write_text(f"AURUM|STATUS|account_login={login}|state=READY\n",encoding="utf-8")
    (root/"preset-sanitized.set").write_text("OperatingMode=0\nLicenseKey=[redacted]\n",encoding="utf-8")
    files=[]
    for path in sorted(root.iterdir()):
        if path.is_file():
            files.append({"file":path.name,"bytes":path.stat().st_size,"sha256":sha256(path)})
    manifest={
        "schema_version":1,
        "product":"Aurum Quant MT5",
        "bundle_kind":"customer-support-diagnostics",
        "captured_utc":"2026-09-30T10:00:00Z",
        "source_commit":"a"*40,
        "sanitized":True,
        "raw_account_login_included":False,
        "raw_terminal_path_included":False,
        "aurum_log_included":True,
        "preset_included":True,
        "files":files,
    }
    (root/"support-manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")


def self_test() -> None:
    with tempfile.TemporaryDirectory(prefix="aurum-support-") as tmp:
        root=Path(tmp)
        write_fixture(root)
        verify(root)
    with tempfile.TemporaryDirectory(prefix="aurum-support-raw-") as tmp:
        root=Path(tmp)
        write_fixture(root,raw_login=True)
        rejected=False
        try:
            verify(root)
        except RuntimeError:
            rejected=True
        require(rejected,"support verifier did not reject raw account login")
    print("PASS: support bundle verifier self-test rejected raw account identifiers")


def main() -> None:
    parser=argparse.ArgumentParser()
    parser.add_argument("support_dir",nargs="?",type=Path)
    parser.add_argument("--self-test",action="store_true")
    args=parser.parse_args()
    if args.self_test:
        self_test()
        return
    if args.support_dir is None:
        parser.error("support_dir is required unless --self-test is used")
    verify(args.support_dir)


if __name__=="__main__":
    main()
