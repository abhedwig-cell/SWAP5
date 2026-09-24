#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ahl24-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/tables"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
PYTHONPATH=research/ahl python3 research/ahl/ahl15_wet_local_k.py "$BUILD/tables" >/dev/null
for material in B01 B12 O05 O14; do
  tail -n +2 "$BUILD/tables/${material}_dc.dat" > "$BUILD/tables/${material}_konly.dat"
done
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
 research/ahl/mod_ahl08_klookup_provider.f90
)
objects=()
for source in "${SRC[@]}"; do
 obj="$BUILD/$(basename "${source%.*}").o"
 gfortran "${COMMON[@]}" -O2 -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj"
 objects+=("$obj")
done
gfortran "${COMMON[@]}" -O2 -J "$BUILD" -I "$BUILD" -c research/ahl/test_ahl21e_exact_retention.f90 -o "$BUILD/test.o"
gfortran -O2 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test"

RESULT="${1:-/tmp/ahl24_result.txt}"; : > "$RESULT"
fail=0; pass=0
for material in B01 B12 O05 O14; do
 for spec in "wet -10" "mid -75" "dry -500"; do
  read -r regime h0 <<< "$spec"
  set +e
  "$BUILD/test" "$BUILD/tables/${material}_konly.dat" "$material" "$regime" "$h0" 0 0.99 0.0625 2>&1 | tee -a "$RESULT"
  rc=${PIPESTATUS[0]}
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "AHL24_CASE_STATUS ${material}:${regime} PASS" | tee -a "$RESULT"; pass=$((pass+1))
  else
    echo "AHL24_CASE_STATUS ${material}:${regime} FAIL rc=$rc" | tee -a "$RESULT"; fail=1
  fi
 done
done
echo "AHL24_PASS_COUNT $pass" | tee -a "$RESULT"
if [[ "$fail" -ne 0 ]]; then echo "AHL24_MATRIX=FAIL" | tee -a "$RESULT"; exit 1; fi
echo "AHL24_MATRIX_12_OF_12=PASS" | tee -a "$RESULT"
