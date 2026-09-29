#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ppa-irr-fixed-input-application-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
SOURCES=(
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/process/mod_irrigation_process.f90
  src/process/mod_ppa_irr_fixed_input_normalization.f90
  tests/fapp/test_ppa_irr_fixed_input_application.f90
)
for OPT in 0 2; do
  mkdir -p "$BUILD/o$OPT"
  gfortran -std=f2008 -Wall -Wextra -Werror -Wno-error=unused-dummy-argument \
    -fcheck=all -ffpe-trap=invalid,zero,overflow -O"$OPT" \
    -J "$BUILD/o$OPT" -I "$BUILD/o$OPT" "${SOURCES[@]}" -o "$BUILD/o$OPT/oracle"
  "$BUILD/o$OPT/oracle" > "$BUILD/o$OPT/output.txt"
done
diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o2/output.txt"
echo 'PPA_IRR_FIXED_INPUT_APPLICATION_O0_O2_IDENTITY=PASS'