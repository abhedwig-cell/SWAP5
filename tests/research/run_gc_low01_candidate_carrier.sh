#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-low01-carrier-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
fail(){ echo "GC_LOW01_CARRIER_RUNNER_FAIL $*" >&2; exit 1; }
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace)
for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    tests/research/support/mod_gc_low01_mode1_candidate_carrier.f90 \
    tests/research/test_gc_low01_mode1_candidate_carrier.f90 \
    -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "runtime O$opt"; }
  grep -Fq 'GC_LOW01_CARRIER_GATE=PASS' "$OUT/output.txt" || fail "marker O$opt"
  cat "$OUT/output.txt"
  echo "GC_LOW01_CARRIER_O${opt}=PASS"
done
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 drift'
}
echo 'GC_LOW01_CARRIER_O0_O2_IDENTITY=PASS'
git diff --check -- \
  integration/research/GC_LOW01_MODE1_CANDIDATE_CARRIER_PREREGISTRATION.json \
  integration/research/GC_LOW01_MODE1_CANDIDATE_CARRIER_PREREGISTRATION_AMENDMENT.json \
  tests/research/support/mod_gc_low01_mode1_candidate_carrier.f90 \
  tests/research/test_gc_low01_mode1_candidate_carrier.f90 \
  tests/research/run_gc_low01_candidate_carrier.sh
echo 'GC_LOW01_CARRIER_QUALIFICATION=PASS'
