#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ppa-low02-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "PPA_LOW02_GATE_FAIL $*" >&2; exit 1; }

CANONICAL="e473afc2d378a2567a59cc0db1577b4c724feeb2"
LOW02_ADMISSION="6c63b8d0e340669d9722bc5e3d947d42d2b467a5"
LOW02_BACKEND_BLOB="80c7ca618ea228e31ac43ae493f16dd6eccc5991"
ROOT_HYD01_ADMISSION="308a619c91d2cc3dae7f7aa143cfbe97c780c635"
ROOT_HYD01_TEMPORAL_BLOB="2068215a57edb1d2a59c36d6b32f519ebdc09ebd"
PPA_WU04A_ADMISSION="50e7d1dece5b75d0103459d5c118d03a2665eea3"
PPA_WU04A_QUALIFIED="f1fd0fa5633cea1fa5f3870eb2aa7b236d40a938"
PPA_WU04A_BACKEND_BLOB="b1ba0549ef9149c4261b8a595c8782be01726c43"
PPA_WU04A_BOOTSTRAP_BLOB="9ae38276a353bd08f5d971d6368eed41967086b6"
PPA_WU04B_ADMISSION="4d40b8d4b6a1df06ff97fab55497542778431290"
PPA_WU04B_QUALIFIED="eb0e635975b77ec92084e1416038b1bc1f8232bc"
PPA_WU04B_BACKEND_BLOB="9bd344a83afd5e10b96178933362dbb7eeea4f30"
PPA_WU04B_BOOTSTRAP_BLOB="356b3825a8ba13af1fed385ab17ffdb330b1058f"

if git merge-base --is-ancestor "$PPA_WU04B_ADMISSION" HEAD; then
  git merge-base --is-ancestor "$PPA_WU04B_QUALIFIED" "$PPA_WU04B_ADMISSION" || \
    fail 'PPA-WU04-B qualified head is not contained by canonical admission'
  [[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == "$PPA_WU04B_BACKEND_BLOB" ]] || \
    fail 'admitted PPA-WU04-B backend successor drift'
  [[ "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" == "$PPA_WU04B_BOOTSTRAP_BLOB" ]] || \
    fail 'admitted PPA-WU04-B bootstrap successor drift'
  echo 'PPA_LOW02_WU04B_BACKEND_BOOTSTRAP_SUCCESSOR=PASS'
elif git merge-base --is-ancestor "$PPA_WU04A_ADMISSION" HEAD; then
  git merge-base --is-ancestor "$PPA_WU04A_QUALIFIED" "$PPA_WU04A_ADMISSION" || \
    fail 'PPA-WU04-A qualified head is not contained by canonical admission'
  [[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == "$PPA_WU04A_BACKEND_BLOB" ]] || \
    fail 'admitted PPA-WU04-A backend successor drift'
  [[ "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" == "$PPA_WU04A_BOOTSTRAP_BLOB" ]] || \
    fail 'admitted PPA-WU04-A bootstrap successor drift'
  echo 'PPA_LOW02_WU04A_BACKEND_BOOTSTRAP_SUCCESSOR=PASS'
elif git merge-base --is-ancestor "$LOW02_ADMISSION" HEAD; then
  [[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == "$LOW02_BACKEND_BLOB" ]] || \
    fail 'admitted PPA-LOW02 backend successor drift'
  echo 'PPA_LOW02_CURRENT_BACKEND_SUCCESSOR=PASS'
else
  changed_src="$(git diff --name-only "$CANONICAL"...HEAD -- src | sort)"
  expected_src=$'src/runtime/mod_fmr_serialized_reference_backend.f90'
  [[ "$changed_src" == "$expected_src" ]] || fail "unexpected production delta: $changed_src"
fi

for locked in \
  src/adapter/mod_b110_serialized_context_binding.f90 \
  src/solver/mod_soil_water_solver_contract.f90 \
  src/legacy/b1_10_port/headcalc.f90 \
  src/runtime/mod_fmr_legacy_bottom_boundary_application_binding.f90; do
  [[ "$(git rev-parse "HEAD:$locked")" == "$(git rev-parse "$CANONICAL:$locked")" ]] || fail "inherited authority drift: $locked"
done

if ! git merge-base --is-ancestor "$PPA_WU04A_ADMISSION" HEAD; then
  [[ "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" == \
     "$(git rev-parse "$CANONICAL:src/runtime/mod_fmr_production_application_bootstrap.f90")" ]] || \
    fail 'pre-PPA-WU04 bootstrap drift'
fi

