#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-p2e15-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "PUB_P2E15_GATE_FAIL $*" >&2; exit 1; }

PREREG=docs/publication/P2E15_30_MATERIAL_E0_HOLDOUT_PREREGISTRATION.json
TEST=tests/publication/test_pub_p2e15_30_material_e0_holdout.f90

P2E14_RESULT_BLOB=f9f49ce5f0f239d1c1cdd4575a4da65cd84c0351
P2E13_RESULT_BLOB=a8658b710b5b96b1bea0ee8c61dae80a002efa76
P2E10_RESULT_BLOB=83864f6379279725fa97d24d57936f590d3c2174
SOLVER_CONTRACT_BLOB=40a1ddc05fb8e2c1822763de645fd07a094568a3
REFERENCE_BINDING_BLOB=4b545c6fb260e81cd6c8f4d2d65f2beee7281e53
ROSSFAST_SOLVER_BLOB=dbb441f3529be179d64fb57f9c44336d3d20c540
ROSSFAST_MODEL_BINDING_BLOB=5442fd7e7a2f392c9b796cd17c76b17977259f22
ROSSFAST_EXECUTION_POLICY_BLOB=a39a636d01f373ae6ef0dc3ac0e1e25b6522fda9
ROSSFAST_TABLE_PROVIDER_BLOB=ac997bf06c56a37080d1c8db69b6d4208f4b75ca

[[ -f "$PREREG" ]] || fail 'missing P2E15 preregistration'
[[ -f "$TEST" ]] || fail 'missing P2E15 paired matrix test'

grep -Fq '"phase": "PREREGISTERED_BEFORE_NEW_EXTENSION_ROSSFAST_DISCREPANCY_EXECUTION"' "$PREREG" || fail 'preregistration phase drift'
grep -Fq '"case_count": 180' "$PREREG" || fail '180-case holdout not frozen'
grep -Fq '"step_duration_day": 0.0016' "$PREREG" || fail 'paired duration drift'
grep -Fq '"no_threshold_retuning": true' "$PREREG" || fail 'threshold-retuning firewall missing'
grep -Fq '"transaction_layer": "EXCLUDED"' "$PREREG" || fail 'transaction-layer firewall missing'
grep -Fq '"wetting_forcing_added_allowed": false' "$PREREG" || fail 'wetting firewall missing'

CURRENT_BASE="$(git merge-base HEAD origin/integration/f-ci-canonical)"
[[ -n "$CURRENT_BASE" ]] || fail 'unable to resolve current canonical merge-base'
git diff --quiet "$CURRENT_BASE" HEAD -- src reference || fail 'P2E15 mutated src or reference'
echo "PUB_P2E15_RECONCILED_BASE=$CURRENT_BASE"

test "$(git rev-parse HEAD:$PREREG)" = "$PREREG_BLOB" || fail 'P2E15 preregistration drift'
test "$(git rev-parse HEAD:docs/publication/P2E09_REFERENCE_ONLY_THRESHOLD_FREEZE_RESULT.json)" = "$P2E09_RESULT_BLOB" || fail 'P2E09 threshold authority drift'
test "$(git rev-parse HEAD:tests/publication/test_pub_p2e01_solver_seam_paired_pilot.f90)" = "$P2E01_TYPED_PILOT_BLOB" || fail 'typed paired-pilot authority drift'
test "$(git rev-parse HEAD:src/solver/mod_soil_water_solver_contract.f90)" = "$SOLVER_CONTRACT_BLOB" || fail 'solver contract drift'
test "$(git rev-parse HEAD:src/adapter/mod_reference_richards_legacy_binding.f90)" = "$REFERENCE_BINDING_BLOB" || fail 'Reference binding drift'
test "$(git rev-parse HEAD:src/solver/mod_rossfast_d3r_soil_water_solver.f90)" = "$ROSSFAST_SOLVER_BLOB" || fail 'RossFast solver drift'
test "$(git rev-parse HEAD:src/runtime/mod_rossfast_d3r_model_binding.f90)" = "$ROSSFAST_MODEL_BINDING_BLOB" || fail 'RossFast model binding drift'
test "$(git rev-parse HEAD:src/runtime/mod_rossfast_d3r_execution_policy.f90)" = "$ROSSFAST_EXECUTION_POLICY_BLOB" || fail 'RossFast execution policy drift'
test "$(git rev-parse HEAD:src/solver/mod_rossfast_d3r_table_provider.f90)" = "$ROSSFAST_TABLE_PROVIDER_BLOB" || fail 'RossFast table provider drift'

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
    fail "30-material holdout runtime O$opt"
  fi

  for marker in     'PUB_P2E15_CASE_COUNT=180'     'PUB_P2E15_LAYER=A_FIXED_INTERVAL_SOLVER_SEAM'     'PUB_P2E15_STEP_DURATION_DAY=0.0016'     'PUB_P2E15_THRESHOLDS_RETUNED=FALSE'     'PUB_P2E15_TRANSACTION_LEVEL_PAIR_EXECUTED=FALSE'     'PUB_P2E15_PERFORMANCE_CLAIM_EVALUATED=FALSE'     'PUB_P2E15_HOLDOUT_EXECUTION_GATE=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing O$opt marker $marker"; }
  done

  cases="$(grep -Fc 'PUB_P2E15_CASE|' "$OUT/output.txt")"
  thresholds="$(grep -Fc 'PUB_P2E15_THRESHOLD|' "$OUT/output.txt")"
  [[ "$cases" = "180" ]] || fail "expected 180 holdout case records, got $cases"
  [[ "$thresholds" = "3" ]] || fail "expected three threshold strata, got $thresholds"

  cat "$OUT/output.txt"
  echo "PUB_P2E15_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 holdout scientific output drift'
}

echo "PUB_P2E15_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'PUB_P2E15_30_MATERIAL_E0_HOLDOUT_GATE=PASS'
