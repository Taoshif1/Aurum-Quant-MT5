"""Static and local contract checks for the Aurum Supabase license service."""
from __future__ import annotations

import hashlib
from pathlib import Path
import re
import secrets
import sys

ROOT = Path(__file__).resolve().parents[1]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def main() -> None:
    schema = (ROOT / "commercial/license-service/schema.sql").read_text(encoding="utf-8")
    edge = (ROOT / "supabase/functions/aurum-license/index.ts").read_text(encoding="utf-8")
    contract = (ROOT / "supabase/functions/aurum-license/contract.ts").read_text(encoding="utf-8")

    for table in ("aurum_licenses", "aurum_license_activations", "aurum_license_events"):
        require(f"alter table public.{table} enable row level security;" in schema, f"RLS missing: {table}")
        require(f"revoke all on table public.{table} from public, anon, authenticated;" in schema, f"public grants not revoked: {table}")

    require("security invoker" in schema.lower(), "license RPC must remain SECURITY INVOKER")
    require("for update;" in schema.lower(), "license row must be locked for atomic activation count")
    require("revoke all on function public.aurum_validate_license" in schema.lower(), "RPC public execute not revoked")
    require("grant execute on function public.aurum_validate_license" in schema.lower() and "to service_role" in schema.lower(), "RPC not restricted to service_role")
    require("RATE_LIMITED" in schema, "database rate limit decision missing")

    require("npm:@supabase/supabase-js@2.95.0" in edge, "supabase-js dependency must stay pinned")
    require("SUPABASE_SECRET_KEYS" in edge, "modern server secret dictionary not used")
    require("SUPABASE_SERVICE_ROLE_KEY" in edge, "legacy service-role fallback missing")
    require("crypto.subtle.digest('SHA-256'" in edge, "license key hashing missing")
    require("license_key" not in re.sub(r"form\.get\('license_key'\)", "", edge), "edge function should not log/store raw license key")
    require("account_login" not in edge, "raw MT5 account login must never reach the service")
    require("application/x-www-form-urlencoded" in edge, "MT5 form contract missing")
    require("AURUM_LICENSE|status=VALID" in contract, "MT5 VALID response contract missing")

    key = "AQ-" + secrets.token_urlsafe(24)
    digest = hashlib.sha256(key.encode()).hexdigest()
    require(bool(re.fullmatch(r"[0-9a-f]{64}", digest)), "license hash generation invalid")

    print("PASS: license-service schema/security/contract checks")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        raise
