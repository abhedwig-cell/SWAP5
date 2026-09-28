#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ppa-wu01-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "PPA_WU01_GATE_FAIL $*" >&2; exit 1; }

python3 - <<'PY'
from pathlib import Path

src = Path("src/runtime/mod_fmr_production_application_bootstrap.f90").read_text().lower()
test = Path("tests/fapp/test_ppa_wu01_production_application_bootstrap.f90").read_text().lower()
output_binding = Path("tests/fapp/test_ppa_output_canon_application_binding.f90").read_text().lower()

required = [
    "fmr_production_application_bootstrap_t",
    "fmr_run_serialized_physical_multiswap",
    "fmr_groundwater_participant_registry_t",
    "groundwater_interface_mass_ledger_t",
    "materialize_groundwater_application_plan",
    "register_fmr_groundwater_application_context",
    "release_fmr_groundwater_application_context",
]
for token in required:
    assert token in src, token

for forbidden in [
    "mod_fgc49d_application_context_fixture",
    "fgc49d_fixture_initialize_c",
    "xmiwrapper",
    "readswap",
    "swap_main",
    "open(",
]:
    assert forbidden not in src, forbidden

assert "tile%parameters%bottom_mode /= 5 .and. tile%parameters%bottom_mode /= 7" in src
assert "tile%parameters%bottom_mode /= 2" in src
runtime_src = Path("src/runtime/mod_fmr_serialized_multiswap_runtime.f90").read_text().lower()
assert "materialize_column_diagnostics" in runtime_src
assert "allocate(diagnostics(0))" in runtime_src
assert "summary diagnostics require column diagnostics" in runtime_src
assert "runtime diagnostics require column diagnostics" in runtime_src
assert "materialize_column_diagnostics=.false." in src
print("FPE_ZERO_WASTE01_COLUMN_DIAGNOSTICS_OPTOUT_STATIC=PASS")
backend_src = Path("src/runtime/mod_fmr_serialized_reference_backend.f90").read_text().lower()
assert "prepared_default_mvg_compatible" in backend_src
assert "prepared_default_mvg%cofgen(1:24,:) == parameters%cofgen(1:24,:)" in backend_src
assert "self%owned_hydraulic_parameters = parameters%prepared_default_mvg" in backend_src
assert "self%hydraulic_parameters => self%trusted_parameter_source%prepared_default_mvg" in backend_src
assert "nullify(self%model%trusted_parameter_source)" in backend_src
assert "prepare_fmr_b110_default_mvg" in src
print("FPE_ZERO_WASTE01_PREPARED_MVG_FAILSAFE_STATIC=PASS")
print("FPE_ZERO_WASTE01_H22B_BORROWED_BINDING_STATIC=PASS")
assert "production_application_groundwater_ready" in src
assert "groundwater_profile = groundwater_profile .and. config%tiles(i)%parameters%bottom_mode == 5" in src
assert "standalone_profile = standalone_profile .and. config%tiles(i)%parameters%bottom_mode == 7" in src
assert "if (groundwater_profile) then" in src
assert "macropore_active" in src
assert "frost_active" in src
assert "root_extraction_active" in src
assert "ppa-wu01 production application bootstrap gate pass" in test
assert "public :: production_application_serialize_canonical_result_text" in src
binding_start = src.index("subroutine production_application_serialize_canonical_result_text")
binding_end = src.index("end subroutine production_application_serialize_canonical_result_text", binding_start)
binding = src[binding_start:binding_end]
assert "type(canonical_result_t), intent(in) :: result" in binding
assert "call serialize_canonical_result_text(result, text)" in binding
for forbidden in ["open(", "read(", "write(", "close(", "newunit=", "file=", "get_command_argument", "get_environment_variable"]:
    assert forbidden not in binding, forbidden
assert "ppa_output_canon_application_byte_identity=pass" in output_binding
assert "ppa_output_canon_application_read_only_snapshot=pass" in output_binding

