#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"
fail(){ echo "FCI60_REPLAY_FAIL $*" >&2; exit 260; }
FVQ72=a3c7bf5a60d80b430758f85489b316b5bcbc2fdc
FMR43=c8ff545cf720db467389c67ac2f9a595e57277ed
FVQ57=4ccc2a21390af3872042b899ff39ead628a1a65e
TMP="${RUNNER_TEMP:-/tmp}/fci60-replay-${GITHUB_RUN_ID:-local}-$$"; rm -rf "$TMP"; mkdir -p "$TMP"; trap 'rm -rf "$TMP"' EXIT

git show "$FVQ72:tests/fvq/test_fvq72_surface_publication_independent.f90" > "$TMP/fvq72.f90" || fail 'materialize F-VQ72 oracle'
git show "$FVQ72:tests/fvq/fvq72_forbidden_split_surface_publication.f90" > "$TMP/fvq72_forbidden.f90" || fail 'materialize F-VQ72 split attack'
git show "$FMR43:tests/fmr/test_fmr43_atomic_surface_publication.f90" > "$TMP/fmr43.f90" || fail 'materialize F-MR43 support'
sed '/^program test_fmr43_atomic_surface_publication/,$d' "$TMP/fmr43.f90" > "$TMP/fmr43_support.f90"
git show "$FVQ57:tests/fvq/mod_fvq57_independent_publication_backend.f90" > "$TMP/fvq57_backend.f90" || fail 'materialize F-VQ57 backend'
git show "$FVQ57:tests/fvq/test_fvq57_surface_result_candidate_binding.f90" > "$TMP/fvq57_attack.f90" || fail 'materialize exact F-VQ57 attack'

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
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TMP/fvq72.f90" -o "$OUT/fvq72.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/support.o" "$OUT/fvq72.o" -o "$OUT/fvq72"
  "$OUT/fvq72" > "$OUT/fvq72.txt" 2>&1 || { cat "$OUT/fvq72.txt" >&2; fail "F-VQ72 replay O$opt"; }
  for marker in \
    FVQ72_ACCEPTED_ONCE=PASS \
    FVQ72_SAME_EXECUTOR_STANDALONE=PASS \
    FVQ72_SERIALIZED_MULTISWAP_EQUIVALENCE=PASS \
    FVQ72_ATOMIC_PLAIN_COMMIT_PHYSICAL_EQUIVALENCE=PASS \
    FVQ72_NO_SECOND_MASS_BOOKING=PASS \
    FVQ72_REJECT_IMMUTABILITY=PASS_EXACT_COMMITTED_STATE \
    FVQ72_PRELOADED_OUTPUT_CLEARED=PASS \
    FVQ72_REJECT_THEN_ACCEPT=PASS \
    FVQ72_REJECT_REJECT_ACCEPT_NO_ACCUMULATION=PASS \
    FVQ72_RETRY_EXHAUSTION=PASS_NO_ACCEPTED_PUBLICATION \
    FVQ72_CROSS_LINEAGE_FAIL_CLOSED=PASS \
    FVQ72_SAME_ORIGIN_ALTERNATE_AFTER_ACCEPT=PASS_FAIL_CLOSED \
    FVQ72_INDEPENDENT_ORACLE=PASS; do
      grep -Fq "$marker" "$OUT/fvq72.txt" || fail "missing F-VQ72 marker O$opt $marker"
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TMP/fvq57_backend.f90" -o "$OUT/fvq57_backend.o"
  if gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TMP/fvq57_attack.f90" -o "$OUT/fvq57_attack.o" > "$OUT/fvq57_attack.log" 2>&1; then
    fail "historical F-VQ57 attack compiled O$opt"
  fi
  grep -Eq 'fmr_prepared_surface_evaporation_publication_t|fmr_prepare_surface_evaporation_publication|fmr_finalize_surface_evaporation_publication' "$OUT/fvq57_attack.log" || fail "F-VQ57 failure not tied to closed API O$opt"
  if gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TMP/fvq72_forbidden.f90" -o "$OUT/forbidden.o" > "$OUT/forbidden.log" 2>&1; then
    fail "forbidden split API compiled O$opt"
  fi
  echo "FCI60_FVQ72_REPLAY_O${opt}=PASS"
done

cmp -s "$TMP/o0/fvq72.txt" "$TMP/o2/fvq72.txt" || { diff -u "$TMP/o0/fvq72.txt" "$TMP/o2/fvq72.txt" >&2 || true; fail 'O0/O2 replay drift'; }
echo 'FCI60_FVQ72_O0_O2_PRESERVED=PASS'
echo 'FCI60_FVQ57_ATTACK_PRESERVED_CLOSED=PASS'
echo 'FCI60_REJECT_PUBLICATION_IMPOSSIBLE=PASS'
echo 'FCI60_RETRY_PROVENANCE=PASS'
echo 'FCI60_MASS_PRESERVED=PASS_NO_SECOND_BOOKING'
echo 'FCI60_STANDALONE_MULTISWAP_PRESERVED=PASS'
echo 'FCI60_FVQ72_REPLAY_GATE=PASS'
