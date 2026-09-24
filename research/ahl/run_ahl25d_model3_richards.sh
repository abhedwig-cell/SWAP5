#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ahl25d-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/tables" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
PYTHONPATH=research/ahl python3 research/ahl/ahl25d_generate_tables.py "$BUILD/tables" > "$BUILD/table_summary.txt"
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
 src/solver/mod_b110_source_sink_provider.f90
 src/solver/mod_b110_root_sink_provider.f90
 src/solver/mod_fixed_flux_top_boundary_provider.f90
 src/solver/mod_reference_richards_temporal_indicator.f90
 tests/fmr/mod_fmr04_fixed_top_provider.f90
 src/legacy/b1_10_port/headcalc.f90
 src/adapter/mod_reference_richards_legacy_binding.f90
 research/ahl/mod_ahl25d_model3_analytical.f90
 research/ahl/mod_ahl25d_model3_lookup.f90
)
objects=()
for source in "${SRC[@]}";do
 obj="$BUILD/o2/$(basename "${source%.*}").o"
 gfortran "${COMMON[@]}" -O2 -J "$BUILD/o2" -I "$BUILD/o2" -c "$source" -o "$obj"
 objects+=("$obj")
done
gfortran "${COMMON[@]}" -O2 -J "$BUILD/o2" -I "$BUILD/o2" -c research/ahl/test_ahl25d_model3_richards.f90 -o "$BUILD/o2/test.o"
gfortran -O2 "${objects[@]}" "$BUILD/o2/test.o" -o "$BUILD/o2/test"
RESULT="${1:-/tmp/ahl25d_result.txt}";:>"$RESULT";fail=0
for material in M3_BALANCED M3_SEPARATED M3_DOMINANT_SECOND;do
 for spec in "wet -10 -7.5" "mid -75 -50" "dry -500 -400";do
  read -r regime h0 hbot <<< "$spec"
  set +e
  "$BUILD/o2/test" "$BUILD/tables/${material}.dat" "$material" "$regime" "$h0" "$hbot" 2>&1 | tee -a "$RESULT"
  rc=${PIPESTATUS[0]}
  set -e
  if [[ "$rc" -ne 0 ]];then echo "AHL25D_CASE_STATUS ${material}:${regime} FAIL rc=$rc"|tee -a "$RESULT";fail=1
  else echo "AHL25D_CASE_STATUS ${material}:${regime} PASS"|tee -a "$RESULT";fi
 done
done
if [[ "$fail" -eq 0 ]];then echo "AHL25D_MATRIX_9_OF_9=PASS"|tee -a "$RESULT";else echo "AHL25D_MATRIX=FAIL"|tee -a "$RESULT";exit 1;fi
