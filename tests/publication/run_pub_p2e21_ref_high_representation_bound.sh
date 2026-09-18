#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-p2e21-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "PUB_P2E21_GATE_FAIL $*" >&2; exit 1; }

PREREG=docs/publication/P2E21_REF_HIGH_REPRESENTATION_BOUND_PREREGISTRATION.json
TEST=tests/publication/test_pub_p2e21_ref_high_representation_bound.f90
P2E20_RESULT=docs/publication/P2E20_REF_HIGH_SCALED_CONSTRUCTION_RESULT.json
PARENT_BASE=a561ff1389af06d4521185b9d0d080785716bf3b

PREREG_BLOB=789909855e70c06d0f333e48d3e5ab5c1bdc2a97
TEST_BLOB=ab0cfe911af87ccad0926b0ed51d05feaa97ed20
P2E20_RESULT_BLOB=1657c73e631f4a5e6b9ee65d43669054a65e3008
D3_RESULT_BLOB=c06193ca08031f24f9f40a1b6713287b2599926d
P2E07_RESULT_BLOB=be60ba751141545e1534f190e709dc5d2b7b83e6

REFERENCE_TREE=684f1e2889b6992e5aedc88f52bb45f4558bb3e4
SOLVER_CONTRACT_BLOB=40a1ddc05fb8e2c1822763de645fd07a094568a3
MODEL_BINDING_BLOB=5442fd7e7a2f392c9b796cd17c76b17977259f22
REFERENCE_BINDING_BLOB=4b545c6fb260e81cd6c8f4d2d65f2beee7281e53
WORKSPACE_BLOB=74f99556005ae39614f9df678467b1e19097bae2
HEADCALC_BLOB=3ff8d5cfd6963dfb7dafb33ec454fbc0df938a55

[[ -f "$PREREG" ]] || fail 'missing P2E21 preregistration'
[[ -f "$TEST" ]] || fail 'missing P2E21 test'
[[ -f "$P2E20_RESULT" ]] || fail 'missing P2E20 authority'

test "$(git rev-parse HEAD:$PREREG)" = "$PREREG_BLOB" || fail 'P2E21 preregistration drift'
test "$(git rev-parse HEAD:$TEST)" = "$TEST_BLOB" || fail 'P2E21 test drift'
test "$(git rev-parse HEAD:$P2E20_RESULT)" = "$P2E20_RESULT_BLOB" || fail 'P2E20 result drift'

git rev-parse --verify refs/remotes/origin/work/pub-p2e18d3-reference-total-balance-floor >/dev/null || fail 'missing D3 remote authority'
test "$(git rev-parse refs/remotes/origin/work/pub-p2e18d3-reference-total-balance-floor:docs/publication/P2E18D3_REFERENCE_TOTAL_BALANCE_FLOOR_RESULT.json)" = "$D3_RESULT_BLOB" || fail 'D3 result authority drift'
git rev-parse --verify refs/remotes/origin/work/pub-p2e07-reference-cancellation-floor >/dev/null || fail 'missing P2E07 remote authority'
test "$(git rev-parse refs/remotes/origin/work/pub-p2e07-reference-cancellation-floor:docs/publication/P2E07_REFERENCE_CANCELLATION_FLOOR_RESULT.json)" = "$P2E07_RESULT_BLOB" || fail 'P2E07 result authority drift'

grep -Fq '"phase": "PREREGISTERED_BEFORE_REPRESENTATION_BOUNDED_REF_HIGH_EXECUTION"' "$PREREG" || fail 'phase drift'
grep -Fq '"total_integrated_bound_formula": "max(1.6e-15, 0.5 * sum_i((spacing(theta_s_material) + spacing(theta_base_i)) * dz_i))"' "$PREREG" || fail 'total-bound formula drift'
grep -Fq '"no_safety_factor": true' "$PREREG" || fail 'no-safety-factor lock missing'
grep -Fq '"D3_residual_fitting_allowed": false' "$PREREG" || fail 'D3 residual-fit firewall missing'
grep -Fq '"rossfast_numerical_execution_allowed": false' "$PREREG" || fail 'RossFast firewall missing'
grep -Fq '"timing_allowed": false' "$PREREG" || fail 'timing firewall missing'
grep -Fq '"production_tolerance_change_allowed": false' "$PREREG" || fail 'production tolerance firewall missing'

