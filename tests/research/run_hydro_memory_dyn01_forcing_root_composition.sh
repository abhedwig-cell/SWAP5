#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-hm-dyn01-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "HYDRO_MEMORY_DYN01_FAIL $*" >&2; exit 73; }

BASE=831d1d000899422099eaa702870c3c22a4b8bb7d
git merge-base --is-ancestor "$BASE" HEAD || fail "branch not descended from F2 canonical authority"
git diff --quiet "$BASE"..HEAD -- src || fail "DYN01 changed production source"
git diff --quiet "$BASE"..HEAD -- reference || fail "DYN01 changed reference source"
grep -Fq '"state": "CANONICAL_ADMITTED_CLOSED"' integration/audits/PPA_WU03_STATUS.json || fail "PPA-WU03 authority missing"
grep -Fq '"decision": "QUALIFIED_CLOSED_REFERENCE_ET_TO_RESTRICTED_ROOT_UPTAKE_EXECUTION_CANONICAL_ADMISSION"' integration/f-ci/F-CI31_STATUS.json || fail "F-CI31 authority missing"
echo 'HYDRO_MEMORY_DYN01_AUTHORITY_LOCK=PASS'

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
  src/solver/mod_b110_root_sink_provider.f90
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
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/runtime/mod_fmr_soil_water_application_host.f90
  src/runtime/mod_rossfast_d3r_execution_policy.f90
  src/runtime/mod_rossfast_d3r_model_binding.f90
  src/solver/mod_rossfast_d3r_table_kernel.f90
  src/solver/mod_rossfast_d3r_table_provider.f90
  src/solver/mod_rossfast_d3r_soil_water_solver.f90
  src/runtime/mod_fmr_rossfast_solver_selection_binding.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_process_hydraulic_view_binding.f90
  src/process/mod_root_water_uptake_process.f90
  src/runtime/mod_fmr_root_uptake_process_binding.f90
  src/crop/mod_crop_root_uptake_input_contract.f90
  src/runtime/mod_fmr_crop_root_uptake_input_adapter.f90
  src/process/mod_reference_et_demand_process.f90
  src/runtime/mod_fmr_reference_et_demand_binding.f90
  src/runtime/mod_fmr_reference_et_ptra_root_input_binding.f90
  src/runtime/mod_fmr_reference_et_root_uptake_composition.f90
  src/adapter/mod_ppa_wu03_common_forcing_adapter.f90
)

run_one(){
  local opt="$1" out="$BUILD/o$1"
  mkdir -p "$out"
  local objects=() source obj
  for source in "${MODULE_SRC[@]}"; do
    obj="$out/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$source" -o "$obj" || fail "compile O$opt $source"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c tests/research/test_hydro_memory_dyn01_forcing_root_composition.f90 -o "$out/test.o" || fail "compile DYN01 test O$opt"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$out/test.o" -o "$out/test" || fail "link DYN01 test O$opt"
  "$out/test" > "$out/output.txt" 2>&1 || { cat "$out/output.txt" >&2; fail "run DYN01 O$opt"; }
}
run_one 0
run_one 2

for marker in \
  HYDRO_MEMORY_DYN01_REFERENCE_ET_MAPPING=PASS \
  HYDRO_MEMORY_DYN01_DYNAMIC_TOP_MAPPING=PASS \
  HYDRO_MEMORY_DYN01_ACCEPTED_STATE_DEPENDENT_FEDDES=PASS \
  HYDRO_MEMORY_DYN01_STATELESS_REPLAY=PASS \
  HYDRO_MEMORY_DYN01_GATE=PASS; do
  grep -Fxq "$marker" "$BUILD/o0/output.txt" || { cat "$BUILD/o0/output.txt" >&2; fail "missing marker $marker"; }
done
diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || fail "O0/O2 output identity"
cat "$BUILD/o0/output.txt"
echo 'HYDRO_MEMORY_DYN01_O0_O2_OUTPUT_IDENTITY=PASS'
echo 'HYDRO_MEMORY_DYN01_QUALIFICATION=PASS'
