#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${TMPDIR:-/tmp}/swap5-perch19-state"
rm -rf "$BUILD"
mkdir -p "$BUILD"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     src/runtime/mod_fmr_macropore_reduction_continuation.f90 -o "$OUT/state.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     tests/fpm/test_ppa_wu05_perch19_reduction_state_machine.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/state.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" | tee "$OUT/out.txt"
  grep -Fq 'PPA_WU05_PERCH19_STATE_MACHINE_GATE=PASS' "$OUT/out.txt"
done

cmp "$BUILD/o0/out.txt" "$BUILD/o2/out.txt"
echo "PPA_WU05_PERCH19_O0_O2_IDENTITY=PASS"
