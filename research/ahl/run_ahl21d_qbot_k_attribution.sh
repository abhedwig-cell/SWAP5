#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ahl21d-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/selected" "$BUILD/k03"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

PYTHONPATH=research/ahl python3 research/ahl/ahl15_wet_local_k.py "$BUILD/selected" >/dev/null
PYTHONPATH=research/ahl python3 research/ahl/ahl11_generate_decoupled_support.py "$BUILD/k03" >/dev/null

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
 research/ahl/mod_ahl13_dc_exactk_provider.f90
 research/ahl/mod_ahl11_decoupled_provider.f90
)
objects=()
for source in "${SRC[@]}"; do
 obj="$BUILD/$(basename "${source%.*}").o"
 gfortran "${COMMON[@]}" -O2 -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj"
 objects+=("$obj")
done
for test in test_ahl21b_wet_dt_envelope test_ahl21d_exactk test_ahl21d_k03; do
 gfortran "${COMMON[@]}" -O2 -J "$BUILD" -I "$BUILD" -c "research/ahl/${test}.f90" -o "$BUILD/${test}.o"
 gfortran -O2 "${objects[@]}" "$BUILD/${test}.o" -o "$BUILD/${test}"
done

RESULT="${1:-/tmp/ahl21d_result.txt}"; : > "$RESULT"
set +e
"$BUILD/test_ahl21b_wet_dt_envelope" "$BUILD/selected/O05_dc.dat" O05 dry -500 0 0.99 0.0625 2>&1 | tee -a "$RESULT"
rc_selected=${PIPESTATUS[0]}
"$BUILD/test_ahl21d_exactk" "$BUILD/selected/O05_dc.dat" O05 dry -500 0 0.99 0.0625 2>&1 | tee -a "$RESULT"
rc_exact=${PIPESTATUS[0]}
"$BUILD/test_ahl21d_k03" "$BUILD/k03/O05_ret_dc.dat" "$BUILD/k03/O05_k03_k.dat" O05 dry -500 0 0.99 0.0625 2>&1 | tee -a "$RESULT"
rc_k03=${PIPESTATUS[0]}
set -e

echo "AHL21D_STATUS selected=$rc_selected exactK=$rc_exact global_k03=$rc_k03" | tee -a "$RESULT"
[[ "$rc_selected" -ne 0 ]]
[[ "$rc_exact" -eq 0 ]]
[[ "$rc_k03" -eq 0 ]]
echo "AHL21D_ATTRIBUTION=PASS" | tee -a "$RESULT"
