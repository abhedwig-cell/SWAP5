#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fpe-zero-waste01-capture-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
fail(){ echo "FPE_ZERO_WASTE01_CAPTURE_FAIL $*" >&2; exit 1; }
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_soil_water_solver_contract.f90 -o "$OUT/contract.o" || fail "contract O$opt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_reference_richards_workspace.f90 -o "$OUT/workspace.o" || fail "workspace O$opt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpe/test_fpe_zero_waste01_capture_capacity.f90 -o "$OUT/test.o" || fail "test O$opt"
  gfortran -O"$opt" "$OUT/contract.o" "$OUT/workspace.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "run O$opt"; }
  grep -Fq 'FPE_ZERO_WASTE01_CAPTURE_CAPACITY_REUSE=PASS' "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "marker O$opt"; }
done
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || { diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true; fail 'O0/O2 drift'; }
echo 'FPE_ZERO_WASTE01_CAPTURE_CAPACITY_GATE=PASS'
