#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ftab02d-dynamic-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "F_TAB02_D_DYNAMIC_GATE_FAIL $*" >&2; exit 1; }

python3 - <<'PY'
from pathlib import Path
contract=Path("src/solver/mod_soil_water_solver_contract.f90").read_text()
temporal=Path("src/solver/mod_reference_richards_temporal_indicator.f90").read_text()
generated=Path("src/solver/mod_b110_generated_mvg_provider.f90").read_text()
test=Path("tests/fsi/test_ftab02d_generated_temporal_certificate.f90").read_text()

assert "procedure :: context_compatible => constitutive_context_incompatible" in contract
assert "request%evaluation%constitutive%context_compatible(dt)" in temporal
assert "select type (constitutive => request%evaluation%constitutive)" not in temporal
assert "b110_default_mvg_provider_t" not in temporal
assert "procedure :: context_compatible => b110_generated_mvg_context_compatible" in generated
assert "TX_TEMPORAL_MODEL_CERTIFICATE" in test
assert "qualification_head_budget = 2.5e-11_real64" in test
assert "parameters%generated_mvg_acceleration_active = generated" in test
assert "temporal_head_inf_bound <= qualification_head_budget" in test
print("F_TAB02_D_DYNAMIC_COMMON_CONTEXT_CAPABILITY=PASS")
print("F_TAB02_D_DYNAMIC_EXISTING_HEAD_BUDGET_PRESERVED=PASS")
print("F_TAB02_D_DYNAMIC_EXPLICIT_GENERATED_SELECTION=PASS")
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fopenmp -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -O2)
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
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
)

objs=()
for source in "${MODULES[@]}"; do
  obj="$BUILD/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj" || fail "compile $source"
  objs+=("$obj")
done

gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD"   -c tests/fsi/test_ftab02d_generated_temporal_certificate.f90 -o "$BUILD/test.o" || fail "compile dynamic oracle"
gfortran -O2 -fopenmp "${objs[@]}" "$BUILD/test.o" -o "$BUILD/test" || fail "link dynamic oracle"

"$BUILD/test" > "$BUILD/output.txt" 2>&1 || {
  cat "$BUILD/output.txt" >&2
  fail "runtime dynamic oracle"
}
cat "$BUILD/output.txt"

for marker in   'F_TAB02_D_GENERATED_TEMPORAL_CERTIFICATE=PASS'   'F_TAB02_D_DYNAMIC_TRANSACTION_SEMANTICS=PASS'   'F-TAB02-D DYNAMIC CERTIFICATE GATE PASS'; do
  grep -Fq "$marker" "$BUILD/output.txt" || fail "missing marker $marker"
done

echo "F-TAB02-D DYNAMIC OWNER QUALIFICATION PASS"
