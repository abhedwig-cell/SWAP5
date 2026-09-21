#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-low01c2-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail(){ echo "GC_LOW01C2_RUNNER_FAIL $*" >&2; exit 1; }

python3 tests/research/test_gc_low01c2_lower_half_cell_policy.py | tee "$BUILD/c2.txt"

for marker in \
  'GC_LOW01C2_POLICY_CASES=PASS' \
  'GC_LOW01C2_GAP_EXCLUSION=PASS' \
  'GC_LOW01C2_BOTTOM_FACE_HBOT=PASS' \
  'GC_LOW01C2_REVERSE_REPLAY=PASS' \
  'GC_LOW01C2_GATE=PASS'; do
  grep -Fq "$marker" "$BUILD/c2.txt" || fail "missing $marker"
done

git diff --check -- \
  integration/research/GC_LOW01C2_PREREGISTRATION.json \
  tests/research/test_gc_low01c2_lower_half_cell_policy.py \
  tests/research/run_gc_low01c2.sh

echo 'GC_LOW01C2_QUALIFICATION=PASS'
