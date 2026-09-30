# Commercial release process

Aurum Quant must not be sold merely because an EX5 exists. The release process binds compiled binaries to verified native evidence and keeps commercial claims separate from engineering evidence.

## Release candidate gate

A commercial **candidate** may be built only when:

- the current source commit exactly matches the native evidence `source_commit`;
- the native evidence independently verifies;
- the evidence includes the exact compiled `AurumQuantEA.ex5`, `AurumQuantValidation.ex5`, and `AurumQuantBrokerProbe.ex5`;
- all six shipped presets remain OBSERVE with order submission off;
- the candidate manifest and every packaged file are SHA-256 checked.

Build:

```sh
python3 tools/build-commercial-candidate.py PATH_TO_NATIVE_EVIDENCE
python3 tools/check-commercial-candidate.py
```

The generated candidate contains compiled EX5 files, presets, operator documentation, and the compiled-package installer. It deliberately excludes MQL source.

## Candidate is not the final sales release

A candidate manifest keeps these declarations false until separate evidence exists:

- `performance_validation_complete`
- `license_enforcement_complete`
- `code_signing_complete`
- `commercial_ready`

The candidate ZIP therefore proves binary provenance and packaging integrity, not profitability or legal/commercial completeness. v1.25 has both client-side licensing and a source-complete Supabase validation service. `license_enforcement_complete` remains false until that service is deployed to a dedicated Aurum project, an issuance/revocation administration workflow exists, and native MT5 activation/expiry/revocation/rate-limit tests pass.

## Final gates still required

Before a sales release, record broker/demo compatibility, real-tick historical methodology, untouched out-of-sample results, demo forward operation, support policy, license/activation design, privacy handling, refund/terms review, and signing/distribution procedure. The repository now provides privacy-safe support diagnostics, but the actual support SLA, escalation path, refund rules, and contact channel still require a business decision. Any performance statement must be based on the exact released binary and documented test population/period/cost assumptions.

Do not rename a candidate ZIP to imply final readiness. Promotion to a sales release needs a separate gated process.