git merge-base --is-ancestor "$PARENT_BASE" HEAD || fail 'P2E20 parent is not ancestor'
git diff --quiet "$PARENT_BASE" HEAD -- src reference || fail 'P2E21 mutated src or reference'
test "$(git rev-parse HEAD:reference)" = "$REFERENCE_TREE" || fail 'reference tree drift'
test "$(git rev-parse HEAD:src/solver/mod_soil_water_solver_contract.f90)" = "$SOLVER_CONTRACT_BLOB" || fail 'solver contract drift'
test "$(git rev-parse HEAD:src/runtime/mod_rossfast_d3r_model_binding.f90)" = "$MODEL_BINDING_BLOB" || fail 'material binding drift'
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
    [[ "$source" != "$forbidden" ]] || fail "RossFast numerical implementation entered Reference-only P2E21 build"
  done
done

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
    fail "P2E21 runtime O$opt"
  fi

  for marker in     'PUB_P2E21_CASE_COUNT=36'     'PUB_P2E21_FINE_LEVEL_COUNT=3'     'PUB_P2E21_REF_HIGH_ENDPOINT=32_SUBSTEPS'     'PUB_P2E21_COMPARTMENT_INTEGRATED_ALLOWANCE_CM=1.6E-15'     'PUB_P2E21_TOTAL_BOUND_FORMULA=PRE_SOLVE_THETA_S_AND_BASE_SPACING'     'PUB_P2E21_EMPIRICAL_SAFETY_FACTOR=NONE'     'PUB_P2E21_ROSSFAST_EXECUTED=FALSE'     'PUB_P2E21_TIMING_EXECUTED=FALSE'     'PUB_P2E21_PRODUCTION_TOLERANCE_CHANGED=FALSE'     'PUB_P2E21_SCIENTIFIC_RESULT_IS_CI_FAILURE=FALSE'     'PUB_P2E21_REPRESENTATION_BOUNDED_REF_HIGH_GATE=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing marker $marker"; }
  done

  levels="$(grep -Fc 'PUB_P2E21_LEVEL|' "$OUT/output.txt" || true)"
  cases="$(grep -Fc 'PUB_P2E21_CASE|' "$OUT/output.txt" || true)"
  budgets="$(grep -Fc 'PUB_P2E21_BUDGET|' "$OUT/output.txt" || true)"
  policy_summaries="$(grep -Fc 'PUB_P2E21_POLICY_ROUTE_SUMMARY|' "$OUT/output.txt" || true)"
  [[ "$levels" = "216" ]] || fail "expected 216 two-policy level records, got $levels"
  [[ "$cases" = "36" ]] || fail "expected 36 case records, got $cases"
  [[ "$budgets" = "3" ]] || fail "expected 3 budget records, got $budgets"
  [[ "$policy_summaries" = "3" ]] || fail "expected 3 policy-route summaries, got $policy_summaries"

  qualified="$(grep 'PUB_P2E21_QUALIFIED_COUNT=' "$OUT/output.txt" | tail -1 | cut -d= -f2)"
  route_unresolved="$(grep 'PUB_P2E21_ROUTE_UNRESOLVED_COUNT=' "$OUT/output.txt" | tail -1 | cut -d= -f2)"
  policy_unresolved="$(grep 'PUB_P2E21_POLICY_UNRESOLVED_COUNT=' "$OUT/output.txt" | tail -1 | cut -d= -f2)"
  stability_unresolved="$(grep 'PUB_P2E21_STABILITY_UNRESOLVED_COUNT=' "$OUT/output.txt" | tail -1 | cut -d= -f2)"
  [[ $((qualified + route_unresolved + policy_unresolved + stability_unresolved)) -eq 36 ]] || fail 'case classifications do not sum to 36'

  neutral="$(grep 'PUB_P2E21_POLICY_NEUTRAL_COMPARISON_COUNT=' "$OUT/output.txt" | tail -1 | cut -d= -f2)"
  neutral_pass="$(grep 'PUB_P2E21_POLICY_NEUTRAL_PASS_COUNT=' "$OUT/output.txt" | tail -1 | cut -d= -f2)"
  neutral_fail="$(grep 'PUB_P2E21_POLICY_NEUTRAL_FAIL_COUNT=' "$OUT/output.txt" | tail -1 | cut -d= -f2)"
  [[ $((neutral_pass + neutral_fail)) -eq "$neutral" ]] || fail 'policy-neutral classifications do not sum'

  nodes="$(grep -Fc 'PUB_P2E21_REF_HIGH_NODE|' "$OUT/output.txt" || true)"
  [[ "$nodes" -eq $((qualified * 16)) ]] || fail "REF-HIGH node count $nodes inconsistent with qualified count $qualified"

  cat "$OUT/output.txt"
  echo "PUB_P2E21_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 P2E21 scientific output drift'
}

echo "PUB_P2E21_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'PUB_P2E21_REPRESENTATION_BOUNDED_REF_HIGH_QUALIFICATION_GATE=PASS'
