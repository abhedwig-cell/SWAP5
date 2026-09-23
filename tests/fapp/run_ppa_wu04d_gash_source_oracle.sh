#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ppa-wu04d-gash-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
SOURCES=(
  src/process/mod_vonhhbraden_interception.f90
  src/process/mod_gash_interception.f90
  tests/fapp/test_ppa_wu04d_gash_source_oracle.f90
)
for OPT in 0 2; do
  mkdir -p "$BUILD/o$OPT"
  gfortran -std=f2008 -Wall -Wextra -Werror -Wno-error=compare-reals -ffree-line-length-none \
    -fcheck=all -ffpe-trap=invalid,zero,overflow -O"$OPT" \
    -J "$BUILD/o$OPT" -I "$BUILD/o$OPT" "${SOURCES[@]}" -o "$BUILD/o$OPT/oracle"
  "$BUILD/o$OPT/oracle" > "$BUILD/o$OPT/output.txt"
done
diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o2/output.txt"
echo 'PPA_WU04D_GASH_SOURCE_ORACLE_O0_O2_IDENTITY=PASS'