if git merge-base --is-ancestor "$ROOT_HYD01_ADMISSION" HEAD; then
  [[ "$(git rev-parse HEAD:src/solver/mod_reference_richards_temporal_indicator.f90)" == "$ROOT_HYD01_TEMPORAL_BLOB" ]] || \
    fail 'admitted PPA-ROOT-HYD01 temporal-indicator successor drift'
  echo 'PPA_LOW02_ROOT_HYD01_TEMPORAL_SUCCESSOR=PASS'
else
  [[ "$(git rev-parse HEAD:src/solver/mod_reference_richards_temporal_indicator.f90)" == \
     "$(git rev-parse "$CANONICAL:src/solver/mod_reference_richards_temporal_indicator.f90")" ]] || \
    fail 'pre-ROOT-HYD01 temporal-indicator drift'
fi

grep -Fq '"production_canonical_admitted": true' integration/f-ci/F-CI62P_STATUS.json || fail 'F-CI62 prescribed-qbot canonical authority missing'
grep -Fq '"decision": "QUALIFIED_FOR_CURRENT_CANONICAL_ADMISSION_REVIEW"' qualification/F-VQ75_STATUS.json || fail 'F-VQ75 independent qbot authority missing'
grep -Fq '"status": "CANONICAL_ADMITTED_CLOSED"' integration/audits/PPA_WU02_STATUS.json || fail 'PPA-WU02 application authority missing'

python3 - <<'PY'
from pathlib import Path

backend = Path("src/runtime/mod_fmr_serialized_reference_backend.f90").read_text().lower()
test = Path("tests/fapp/test_ppa_low02_time_application_admission.f90").read_text().lower()

for token in [
    "sinave + self%sinamp * cos(freq * (legacy_t - self%sinmax))",
    "legacy_end_t1900",
    "afgen_pairs",
    "bottom_pressure_head_cm < b110_swbotb2_dry_head_cm",
    "effective_bottom_mode = -2",
    "effective_bottom_mode = 2",
    "calendar_year_start_t1900",
]:
    assert token in backend, token

for forbidden in ["open(", "read(", "readswap", "swap_main", "ttutil"]:
    assert forbidden not in backend, forbidden

assert "legacy_swbotb2_control" in backend
assert "physical_control%pressure_head(physical_control%active_nodes)" in backend
assert "request%boundary%bottom_mode = effective_bottom_mode" in backend
assert "request%boundary%bottom_flux = effective_bottom_flux" in backend
assert "self%bottom_mode /= 2" in backend
assert "soil_water_selection%uses_reference()" in backend
assert "ppa-low02-time owner qualification pass" in test

print("PPA_LOW02_SOURCE_SEMANTICS_STATIC=PASS")
print("PPA_LOW02_PARSER_FREE_TYPED_CONTROL_STATIC=PASS")
print("PPA_LOW02_TRIAL_START_STATE_BINDING_STATIC=PASS")
print("PPA_LOW02_NO_SECOND_SELECTOR_STATE_STATIC=PASS")
print("PPA_LOW02_REFERENCE_ONLY_FAIL_CLOSED_STATIC=PASS")
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
  src/solver/mod_b110_adaptive_hydraulic_builder.f90
  src/solver/mod_b110_adaptive_hydraulic_cache.f90
  src/solver/mod_b110_adaptive_hydraulic_provider.f90
  src/solver/mod_b110_default_mvg_directional_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
  src/solver/mod_b110_root_sink_provider.f90
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
  src/runtime/mod_fmr_production_application_bootstrap.f90
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
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fapp/test_ppa_low02_time_application_admission.f90 -o "$OUT/test.o" || fail "compile test O$opt"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test_ppa_low02" || fail "link O$opt"

  "$OUT/test_ppa_low02" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "runtime O$opt"
  }
  grep '^PPA_LOW02_' "$OUT/output.txt" > "$OUT/stable.txt"
  grep -Fq 'PPA-LOW02-TIME OWNER QUALIFICATION PASS' "$OUT/output.txt" || fail "missing final marker O$opt"
  echo "PPA_LOW02_O${opt}=PASS"
done

diff -u "$BUILD/o0/stable.txt" "$BUILD/o2/stable.txt"
cat "$BUILD/o0/output.txt"

git diff --check -- \
  src/runtime/mod_fmr_serialized_reference_backend.f90 \
  tests/fapp/test_ppa_low02_time_application_admission.f90 \
  tests/fapp/run_ppa_low02_time_application_admission.sh

echo 'PPA_LOW02_O0_O2_OUTPUT_IDENTITY=PASS'
echo 'PPA-LOW02-TIME OWNER GATE PASS'
