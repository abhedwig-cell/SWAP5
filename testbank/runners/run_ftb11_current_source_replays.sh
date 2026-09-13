#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
CANON=379afd11e9a1d7fbef5ec74c9e05b0ec55884f4b
FVQ65=b1fd9e15a22d4dd68997ec38c074ce343eec0a70
FVQ71=f2f410bb74ef40c23fcc16048bb54f9301b989db
WT="${RUNNER_TEMP:-/tmp}/ftb11-canonical-${GITHUB_RUN_ID:-local}-$$"
BUILD="${RUNNER_TEMP:-/tmp}/ftb11-replay-${GITHUB_RUN_ID:-local}-$$"
fail(){ echo "FTB11_REPLAY_FAIL $*" >&2; exit 111; }
cleanup(){ git -C "$ROOT" worktree remove --force "$WT" >/dev/null 2>&1 || true; rm -rf "$WT" "$BUILD"; }
trap cleanup EXIT
rm -rf "$WT" "$BUILD"; mkdir -p "$BUILD"
git worktree add --detach "$WT" "$CANON" >/dev/null
cd "$WT"
[[ "$(git rev-parse HEAD)" == "$CANON" ]] || fail 'canonical worktree mismatch'

# FTB11-TXN-001 / FTB11-MASS-001. A23BL predates the mandatory
# mass-completeness contract, so the independently qualified F-VQ65 attack
# matrix is the valid moving transaction/mass oracle for this source generation.
mkdir -p tests/fvq
for f in \
  mod_fvq65_mass_attack_support.f90 \
  test_fvq65_mass_fail_closed.f90 \
  test_fvq65_canonical_gap_witness.f90 \
  run_fvq65_mass_completeness_independent.sh \
  run_fvq65_current_preservation.sh; do
  git show "$FVQ65:tests/fvq/$f" > "tests/fvq/$f" || fail "cannot materialize F-VQ65 $f"
done
chmod +x tests/fvq/run_fvq65_mass_completeness_independent.sh tests/fvq/run_fvq65_current_preservation.sh
bash tests/fvq/run_fvq65_mass_completeness_independent.sh
if grep -Ein '\bsave\b|open\s*\(|read\s*\(|write\s*\(' src/transaction/mod_transaction_reference.f90; then
  fail 'transaction source acquired hidden state or file I/O'
fi
echo 'FTB11-TXN-001=PASS_QUALIFIED_FVQ65_CURRENT_SOURCE_ORACLE'
echo 'FTB11-MASS-001=PASS'

# FTB11-RST-001 / FTB11-MSW-001. This independent preservation replay rebuilds
# restart, serialized MultiSWAP, parallel runtime and coupling on current source.
bash tests/fvq/run_fvq65_current_preservation.sh
echo 'FTB11-RST-001=PASS_EXECUTABLE_CURRENT_SOURCE_REPLAY'
echo 'FTB11-MSW-001=PASS_EXECUTABLE_CURRENT_SOURCE_REPLAY'

# FTB11-REJECT-001 / FTB11-ETPUB-001. F-VQ71 is the current independent oracle
# for atomic accepted publication. It proves stale and cross-lineage candidates
# fail before commit/publication and leave the committed revision unchanged.
for f in test_fvq71_atomic_surface_publication_independent.f90 fvq71_forbidden_split_surface_publication.f90; do
  git show "$FVQ71:tests/fvq/$f" > "$BUILD/$f" || fail "cannot materialize F-VQ71 $f"
done
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
  OUT="$BUILD/pub-o$opt"; mkdir -p "$OUT"; objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/test_fvq71_atomic_surface_publication_independent.f90" -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "F-VQ71 O$opt execution"; }
  for marker in \
    'FVQ71_FVQ69_CLASS_STALE_ALTERNATE=PASS_CLOSED' \
    'FVQ71_CROSS_LINEAGE_PRECOMMIT=PASS_CLOSED' \
    'FVQ71_NO_MASS_REGRESSION=PASS' \
    'FVQ71_INDEPENDENT_ORACLE=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || fail "F-VQ71 O$opt missing marker: $marker"
  done
  if gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/fvq71_forbidden_split_surface_publication.f90" -o "$OUT/attack.o" >"$OUT/attack.log" 2>&1; then
    fail "forbidden split surface-publication API compiled at O$opt"
  fi
done
cmp -s "$BUILD/pub-o0/output.txt" "$BUILD/pub-o2/output.txt" || fail 'F-VQ71 O0/O2 semantic drift'
echo 'FTB11-REJECT-001=PASS_FVQ71_PRECOMMIT_IMMUTABILITY'
echo 'FTB11-ETPUB-001=PASS'
echo 'FTB11_CURRENT_SOURCE_SEMANTIC_REPLAYS=PASS'
