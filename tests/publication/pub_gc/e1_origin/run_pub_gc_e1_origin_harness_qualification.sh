#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT"
fail() { echo "PUB_GC_E1_GATE_FAIL $*" >&2; exit 1; }

CANONICAL_BASE="8e0de81a62527bc7d8e49068f1ffd4a8a85aeec3"
SPEC_COMMIT="e85786ff687eb03994d528126f0c2f5a7eeec7e1"
SPEC_PATH="docs/publications/PUB-GC_E1_ORIGIN_HARNESS_SPEC.md"
TEST="tests/publication/pub_gc/e1_origin/test_pub_gc_e1_origin_harness.f90"
RUNNER="tests/publication/pub_gc/e1_origin/run_pub_gc_e1_origin_harness_qualification.sh"
WORKFLOW=".github/workflows/pub-gc-e1-origin-harness.yml"

# Chronology and research-only scope are qualification preconditions.
git cat-file -e "$SPEC_COMMIT^{commit}" || fail "missing frozen E1 specification commit"
git cat-file -e "$SPEC_COMMIT:$SPEC_PATH" || fail "missing frozen E1 specification file"
git merge-base --is-ancestor "$CANONICAL_BASE" HEAD || fail "research head does not descend from canonical base"
[[ -z "$(git diff --name-only "$CANONICAL_BASE..HEAD" -- 'src/**' 'reference/**')" ]] || \
  fail "production/reference mutation present on research branch"
git diff --check -- "$TEST" "$RUNNER" "$WORKFLOW" || fail "diff check"

echo "PUB_GC_E1_CANONICAL_BASE=PASS:$CANONICAL_BASE"
echo "PUB_GC_E1_FROZEN_SPEC=PASS:$SPEC_COMMIT"
echo 'PUB_GC_E1_RESEARCH_ONLY_SCOPE=PASS'

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-gc-e1-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -fopenmp -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/transaction/mod_transaction_reference.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
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
  src/adapter/mod_reference_richards_accepted_step_directional_service.f90
  src/adapter/mod_b110_serialized_context_binding.f90
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
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/runtime/mod_fmr_top_sensible_boundary_carrier.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_owned_commit_receipt.f90
  src/runtime/mod_fmr_bottom_external_thermal_binding.f90
  src/runtime/mod_fmr_bottom_external_thermal_provider.f90
  src/process/mod_liquid_water_sensible_enthalpy.f90
  src/runtime/mod_fmr_bottom_sensible_energy.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    [[ -f "$source" ]] || fail "missing compile source $source"
    obj="$OUT/$(basename "${source%.*}").o"
    extra=()
    [[ "$source" == "src/solver/mod_soil_water_solver_contract.f90" ]] && extra=(-Wno-error=unused-dummy-argument)
    gfortran "${COMMON[@]}" "${extra[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/test.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"

  if ! "$OUT/test" > "$OUT/output.txt" 2>&1; then
    cat "$OUT/output.txt" >&2
    fail "real-SWAP E1 oracle O$opt"
  fi
  for marker in \
    PUB_GC_E1_REAL_B110_MODE5 \
    PUB_GC_E1_SAME_ORIGIN_A_B_A_REPLAY \
    PUB_GC_E1_SAME_ORIGIN_ENDPOINT_IDENTITY \
    PUB_GC_E1_HISTORY_DIAG_PUBLIC_SNAPSHOT_INITIALIZE \
    PUB_GC_E1_ACCEPTED_ORIGIN_NONPUBLICATION \
    PUB_GC_E1_WHOLE_WINDOW_AND_TERMINAL_OBSERVABLES \
    PUB_GC_E1_ORIGIN_HARNESS_ORACLE; do
    grep -q "^${marker}=PASS$" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing O$opt marker $marker"; }
  done
  cat "$OUT/output.txt"
  echo "PUB_GC_E1_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail "O0/O2 origin-harness semantic drift"
}

echo "PUB_GC_E1_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo "PUB_GC_E1_RESEARCH_HEAD=$(git rev-parse HEAD)"
echo "PUB_GC_E1_TEST_BLOB=$(git rev-parse HEAD:$TEST)"
echo "PUB_GC_E1_RUNNER_BLOB=$(git rev-parse HEAD:$RUNNER)"
echo 'PUB_GC_E1_H1_EFFECT_NOT_TESTED=PASS'
echo 'PUB_GC_E1_ORIGIN_HARNESS_QUALIFICATION=PASS'
