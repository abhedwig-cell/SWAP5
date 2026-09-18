#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fapp07-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_APP07_FAIL $*" >&2; exit 1; }

SRC=src/process/mod_tcs1_dcs2_sprinkling_irrigation_process.f90
TEST=tests/f-app07/test_tcs1_dcs2_sprinkling_process.f90
[[ -f "$SRC" && -f "$TEST" ]] || fail "missing source/test"

grep -Fq 'pure subroutine evaluate_tcs1_dcs2_sprinkling_interval' "$SRC" || fail "missing pure process"
if grep -Eiq 'open[[:space:]]*\(|read[[:space:]]*\(|write[[:space:]]*\(' "$SRC"; then
  fail "process contains file or formatted I/O"
fi
if grep -Eiq 'mod_rutter|mod_fmr|headcalc|timecontrol' "$SRC"; then
  fail "process depends on runtime, interception or solver internals"
fi

COMMON=(-std=f2008 -pedantic-errors -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$SRC" -o "$OUT/process.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/process.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "runtime O$opt"; }
  grep -Fq 'F_APP07_TCS1_DCS2_HUPSEL_PROCESS=PASS' "$OUT/output.txt" || fail "missing Hupsel marker O$opt"
  grep -Fq 'F_APP07_TCS1_DCS2_SPLIT_REPLAY=PASS' "$OUT/output.txt" || fail "missing split marker O$opt"
  grep -Fq 'F_APP07_TCSFIX_DAYFIX=PASS' "$OUT/output.txt" || fail "missing dayfix marker O$opt"
  echo "F_APP07_O${opt}=PASS"
done
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || { diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true; fail "O0/O2 drift"; }
cat "$BUILD/o0/output.txt"
echo "F_APP07_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'F_APP07_TCS1_DCS2_PROCESS_QUALIFICATION=PASS'
