#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT"

BASE="c48ad3e09a7ab373e3ee424ae90fabbb65e83e4f"
SOURCE_TREE="d7ef6c045263de821db7800459289efcd8a6420b"
MANIFEST_COMMIT="6096c24e91d6d9ab8ee8b812b0090123878a6cef"
MANIFEST_PATH="docs/publications/manifests/PUB-GC-TRANSIENT-SCREEN-0001.yaml"
MANIFEST_BLOB="7aa93be2f6698ad6e655e70bf1024758e7516da4"

GW_A_DIR="tests/publication/pub_gc/gw_a"
E1_ORIGIN_DIR="tests/publication/pub_gc/e1_origin"
E1_ENGINE_DIR="tests/publication/pub_gc/e1_primary_engine"
E2_DIR="tests/publication/pub_gc/e2_terminal_comparator"
GC_REF_DIR="tests/publication/pub_gc/gc_ref"
REF_SCREEN_DIR="tests/publication/pub_gc/reference_screening"
DIR="tests/publication/pub_gc/transient_screening"
TRAJECTORY="$DIR/mod_pub_gc_transient_trajectory.f90"
TEST="$DIR/test_pub_gc_transient_screening.f90"
RUNNER="$DIR/run_pub_gc_transient_screening.sh"
WORKFLOW=".github/workflows/pub-gc-transient-screening.yml"

fail(){ echo "PUB_GC_TRANSIENT_SCREEN_RUN_FAIL $*" >&2; exit 96; }

git cat-file -e "$BASE^{commit}" 2>/dev/null || fail "frozen stable-reference base unavailable"
git merge-base --is-ancestor "$BASE" HEAD || fail "transient branch does not descend from frozen base"
[[ "$(git rev-parse HEAD:src)" == "$SOURCE_TREE" ]] || fail "production source tree drift"

for dep in "$GW_A_DIR" "$E1_ORIGIN_DIR" "$E1_ENGINE_DIR" "$E2_DIR" "$GC_REF_DIR" "$REF_SCREEN_DIR"; do
  [[ "$(git rev-parse HEAD:$dep)" == "$(git rev-parse "$BASE:$dep")" ]] || fail "qualified dependency changed: $dep"
done

