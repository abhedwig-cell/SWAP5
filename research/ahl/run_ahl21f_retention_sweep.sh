#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ahl21f-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/tables"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

PYTHONPATH=research/ahl python3 research/ahl/ahl21f_generate_retention_variants.py "$BUILD/tables" | tee "$BUILD/support.txt"

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
 research/ahl/mod_ahl11_decoupled_provider.f90
)
objects=()
for source in "${SRC[@]}"; do
 obj="$BUILD/$(basename "${source%.*}").o"
 gfortran "${COMMON[@]}" -O2 -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj"
 objects+=("$obj")
done
gfortran "${COMMON[@]}" -O2 -J "$BUILD" -I "$BUILD" -c research/ahl/test_ahl21d_k03.f90 -o "$BUILD/test.o"
gfortran -O2 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test"

RESULT="${1:-/tmp/ahl21f_result.txt}"; : > "$RESULT"
declare -A rc
for variant in selected ret3 ret1; do
  set +e
  "$BUILD/test" "$BUILD/tables/O05_${variant}_ret_dc.dat" "$BUILD/tables/O05_selected_k.dat"     O05 dry -500 0 0.99 0.0625 2>&1 | tee -a "$RESULT"
  rc[$variant]=${PIPESTATUS[0]}
  set -e
  echo "AHL21F_VARIANT_STATUS ${variant} rc=${rc[$variant]}" | tee -a "$RESULT"
done

# The selected representation is already known to fail. One of the tighter
# preregistered variants must restore the path for this work unit to advance.
[[ "${rc[selected]}" -ne 0 ]]
if [[ "${rc[ret3]}" -eq 0 ]]; then
  echo "AHL21F_SELECTED_RETENTION ret3" | tee -a "$RESULT"
elif [[ "${rc[ret1]}" -eq 0 ]]; then
  echo "AHL21F_SELECTED_RETENTION ret1" | tee -a "$RESULT"
else
  echo "AHL21F_NO_TESTED_RETENTION_CLOSES_PATH" | tee -a "$RESULT"
  exit 1
fi
echo "AHL21F_SWEEP=PASS" | tee -a "$RESULT"
