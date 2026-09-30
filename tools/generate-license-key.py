"""Generate an Aurum Quant license key and its server-side SHA-256 hash."""
from __future__ import annotations

import argparse
import hashlib
import json
import secrets


def generate() -> tuple[str, str]:
    key = "AQ-" + secrets.token_urlsafe(24)
    digest = hashlib.sha256(key.encode("utf-8")).hexdigest()
    return key, digest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--plan", default="commercial")
    parser.add_argument("--max-activations", type=int, default=1)
    parser.add_argument("--expires-at", default=None, help="ISO-8601 timestamp or omit for no expiry")
    args = parser.parse_args()
    if not 1 <= args.max_activations <= 20:
        raise SystemExit("--max-activations must be 1..20")

    key, digest = generate()
    row = {
        "license_key": key,
        "key_hash": digest,
        "plan": args.plan,
        "max_activations": args.max_activations,
        "expires_at": args.expires_at,
    }
    print(json.dumps(row, indent=2))
    print("\nStore only key_hash in the database. Deliver license_key to the customer once and keep it out of Git/logs.")


if __name__ == "__main__":
    main()
