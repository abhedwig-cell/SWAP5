#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
MODE="${FCI33R_MODE:-repair}"

python3 tools/fci/fci33r_current_postimage_gate.py --mode "$MODE"

BUILD="$ROOT/tests/fci/.fci33r-build-${GITHUB_RUN_ID:-$$}-${GITHUB_RUN_ATTEMPT:-0}"
trap 'rm -rf "$BUILD"' EXIT
mkdir -p "$BUILD/o0" "$BUILD/o2"

compile_and_run() {
  local opt="$1"
  local dir="$2"
  gfortran -std=f2008 -Wall -Wextra "$opt" -J"$dir" -I"$dir" -c src/solver/mod_soil_water_solver_contract.f90 -o "$dir/contract.o"
  gfortran -std=f2008 -Wall -Wextra "$opt" -J"$dir" -I"$dir" -c src/solver/mod_process_hydraulic_view.f90 -o "$dir/view.o"
  gfortran -std=f2008 -Wall -Wextra "$opt" -J"$dir" -I"$dir" -c src/process/mod_drainage_spatial_distribution.f90 -o "$dir/divdra.o"
  gfortran -std=f2008 -Wall -Wextra "$opt" -J"$dir" -I"$dir" -c src/runtime/mod_fmr_divdra_runtime_binding.f90 -o "$dir/binding.o"
  gfortran -std=f2008 -Wall -Wextra "$opt" -J"$dir" -I"$dir" -c src/solver/mod_b110_source_sink_provider.f90 -o "$dir/source_sink.o"
  gfortran -std=f2008 -Wall -Wextra "$opt" -J"$dir" -I"$dir" tests/fci/fci33_divdra_runtime_admission_smoke.f90 \
    "$dir/contract.o" "$dir/view.o" "$dir/divdra.o" "$dir/binding.o" "$dir/source_sink.o" -o "$dir/smoke"
  "$dir/smoke" > "$dir/output.txt"
  grep -Fx 'FCI33_DIVDRA_RUNTIME_ADMISSION_SMOKE=PASS' "$dir/output.txt"
}

compile_and_run -O0 "$BUILD/o0"
compile_and_run -O2 "$BUILD/o2"
diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
HASH0="$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
HASH2="$(sha256sum "$BUILD/o2/output.txt" | awk '{print $1}')"
test "$HASH0" = "$HASH2"
test "$HASH0" = f4643471accfb5ec067c7f38d845c3addc1e9d94be7fae82e3208b60c6cb99ce
printf 'FCI33R_O0_SHA256=%s\n' "$HASH0"
printf 'FCI33R_O2_SHA256=%s\n' "$HASH2"
echo 'FCI33R_O0_O2_IDENTICAL_TO_FCI33=PASS'
echo 'FCI33R_CURRENT_POSTIMAGE_RECONCILIATION=PASS'
