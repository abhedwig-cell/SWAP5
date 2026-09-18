#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-p2e20-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "PUB_P2E20_GATE_FAIL $*" >&2; exit 1; }

PREREG=docs/publication/P2E20_REF_HIGH_SCALED_CONSTRUCTION_PREREGISTRATION.json
P2E19_RESULT=docs/publication/P2E19_REFERENCE_BALANCE_SCALING_DIAGNOSTIC_RESULT.json
TEST=tests/publication/test_pub_p2e20_ref_high_scaled_construction.f90
PARENT_BASE=f2d5cd8d0e69a35436573f6d32dd0916c344ca49

PREREG_BLOB=9b98b4d5151103371d00ad61cd8e3c040f4124f9
P2E19_RESULT_BLOB=bbf6b235c81f30b517dee6e3346499f4823b597a
TEST_BLOB=549fc5792778b255ec19bafc1d9bd0d5925f199c

REFERENCE_TREE=684f1e2889b6992e5aedc88f52bb45f4558bb3e4
SOLVER_CONTRACT_BLOB=40a1ddc05fb8e2c1822763de645fd07a094568a3
MODEL_BINDING_BLOB=5442fd7e7a2f392c9b796cd17c76b17977259f22
REFERENCE_BINDING_BLOB=4b545c6fb260e81cd6c8f4d2d65f2beee7281e53
WORKSPACE_BLOB=74f99556005ae39614f9df678467b1e19097bae2
HEADCALC_BLOB=3ff8d5cfd6963dfb7dafb33ec454fbc0df938a55

[[ -f "$PREREG" ]] || fail 'missing P2E20 preregistration'
[[ -f "$P2E19_RESULT" ]] || fail 'missing P2E19 result'
[[ -f "$TEST" ]] || fail 'missing P2E20 test'

test "$(git rev-parse HEAD:$PREREG)" = "$PREREG_BLOB" || fail 'P2E20 preregistration drift'
test "$(git rev-parse HEAD:$P2E19_RESULT)" = "$P2E19_RESULT_BLOB" || fail 'P2E19 result drift'
test "$(git rev-parse HEAD:$TEST)" = "$TEST_BLOB" || fail 'P2E20 test drift'

grep -Fq '"phase": "PREREGISTERED_BEFORE_REF_HIGH_MATERIALIZATION"' "$PREREG" || fail 'phase drift'
grep -Fq '"integrated_balance_allowance_cm_per_substep": 1.6e-15' "$PREREG" || fail 'integrated policy drift'
grep -Fq '"substeps": [8,16,32]' "$PREREG" || fail 'fine ladder drift'
grep -Fq '"qualified_count": 33' "$PREREG" || fail 'expected reproduction count drift'
grep -Fq '"rossfast_execution_allowed": false' "$PREREG" || fail 'RossFast firewall missing'
grep -Fq '"rossfast_timing_allowed": false' "$PREREG" || fail 'timing firewall missing'
grep -Fq '"production_tolerance_change_allowed": false' "$PREREG" || fail 'production tolerance firewall missing'

git merge-base --is-ancestor "$PARENT_BASE" HEAD || fail 'P2E19 parent is not an ancestor'
git diff --quiet "$PARENT_BASE" HEAD -- src reference || fail 'P2E20 mutated src or reference'
test "$(git rev-parse HEAD:reference)" = "$REFERENCE_TREE" || fail 'reference tree drift'
test "$(git rev-parse HEAD:src/solver/mod_soil_water_solver_contract.f90)" = "$SOLVER_CONTRACT_BLOB" || fail 'solver contract drift'
test "$(git rev-parse HEAD:src/runtime/mod_rossfast_d3r_model_binding.f90)" = "$MODEL_BINDING_BLOB" || fail 'material-domain binding drift'
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

  for marker in     'PUB_P2E20_CASE_COUNT=36'     'PUB_P2E20_FINE_LEVEL_COUNT=3'     'PUB_P2E20_QUALIFIED_COUNT=33'     'PUB_P2E20_ROUTE_UNRESOLVED_COUNT=2'     'PUB_P2E20_STABILITY_UNRESOLVED_COUNT=1'     'PUB_P2E20_REF_HIGH_ENDPOINT=32_SUBSTEPS'     'PUB_P2E20_INTEGRATED_ALLOWANCE_CM=1.6E-15'     'PUB_P2E20_ROSSFAST_EXECUTED=FALSE'     'PUB_P2E20_TIMING_EXECUTED=FALSE'     'PUB_P2E20_PRODUCTION_TOLERANCE_CHANGED=FALSE'     'PUB_P2E20_CASEWISE_REF_HIGH_CONSTRUCTION_GATE=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing marker $marker"; }
  done

  levels="$(grep -Fc 'PUB_P2E20_LEVEL|' "$OUT/output.txt" || true)"
  cases="$(grep -Fc 'PUB_P2E20_CASE|' "$OUT/output.txt" || true)"
  deltas="$(grep -Fc 'PUB_P2E20_DELTA|' "$OUT/output.txt" || true)"
  nodes="$(grep -Fc 'PUB_P2E20_REF_HIGH_NODE|' "$OUT/output.txt" || true)"
  budgets="$(grep -Fc 'PUB_P2E20_BUDGET|' "$OUT/output.txt" || true)"

  [[ "$levels" = "108" ]] || fail "expected 108 fine-level records, got $levels"
  [[ "$cases" = "36" ]] || fail "expected 36 case records, got $cases"
  [[ "$deltas" = "68" ]] || fail "expected 68 fine-delta records, got $deltas"
  [[ "$nodes" = "528" ]] || fail "expected 528 REF-HIGH node records, got $nodes"
  [[ "$budgets" = "3" ]] || fail "expected three budget records, got $budgets"

  cat "$OUT/output.txt"
  echo "PUB_P2E20_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 P2E20 scientific output drift'
}

echo "PUB_P2E20_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'PUB_P2E20_CASEWISE_REF_HIGH_CONSTRUCTION_GATE=PASS'
