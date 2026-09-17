#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fgc31-gwl-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail(){ echo "FGC31_GWL_GATE_FAIL $*" >&2; exit 31; }
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     src/solver/mod_b110_smooth_freatic_projection.f90 -o "$OUT/projection.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT"     tests/fgc/test_fgc31_smooth_freatic_projection.f90 "$OUT/projection.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "test execution O$opt"
  }
  for marker in     'FGC31_SMOOTH_FREATIC_PROJECTION=PASS'     'FGC31_ANALYTIC_DIRECTION_CENTERED_FD=PASS'     'FGC31_LEGACY_CURRENT_INTERIOR_FORMULA_EQUIVALENCE=PASS'     'FGC31_BRANCH_BOUNDARIES_FAIL_CLOSED=PASS'; do
    grep -Fxq "$marker" "$OUT/output.txt" || {
      cat "$OUT/output.txt" >&2
      fail "missing O$opt marker: $marker"
    }
  done
  echo "FGC31_SMOOTH_FREATIC_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 output identity'
}
echo 'FGC31_SMOOTH_FREATIC_O0_O2_EXACT_IDENTITY=PASS'
echo "FGC31_SMOOTH_FREATIC_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
cat "$BUILD/o0/output.txt"
echo 'F-GC31 SMOOTH FREATIC PROJECTION GATE PASS'
