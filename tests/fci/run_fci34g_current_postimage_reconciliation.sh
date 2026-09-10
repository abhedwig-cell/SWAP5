#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
MODE="${FCI34G_MODE:-repair}"
BUILD="$ROOT/tests/fci/.fci34g-build-${GITHUB_RUN_ID:-$$}-${GITHUB_RUN_ATTEMPT:-0}"
trap 'rm -rf "$BUILD"' EXIT
mkdir -p "$BUILD/divdra-o0" "$BUILD/divdra-o2"

python3 tools/fci/fci34g_current_postimage_gate.py --mode "$MODE"

# Re-run the unchanged F-CI34 strong source/science admission gate against the
# current postimage. It replays F-VQ50 plus the real F-VQ21/HeadCalc oracle in
# O0/O2 and checks the exact F-MR31 runtime blob and all 30 invariants.
bash tests/fci/run_fci34_fmr31_root_attribution_canonical_admission.sh

echo 'FCI34G_FCI34_STRONG_POSTIMAGE_REPLAY=PASS'

compile_divdra_smoke() {
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

compile_divdra_smoke -O0 "$BUILD/divdra-o0"
compile_divdra_smoke -O2 "$BUILD/divdra-o2"
diff -u "$BUILD/divdra-o0/output.txt" "$BUILD/divdra-o2/output.txt"
echo 'FCI34G_CURRENT_DIVDRA_O0=PASS'
echo 'FCI34G_CURRENT_DIVDRA_O2=PASS'
echo 'FCI34G_CURRENT_DIVDRA_O0_O2_IDENTITY=PASS'

echo 'FCI34G_ZERO_SRC_REMEDIATION=PASS'
echo 'FCI34G_ZERO_REFERENCE_REMEDIATION=PASS'
echo 'FCI34G_CURRENT_POSTIMAGE_RECONCILIATION=PASS'