mapfile -t changed < <(git diff --name-only "$BASE..HEAD")
for changed_path in "${changed[@]}"; do
  case "$changed_path" in
    "$DIR"/*|"$WORKFLOW") ;;
    *) fail "out-of-scope transient-screening mutation: $changed_path" ;;
  esac
done

git fetch --quiet --no-tags origin refs/heads/work/pub-gc-scientific-contract:refs/remotes/origin/work/pub-gc-scientific-contract
git cat-file -e "$MANIFEST_COMMIT^{commit}" 2>/dev/null || fail "transient manifest authority unavailable"
[[ "$(git rev-parse "$MANIFEST_COMMIT:$MANIFEST_PATH")" == "$MANIFEST_BLOB" ]] || fail "transient manifest blob drift"

grep -Fq 'fmr_commit_candidate_with_receipt' "$TRAJECTORY" || fail "accepted SWAP commit route missing"
grep -Fq 'groundwater_prepare_candidate' "$TRAJECTORY" || fail "groundwater prepare route missing"
grep -Fq 'groundwater_commit_prepared' "$TRAJECTORY" || fail "groundwater prepared commit route missing"
grep -Fq 'gc_ref_bisect' "$TRAJECTORY" || fail "qualified GC-REF root oracle missing"
grep -Fq 'pub_gc_e2_compare' "$TRAJECTORY" || fail "qualified E2 terminal comparator missing"
for case_id in TS-WET-5 TS-DRY-1 TS-REV TS-GW-UP TS-GW-DOWN TS-LOW-SY-WET; do
  grep -Fq "'$case_id'" "$TEST" || fail "missing preregistered case $case_id"
done
if grep -Eiq 'newton|broyden|aitken|secant|tangent|dQ.?/.?dh|dh.?/.?dq' "$TRAJECTORY" "$TEST"; then
  fail "response/derivative acceleration leaked into PUB-GC screening"
fi

echo "PUB_GC_TRANSIENT_MANIFEST_LOCK=PASS:$MANIFEST_COMMIT:$MANIFEST_BLOB"
echo "PUB_GC_TRANSIENT_PRODUCTION_SRC_UNCHANGED=PASS:$SOURCE_TREE"
echo "PUB_GC_TRANSIENT_QUALIFIED_DEPENDENCIES_UNCHANGED=PASS"
echo "PUB_GC_TRANSIENT_ACCEPTED_PUBLICATION_POLICY=PASS"
echo "PUB_GC_TRANSIENT_DERIVATIVE_ACCELERATION_ABSENT=PASS"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-gc-transient-screening-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
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
  src/runtime/mod_fmr_accepted_commit_receipt.f90
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
  src/runtime/mod_fmr_owned_commit_receipt.f90
  src/runtime/mod_fmr_bottom_external_thermal_binding.f90
  src/runtime/mod_fmr_bottom_external_thermal_provider.f90
  src/process/mod_liquid_water_sensible_enthalpy.f90
  src/runtime/mod_fmr_bottom_sensible_energy.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_groundwater_exchange_service_contract.f90
  tests/publication/pub_gc/gw_a/mod_pub_gc_gw_a.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
  tests/publication/pub_gc/gc_ref/mod_pub_gc_gc_ref.f90
  tests/publication/pub_gc/e2_terminal_comparator/mod_pub_gc_e2_terminal_comparator.f90
  "$TRAJECTORY"
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    [[ -f "$source" ]] || fail "missing compile source $source"
    obj="$OUT/$(echo "$source" | tr '/.' '__').o"
    extra=()
    [[ "$source" == "src/solver/mod_soil_water_solver_contract.f90" ]] && extra=(-Wno-error=unused-dummy-argument)
    gfortran "${COMMON[@]}" "${extra[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/test.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"

  timeout 900s "$OUT/test" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "O$opt transient-screening executable failed"
  }

  grep -Fq 'PUB_GC_TRANSIENT_SCREEN_CASES_ADJUDICATED=6' "$OUT/output.txt" || {
    cat "$OUT/output.txt" >&2
    fail "O$opt did not adjudicate all six cases"
  }
  grep -Fq 'PUB_GC_TRANSIENT_SCREEN_PRIMARY_H2_H3_ELIGIBLE=false' "$OUT/output.txt" || fail "O$opt primary-eligibility guard missing"
  grep -Fq 'PUB_GC_TRANSIENT_SCREEN_EXECUTION_VALID=PASS' "$OUT/output.txt" || fail "O$opt execution-valid marker missing"

  case_count=$(grep -Ec '^PUB_GC_TRANSIENT_CASE_CLASS=(VALID_STABLE_RESOLVED|VALID_STABLE_UNRESOLVED|VALID_UNSTABLE|INVALID)$' "$OUT/output.txt" || true)
  [[ "$case_count" -eq 6 ]] || {
    cat "$OUT/output.txt" >&2
    fail "O$opt expected six scientific case adjudications, got $case_count"
  }
  echo "PUB_GC_TRANSIENT_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail "O0/O2 scientific output drift"
}

cp "$BUILD/o0/output.txt" "$BUILD/transient-screening-output.txt"
cat "$BUILD/o0/output.txt"
echo "PUB_GC_TRANSIENT_O0_O2_IDENTITY=PASS"
echo "PUB_GC_TRANSIENT_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo "PUB_GC_TRANSIENT_HEAD=$(git rev-parse HEAD)"
echo "PUB_GC_TRANSIENT_SOURCE_TREE=$(git rev-parse HEAD:src)"
echo "PUB_GC_TRANSIENT_TRAJECTORY_BLOB=$(git rev-parse HEAD:$TRAJECTORY)"
echo "PUB_GC_TRANSIENT_TEST_BLOB=$(git rev-parse HEAD:$TEST)"
echo "PUB_GC_TRANSIENT_RUNNER_BLOB=$(git rev-parse HEAD:$RUNNER)"
echo 'PUB_GC_TRANSIENT_SCREENING=PASS'