print("PPA_WU01_FORTRAN_FMR_OWNERSHIP_STATIC=PASS")
print("PPA_WU01_NO_QUALIFICATION_FIXTURE_PROMOTION_STATIC=PASS")
print("PPA_WU01_NO_LEGACY_PARSER_STATIC=PASS")
print("PPA_WU01_PROFILE_FAIL_CLOSED_STATIC=PASS")
print("PPA_WU01_GROUNDWATER_MODE5_CONTEXT_GUARD_STATIC=PASS")
print("PPA_WU01_OPTIONAL_GROUNDWATER_OWNERSHIP_STATIC=PASS")
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fopenmp -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/adapter/mod_canonical_result_text_adapter.f90
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
  src/process/mod_drainage_extended_exchange.f90
  src/runtime/mod_fmr_drainage_response_binding.f90
  src/solver/mod_b110_smooth_freatic_projection.f90
  src/runtime/mod_fmr_drainage_qbot_directional_binding.f90
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_direct_retention_core.f90
  src/solver/mod_b110_default_mvg_directional_provider.f90
  src/solver/mod_b110_direct_retention_provider.f90
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
  src/process/mod_irrigation_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_modflow6_swap_prescribed_qbot_bottom_face.f90
  src/runtime/mod_groundwater_swap_forcing_adapter.f90
  src/runtime/mod_groundwater_swap_transaction_participant.f90
  src/runtime/mod_fmr_groundwater_head_forcing_adapter.f90
  src/runtime/mod_fmr_groundwater_swap_participant.f90
  src/runtime/mod_fmr_groundwater_participant_registry.f90
  src/runtime/mod_groundwater_interface_mass_ledger.f90
  src/runtime/mod_groundwater_tile_aggregation.f90
  src/runtime/mod_groundwater_multiswap_types.f90
  src/runtime/mod_modflow6_swap_predictor_response.f90
  src/runtime/mod_modflow6_multiswap_cell_response.f90
  src/runtime/mod_modflow6_linear_response_backend.f90
  src/runtime/mod_modflow6_api_binding.f90
  src/runtime/mod_groundwater_topology_composition.f90
  src/runtime/mod_groundwater_application_plan.f90
  src/runtime/mod_fmr_groundwater_application_context.f90
  src/adapter/mod_fmr_groundwater_application_c_api.f90
  src/kernel/mod_kernel_committed_persistence.f90
  src/runtime/mod_fmr_restart_state_contract.f90
  src/runtime/mod_fmr_committed_restart.f90
  src/runtime/mod_fmr_production_application_bootstrap.f90
  src/process/mod_pmdirect_swetr0_process.f90
  src/crop/mod_crop_root_uptake_input_contract.f90
  src/adapter/mod_ppa_atm02_typed_meteo_ingestion.f90
  src/adapter/mod_ppa_atm02_pmdirect_daily_binding.f90
  src/adapter/mod_ppa_atm02_pmdirect_prescribed_root_sink.f90
  src/runtime/mod_fmr_pmdirect_surface_evaporation_binding.f90
  src/runtime/mod_fmr_pmdirect_swinter0_dynamic_top_binding.f90
  src/adapter/mod_ppa_atm02_pmdirect_production_forcing_adapter.f90
  src/process/mod_vonhhbraden_interception.f90
  src/adapter/mod_ppa_wu04c_vonhhbraden_forcing_adapter.f90
  src/adapter/mod_ppa_wu04c_dynamic_top_forcing_adapter.f90
  src/adapter/mod_ppa_wu04c_production_forcing_adapter.f90
  src/process/mod_gash_interception.f90
  src/adapter/mod_ppa_wu04d_gash_forcing_adapter.f90
  src/adapter/mod_ppa_wu04d_production_forcing_adapter.f90
  src/runtime/mod_fmr_vonhhbraden_source_window_progress.f90
  src/runtime/mod_ppa_wu04c_runtime_publication.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj" || fail "compile O$opt $source"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fapp/test_ppa_output_canon_application_binding.f90 -o "$OUT/output_canon_test.o" || fail "compile output binding test O$opt"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/output_canon_test.o" -o "$OUT/test_output_canon" || fail "link output binding test O$opt"
  "$OUT/test_output_canon" > "$OUT/output_canon.txt" 2>&1 || {
    cat "$OUT/output_canon.txt" >&2
    fail "output binding test O$opt"
  }
  grep '^PPA_OUTPUT_CANON_' "$OUT/output_canon.txt" > "$OUT/output_canon_stable.txt"
  grep -Fq 'PPA_OUTPUT_CANON_APPLICATION_BYTE_IDENTITY=PASS' "$OUT/output_canon.txt" || fail "missing output identity marker O$opt"
  grep -Fq 'PPA_OUTPUT_CANON_APPLICATION_READ_ONLY_SNAPSHOT=PASS' "$OUT/output_canon.txt" || fail "missing read-only marker O$opt"
  echo "PPA_OUTPUT_CANON_APPLICATION_O${opt}=PASS"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fapp/test_ppa_wu01_production_application_bootstrap.f90 -o "$OUT/test.o" || fail "compile test O$opt"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test_ppa_wu01" || fail "link O$opt"

  "$OUT/test_ppa_wu01" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "runtime O$opt"
  }
  grep '^PPA_WU01_' "$OUT/output.txt" > "$OUT/stable.txt"
  grep -Fq 'PPA-WU01 PRODUCTION APPLICATION BOOTSTRAP GATE PASS' "$OUT/output.txt" || fail "missing final marker O$opt"
  echo "PPA_WU01_O${opt}=PASS"
done

diff -u "$BUILD/o0/output_canon_stable.txt" "$BUILD/o2/output_canon_stable.txt"
echo 'PPA_OUTPUT_CANON_APPLICATION_O0_O2_IDENTITY=PASS'
diff -u "$BUILD/o0/stable.txt" "$BUILD/o2/stable.txt"
cat "$BUILD/o0/output.txt"

git diff --check --   src/runtime/mod_fmr_production_application_bootstrap.f90   tests/fapp/test_ppa_wu01_production_application_bootstrap.f90   tests/fapp/run_ppa_wu01_production_application_bootstrap.sh

echo 'PPA_WU01_O0_O2_OUTPUT_IDENTITY=PASS'
echo 'PPA-WU01 PRODUCTION APPLICATION BOOTSTRAP OWNER GATE PASS'
