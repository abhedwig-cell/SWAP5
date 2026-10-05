#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-mig431-tillage-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
COMMON=(-std=f2008 -pedantic-errors -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/process/mod_tillage_constitutive_process.f90 -o "$OUT/process.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/process/mod_tillage_water_redistribution.f90 -o "$OUT/water.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/tillage/test_mig431_tillage_constitutive.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/process.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; exit 1; }
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/tillage/test_mig431_tillage_water.f90 -o "$OUT/water-test.o"
  gfortran -O"$opt" "$OUT/water.o" "$OUT/water-test.o" -o "$OUT/water-test"
  "$OUT/water-test" >> "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; exit 1; }
  rg -q 'F_MIG431_TILLAGE_B111_EVENT_START=PASS' "$OUT/output.txt"
  rg -q 'F_MIG431_TILLAGE_DENSITY_CONSOLIDATION=PASS' "$OUT/output.txt"
  rg -q 'F_MIG431_TILLAGE_MVG_N123=PASS' "$OUT/output.txt"
  rg -q 'F_MIG431_TILLAGE_ZERO_CLAY_REJECTED=PASS' "$OUT/output.txt"
  rg -q 'F_MIG431_TILLAGE_SIMPLE_MASS_CLOSURE=PASS' "$OUT/output.txt"
  rg -q 'F_MIG431_TILLAGE_PROFILE_MASS_CLOSURE=PASS' "$OUT/output.txt"
  echo "F_MIG431_TILLAGE_O${opt}=PASS"
done
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o0/output.txt"
echo 'F_MIG431_TILLAGE_CONSTITUTIVE_QUALIFICATION=PASS'
