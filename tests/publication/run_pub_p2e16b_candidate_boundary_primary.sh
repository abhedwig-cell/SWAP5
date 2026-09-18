#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-p2e16b-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "PUB_P2E16B_GATE_FAIL $*" >&2; exit 1; }

PREREG=docs/publication/P2E16B_CANDIDATE_BOUNDARY_PRIMARY_PREREGISTRATION.json
STAGE_A_RESULT=docs/publication/P2E16A_REFERENCE_BOUNDARY_THRESHOLD_TRANSFER_RESULT.json
TEST=tests/publication/test_pub_p2e16b_candidate_boundary_primary.f90
PARENT_BASE=409b1047764d8ae4a04b13d55b490af3225e7067

PREREG_BLOB=5e0d1722d9f99e2bef32b461e259b69434ae5d3b
TEST_BLOB=77e3b027119a7d1bfe8d4745a45ec3174118424a
STAGE_A_RESULT_BLOB=2c9b856e2d18d5d8e42c098f12b6405e5e15ff58
P2E14_RESULT_BLOB=f9f49ce5f0f239d1c1cdd4575a4da65cd84c0351
SOLVER_CONTRACT_BLOB=40a1ddc05fb8e2c1822763de645fd07a094568a3
REFERENCE_BINDING_BLOB=4b545c6fb260e81cd6c8f4d2d65f2beee7281e53
ROSSFAST_SOLVER_BLOB=dbb441f3529be179d64fb57f9c44336d3d20c540
ROSSFAST_MODEL_BINDING_BLOB=5442fd7e7a2f392c9b796cd17c76b17977259f22
ROSSFAST_EXECUTION_POLICY_BLOB=a39a636d01f373ae6ef0dc3ac0e1e25b6522fda9
ROSSFAST_TABLE_PROVIDER_BLOB=ac997bf06c56a37080d1c8db69b6d4208f4b75ca
ROSSFAST_TABLE_KERNEL_BLOB=034136c193b287bcf9a953a9b89df2a8fb0c97cc

[[ -f "$PREREG" ]] || fail 'missing P2E16B preregistration'
[[ -f "$STAGE_A_RESULT" ]] || fail 'missing P2E16A result'
[[ -f "$TEST" ]] || fail 'missing P2E16B test'

test "$(git rev-parse HEAD:$PREREG)" = "$PREREG_BLOB" || fail 'P2E16B preregistration drift'
test "$(git rev-parse HEAD:$STAGE_A_RESULT)" = "$STAGE_A_RESULT_BLOB" || fail 'P2E16A result drift'
test "$(git rev-parse HEAD:$TEST)" = "$TEST_BLOB" || fail 'P2E16B test drift'

grep -Fq '"phase": "PREREGISTERED_AFTER_P2E16A_BEFORE_ANY_P2E16_CANDIDATE_EXECUTION"' "$PREREG" || fail 'preregistration phase drift'
grep -Fq '"total_cases": 1296' "$PREREG" || fail '1296-case matrix not frozen'
grep -Fq '"authorized_route_valid_pair_count": 850' "$PREREG" || fail 'Stage-A pairwise authorization drift'
grep -Fq '"p2e14_threshold_retuning_allowed": false' "$PREREG" || fail 'threshold firewall missing'
grep -Fq '"stage_A_authorization_reclassification_allowed": false' "$PREREG" || fail 'Stage-A authorization firewall missing'
grep -Fq '"performance_claim_authorized": false' "$PREREG" || fail 'performance firewall missing'

git merge-base --is-ancestor "$PARENT_BASE" HEAD || fail 'P2E16A result parent is not an ancestor'
git diff --quiet fe5e34652e5da69c6e97977ca64c82db571e7441 HEAD -- src reference || fail 'P2E16 work mutated src or reference'

test "$(git rev-parse HEAD:docs/publication/P2E14_REFERENCE_COMMON_MATERIAL_THRESHOLD_FREEZE_RESULT.json)" = "$P2E14_RESULT_BLOB" || fail 'P2E14 threshold authority drift'
test "$(git rev-parse HEAD:src/solver/mod_soil_water_solver_contract.f90)" = "$SOLVER_CONTRACT_BLOB" || fail 'solver contract drift'
test "$(git rev-parse HEAD:src/adapter/mod_reference_richards_legacy_binding.f90)" = "$REFERENCE_BINDING_BLOB" || fail 'Reference binding drift'
test "$(git rev-parse HEAD:src/solver/mod_rossfast_d3r_soil_water_solver.f90)" = "$ROSSFAST_SOLVER_BLOB" || fail 'RossFast solver drift'
test "$(git rev-parse HEAD:src/runtime/mod_rossfast_d3r_model_binding.f90)" = "$ROSSFAST_MODEL_BINDING_BLOB" || fail 'RossFast model binding drift'
test "$(git rev-parse HEAD:src/runtime/mod_rossfast_d3r_execution_policy.f90)" = "$ROSSFAST_EXECUTION_POLICY_BLOB" || fail 'RossFast execution policy drift'
test "$(git rev-parse HEAD:src/solver/mod_rossfast_d3r_table_provider.f90)" = "$ROSSFAST_TABLE_PROVIDER_BLOB" || fail 'RossFast table provider drift'
test "$(git rev-parse HEAD:src/solver/mod_rossfast_d3r_table_kernel.f90)" = "$ROSSFAST_TABLE_KERNEL_BLOB" || fail 'RossFast table kernel drift'

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
  src/solver/mod_rossfast_d3r_table_kernel.f90
  src/solver/mod_rossfast_d3r_table_provider.f90
  src/solver/mod_rossfast_d3r_soil_water_solver.f90
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
    fail "P2E16B candidate boundary runtime O$opt"
  fi

  for marker in     'PUB_P2E16B_CASE_COUNT=1296'     'PUB_P2E16B_P2E14_THRESHOLDS_CHANGED=FALSE'     'PUB_P2E16B_STAGE_A_AUTHORIZATION_CHANGED=FALSE'     'PUB_P2E16B_PERFORMANCE_CLAIM_EVALUATED=FALSE'     'PUB_P2E16B_SCIENTIFIC_FAILURE_IS_CI_FAILURE=FALSE'     'PUB_P2E16B_CANDIDATE_BOUNDARY_PRIMARY_GATE=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing O$opt marker $marker"; }
  done

  cases="$(grep -Fc 'PUB_P2E16B_CASE|' "$OUT/output.txt")"
  [[ "$cases" = "1296" ]] || fail "expected 1296 case records, got $cases"

  cat "$OUT/output.txt"
  echo "PUB_P2E16B_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 P2E16B scientific output drift'
}

echo "PUB_P2E16B_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'PUB_P2E16B_CANDIDATE_BOUNDARY_PRIMARY_GATE=PASS'
