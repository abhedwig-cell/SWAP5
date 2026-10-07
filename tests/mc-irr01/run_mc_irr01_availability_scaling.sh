#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/mc-irr01-avail-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
COMMON=(-std=f2008 -pedantic-errors -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_irrigation_availability_scaling.f90 -o "$OUT/policy.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/mc-irr01/test_mc_irr01_availability_scaling.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/policy.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt"
  grep -Fq 'MC_IRR01_AVAIL_LITERAL_SCALING=PASS' "$OUT/output.txt"
  grep -Fq 'MC_IRR01_AVAIL_POSITIVE_RATE_QUADRATIC_VOLUME=PASS' "$OUT/output.txt"
  grep -Fq 'MC_IRR01_AVAIL_ZERO_RATE_LINEAR_VOLUME=PASS' "$OUT/output.txt"
done
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o0/output.txt"
echo "MC_IRR01_AVAIL_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'MC_IRR01_AVAIL_CONTRACT=PASS'
