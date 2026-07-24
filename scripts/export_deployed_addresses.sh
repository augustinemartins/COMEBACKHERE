#!/usr/bin/env bash
# Write deployed contract addresses to artifacts/addresses.json (machine-readable),
# then validate the output against the schema defined in
# artifacts/addresses.json.example — catching a broken export before it silently
# produces a malformed file consumed by other tooling.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_FILE="${DEPLOYED_ADDRESSES_FILE:-$ROOT_DIR/artifacts/addresses.json}"
EXAMPLE_FILE="$ROOT_DIR/artifacts/addresses.json.example"

: "${STELLAR_NETWORK:?STELLAR_NETWORK is required}"
: "${INVOICE_CONTRACT_ID:?INVOICE_CONTRACT_ID is required}"
: "${TREASURY_CONTRACT_ID:?TREASURY_CONTRACT_ID is required}"
: "${COMPLIANCE_CONTRACT_ID:?COMPLIANCE_CONTRACT_ID is required}"

mkdir -p "$(dirname "$OUT_FILE")"
export LC_ALL=C
export LANG=C

# ── 1. write the addresses file ───────────────────────────────────────────────

python3 - "$OUT_FILE" <<'PY'
import json
import os
import sys

out_path = sys.argv[1]
payload = {
    "network": os.environ["STELLAR_NETWORK"],
    "contracts": [
        {"name": "invoice",    "address": os.environ["INVOICE_CONTRACT_ID"]},
        {"name": "treasury",   "address": os.environ["TREASURY_CONTRACT_ID"]},
        {"name": "compliance", "address": os.environ["COMPLIANCE_CONTRACT_ID"]},
    ],
}
with open(out_path, "w", encoding="utf-8", newline="\n") as handle:
    json.dump(payload, handle, indent=2, ensure_ascii=True)
    handle.write("\n")
PY

echo "Deployed addresses written to $OUT_FILE"

# ── 2. validate output against addresses.json.example schema ─────────────────
#
# Rules derived from addresses.json.example:
#   • Top-level key "network"   — string, non-empty
#   • Top-level key "contracts" — array with at least one element
#   • Every element of "contracts" must have:
#       - "name"    — string, non-empty
#       - "address" — string, non-empty
#   • The required contract names that must be present:
#       invoice, treasury, compliance

python3 - "$OUT_FILE" "$EXAMPLE_FILE" <<'PY'
import json
import sys

out_path  = sys.argv[1]
ex_path   = sys.argv[2]

REQUIRED_CONTRACT_NAMES = {"invoice", "treasury", "compliance"}

def die(msg):
    print(f"[schema-validation] FAIL: {msg}", file=sys.stderr)
    sys.exit(1)

# -- load generated file -------------------------------------------------------
try:
    with open(out_path, encoding="utf-8") as f:
        data = json.load(f)
except json.JSONDecodeError as exc:
    die(f"{out_path} is not valid JSON: {exc}")

# -- load example schema (for reference; we derive rules from it) --------------
try:
    with open(ex_path, encoding="utf-8") as f:
        example = json.load(f)
except json.JSONDecodeError as exc:
    die(f"{ex_path} (schema example) is not valid JSON: {exc}")

# -- structural checks ---------------------------------------------------------

if not isinstance(data, dict):
    die("root must be a JSON object")

# "network" key
if "network" not in data:
    die('required key "network" is missing')
if not isinstance(data["network"], str) or not data["network"].strip():
    die('"network" must be a non-empty string')

# "contracts" key
if "contracts" not in data:
    die('required key "contracts" is missing')
contracts = data["contracts"]
if not isinstance(contracts, list):
    die('"contracts" must be a JSON array')
if len(contracts) == 0:
    die('"contracts" array must not be empty')

# validate each contract entry
found_names = set()
for i, entry in enumerate(contracts):
    if not isinstance(entry, dict):
        die(f'"contracts[{i}]" must be a JSON object')
    for field in ("name", "address"):
        if field not in entry:
            die(f'"contracts[{i}]" is missing required field "{field}"')
        if not isinstance(entry[field], str) or not entry[field].strip():
            die(f'"contracts[{i}].{field}" must be a non-empty string')
    found_names.add(entry["name"])

# check all required contract names are present
missing = REQUIRED_CONTRACT_NAMES - found_names
if missing:
    die(f'contracts array is missing required entries: {sorted(missing)}')

# -- cross-check keys against example schema ----------------------------------
# Warn about any top-level keys in the example that are absent from the output
# (non-fatal; new optional keys should not break existing consumers).
example_keys = set(example.keys())
output_keys  = set(data.keys())
extra_in_example = example_keys - output_keys
if extra_in_example:
    print(
        f"[schema-validation] WARN: example has keys not in output "
        f"(may be optional): {sorted(extra_in_example)}",
        file=sys.stderr,
    )

print(f"[schema-validation] OK: {out_path} matches expected schema.")
PY
