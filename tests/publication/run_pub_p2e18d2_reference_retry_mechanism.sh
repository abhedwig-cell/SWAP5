#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-p2e18d2-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "PUB_P2E18D2_GATE_FAIL $*" >&2; exit 1; }

TEST=tests/publication/test_pub_p2e18d2_reference_retry_mechanism.f90
PREREG=docs/publication/P2E18D2_REFERENCE_RETRY_MECHANISM_PREREGISTRATION.json
PARENT_BASE=2a1f0e23592573a520706758a37c031330a0d56d
PREREG_BLOB=3b032963224a159acadbefb953be887f426297ce
TEST_BLOB=9dac4d004388dceeb157168b0665c4ace9351065
P2E18D1_RESULT_BLOB=5f6ebdcff315f23dd2c8c54666b8f413bc2dbcea
REFERENCE_TREE=684f1e2889b6992e5aedc88f52bb45f4558bb3e4
SOLVER_CONTRACT_BLOB=40a1ddc05fb8e2c1822763de645fd07a094568a3
MODEL_BINDING_BLOB=5442fd7e7a2f392c9b796cd17c76b17977259f22
REFERENCE_BINDING_BLOB=4b545c6fb260e81cd6c8f4d2d65f2beee7281e53
WORKSPACE_BLOB=74f99556005ae39614f9df678467b1e19097bae2
HEADCALC_BLOB=3ff8d5cfd6963dfb7dafb33ec454fbc0df938a55

grep -Fq '"phase": "PREREGISTERED_BEFORE_REFERENCE_RETRY_MECHANISM_DIAGNOSTIC"' "$PREREG" || fail 'preregistration phase missing'
grep -Fq '"physical_case_count": 4' "$PREREG" || fail '4-case mechanism matrix not frozen'
grep -Fq '"invariant_integrated_balance_scale_cm": 1.6e-15' "$PREREG" || fail 'integrated balance scale missing'
grep -Fq '"No RossFast numerical execution"' "$PREREG" || fail 'RossFast firewall missing'
grep -Fq '"No timing"' "$PREREG" || fail 'timing firewall missing'

git merge-base --is-ancestor "$PARENT_BASE" HEAD || fail 'P2E18D1 result parent missing'
git diff --quiet "$PARENT_BASE" HEAD -- src reference || fail 'P2E18D2 mutated src or reference'
test "$(git rev-parse HEAD:$PREREG)" = "$PREREG_BLOB" || fail 'preregistration drift'
test "$(git rev-parse HEAD:$TEST)" = "$TEST_BLOB" || fail 'test drift'
test "$(git rev-parse HEAD:docs/publication/P2E18D1_REFERENCE_BALANCE_SCALING_DIAGNOSTIC_RESULT.json)" = "$P2E18D1_RESULT_BLOB" || fail 'P2E18D1 result authority drift'
test "$(git rev-parse HEAD:reference)" = "$REFERENCE_TREE" || fail 'reference tree drift'
test "$(git rev-parse HEAD:src/solver/mod_soil_water_solver_contract.f90)" = "$SOLVER_CONTRACT_BLOB" || fail 'solver contract drift'
test "$(git rev-parse HEAD:src/runtime/mod_rossfast_d3r_model_binding.f90)" = "$MODEL_BINDING_BLOB" || fail 'model binding drift'
test "$(git rev-parse HEAD:src/adapter/mod_reference_richards_legacy_binding.f90)" = "$REFERENCE_BINDING_BLOB" || fail 'Reference binding drift'
test "$(git rev-parse HEAD:src/solver/mod_reference_richards_workspace.f90)" = "$WORKSPACE_BLOB" || fail 'Reference workspace drift'
test "$(git rev-parse HEAD:src/legacy/b1_10_port/headcalc.f90)" = "$HEADCALC_BLOB" || fail 'HeadCalc drift'

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

for forbidden in   src/solver/mod_rossfast_d3r_table_kernel.f90   src/solver/mod_rossfast_d3r_table_provider.f90   src/solver/mod_rossfast_d3r_soil_water_solver.f90   src/runtime/mod_fmr_rossfast_solver_selection_binding.f90; do
  for source in "${MODULE_SRC[@]}"; do
    [[ "$source" != "$forbidden" ]] || fail "RossFast numerical implementation entered Reference-only build: $forbidden"
  done
done

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    extra=()
    [[ "$source" == "src/solver/mod_soil_water_solver_contract.f90" ]] && extra=(-Wno-error=unused-dummy-argument)
    gfortran "${COMMON[@]}" "${extra[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/test.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"

  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "diagnostic runtime O$opt"; }

  for marker in     'PUB_P2E18D2_CASE_COUNT=4'     'PUB_P2E18D2_LEVEL_RECORD_COUNT=24'     'PUB_P2E18D2_POLICY=INVARIANT_INTEGRATED_BALANCE_SCALE_UNCHANGED_FROM_D1'     'PUB_P2E18D2_ROSSFAST_SOLVER_EXECUTED=FALSE'     'PUB_P2E18D2_TIMING_EXECUTED=FALSE'     'PUB_P2E18D2_REF_HIGH_STABILITY_QUALIFIED=FALSE'     'PUB_P2E18D2_DIAGNOSTIC_OUTCOME=RETRY_MECHANISM_CLASSIFIED'     'PUB_P2E18D2_GATE=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing marker $marker"; }
  done

  [[ "$(grep -Fc 'PUB_P2E18D2_POLICY|NSUB=' "$OUT/output.txt")" = "6" ]] || fail 'expected 6 policy records'
  [[ "$(grep -Fc 'PUB_P2E18D2_LEVEL|CASE=' "$OUT/output.txt")" = "24" ]] || fail 'expected 24 level records'
  [[ "$(grep -Fc 'PUB_P2E18D2_LEVEL_SUMMARY|NSUB=' "$OUT/output.txt")" = "6" ]] || fail 'expected 6 level summaries'
  grep -Fq 'PUB_P2E18D2_DIAGNOSTIC_OUTCOME=RETRY_MECHANISM_CLASSIFIED' "$OUT/output.txt" || fail 'missing mechanism diagnostic outcome'
  grep -Fq 'PUB_P2E18D2_RETRY_BALANCE_ONLY_COUNT=' "$OUT/output.txt" || fail 'missing balance-only count'
  grep -Fq 'PUB_P2E18D2_RETRY_HEAD_ONLY_COUNT=' "$OUT/output.txt" || fail 'missing head-only count'
  grep -Fq 'PUB_P2E18D2_RETRY_BOTH_COUNT=' "$OUT/output.txt" || fail 'missing both count'
  grep -Fq 'PUB_P2E18D2_RETRY_OTHER_COUNT=' "$OUT/output.txt" || fail 'missing other count'

  cat "$OUT/output.txt"
  echo "PUB_P2E18D2_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 diagnostic output drift'
}
echo "PUB_P2E18D2_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'PUB_P2E18D2_GATE=PASS'
