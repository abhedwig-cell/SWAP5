#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ahl21i-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/tables"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

PYTHONPATH=research/ahl python3 research/ahl/ahl15_wet_local_k.py "$BUILD/tables" >/dev/null
for m in B01 B12 O05 O14; do
  tail -n +2 "$BUILD/tables/${m}_dc.dat" > "$BUILD/tables/${m}_konly.dat"
done

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fbacktrace)
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
 research/ahl/mod_ahl08_klookup_provider.f90
)
objects=()
for source in "${SRC[@]}"; do
  obj="$BUILD/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -O3 -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -O3 -J "$BUILD" -I "$BUILD" -c research/ahl/test_ahl21g_exact_retention_timing.f90 -o "$BUILD/test.o"
gfortran -O3 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test"

RESULT="${1:-/tmp/ahl21i_result.txt}"
: > "$RESULT"
run_case () {
  local m="$1" regime="$2" h0="$3"
  echo "AHL21I_CASE_BEGIN $m $regime" | tee -a "$RESULT"
  "$BUILD/test" "$BUILD/tables/${m}_konly.dat" "$m" "$regime" "$h0" 0 0.99 0.0625 | tee -a "$RESULT"
  echo "AHL21I_CASE_END $m $regime" | tee -a "$RESULT"
}
for m in B01 B12 O05 O14; do
  run_case "$m" wet -10
  run_case "$m" mid -75
  run_case "$m" dry -500
done
count=$(grep -c 'AHL21G_FIDELITY .* PASS' "$RESULT")
[[ "$count" -eq 12 ]]
echo "AHL21I_TIMING_MATRIX_COMPLETE" | tee -a "$RESULT"
