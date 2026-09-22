#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

D04="${1:?D04 artifact directory required}"
E01="${2:?E01 artifact directory required}"
E03="${3:?E03 artifact directory required}"
E03B="${4:?E03B artifact directory required}"
E03C="${5:?E03C artifact directory required}"
PREREG=21bbfdf16edbe842647b345223454bd3507a1a03
EVIDENCE="${RZM06E05_EVIDENCE_DIR:-$ROOT/RZM06E05-EVIDENCE}"
mkdir -p "$EVIDENCE"
fail(){ echo "GC_RZM06E05_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG" HEAD || fail "preregistration not ancestor"

for spec in   "$D04/d04-o0.txt:$D04/d04-o2.txt:D04"   "$E01/e01-o0.txt:$E01/e01-o2.txt:E01"   "$E03/e03-o0.txt:$E03/e03-o2.txt:E03"   "$E03B/e03b-o0.txt:$E03B/e03b-o2.txt:E03B"   "$E03C/e03c-o0.txt:$E03C/e03c-o2.txt:E03C"
do
  IFS=: read -r o0 o2 label <<<"$spec"
  test -f "$o0" && test -f "$o2" || fail "$label state files absent"
  cmp "$o0" "$o2" || fail "$label O0/O2 artifact drift"
  echo "GC_RZM06E05_SOURCE_IDENTITY_${label}=PASS"
done

python3 tests/research/test_gc_rootzone_memory_rzm06e05_census.py   --d04 "$D04/d04-o2.txt"   --e01 "$E01/e01-o2.txt"   --e03 "$E03/e03-o2.txt"   --e03b "$E03B/e03b-o2.txt"   --e03c "$E03C/e03c-o2.txt" | tee "$EVIDENCE/census.txt"

grep -Fq 'GC_RZM06E05_RESPONSE_BLIND_CENSUS=PASS' "$EVIDENCE/census.txt" || fail "census marker"
sha256sum   "$D04/d04-o2.txt" "$E01/e01-o2.txt" "$E03/e03-o2.txt"   "$E03B/e03b-o2.txt" "$E03C/e03c-o2.txt" "$EVIDENCE/census.txt"   > "$EVIDENCE/sha256.txt"

echo 'GC_RZM06E05_QUALIFICATION=PASS'
