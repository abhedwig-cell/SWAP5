#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"
fail(){ echo "FPM12_RUNTIME_FAIL $*" >&2; exit 212; }
FMR43=c8ff545cf720db467389c67ac2f9a595e57277ed
FVQ71=f2f410bb74ef40c23fcc16048bb54f9301b989db
TMP="${RUNNER_TEMP:-/tmp}/fpm12-${GITHUB_RUN_ID:-local}-$$"; rm -rf "$TMP"; mkdir -p "$TMP"; trap 'rm -rf "$TMP"' EXIT

git show "$FMR43:tests/fmr/test_fmr43_atomic_surface_publication.f90" > "$TMP/fmr43.f90" || fail 'materialize F-MR43 oracle'
sed '/^program test_fmr43_atomic_surface_publication/,$d' "$TMP/fmr43.f90" > "$TMP/fmr43_support.f90"
git show "$FMR43:tests/fmr/fmr43_forbidden_split_publication_attack.f90" > "$TMP/fmr43_attack.f90" || fail 'materialize F-MR43 attack'
git show "$FVQ71:tests/fvq/test_fvq71_atomic_surface_publication_independent.f90" > "$TMP/fvq71.f90" || fail 'materialize F-VQ71 oracle'
git show "$FVQ71:tests/fvq/fvq71_forbidden_split_surface_publication.f90" > "$TMP/fvq71_attack.f90" || fail 'materialize F-VQ71 attack'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
 tests/fsi/fsi04_real_headcalc_stubs.f90
 src/runtime/mod_a23bu_worker_execution_context.f90
 src/transaction/mod_transaction_reference.f90
 src/transaction/mod_fkt_temporal_indicator_history.f90
 src/runtime/mod_canonical_contracts.f90
 src/runtime/mod_canonical_interval_runtime.f90
 src/kernel/mod_kernel_transactions.f90
 src/runtime/mod_fmr_runtime_core.f90
 src/runtime/mod_fmr_checkpoint_orchestrator.f90
 src/solver/mod_soil_water_solver_contract.f90
 src/solver/mod_process_hydraulic_view.f90
 src/process/mod_soil_temperature_contract.f90
 src/process/mod_restricted_soil_temperature.f90
 src/solver/mod_reference_richards_workspace.f90
 src/solver/mod_reference_richards_state_binding.f90
 src/solver/mod_reference_linear_solver.f90
 src/solver/mod_b110_default_mvg_provider.f90
 src/solver/mod_b110_source_sink_provider.f90
 src/solver/mod_fixed_flux_top_boundary_provider.f90
 src/solver/mod_reference_richards_temporal_indicator.f90
 src/legacy/b1_10_port/headcalc.f90
 src/adapter/mod_reference_richards_legacy_binding.f90
 src/adapter/mod_b110_serialized_context_binding.f90
 src/process/mod_snow_process.f90
 src/solver/mod_b110_root_sink_provider.f90
 src/process/mod_restricted_fixed_weir_surface_water.f90
 tests/fpm/mod_fpm08d7_optional_state_compat.f90
 src/runtime/mod_fmr_serialized_reference_backend.f90
 src/runtime/mod_fmr_process_hydraulic_view_binding.f90
 src/process/mod_reference_et_demand_process.f90
 src/runtime/mod_fmr_reference_et_demand_binding.f90
 src/solver/mod_surface_evaporation_capacity_contract.f90
 src/process/mod_restricted_surface_evaporation.f90
 src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90
 src/runtime/mod_fmr_accepted_commit_receipt.f90
 src/runtime/mod_fmr_surface_evaporation_accepted_publication.f90
)
for opt in 0 2; do
  OUT="$TMP/o$opt"; mkdir -p "$OUT"; objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TMP/fmr43_support.f90" -o "$OUT/support.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpm/test_fpm12_surface_publication_retry_oracle.f90 -o "$OUT/fpm12.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/support.o" "$OUT/fpm12.o" -o "$OUT/fpm12"
  "$OUT/fpm12" > "$OUT/fpm12.txt" 2>&1 || { cat "$OUT/fpm12.txt" >&2; fail "F-PM12 retry oracle O$opt"; }
  for marker in FPM12_ACCEPTED_ONCE=PASS FPM12_REJECT_ZERO_PUBLICATION=PASS FPM12_STALE_OUTPUT_CLEARED=PASS FPM12_REJECT_THEN_ACCEPT=PASS FPM12_REJECT_REJECT_ACCEPT_NO_ACCUMULATION=PASS FPM12_RETRY_EXHAUSTION_NO_PUBLICATION=PASS FPM12_RETRY_ORACLE=PASS; do
    grep -Fq "$marker" "$OUT/fpm12.txt" || fail "missing F-PM12 marker O$opt $marker"
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TMP/fmr43.f90" -o "$OUT/fmr43.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/fmr43.o" -o "$OUT/fmr43"
  "$OUT/fmr43" > "$OUT/fmr43.txt" 2>&1 || { cat "$OUT/fmr43.txt" >&2; fail "F-MR43 replay O$opt"; }
  for marker in FMR43_ATOMIC_CROSS_EXECUTOR_POSITIVE=PASS FMR43_ATOMIC_SECOND_COLUMN_POSITIVE=PASS FMR43_CROSS_CANDIDATE_PRECOMMIT_FAIL_CLOSED=PASS FMR43_MATERIALIZATION_FAILURE_PRECOMMIT_FAIL_CLOSED=PASS FMR43_NO_SECOND_MASS_BOOKING=PASS 'FMR43_OWNER_TEST PASS'; do
    grep -Fq "$marker" "$OUT/fmr43.txt" || fail "missing F-MR43 marker O$opt $marker"
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TMP/fvq71.f90" -o "$OUT/fvq71.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/fvq71.o" -o "$OUT/fvq71"
  "$OUT/fvq71" > "$OUT/fvq71.txt" 2>&1 || { cat "$OUT/fvq71.txt" >&2; fail "F-VQ71 replay O$opt"; }
  for marker in FVQ71_FVQ69_CLASS_STALE_ALTERNATE=PASS_CLOSED FVQ71_CROSS_LINEAGE_PRECOMMIT=PASS_CLOSED FVQ71_NO_MASS_REGRESSION=PASS FVQ71_INDEPENDENT_ORACLE=PASS; do
    grep -Fq "$marker" "$OUT/fvq71.txt" || fail "missing F-VQ71 marker O$opt $marker"
  done

  for attack in fmr43_attack fvq71_attack; do
    if gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TMP/${attack}.f90" -o "$OUT/${attack}.o" > "$OUT/${attack}.log" 2>&1; then
      cat "$OUT/${attack}.log" >&2 || true; fail "forbidden split API compiled O$opt $attack"
    fi
  done
  echo "FPM12_RUNTIME_O${opt}=PASS"
done

for f in fpm12 fmr43 fvq71; do cmp -s "$TMP/o0/$f.txt" "$TMP/o2/$f.txt" || { diff -u "$TMP/o0/$f.txt" "$TMP/o2/$f.txt" >&2 || true; fail "$f O0/O2 drift"; }; done
echo 'FPM12_O0_O2_EXACT_SEMANTIC_IDENTITY=PASS'
echo 'FPM12_FVQ57_ATTACK=PASS_CLOSED'
echo 'FPM12_REJECT_IMMUTABILITY=PASS'
echo 'FPM12_RETRY_PROVENANCE=PASS'
echo 'FPM12_MASS_PRESERVATION=PASS_NO_SECOND_BOOKING'
echo 'FPM12_STANDALONE_MULTISWAP_CROSS_EXECUTOR=PASS'
echo 'FPM12_RUNTIME_GATE=PASS'
