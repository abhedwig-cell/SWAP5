#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ppa-low02-independent-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "PPA_LOW02_INDEPENDENT_GATE_FAIL $*" >&2; exit 1; }

AUDIT="docs/audits/PPA_WU02_SOURCE_BOUND_LOWER_BOUNDARY_ENVELOPE.md"
grep -Fq '24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2' "$AUDIT" || fail 'B1.11 manifest authority missing'
grep -Fq 'boundbottom.f90=5735f2b6e70408d304f6f5fa35ba659fb3422e03109630e27368933f5c10836e' "$AUDIT" || fail 'B1.11 BoundBottom identity missing'
grep -Fq 'readswap.f90' "$AUDIT" || fail 'B1.11 readswap authority missing'
grep -Fq 'At extremely dry bottom pressure head (< -1e7 cm)' "$AUDIT" || fail 'dry continuation authority missing'
grep -Fq 'sinusoid or time table' "$AUDIT" || fail 'time-law authority missing'

python3 - <<'PY'
from pathlib import Path
import json

pre = json.loads(Path("integration/audits/PPA_LOW02_TIME_PREREGISTRATION.json").read_text())
assert pre["authority"]["member_manifest_sha256"] == "24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2"
assert pre["authority"]["boundbottom_sha256"] == "5735f2b6e70408d304f6f5fa35ba659fb3422e03109630e27368933f5c10836e"
assert pre["authority"]["headcalc_sha256"] == "db667598dd0a9dbc2cd651d63f0074d3051db748fa45ee460da9c61904c113f5"

backend = Path("src/runtime/mod_fmr_serialized_reference_backend.f90").read_text().lower()
for token in [
    "twopi = 8.0_real64 * atan(1.0_real64)",
    "freq = twopi / 365.0_real64",
    "legacy_start_t1900",
    "legacy_end_t1900",
    "bottom_pressure_head_cm < b110_swbotb2_dry_head_cm",
    "effective_bottom_mode = -2",
    "value = y_table(1)",
    "value = y_table(size(y_table))",
    "physical_control%pressure_head(physical_control%active_nodes)",
    "request%boundary%bottom_mode = effective_bottom_mode",
    "request%boundary%bottom_flux = effective_bottom_flux",
]:
    assert token in backend, token

advance = backend[backend.index("subroutine fmr_serialized_advance"):backend.index("end subroutine fmr_serialized_advance")]
assert "self%bottom_mode =" not in advance
for forbidden in ["open(", "read(", "readswap", "swap_main", "ttutil"]:
    assert forbidden not in backend, forbidden

print("PPA_LOW02_INDEPENDENT_B111_AUTHORITY_LOCK=PASS")
print("PPA_LOW02_INDEPENDENT_BACKEND_NO_SELECTOR_MUTATION=PASS")
print("PPA_LOW02_INDEPENDENT_PARSER_FREE=PASS")
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
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/fvq/test_ppa_low02_time_independent.f90 -o "$OUT/test.o" || fail "compile test O$opt"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test" || fail "link O$opt"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "runtime O$opt"
  }
  grep '^PPA_LOW02_' "$OUT/output.txt" > "$OUT/stable.txt"
  grep -Fq 'PPA-LOW02-TIME INDEPENDENT QUALIFICATION PASS' "$OUT/output.txt" || fail "missing final marker O$opt"
done

diff -u "$BUILD/o0/stable.txt" "$BUILD/o2/stable.txt"
cat "$BUILD/o0/output.txt"

git diff --check -- \
  src/runtime/mod_fmr_serialized_reference_backend.f90 \
  tests/fvq/test_ppa_low02_time_independent.f90 \
  tests/fvq/run_ppa_low02_time_independent.sh

echo 'PPA_LOW02_INDEPENDENT_O0_O2_IDENTITY=PASS'
echo 'PPA-LOW02-TIME INDEPENDENT GATE PASS'
