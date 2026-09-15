#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fkt22-eb-i25-preservation-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail(){ echo "FKT22_EB_I25_PRESERVATION_FAIL $*" >&2; exit 1; }

# Preservation is semantic, not an obsolete exact-blob lock. F-KT22 must keep
# the admitted EB-I25 transaction-local carrier behavior while extending the
# same serialized backend with accepted-trajectory directional provenance.
grep -Fq 'type(fmr_top_sensible_boundary_carrier_t) :: top_sensible_boundary_carrier' \
  src/runtime/mod_fmr_serialized_reference_backend.f90 || fail 'EB-I25 top carrier missing'
grep -Fq 'call self%top_sensible_boundary_carrier%copy_to(typed%top_sensible_boundary_carrier)' \
  src/runtime/mod_fmr_serialized_reference_backend.f90 || fail 'EB-I25 capture missing'
grep -Fq 'call self%top_sensible_boundary_carrier%restore_from(typed%top_sensible_boundary_carrier)' \
  src/runtime/mod_fmr_serialized_reference_backend.f90 || fail 'EB-I25 restore missing'
grep -Fq 'record_top_sensible_boundary_sample' src/runtime/mod_fmr_serialized_reference_backend.f90 || \
  fail 'EB-I25 accepted-step sampling missing'
grep -Fq 'type(accepted_trajectory_direction_t) :: trajectory_direction' \
  src/runtime/mod_fmr_serialized_reference_backend.f90 || fail 'F-KT22 transactional trajectory missing'
grep -Fq 'call accept_trajectory_step' src/runtime/mod_fmr_serialized_reference_backend.f90 || \
  fail 'F-KT22 accepted-step promotion missing'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
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
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/runtime/mod_fmr_top_sensible_boundary_carrier.f90
  src/process/mod_liquid_water_sensible_enthalpy.f90
  src/runtime/mod_fmr_bottom_external_thermal_binding.f90
  src/runtime/mod_fmr_bottom_external_thermal_provider.f90
  src/runtime/mod_fmr_bottom_sensible_energy.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_owned_commit_receipt.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/process/mod_linear_mixture_sensible_storage.f90
  src/kernel/mod_energy_conservation_types.f90
  src/process/mod_whole_column_sensible_energy_accounting.f90
  src/runtime/mod_eb_i23_sensible_boundary_runtime.f90
  src/process/mod_external_liquid_water_temperature.f90
  src/runtime/mod_eb_i24_top_liquid_sensible_inflow_runtime.f90
  src/runtime/mod_eb_i25_multisubstep_sensible_boundary_runtime.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj" || \
      fail "compile O$opt $source"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/eb/test_eb_i25_multisubstep_sensible_boundary_runtime.f90 -o "$OUT/test.o" || \
    fail "compile EB-I25 oracle O$opt"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test" || fail "link EB-I25 oracle O$opt"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "EB-I25 runtime O$opt"; }
  for marker in \
    'EB_I25_TWO_HALF_ACCEPTED_AGGREGATION=PASS' \
    'EB_I25_MISSING_TOP_DONOR_FAIL_CLOSED=PASS' \
    'EB_I25_OUTFLOW_FIXTURE_REJECTED_NO_PUBLICATION=PASS' \
    'EB_I25_SINGLE_SUBSTEP_I24_EQUIVALENCE=PASS' \
    'EB_I25_REJECTED_TRIAL_NO_PUBLICATION=PASS' \
    'EB_I25_MULTISUBSTEP_SENSIBLE_BOUNDARY_GATE=PASS'; do
    grep -Fxq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing O$opt marker $marker"; }
  done
  cat "$OUT/output.txt"
  echo "FKT22_EB_I25_PRESERVATION_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'EB-I25 O0/O2 semantic drift under F-KT22 recomposition'
}

echo 'FKT22_EB_I25_O0_O2_IDENTITY=PASS'
echo 'FKT22_EB_I25_PRESERVATION_GATE=PASS'
