# Customer support diagnostics and privacy

Commercial support needs enough technical context to reproduce a problem without asking customers to send their entire MT5 data folder.

## Create a support bundle

Run:

```powershell
.\tools\Collect-Support-Bundle.ps1 `
  -TerminalData 'YOUR_MT5_DATA_FOLDER' `
  -Preset 'OPTIONAL_ACTIVE_PRESET.set' `
  -AurumLog 'OPTIONAL_MT5_LOG.log'
```

If `-BrokerProbe` is omitted, the tool uses the latest Aurum broker-probe CSV from the selected terminal. If `-AurumLog` is omitted, it attempts to use the latest terminal log.

The collector writes an ignored `support/support-<timestamp>` folder and ZIP.

## Default privacy behavior

The bundle intentionally excludes:

- the raw MT5 account login column;
- the local terminal-data path;
- non-Aurum terminal log lines;
- email addresses found in retained Aurum log lines;
- raw login/account-login values found in retained lines;
- preset values whose key looks like a password, token, secret, license key, API key, or credential.

Broker company/server, account currency/mode, terminal build, symbol economics, Aurum-only log lines, and non-secret preset values remain because they are useful for reproducing broker-specific issues.

## Verify before sharing

Run:

```sh
python3 tools/check-support-bundle.py support/support-YYYYMMDD-HHMMSS
```

The verifier recomputes hashes and rejects a bundle containing a raw account-login column, raw login values in logs/presets, email addresses in retained logs/presets, or an unredacted secret-like preset field.

No automatic upload is implemented. The customer remains in control of whether the ZIP is shared. The customer should still review the sanitized files before sending them to support.
