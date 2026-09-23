#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rm11-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "RM11_FAIL $*" >&2; exit 1; }

SRC=src/runtime/mod_fmr_ribasim_management_scheduler.f90
TEST=tests/ribasim-management/test_rm11_management_boundary_scheduler.f90

grep -Fq 'FMR_RMS_BOUNDARY_PENDING' "$SRC" || fail "pending-boundary state missing"
grep -Fq 'plan_advance' "$SRC" || fail "plan seam missing"
grep -Fq 'mark_boundary_solved' "$SRC" || fail "boundary-solve seam missing"
grep -Fq 'export_fmr_ribasim_management_clock' "$SRC" || fail "restart export missing"
echo 'RM11_STATIC_CLOCK_CONTRACT=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -Wno-error=compare-reals -Wno-error=function-elimination -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$SRC" -o "$OUT/scheduler.o" || fail "compile scheduler O$opt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/test.o" || fail "compile test O$opt"
  gfortran -O"$opt" "$OUT/scheduler.o" "$OUT/test.o" -o "$OUT/test" || fail "link O$opt"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "runtime O$opt"; }
  grep -Fq 'RM11 MANAGEMENT BOUNDARY SCHEDULER GATE PASS' "$OUT/output.txt" || fail "final marker O$opt"
  echo "RM11_O${opt}=PASS"
done
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || fail "O0/O2 output drift"
cat "$BUILD/o0/output.txt"
echo "RM11_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'RM11_O0_O2_IDENTITY=PASS'
echo 'RM11_MANAGEMENT_BOUNDARY_SCHEDULER_GATE=PASS'
