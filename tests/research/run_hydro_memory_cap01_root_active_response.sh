#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-hmcap01-a-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "HMCAP01_A_FAIL $*" >&2; exit 61; }

BASE=187e30153c890151768e929170d14bb22af1d86d
git merge-base --is-ancestor "$BASE" HEAD || fail "branch is not descended from frozen CAP01 authority base"

git diff --quiet "$BASE"..HEAD -- src || fail "CAP01-A changed production source"
git diff --quiet "$BASE"..HEAD -- reference || fail "CAP01-A changed reference source"

python3 - <<'PY'
from pathlib import Path
tangent=Path('src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90').read_text()
direction=Path('src/adapter/mod_reference_richards_accepted_step_directional_service.f90').read_text()
response=Path('src/runtime/mod_modflow6_swap_predictor_response.f90').read_text()
assert 'endpoint%coverage%root_uptake_covered = .false.' in tangent
assert "route = 'root-sink-direction-unavailable'" in direction
assert 'case (MODFLOW6_DERIVATIVE_CENTERED_FD)' in response
print('HMCAP01_AUTHORITY_ANALYTIC_ROOT_FAIL_CLOSED=PASS')
print('HMCAP01_AUTHORITY_CENTERED_FD_ROUTE_PRESENT=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -fopenmp -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/runtime/mod_fmr_top_sensible_boundary_carrier.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/process/mod_drainage_process.f90
  src/process/mod_drainage_tabulated_response.f90
  src/process/mod_drainage_hooghoudt_equivalent_depth.f90
  src/process/mod_drainage_hooghoudt_ipos1_response.f90
  src/process/mod_drainage_hooghoudt_ipos23_response.f90
  src/process/mod_drainage_ernst_ipos45_preparation.f90
  src/process/mod_drainage_ernst_ipos45_response.f90
  src/process/mod_drainage_empirical_interflow_response.f90
  src/process/mod_drainage_multilevel_aggregation.f90
  src/runtime/mod_fmr_drainage_response_binding.f90
  src/solver/mod_b110_smooth_freatic_projection.f90
  src/runtime/mod_fmr_drainage_qbot_directional_binding.f90
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_default_mvg_directional_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/adapter/mod_reference_richards_accepted_step_directional_service.f90
  src/process/mod_snow_process.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/runtime/mod_fmr_soil_water_application_host.f90
  src/runtime/mod_rossfast_d3r_execution_policy.f90
  src/runtime/mod_rossfast_d3r_model_binding.f90
  src/solver/mod_rossfast_d3r_table_kernel.f90
  src/solver/mod_rossfast_d3r_table_provider.f90
  src/solver/mod_rossfast_d3r_soil_water_solver.f90
  src/runtime/mod_fmr_rossfast_solver_selection_binding.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_groundwater_swap_forcing_adapter.f90
  src/runtime/mod_groundwater_swap_transaction_participant.f90
  src/runtime/mod_fmr_groundwater_head_forcing_adapter.f90
  src/runtime/mod_fmr_groundwater_swap_participant.f90
  src/runtime/mod_groundwater_interface_mass_ledger.f90
  src/runtime/mod_groundwater_tile_aggregation.f90
  src/runtime/mod_groundwater_multiswap_types.f90
  src/runtime/mod_modflow6_swap_predictor_response.f90
  src/runtime/mod_modflow6_swap_prescribed_qbot_bottom_face.f90
  src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90
  src/runtime/mod_modflow6_multiswap_cell_response.f90
)

run_one(){
  local opt="$1"
  local out="$BUILD/o$opt"
  mkdir -p "$out"
  local objects=()
  local source obj
  for source in "${MODULE_SRC[@]}"; do
    obj="$out/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$source" -o "$obj" || fail "compile $source O$opt"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c tests/research/test_hydro_memory_cap01_root_active_response.f90 -o "$out/test.o" || fail "compile CAP01 test O$opt"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$out/test.o" -o "$out/test" || fail "link CAP01 test O$opt"
  "$out/test" > "$out/output.txt" 2>&1 || { cat "$out/output.txt" >&2; fail "run CAP01 test O$opt"; }
}

run_one 0
run_one 2

for marker in   HMCAP01_ROOT_ACTIVE_REAL_TRIAL=PASS   HMCAP01_ROOT_ACTIVE_HARD_MASS=PASS   HMCAP01_ANALYTIC_ROOT_TANGENT_FAIL_CLOSED=PASS   HMCAP01_ROOT_ACTIVE_CENTERED_FD=PASS   HMCAP01_TYPED_ROOT_ACTIVE_FD_RESPONSE=PASS   HMCAP01_ROOT_SINK_IMMUTABLE_ACROSS_HEADS=PASS   HMCAP01_SAME_ORIGIN_CORRECTORS_ZERO_MUTATION=PASS   HMCAP01_ROOT_ACTIVE_LOCAL_SLOPE_AGREEMENT=PASS   HYDRO_MEMORY_CAP01_A_PASS_CENTERED_FD_ROUTE; do
  grep -Fq "$marker" "$BUILD/o0/output.txt" || { cat "$BUILD/o0/output.txt" >&2; fail "missing marker $marker"; }
done

diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || fail "O0/O2 output identity"
cat "$BUILD/o0/output.txt"
echo 'HMCAP01_A_O0_O2_OUTPUT_IDENTITY=PASS'
echo 'HYDRO_MEMORY_CAP01_A_GATE=PASS'
