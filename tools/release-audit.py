"""Fail CI when release-facing Aurum Quant metadata drifts from production source."""
from __future__ import annotations

from decimal import Decimal, InvalidOperation
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def decimal_version(value: str) -> Decimal:
    try:
        return Decimal(value)
    except InvalidOperation as exc:
        raise RuntimeError(f"invalid version string: {value}") from exc


def first_match(pattern: str, text: str, label: str, flags: int = 0) -> str:
    match = re.search(pattern, text, flags)
    if not match:
        raise RuntimeError(f"{label} not found")
    return match.group(1)


def count_checks(path: str) -> int:
    # Shared validation classes use one Check(...) call per deterministic assertion.
    # Calls are sometimes chained on one source line, so line-start counting undercounts them.
    text = read(path)
    occurrences = len(re.findall(r"\bCheck\(", text))
    helper_definitions = len(re.findall(r"\bstatic\s+void\s+Check\(", text))
    count = occurrences - helper_definitions
    if count < 0:
        raise RuntimeError(f"invalid Check() count in {path}")
    return count


def main() -> None:
    ea = read("Experts/AurumQuantEA.mq5")
    readme = read("README.md")
    changelog = read("docs/CHANGELOG.md")
    validation = read("docs/VALIDATION.md")
    release = read("docs/RELEASE-CHECKLIST.md")
    workflow = read(".github/workflows/portable-regression.yml")
    gitignore = read(".gitignore")
    package_builder = read("tools/build-source-release.py")

    ea_version_raw = first_match(
        r'^#property\s+version\s+"([^"]+)"', ea, "EA #property version", re.MULTILINE
    )
    ea_version = decimal_version(ea_version_raw)

    readme_version = decimal_version(
        first_match(
            r"^# Aurum Quant MT5 · ([0-9.]+) research preview$",
            readme,
            "README release version",
            re.MULTILINE,
        )
    )
    changelog_version = decimal_version(
        first_match(
            r"^## ([0-9.]+) research preview\s+—",
            changelog,
            "latest changelog version",
            re.MULTILINE,
        )
    )
    validation_version = decimal_version(
        first_match(
            r"^## v([0-9.]+) validation coverage$",
            validation,
            "validation coverage version",
            re.MULTILINE,
        )
    )
    release_version = decimal_version(
        first_match(
            r"Official MetaEditor compilation \| Pending for v([0-9.]+);",
            release,
            "release-checklist version",
        )
    )

    for label, version in {
        "README": readme_version,
        "CHANGELOG": changelog_version,
        "VALIDATION": validation_version,
        "RELEASE-CHECKLIST": release_version,
    }.items():
        require(version == ea_version, f"{label} version {version} != EA version {ea_version}")

    direct = count_checks("Include/AurumQuant/Research/ValidationSuite.mqh")
    strategy = count_checks("Include/AurumQuant/Research/StrategyValidation.mqh")
    management = count_checks("Include/AurumQuant/Research/PositionManagementValidation.mqh")
    expected_tests = direct + strategy + management
    require(direct > 0 and strategy > 0 and management > 0, "validation source contains no assertions")

    documented_pipe_counts = []
    for path in ("README.md", "docs/VALIDATION.md"):
        documented_pipe_counts.extend(
            int(value) for value in re.findall(r"passed=(\d+)\|failed=0", read(path))
        )
    require(documented_pipe_counts, "no documented native passed=N|failed=0 target")
    require(
        all(value == expected_tests for value in documented_pipe_counts),
        f"native test target drift: source={expected_tests}, documented={documented_pipe_counts}",
    )

    release_count = int(
        first_match(
            r"Native self-test \| Pending; require passed=(\d+) and failed=0",
            release,
            "release native self-test target",
        )
    )
    require(
        release_count == expected_tests,
        f"release native test target {release_count} != source count {expected_tests}",
    )

    strategy_doc = int(
        first_match(r"(\d+) strategy assertions", readme, "README strategy assertion count")
    )
    management_doc = int(
        first_match(
            r"(\d+) position-management assertions",
            readme,
            "README position-management assertion count",
        )
    )
    require(strategy_doc == strategy, f"README strategy count {strategy_doc} != {strategy}")
    require(management_doc == management, f"README management count {management_doc} != {management}")

    defaults = dict(
        re.findall(r"^input\s+\w+\s+(\w+)\s*=\s*([^;]+);", ea, re.MULTILINE)
    )
    required_defaults = {
        "OperatingMode": "MODE_OBSERVE",
        "EnableOrderSubmission": "false",
        "EnableResearchStrategy": "false",
        "EnableBreakEven": "false",
        "EnableTrailingStop": "false",
    }
    for key, expected in required_defaults.items():
        require(defaults.get(key) == expected, f"unsafe/missing EA default {key}={defaults.get(key)!r}")

    require("actions/checkout@v7" in workflow, "CI must use current checkout v7")
    require("actions/upload-artifact@v7" in workflow, "CI must use current upload-artifact v7")
    require("python3 tools/check-presets.py" in workflow, "CI preset safety gate missing")
    require("python3 tools/release-audit.py" in workflow, "CI release audit gate missing")
    require("python3 tools/build-source-release.py" in workflow, "CI source build gate missing")
    require("python3 tools/check-source-release.py" in workflow, "CI source verification gate missing")
    require("python3 tools/check-native-evidence.py --self-test" in workflow, "CI native-evidence verifier self-test missing")
    require("python3 tools/parse-tester-stats.py --self-test" in workflow, "CI tester-stats parser self-test missing")
    require("python3 tools/build-commercial-candidate.py --self-test" in workflow, "CI commercial candidate builder fail-closed test missing")
    require("python3 tools/check-commercial-candidate.py --self-test" in workflow, "CI commercial candidate verifier self-test missing")
    require("dist/" in gitignore.splitlines(), "generated dist/ must remain ignored")
    require("evidence/" in gitignore.splitlines(), "generated evidence/ must remain ignored")
    require("dist-commercial/" in gitignore.splitlines(), "generated dist-commercial/ must remain ignored")

    for tool in (
        "tools/check-presets.py",
        "tools/Collect-Native-Evidence.ps1",
        "tools/build-source-release.py",
        "tools/check-source-release.py",
        "tools/check-native-evidence.py",
        "tools/parse-tester-stats.py",
        "tools/Install-Commercial.ps1",
        "tools/build-commercial-candidate.py",
        "tools/check-commercial-candidate.py",
        "tools/release-audit.py",
    ):
        require(
            f'Path("{tool}")' in package_builder,
            f"source package allowlist missing release tool: {tool}",
        )

    require(r"Tests\AurumQuantBrokerProbe.mq5" in read("tools/Compile-MQL5.ps1"), "compile helper must include broker probe")
    require(r"Tests\AurumQuantBrokerProbe.mq5" in read("tools/Install-MQL5.ps1"), "installer must include broker probe")
    require(r"passed=78\|failed=0" in read("tools/Collect-Native-Evidence.ps1"), "native evidence collector must enforce 78/0 validation")
    require("compiled_ex5_included=$true" in read("tools/Collect-Native-Evidence.ps1"), "native evidence collector must bind compiled EX5")
    require('"commercial_ready": False' in read("tools/build-commercial-candidate.py"), "commercial candidate must not claim final readiness")
    require(
        "source research preview" in readme.lower(),
        "README must retain research-preview status language",
    )
    require(
        "Compiled EX5 candidate distribution | Gated builder/verifier implemented" in release,
        "release checklist must document the gated compiled candidate",
    )
    require(
        "`commercial_ready=false`" in release,
        "release checklist must keep compiled candidates explicitly non-commercial-ready",
    )

    print(
        "PASS: release audit "
        f"EA={ea_version_raw} native_tests={expected_tests} "
        f"(direct={direct}, strategy={strategy}, position_management={management})"
    )


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        raise
