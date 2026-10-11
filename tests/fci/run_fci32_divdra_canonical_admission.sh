#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

python3 tools/fci/fci32_divdra_canonical_gate.py --mode "${FCI32_MODE:-admission}"

BUILD="$ROOT/tests/fci/.fci32-build-${GITHUB_RUN_ID:-$$}-${GITHUB_RUN_ATTEMPT:-0}"
trap 'rm -rf "$BUILD"' EXIT
mkdir -p "$BUILD/o0" "$BUILD/o2"

compile_and_run() {
  local opt="$1"
  local dir="$2"
  gfortran -std=f2008 "$opt" -J"$dir" -I"$dir" -c src/solver/mod_soil_water_solver_contract.f90 -o "$dir/contract.o"
  gfortran -std=f2008 "$opt" -J"$dir" -I"$dir" -c src/solver/mod_process_hydraulic_view.f90 -o "$dir/view.o"
  gfortran -std=f2008 "$opt" -J"$dir" -I"$dir" -c src/process/mod_drainage_spatial_distribution.f90 -o "$dir/divdra.o"
  gfortran -std=f2008 "$opt" -J"$dir" -I"$dir" tests/fci/fci32_divdra_admission_smoke.f90 \
    "$dir/contract.o" "$dir/view.o" "$dir/divdra.o" -o "$dir/smoke"
  "$dir/smoke" > "$dir/output.txt"
  grep -Fx 'FCI32_DIVDRA_ADMISSION_SMOKE=PASS' "$dir/output.txt"
}

compile_and_run -O0 "$BUILD/o0"
compile_and_run -O2 "$BUILD/o2"
diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"

echo 'FCI32_O0_O2_SMOKE_OUTPUT_IDENTICAL=PASS'
echo 'FCI32_DIVDRA_CANONICAL_ADMISSION=PASS'
