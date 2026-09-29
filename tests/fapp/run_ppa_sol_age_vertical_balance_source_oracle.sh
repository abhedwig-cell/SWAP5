#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-sol-age-vertical-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
for OPT in 0 2; do
  mkdir -p "$BUILD/o$OPT"
  gfortran -std=f2008 -Wall -Wextra -Werror -fcheck=all -ffpe-trap=invalid,zero,overflow -O"$OPT" \
    -J "$BUILD/o$OPT" src/process/mod_ppa_sol_age_cell_balance.f90 \
    src/process/mod_ppa_sol_age_vertical_balance.f90 \
    tests/fapp/test_ppa_sol_age_vertical_balance_source_oracle.f90 -o "$BUILD/o$OPT/oracle"
  "$BUILD/o$OPT/oracle" > "$BUILD/o$OPT/output.txt"
done
diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o0/output.txt"
echo 'PPA_SOL_AGE_VERTICAL_O0_O2_IDENTITY=PASS'
