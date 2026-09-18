#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT"

BASE="32d1e9ae1bb3f0cda7a26e114eca0fe5fd900d12"
SOURCE_TREE="d7ef6c045263de821db7800459289efcd8a6420b"
MACRO_MODULE_BLOB="920b93b943ead1187887e683c50a84e0f4cb3a46"
SPEC_COMMIT="9d8528af50bfa8450e5ec731bfdd47f7cd6c83d1"
SPEC_PATH="docs/publications/PUB-GC_NATIVE_TIME_SPEC.md"
SPEC_BLOB="5f563ca26d602a56fdd82419265fa1bfea63399e"
MANIFEST_COMMIT="e553ca282a31f221a23f9291c5670e73f3455b06"
MANIFEST_PATH="docs/publications/manifests/PUB-GC-NATIVE-TIME-0001.yaml"
MANIFEST_BLOB="19c98e4ae7f97d029c9ce2d42d0fe4104a54f0bd"

DIR="tests/publication/pub_gc/native_time"
MACRO_MODULE="tests/publication/pub_gc/macro_window_response/mod_pub_gc_macro_window_response.f90"
TEST="$DIR/test_pub_gc_native_time.f90"
RUNNER="$DIR/run_pub_gc_native_time.sh"
WORKFLOW=".github/workflows/pub-gc-native-time.yml"

fail(){ echo "PUB_GC_NATIVE_RUN_FAIL $*" >&2; exit 97; }

git cat-file -e "$BASE^{commit}" 2>/dev/null || fail "frozen base unavailable"
git merge-base --is-ancestor "$BASE" HEAD || fail "study branch does not descend from qualified macro head"
[[ "$(git rev-parse HEAD:src)" == "$SOURCE_TREE" ]] || fail "production source tree drift"
[[ "$(git rev-parse HEAD:$MACRO_MODULE)" == "$MACRO_MODULE_BLOB" ]] || fail "qualified macro module drift"

for dep in \
  tests/publication/pub_gc/macro_window_response \
  tests/publication/pub_gc/gw_a \
  tests/publication/pub_gc/e1_origin \
  tests/publication/pub_gc/e1_primary_engine \
  tests/publication/pub_gc/e2_terminal_comparator \
  tests/publication/pub_gc/gc_ref \
  tests/publication/pub_gc/reference_screening; do
  [[ "$(git rev-parse HEAD:$dep)" == "$(git rev-parse "$BASE:$dep")" ]] || fail "qualified dependency changed: $dep"
done

mapfile -t changed < <(git diff --name-only "$BASE..HEAD")
for changed_path in "${changed[@]}"; do
  case "$changed_path" in
    "$DIR"/*|"$WORKFLOW") ;;
    *) fail "out-of-scope native-time mutation: $changed_path" ;;
  esac
done

git fetch --quiet --no-tags origin refs/heads/work/pub-gc-scientific-contract:refs/remotes/origin/work/pub-gc-scientific-contract
git cat-file -e "$SPEC_COMMIT^{commit}" 2>/dev/null || fail "spec authority unavailable"
git cat-file -e "$MANIFEST_COMMIT^{commit}" 2>/dev/null || fail "manifest authority unavailable"
[[ "$(git rev-parse "$SPEC_COMMIT:$SPEC_PATH")" == "$SPEC_BLOB" ]] || fail "spec blob drift"
[[ "$(git rev-parse "$MANIFEST_COMMIT:$MANIFEST_PATH")" == "$MANIFEST_BLOB" ]] || fail "manifest blob drift"

grep -Fq "native_dt(nlevel)=[0.01_real64,0.005_real64,0.0025_real64,0.00125_real64]" "$TEST" || fail "frozen ladder missing"
grep -Fq "tol_q=1.0e-4_real64" "$TEST" || fail "exchange tolerance drift"
grep -Fq "tol_head=1.0e-2_real64" "$TEST" || fail "head tolerance drift"
grep -Fq "tol_water=1.0e-5_real64" "$TEST" || fail "water tolerance drift"
grep -Fq "tol_storage=1.0e-4_real64" "$TEST" || fail "storage tolerance drift"
if grep -Eq 'whole_minus_terminal|q_terminal_rectangle|terminal_surrogate.*(>|<|abs)' "$TEST"; then
  fail "terminal-surrogate mismatch leaked into native-time selection oracle"
fi

echo "PUB_GC_NATIVE_SPEC_LOCK=PASS:$SPEC_COMMIT:$SPEC_BLOB"
echo "PUB_GC_NATIVE_MANIFEST_LOCK=PASS:$MANIFEST_COMMIT:$MANIFEST_BLOB"
echo "PUB_GC_NATIVE_MACRO_MODULE_LOCK=PASS:$MACRO_MODULE_BLOB"
echo "PUB_GC_NATIVE_PRODUCTION_SRC_UNCHANGED=PASS:$SOURCE_TREE"
echo "PUB_GC_NATIVE_QUALIFIED_DEPENDENCIES_UNCHANGED=PASS"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-gc-native-${GITHUB_RUN_ID:-local}-$$"
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
  tests/fmr/mod_fmr04_fixed_top_provider.f90
  "$MACRO_MODULE"
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

  timeout 300s "$OUT/test" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "O$opt native-time executable failed"
  }

  grep -Fq 'PUB_GC_NATIVE_TERMINAL_MISMATCH_USED_FOR_SELECTION=false' "$OUT/output.txt" || fail "O$opt selection-firewall marker missing"
  grep -Fq 'PUB_GC_NATIVE_PRIMARY_H2_H3_ELIGIBLE=false' "$OUT/output.txt" || fail "O$opt H2/H3 firewall marker missing"
  grep -Fq 'PUB_GC_NATIVE_TIME_EXECUTION_COMPLETE=PASS' "$OUT/output.txt" || fail "O$opt execution-complete marker missing"
  grep -Eq '^PUB_GC_NATIVE_POLICY_SELECTION=(SELECT_N0_0P01000_DAY|SELECT_N1_0P00500_DAY|SELECT_N2_0P00250_DAY|NO_POLICY_SELECTED|NO_POLICY_SELECTED_FINE_LEVEL_UNSTABLE)$' "$OUT/output.txt" || fail "O$opt invalid selection token"
  echo "PUB_GC_NATIVE_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail "O0/O2 scientific output drift"
}

cat "$BUILD/o0/output.txt"
echo "PUB_GC_NATIVE_O0_O2_IDENTITY=PASS"
echo "PUB_GC_NATIVE_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo "PUB_GC_NATIVE_HEAD=$(git rev-parse HEAD)"
echo "PUB_GC_NATIVE_SOURCE_TREE=$(git rev-parse HEAD:src)"
echo "PUB_GC_NATIVE_TEST_BLOB=$(git rev-parse HEAD:$TEST)"
echo "PUB_GC_NATIVE_RUNNER_BLOB=$(git rev-parse HEAD:$RUNNER)"
echo "PUB_GC_NATIVE_TIME_STUDY=PASS"
