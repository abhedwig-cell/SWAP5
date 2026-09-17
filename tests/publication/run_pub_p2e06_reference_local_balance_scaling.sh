#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-p2e06-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "PUB_P2E06_GATE_FAIL $*" >&2; exit 1; }

TEST=tests/publication/test_pub_p2e06_reference_local_balance_scaling.f90
PREREG=docs/publication/P2E06_REFERENCE_LOCAL_BALANCE_SCALING_PREREGISTRATION.json
BASE_SRC_TREE=10109695195d3f4c715d532bff07551ff639f0a6
BASE_REFERENCE_TREE=684f1e2889b6992e5aedc88f52bb45f4558bb3e4
FROSS13_CANONICAL_BASE=d223b7ab4ed297194c209f85d6b51bef86b79959
FROSS13_PRODUCTION=0fdba1a603ffd54eff7ee92a3cd7001f2b802678
FROSS13_MODEL=src/runtime/mod_rossfast_d3r_model_binding.f90
FROSS13_PROVIDER=src/solver/mod_rossfast_d3r_table_provider.f90
FROSS13_MODEL_POSTIMAGE=5442fd7e7a2f392c9b796cd17c76b17977259f22
FROSS13_PROVIDER_POSTIMAGE=ac997bf06c56a37080d1c8db69b6d4208f4b75ca

[[ -f "$PREREG" ]] || fail 'missing preregistration'
grep -Fq '"phase": "PREREGISTERED_BEFORE_DIAGNOSTIC_EXECUTION"' "$PREREG" || fail 'preregistration phase missing'
grep -Fq '"rossfast_execution_allowed": false' "$PREREG" || fail 'RossFast execution firewall missing'
grep -Fq '"production_or_reference_source_change_allowed": false' "$PREREG" || fail 'source-change firewall missing'
grep -Fq '"production_tolerance_change_allowed": false' "$PREREG" || fail 'production-tolerance firewall missing'

# P2E06 is evidence-only. Preserve its exact P2E05 scientific denominator.
# A later independently admitted canonical successor may run the unchanged
# diagnostic only when Reference is byte-identical and the candidate delta
# above that pinned canonical is exactly the qualified F-ROSS13 two-file change.
if [[ "$(git rev-parse HEAD:src)" == "$BASE_SRC_TREE" ]] && \
   [[ "$(git rev-parse HEAD:reference)" == "$BASE_REFERENCE_TREE" ]]; then
  echo 'PUB_P2E06_EXACT_P2E05_SCIENTIFIC_DENOMINATOR=PASS'
else
  git merge-base --is-ancestor "$FROSS13_CANONICAL_BASE" HEAD || fail 'current F-ROSS13 canonical admission base is not an ancestor'
  git merge-base --is-ancestor "$FROSS13_PRODUCTION" HEAD || fail 'qualified F-ROSS13 production commit is not an ancestor'
  test "$(git rev-parse "$FROSS13_CANONICAL_BASE:reference")" = "$BASE_REFERENCE_TREE" || fail 'current canonical Reference does not preserve P2E05 authority'
  test "$(git rev-parse HEAD:reference)" = "$BASE_REFERENCE_TREE" || fail 'reference tree differs from P2E05 canonical base'
  test "$(git rev-parse HEAD:$FROSS13_MODEL)" = "$FROSS13_MODEL_POSTIMAGE" || fail 'F-ROSS13 model-binding postimage mismatch'
  test "$(git rev-parse HEAD:$FROSS13_PROVIDER)" = "$FROSS13_PROVIDER_POSTIMAGE" || fail 'F-ROSS13 provider postimage mismatch'

  mapfile -t src_delta < <(git diff --name-only "$FROSS13_CANONICAL_BASE" HEAD -- src | sort)
  expected=(src/runtime/mod_rossfast_d3r_model_binding.f90 src/solver/mod_rossfast_d3r_table_provider.f90)
  test "${#src_delta[@]}" -eq 2 || fail 'F-ROSS13 successor src delta above current canonical is not exactly two files'
  test "${src_delta[0]}" = "${expected[0]}" || fail 'unexpected first F-ROSS13 successor src delta'
  test "${src_delta[1]}" = "${expected[1]}" || fail 'unexpected second F-ROSS13 successor src delta'
  echo 'PUB_P2E06_CURRENT_CANONICAL_REFERENCE_PRESERVED=PASS'
  echo 'PUB_P2E06_FROSS13_BOUNDED_SEMANTIC_SUCCESSOR=PASS'
fi

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
  src/runtime/mod_rossfast_d3r_execution_policy.f90
  src/runtime/mod_rossfast_d3r_model_binding.f90
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
    fail "Reference local-balance diagnostic O$opt"
  fi
  for marker in \
    'PUB_P2E06_CASE_COUNT=162' \
    'PUB_P2E06_ACCEPTED_COUNT=47' \
    'PUB_P2E06_TOTAL_ONLY_COUNT=12' \
    'PUB_P2E06_LOCAL_BAL_COUNT=103' \
    'PUB_P2E06_ROSSFAST_SOLVER_EXECUTED=FALSE' \
    'PUB_P2E06_PRODUCTION_TOLERANCE_CHANGED=FALSE' \
    'PUB_P2E06_REFERENCE_LOCAL_BALANCE_SCALING=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing O$opt marker $marker"; }
  done
  cat "$OUT/output.txt"
  echo "PUB_P2E06_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 Reference local-balance diagnostic drift'
}

echo "PUB_P2E06_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'PUB_P2E06_REFERENCE_LOCAL_BALANCE_GATE=PASS'
