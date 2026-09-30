# Commercial licensing architecture

Aurum Quant v1.25 contains a client-side licensing boundary for future paid builds. The feature is intentionally disabled in the research presets and the remote licensing service is not yet deployed.

## Client inputs

- `RequireCommercialLicense=false` by default.
- `LicenseEndpoint` must begin with `https://` when licensing is enabled.
- `LicenseKey` accepts only letters, numbers, dash, and underscore.
- `LicenseTimeoutMs` controls the synchronous request timeout.
- `LicenseRecheckMinutes` controls periodic revalidation.

No endpoint or license key ships in the research presets.

## Privacy model

The request body contains the entered license key, EA version, and an `account_fingerprint`. The fingerprint is SHA-256 over a local string derived from the MT5 account login, broker server, and terminal name. The raw account login is not sent to the license endpoint.

A hash is pseudonymous rather than anonymous. A production privacy notice must describe that identifier and the server-side retention policy before launch.

## MT5 behavior

When licensing is required, the EA performs activation checks on a timer. New DEMO/LIVE entries require a valid, unexpired license state. Unchecked, invalid, expired, configuration-error, or unavailable states block new entries.

OBSERVE does not require activation. Position management is deliberately outside the license boundary, so break-even/trailing protection for already-open EA positions continues even during a licensing outage.

The endpoint must be added by the customer to MT5's allowed WebRequest URL list. WebRequest is synchronous and is not available in Strategy Tester, so Strategy Tester cannot prove remote activation behavior.

## Server contract

The client sends a form-encoded HTTPS POST containing:

```text
license_key=<key>&account_fingerprint=<64-char-sha256>&version=<EA-version>
```

The client currently accepts plain-text responses:

```text
AURUM_LICENSE|status=VALID|expires=<unix-seconds>
AURUM_LICENSE|status=INVALID
AURUM_LICENSE|status=REVOKED
AURUM_LICENSE|status=EXPIRED
```

`expires=0` represents no client-side expiry. HTTP 401/403 are treated as invalid, HTTP 410 as expired, and other non-200/network failures as unavailable.

## Still required

Client code is only one half of licensing. Commercial enforcement remains incomplete until there is a deployed service with a license database, issuance/revocation administration, rate limiting, audit logging, privacy/retention policy, secret management, availability monitoring, and native MT5 activation tests against the production endpoint.

Do not set `license_enforcement_complete=true` in a release manifest until those server-side and native gates are complete.
