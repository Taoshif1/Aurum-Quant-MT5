# Supabase license service

This module is the planned server-side half of Aurum Quant commercial activation. It is source-complete but **not deployed** because the connected Supabase projects belong to other products. Use a dedicated Aurum Quant project.

## Files

- `commercial/license-service/schema.sql` — tables, RLS/grants, event/rate-limit data, and atomic validation RPC.
- `supabase/functions/aurum-license/index.ts` — public MT5-facing Edge Function.
- `supabase/functions/aurum-license/contract.ts` — strict request/response contract.
- `tools/generate-license-key.py` — generates a customer key and its SHA-256 database hash.
- `tools/check-license-service.py` — static security/contract checks.

## Data model

The database stores **only the SHA-256 hash of the customer license key**. It does not need the plaintext key. Activations store the SHA-256 account fingerprint already produced by the EA, not the raw MT5 login.

All three tables have RLS enabled. `anon` and `authenticated` table access is revoked. The Edge Function uses a Supabase server secret and calls `aurum_validate_license` as `service_role`. The RPC is `SECURITY INVOKER`, public execution is revoked, and only `service_role` receives EXECUTE.

The validation RPC locks the matching license row before counting/creating activations so simultaneous first activations cannot bypass `max_activations`.

## Rate limiting

The RPC allows up to 30 recorded requests per license-hash/account-fingerprint pair in a rolling ten-minute window. An excess returns `RATE_LIMITED`, which the Edge Function maps to HTTP 429. The MT5 client treats non-200/non-401/non-403/non-410 responses as temporarily unavailable and blocks new entries.

## Endpoint security

The Edge Function is intentionally designed for `verify_jwt=false` because MT5 does not hold a Supabase user JWT. The license key is the custom client credential. The function validates the request format, hashes the key before querying Postgres, and never logs the raw key.

Server database access uses `SUPABASE_SECRET_KEYS.default` when available, with legacy `SUPABASE_SERVICE_ROLE_KEY` fallback. Those values remain Edge Function secrets and must never be embedded in the EA or browser code.

## Issue a license

Generate a key locally:

```sh
python3 tools/generate-license-key.py --max-activations 1
```

The command prints the plaintext key once plus its SHA-256 hash. Insert **only the hash** into `public.aurum_licenses`. Deliver the plaintext key to the customer through the chosen sales/support channel.

Example database row:

```sql
insert into public.aurum_licenses(key_hash, plan, max_activations, expires_at)
values ('<64-char-hash>', 'commercial', 1, null);
```

Revoke without deleting audit history:

```sql
update public.aurum_licenses
set status='revoked', updated_at=now()
where key_hash='<64-char-hash>';
```

## Deployment gate

Do not deploy this into an unrelated application project. Create/use a dedicated Aurum Quant Supabase project, apply the schema there, run Supabase security/performance advisors, deploy `aurum-license` with JWT verification disabled because the function implements custom license authentication, then test from official desktop MT5 after adding the function URL to MT5's allowed WebRequest URLs.

Only after successful native activation/revocation/expiry/rate-limit tests should `license_enforcement_complete` be considered for promotion.
