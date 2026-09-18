#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq120-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_VQ120_FAIL $*" >&2; exit 1; }

SRC=src/process/mod_tcs1_dcs2_sprinkling_irrigation_process.f90
TEST=tests/fvq/test_fvq120_fapp07_tcs1_dcs2_independent.f90
EXPECTED_SRC_BLOB=6ff53ac9c97b7b4c42fa8043193aa03bb116bd13
[[ "$(git rev-parse HEAD:$SRC)" == "$EXPECTED_SRC_BLOB" ]] || fail "candidate source drift"
[[ -f "$TEST" ]] || fail "missing verifier"
[[ -z "$(git diff --name-only dfe8709faa3cdcd7e4f1adaaeb1b05c4d772acc5..HEAD -- src)" ]] || fail "qualification mutated production source"

COMMON=(-std=f2008 -pedantic-errors -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$SRC" -o "$OUT/process.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/process.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "runtime O$opt"; }
  for m in     F_VQ120_B110_EQUATION_ORACLE=PASS     F_VQ120_TCSFIX_CADENCE=PASS     F_VQ120_SPLIT_ROLLBACK_REPLAY=PASS     F_VQ120_A_B_A=PASS     F_VQ120_FAIL_CLOSED=PASS; do
      grep -Fq "$m" "$OUT/output.txt" || fail "missing O$opt marker $m"
  done
  echo "F_VQ120_O${opt}=PASS"
done
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || { diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true; fail "O0/O2 drift"; }
cat "$BUILD/o0/output.txt"
echo "F_VQ120_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo "F_VQ120_FAPP07_INDEPENDENT=PASS"
