# Source release packaging

Aurum Quant currently distributes a **research source bundle**, not a compiled or commercially validated MT5 release.

## Build locally

From the repository root:

```sh
python3 tools/check-presets.py
python3 tools/build-source-release.py
python3 tools/check-source-release.py
```

Generated files are written to ignored `dist/`:

- `AurumQuant-MT5-source-v<EA_VERSION>.zip`
- `AurumQuant-MT5-source-v<EA_VERSION>.manifest.json`
- `AurumQuant-MT5-source-v<EA_VERSION>.sha256`

The ZIP uses sorted paths, fixed ZIP timestamps, fixed file permissions and maximum DEFLATE compression. Rebuilding the same checked-out commit with the same source files produces the same ZIP bytes.

## Bundle contents

The source bundle includes:

- `Experts/AurumQuantEA.mq5`
- `Include/AurumQuant/**/*.mqh`
- all shipped `Presets/*.set`
- `Tests/AurumQuantValidation.mq5` and `Tests/AurumQuantBrokerProbe.mq5`
- user-facing `docs/*.md`
- `README.md`
- the PowerShell install, official-MetaEditor compile, and native-evidence collection helpers
- preset validation, native-evidence verification, Strategy Tester metric parsing, plus source-package build/verification Python tools

It deliberately excludes Git metadata, GitHub workflow files, portable test shims, `AGENTS.md`, local build output and compiled `.ex5` files.

## Manifest and checksums

The JSON manifest records:

- exact EA version
- checked-out source commit when Git metadata is available
- package type: `source-research-preview`
- locked execution-default declaration
- explicit false flags for native compilation, compiled EX5 and profitability claims
- byte size and SHA-256 digest for every packaged source file

The separate `.sha256` file contains the SHA-256 of the deterministic ZIP. `check-source-release.py` independently verifies the ZIP digest, embedded/external manifest equality, every listed file hash and size, safe paths, exact manifest/ZIP membership, research-only flags, and absence of compiled EX5/internal development files.

## CI artifact

GitHub Actions builds and verifies the bundle after the portable regression and preset-safety gates. The run-scoped artifact is retained for 14 days. It is CI evidence and a source handoff, **not** a GitHub Release, signed installer, compiled EX5, broker certification or performance validation.

Official MetaEditor compilation and native MT5 validation remain separate release gates in [RELEASE-CHECKLIST.md](RELEASE-CHECKLIST.md).
