#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ftab02c-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

python3 - <<'PY'
from pathlib import Path
s=Path("src/runtime/mod_fmr_serialized_reference_backend.f90").read_text()
assert "logical :: generated_mvg_acceleration_active = .false." in s
assert "request%evaluation%constitutive => self%generated_constitutive" in s
assert ".not. parameters%tabulated_hydraulics_active" in s
assert "self%generated_mvg_state%matches(self%hydraulic_parameters)" in s
assert s.count("initialize_b110_generated_mvg_table_state(self%generated_mvg_state") == 1
configure=s[s.index("subroutine fmr_serialized_configure_parameters"):s.index("end subroutine fmr_serialized_configure_parameters")]
advance=s[s.index("subroutine fmr_serialized_advance"):s.index("end subroutine fmr_serialized_advance")]
assert "initialize_b110_generated_mvg_table_state" in configure
assert "initialize_b110_generated_mvg_table_state" not in advance
assert "bind_b110_generated_mvg_provider" in advance
print("F_TAB02_C_GENERATION_OUTSIDE_TRIAL_HOTLOOP=PASS")
print("F_TAB02_C_EXACT_PARAMETER_AUTHORITY_CACHE=PASS")
print("F_TAB02_C_EXPLICIT_PROVIDER_SELECTION_STATIC=PASS")
PY

COMMON=(-std=f2008 -ffree-line-length-none -O2 -fopenmp -fcheck=all -fbacktrace)
MODULES=(
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
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_owned_commit_receipt.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/process/mod_liquid_water_sensible_enthalpy.f90
  src/runtime/mod_fmr_bottom_external_thermal_binding.f90
  src/runtime/mod_fmr_bottom_external_thermal_provider.f90
  src/runtime/mod_fmr_bottom_sensible_energy.f90
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
  src/solver/mod_b110_generated_mvg_tspack.f90
  src/solver/mod_b110_generated_mvg_table_state.f90
  src/solver/mod_b110_generated_mvg_provider.f90
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
)

objs=()
for source in "${MODULES[@]}"; do
  obj="$BUILD/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj"
  objs+=("$obj")
done

gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c tests/fsi/test_ftab02c_serialized_generated_provider.f90 -o "$BUILD/test.o"
gfortran -O2 -fopenmp "${objs[@]}" "$BUILD/test.o" -o "$BUILD/test_ftab02c"
OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$BUILD/test_ftab02c" > "$BUILD/output.txt"
cat "$BUILD/output.txt"

grep -Fq 'F-TAB02-C SERIALIZED PROVIDER SELECTION GATE PASS' "$BUILD/output.txt"
grep -Fq 'F_TAB02_C_GENERIC_TABULATED_FAIL_CLOSED=PASS' "$BUILD/output.txt"
grep -Fq 'F_TAB02_C_REPEATED_GENERATED_IDENTITY=PASS' "$BUILD/output.txt"

git diff --check --   src/runtime/mod_fmr_serialized_reference_backend.f90   tests/fsi/test_ftab02c_serialized_generated_provider.f90   tests/fsi/run_ftab02c_serialized_generated_provider.sh

echo "F-TAB02-C OWNER QUALIFICATION PASS"
