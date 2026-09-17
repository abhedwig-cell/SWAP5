#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT"

BASE_GW_A="8a090fc9228574525e599817771aadb8ae176047"
SPEC_COMMIT="2d0a9ea26dbb6048e60e67dcf6882a1b03664d61"
SPEC_PATH="docs/publications/PUB-GC_E1_ORIGIN_HARNESS_SPEC.md"
SPEC_BLOB="554ebf5841b533b38f19dce533b2efb978348971"
GW_A_DIR="tests/publication/pub_gc/gw_a"
TEST="tests/publication/pub_gc/e1_origin/test_pub_gc_e1_origin_harness.f90"
RUNNER="tests/publication/pub_gc/e1_origin/run_pub_gc_e1_origin_harness_qualification.sh"
WORKFLOW=".github/workflows/pub-gc-e1-origin-harness-qualification.yml"

fail() { echo "PUB_GC_E1_HARNESS_GATE_FAIL $*" >&2; exit 31; }

git cat-file -e "$BASE_GW_A^{commit}" 2>/dev/null || fail "missing GW-A qualified authority"
git cat-file -e "$SPEC_COMMIT^{commit}" 2>/dev/null || fail "missing frozen E1 specification authority"
[[ "$(git rev-parse "$SPEC_COMMIT:$SPEC_PATH")" == "$SPEC_BLOB" ]] || fail "E1 specification blob drift"

git merge-base --is-ancestor "$BASE_GW_A" HEAD || fail "research head does not descend from qualified GW-A"
[[ "$(git rev-parse HEAD:src)" == "$(git rev-parse "$BASE_GW_A:src")" ]] || fail "production source tree changed"
[[ "$(git rev-parse HEAD:$GW_A_DIR)" == "$(git rev-parse "$BASE_GW_A:$GW_A_DIR")" ]] || fail "qualified GW-A implementation changed"

mapfile -t changed < <(git diff --name-only "$BASE_GW_A..HEAD")
for path in "${changed[@]}"; do
  case "$path" in
    tests/publication/pub_gc/e1_origin/*|.github/workflows/pub-gc-e1-origin-harness-qualification.yml) ;;
    *) fail "out-of-scope research mutation: $path" ;;
  esac
done
echo 'PUB_GC_E1_RESEARCH_ONLY_SCOPE=PASS'
echo 'PUB_GC_E1_PRODUCTION_SRC_UNCHANGED=PASS'
echo 'PUB_GC_E1_GW_A_BYTES_UNCHANGED=PASS'
echo "PUB_GC_E1_FROZEN_SPEC=PASS:$SPEC_COMMIT:$SPEC_BLOB"

grep -Fq 'call synthetic%initialize' "$TEST" || fail "history diagnostic does not use public initialize"
grep -Fq 'call local_candidate%snapshot' "$TEST" || fail "candidate physical snapshot route missing"
grep -Fq 'PUB_GC_E1_HISTORY_DIAG_PRODUCTION_VALID=false' "$TEST" || fail "machine-readable invalid-for-production label missing"
if grep -Eq 'fmr_commit_candidate|%commit_candidate|kernel_reconstruct_committed_state_trusted' "$TEST"; then
  fail "history diagnostic contains forbidden publication/reconstruction route"
fi
echo 'PUB_GC_E1_PUBLIC_API_ONLY_STATIC=PASS'
echo 'PUB_GC_E1_NO_PRODUCTION_COMMIT_STATIC=PASS'

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-gc-e1-origin-${GITHUB_RUN_ID:-local}-$$"
GW_A_WORKTREE="$BUILD/gw-a-authority"
mkdir -p "$BUILD"
cleanup() {
  git -C "$ROOT" worktree remove --force "$GW_A_WORKTREE" >/dev/null 2>&1 || true
  rm -rf "$BUILD"
}
trap cleanup EXIT

# Re-run the independently qualified GW-A component exactly at its frozen
# authority. New E1 harness files are deliberately not made acceptable inputs
# to the GW-A gate itself.
git worktree add --detach "$GW_A_WORKTREE" "$BASE_GW_A" >/dev/null
(
  cd "$GW_A_WORKTREE"
  bash tests/publication/pub_gc/gw_a/run_pub_gc_gw_a_qualification.sh
) > "$BUILD/gw-a-qualification.txt" 2>&1 || {
  cat "$BUILD/gw-a-qualification.txt" >&2
  fail "frozen GW-A qualification failed"
}
grep -Fq 'PUB_GC_GW_A_QUALIFICATION=PASS' "$BUILD/gw-a-qualification.txt" || fail "GW-A PASS marker missing"
echo 'PUB_GC_E1_GW_A_INDEPENDENT_QUALIFICATION=PASS'

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
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
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
  timeout 120s "$OUT/test" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "real-SWAP origin oracle O$opt"
  }

  for marker in     'PUB_GC_E1_SAME_ORIGIN_A_B_A=PASS'     'PUB_GC_E1_ACCEPTED_ORIGIN_UNCHANGED=PASS'     'PUB_GC_E1_WHOLE_WINDOW_EXCHANGE_AVAILABLE=PASS'     'PUB_GC_E1_HISTORY_DIAG_PUBLIC_SNAPSHOT_INITIALIZE=PASS'     'PUB_GC_E1_HISTORY_DIAG_DISTINCT_LINEAGE=PASS'     'PUB_GC_E1_HISTORY_DIAG_NO_COMMIT=PASS'     'PUB_GC_E1_HISTORY_DIAG_PRODUCTION_VALID=false'     'PUB_GC_E1_UNSUPPORTED_ROUTE_FAIL_CLOSED=PASS'     'PUB_GC_E1_ORIGIN_HARNESS_ORACLE=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || {
      cat "$OUT/output.txt" >&2
      fail "missing O$opt marker: $marker"
    }
  done
  echo "PUB_GC_E1_REAL_SWAP_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail "O0/O2 scientific-oracle drift"
}

cp "$BUILD/o0/output.txt" "$BUILD/origin-harness-output.txt"
cat "$BUILD/o0/output.txt"
echo 'PUB_GC_E1_O0_O2_IDENTITY=PASS'
echo "PUB_GC_E1_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo "PUB_GC_E1_RESEARCH_HEAD=$(git rev-parse HEAD)"
echo "PUB_GC_E1_SOURCE_TREE=$(git rev-parse HEAD:src)"
echo "PUB_GC_E1_TEST_BLOB=$(git rev-parse HEAD:$TEST)"
echo "PUB_GC_E1_RUNNER_BLOB=$(git rev-parse HEAD:$RUNNER)"
echo 'PUB_GC_E1_ORIGIN_HARNESS_QUALIFICATION=PASS'
