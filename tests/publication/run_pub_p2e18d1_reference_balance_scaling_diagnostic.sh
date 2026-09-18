#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-p2e18d1-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "PUB_P2E18D1_GATE_FAIL $*" >&2; exit 1; }

TEST=tests/publication/test_pub_p2e18d1_reference_balance_scaling_diagnostic.f90
PREREG=docs/publication/P2E18D1_REFERENCE_BALANCE_SCALING_DIAGNOSTIC_PREREGISTRATION.json
PARENT_BASE=8ee5f064dc0f9dae8cccd82c5d0786f58987666a
PREREG_BLOB=73c35bf9454ca7beffbbfcedea0d46b5e791f54d
TEST_BLOB=bc832f1a8b72ebe859fc7cd57110902edfc34b93
P2E18_RESULT_BLOB=95e036de41d90c411359d5c50ae2cc36a522444d
REFERENCE_TREE=684f1e2889b6992e5aedc88f52bb45f4558bb3e4
SOLVER_CONTRACT_BLOB=40a1ddc05fb8e2c1822763de645fd07a094568a3
MODEL_BINDING_BLOB=5442fd7e7a2f392c9b796cd17c76b17977259f22
REFERENCE_BINDING_BLOB=4b545c6fb260e81cd6c8f4d2d65f2beee7281e53
WORKSPACE_BLOB=74f99556005ae39614f9df678467b1e19097bae2
HEADCALC_BLOB=3ff8d5cfd6963dfb7dafb33ec454fbc0df938a55

grep -Fq '"phase": "PREREGISTERED_BEFORE_REFERENCE_BALANCE_SCALING_DIAGNOSTIC"' "$PREREG" || fail 'preregistration phase missing'
grep -Fq '"case_count": 36' "$PREREG" || fail '36-case matrix not frozen'
grep -Fq '"invariant_integrated_balance_scale_cm": 1.6e-15' "$PREREG" || fail 'integrated balance scale missing'
grep -Fq '"No RossFast numerical execution"' "$PREREG" || fail 'RossFast firewall missing'
grep -Fq '"No timing"' "$PREREG" || fail 'timing firewall missing'

git merge-base --is-ancestor "$PARENT_BASE" HEAD || fail 'P2E18 result parent missing'
git diff --quiet "$PARENT_BASE" HEAD -- src reference || fail 'P2E18D1 mutated src or reference'
test "$(git rev-parse HEAD:$PREREG)" = "$PREREG_BLOB" || fail 'preregistration drift'
test "$(git rev-parse HEAD:$TEST)" = "$TEST_BLOB" || fail 'test drift'
test "$(git rev-parse HEAD:docs/publication/P2E18_REF_HIGH_CONSTRUCTION_RESULT.json)" = "$P2E18_RESULT_BLOB" || fail 'P2E18 result authority drift'
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

  for marker in     'PUB_P2E18D1_CASE_COUNT=36'     'PUB_P2E18D1_LEVEL_RECORD_COUNT=180'     'PUB_P2E18D1_POLICY=INVARIANT_INTEGRATED_BALANCE_SCALE'     'PUB_P2E18D1_ROSSFAST_SOLVER_EXECUTED=FALSE'     'PUB_P2E18D1_TIMING_EXECUTED=FALSE'     'PUB_P2E18D1_REF_HIGH_STABILITY_QUALIFIED=FALSE'     'PUB_P2E18D1_GATE=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing marker $marker"; }
  done

  [[ "$(grep -Fc 'PUB_P2E18D1_POLICY|NSUB=' "$OUT/output.txt")" = "5" ]] || fail 'expected 5 policy records'
  [[ "$(grep -Fc 'PUB_P2E18D1_LEVEL|CASE=' "$OUT/output.txt")" = "180" ]] || fail 'expected 180 level records'
  [[ "$(grep -Fc 'PUB_P2E18D1_LEVEL_SUMMARY|NSUB=' "$OUT/output.txt")" = "5" ]] || fail 'expected 5 level summaries'
  grep -Eq 'PUB_P2E18D1_DIAGNOSTIC_OUTCOME=(SCALING_HYPOTHESIS_SUPPORTED_FOR_REQUIRED_FINE_LEVELS|SCALING_HYPOTHESIS_NOT_SUFFICIENT_FOR_REQUIRED_FINE_LEVELS)' "$OUT/output.txt" || fail 'missing diagnostic outcome'

  cat "$OUT/output.txt"
  echo "PUB_P2E18D1_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 diagnostic output drift'
}
echo "PUB_P2E18D1_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'PUB_P2E18D1_GATE=PASS'
