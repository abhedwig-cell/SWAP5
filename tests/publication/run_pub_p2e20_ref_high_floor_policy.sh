#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-p2e20-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "PUB_P2E20_GATE_FAIL $*" >&2; exit 1; }

PREREG=docs/publication/P2E20_REF_HIGH_FLOOR_POLICY_PREREGISTRATION.json
TEST=tests/publication/test_pub_p2e20_ref_high_floor_policy.f90
PARENT_BASE=dfea35a171956895c2c67d287f3c1f49b3905264

PREREG_BLOB=26d5ea8984c234e206ce30992b782fcde4789849
TEST_BLOB=df0d5abc4025e62016837ee4b049343f9a78ce1d
P2E18D3_RESULT_BLOB=c06193ca08031f24f9f40a1b6713287b2599926d
REFERENCE_TREE=684f1e2889b6992e5aedc88f52bb45f4558bb3e4
SOLVER_CONTRACT_BLOB=40a1ddc05fb8e2c1822763de645fd07a094568a3
MODEL_BINDING_BLOB=5442fd7e7a2f392c9b796cd17c76b17977259f22
REFERENCE_BINDING_BLOB=4b545c6fb260e81cd6c8f4d2d65f2beee7281e53
WORKSPACE_BLOB=74f99556005ae39614f9df678467b1e19097bae2
HEADCALC_BLOB=3ff8d5cfd6963dfb7dafb33ec454fbc0df938a55

[[ -f "$PREREG" ]] || fail 'missing P2E20 preregistration'
[[ -f "$TEST" ]] || fail 'missing P2E20 test'

test "$(git rev-parse HEAD:$PREREG)" = "$PREREG_BLOB" || fail 'P2E20 preregistration drift'
test "$(git rev-parse HEAD:$TEST)" = "$TEST_BLOB" || fail 'P2E20 test drift'
test "$(git rev-parse HEAD:docs/publication/P2E18_REF_HIGH_CONSTRUCTION_RESULT.json)" = "$P2E18_RESULT_BLOB" || fail 'P2E18 result drift'

grep -Fq '"phase": "PREREGISTERED_BEFORE_FLOOR_AWARE_REF_HIGH_EXECUTION"' "$PREREG" || fail 'phase drift'
grep -Fq '"safety_factor": 1' "$PREREG" || fail 'representation-floor safety factor drift'
grep -Fq '"rossfast_execution_allowed": false' "$PREREG" || fail 'RossFast firewall missing'
grep -Fq '"production_tolerance_change_allowed": false' "$PREREG" || fail 'production tolerance firewall missing'
grep -Fq '"empirical_multiplier_from_D3_residuals_allowed": false' "$PREREG" || fail 'posthoc multiplier firewall missing'
grep -Fq '"stability_budget_change_allowed": false' "$PREREG" || fail 'stability budget firewall missing'

git merge-base --is-ancestor "$PARENT_BASE" HEAD || fail 'P2E18D3 parent is not ancestor'
git diff --quiet "$PARENT_BASE" HEAD -- src reference || fail 'P2E20 mutated src or reference'
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
    [[ "$source" != "$forbidden" ]] || fail "RossFast numerical implementation entered Reference-only P2E20 build"
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
    fail "P2E20 runtime O$opt"
  fi

  for marker in \
    'PUB_P2E20_CASE_COUNT=36' \
    'PUB_P2E20_POLICY_COUNT=2' \
    'PUB_P2E20_FINE_LEVEL_COUNT=3' \
    'PUB_P2E20_COMPARTMENT_INTEGRATED_ALLOWANCE_CM=1.6E-15' \
    'PUB_P2E20_TOTAL_FLOOR_SAFETY_FACTOR=1.0' \
    'PUB_P2E20_REF_HIGH_ENDPOINT_SUBSTEPS=32' \
    'PUB_P2E20_ROSSFAST_EXECUTED=FALSE' \
    'PUB_P2E20_TIMING_EXECUTED=FALSE' \
    'PUB_P2E20_REF_HIGH_FLOOR_POLICY_GATE=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing marker $marker"; }
  done

  levels="$(grep -Fc 'PUB_P2E20_LEVEL|' "$OUT/output.txt" || true)"
  budgets="$(grep -Fc 'PUB_P2E20_BUDGET|' "$OUT/output.txt" || true)"
  floors="$(grep -Fc 'PUB_P2E20_FLOOR|' "$OUT/output.txt" || true)"
  cases="$(grep -Fc 'PUB_P2E20_CASE|CASE=' "$OUT/output.txt" || true)"
  [[ "$levels" = "216" ]] || fail "expected 216 policy-level records, got $levels"
  [[ "$budgets" = "3" ]] || fail "expected three budget records, got $budgets"
  [[ "$floors" = "36" ]] || fail "expected 36 floor records, got $floors"
  [[ "$cases" = "36" ]] || fail "expected 36 case classifications, got $cases"
  if grep -Fq 'PUB_P2E20_SCIENTIFIC_OUTCOME=QUALIFIED_CASEWISE_REF_HIGH_NONEMPTY' "$OUT/output.txt"; then
    :
  elif grep -Fq 'PUB_P2E20_SCIENTIFIC_OUTCOME=BLOCKED_ZERO_CASEWISE_REF_HIGH' "$OUT/output.txt"; then
    :
  else
    cat "$OUT/output.txt" >&2
    fail 'missing P2E20 scientific outcome'
  fi

  cat "$OUT/output.txt"
  echo "PUB_P2E20_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 P2E20 output drift'
}

echo "PUB_P2E20_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'PUB_P2E20_REF_HIGH_FLOOR_POLICY_GATE=PASS'
