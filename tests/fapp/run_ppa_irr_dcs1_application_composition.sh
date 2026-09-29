#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ppa-irr-dcs1-application-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
SOURCES=(
  src/process/mod_ppa_irr_dcs1_depth.f90
  src/process/mod_ppa_irr_fixed_input_normalization.f90
  src/process/mod_ppa_irr_rate_materialization.f90
  tests/fapp/test_ppa_irr_dcs1_application_composition.f90
)
for OPT in 0 2; do
  mkdir -p "$BUILD/o$OPT"
  gfortran -std=f2008 -Wall -Wextra -Werror -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -O"$OPT" -J "$BUILD/o$OPT" -I "$BUILD/o$OPT" "${SOURCES[@]}" -o "$BUILD/o$OPT/oracle"
  "$BUILD/o$OPT/oracle" > "$BUILD/o$OPT/output.txt"
done
diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o2/output.txt"
echo 'PPA_IRR_DCS1_APPLICATION_COMPOSITION_O0_O2_IDENTITY=PASS'
