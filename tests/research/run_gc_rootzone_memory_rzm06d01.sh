#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rzm06d01-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/extract" "$BUILD/evidence"
trap 'rm -rf "$BUILD/extract" "$BUILD/rom1ar2.zip"' EXIT

fail(){ echo "RZM06D01_FAIL $*" >&2; exit 1; }

ARTIFACT_ID=10561841507
ARTIFACT_SHA=2b04e188b7ce1593e073031fc43580550513e857dfb74b9993844a3230a1a67f
PREREG=2af534f0455ceb121f9a7965d1fe9f92895b3e4d

git merge-base --is-ancestor "$PREREG" HEAD || fail "preregistration not ancestor"
: "${GITHUB_TOKEN:?GITHUB_TOKEN required}"

curl --fail --location --silent --show-error \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/abhedwig-cell/SWAP5/actions/artifacts/$ARTIFACT_ID/zip" \
  -o "$BUILD/rom1ar2.zip"

echo "$ARTIFACT_SHA  $BUILD/rom1ar2.zip" | sha256sum -c - || fail "artifact digest"
unzip -q "$BUILD/rom1ar2.zip" -d "$BUILD/extract"

test -f "$BUILD/extract/o0.txt" || fail "missing o0"
test -f "$BUILD/extract/o2.txt" || fail "missing o2"
test -f "$BUILD/extract/ROM1AR2_RESULT.json" || fail "missing historical result"
cmp "$BUILD/extract/o0.txt" "$BUILD/extract/o2.txt" || fail "ROM1AR2 O0/O2 drift"

python3 - "$BUILD/extract/ROM1AR2_RESULT.json" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
assert r["decision"]=="ROM1AR2_REACHABLE_STATE_LIBRARY_QUALIFIED"
assert r["library"]["accepted_state_count"]==768
assert r["library"]["discovery_state_count"]==512
assert r["library"]["held_out_state_count"]==256
assert r["library"]["nodes_per_state"]==16
assert r["repeat_stdout_bitwise_identity"] is True
print("GC_RZM06D01_ROM1AR2_AUTHORITY=PASS")
PY

python3 tests/research/analyze_gc_rootzone_memory_rzm06d01.py \
  --input "$BUILD/extract/o2.txt" \
  --artifact-sha256 "$ARTIFACT_SHA" \
  --output "$BUILD/evidence/GC_ROOTZONE_MEMORY_RZM06D01_RESULT.json" \
  | tee "$BUILD/evidence/d01.txt"

grep -Fq 'GC_RZM06D01_RESPONSE_BLIND_ORIGIN_SELECTION=PASS' "$BUILD/evidence/d01.txt" \
  || fail "D01 selector marker"

cp "$BUILD/extract/ROM1AR2_RESULT.json" "$BUILD/evidence/ROM1AR2_RESULT_AUTHORITY.json"
sha256sum "$BUILD/evidence/"* > "$BUILD/evidence/sha256.txt"

echo "GC_RZM06D01_GATE=PASS"
echo "RZM06D01_EVIDENCE_DIR=$BUILD/evidence"
