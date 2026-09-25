#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ahl11e-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/tables"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

python3 research/ahl/ahl11e_build_full_catalog_1e4.py "$BUILD/tables" > "$BUILD/table_summary.json"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  research/ahl/mod_ahl09_dc_provider.f90
)
OUT="$BUILD/o2"; mkdir -p "$OUT"
objects=()
for source in "${SRC[@]}"; do
  obj="$OUT/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -O2 -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -O2 -J "$OUT" -I "$OUT" -c research/ahl/test_ahl11e_full_catalog_matrix.f90 -o "$OUT/test.o"
gfortran -O2 "${objects[@]}" "$OUT/test.o" -o "$OUT/test"

RESULT="${1:-/tmp/ahl11e_result.txt}"
: > "$RESULT"
materials=()
for prefix in B O; do
  for i in $(seq -w 1 18); do materials+=("${prefix}${i}"); done
done
for m in "${materials[@]}"; do
  "$OUT/test" "$BUILD/tables/${m}_dc.dat" "$m" wet -10 -7.5 | tee -a "$RESULT"
  "$OUT/test" "$BUILD/tables/${m}_dc.dat" "$m" mid -75 -50 | tee -a "$RESULT"
  "$OUT/test" "$BUILD/tables/${m}_dc.dat" "$m" dry -500 -400 | tee -a "$RESULT"
done
count=$(grep -c '^AHL11E .* PASS$' "$RESULT")
[[ "$count" -eq 108 ]]
echo "AHL11E_MATRIX_108_OF_108=PASS" | tee -a "$RESULT"
