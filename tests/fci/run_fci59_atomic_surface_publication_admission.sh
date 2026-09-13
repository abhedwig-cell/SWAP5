#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fci59-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FCI59_GATE_FAIL $*" >&2; exit 159; }

BASE=4fae08472c053d1b3d43d3d0b4f9b61956e7b646
INDEPENDENT=f2f410bb74ef40c23fcc16048bb54f9301b989db
MATERIALIZER=src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90
PUBLICATION=src/runtime/mod_fmr_surface_evaporation_accepted_publication.f90
KERNEL=src/kernel/mod_kernel_transactions.f90
RECEIPT=src/runtime/mod_fmr_accepted_commit_receipt.f90
PROCESS=src/process/mod_restricted_surface_evaporation.f90

# Current-canonical recomposition must be exact and bounded.
test "$(git merge-base "$BASE" HEAD)" = "$BASE" || fail 'branch no longer descends from restart canonical'
mapfile -t src_delta < <(git diff --name-only "$BASE"..HEAD -- src | sort)
expected=("$PUBLICATION" "$MATERIALIZER")
[[ "${src_delta[*]}" == "${expected[*]}" ]] || fail "unexpected production delta: ${src_delta[*]:-none}"
git diff --quiet "$BASE"..HEAD -- reference || fail 'reference source changed'
test "$(git rev-parse HEAD:$MATERIALIZER)" = b8ff1fb1d9434e952163b6955305c6373dd8ac82 || fail 'materializer blob mismatch'
test "$(git rev-parse HEAD:$PUBLICATION)" = f0f3ce5c16a66c2058c22a529e176d6b06446649 || fail 'publication blob mismatch'
test "$(git rev-parse HEAD:$KERNEL)" = c7c5b7d3357e4e6739c8f647d6232baca45563e6 || fail 'kernel drift or F-KT20 leakage'
test "$(git rev-parse HEAD:$RECEIPT)" = 6798b3296b426950bf028814585c3f5de9be950b || fail 'accepted receipt drift'
test "$(git rev-parse HEAD:$PROCESS)" = a213af4deec2fe854d79120899827852a57237d1 || fail 'surface process physics drift'
echo 'FCI59_EXACT_TWO_FILE_PRODUCTION_COMPOSITION=PASS'
echo 'FCI59_REFERENCE_UNCHANGED=PASS'
echo 'FCI59_NO_FKT20_KERNEL_DEPENDENCY=PASS'

# The permanent canonical preservation workflow must now bind the exact F-CI59
# production composition rather than silently accepting the intentional delta.
grep -Fq 'AUTH=2d8b08c06b67132f57b2c757f493d1b31a954a92' .github/workflows/fci-canonical.yml || fail 'canonical moving authority not advanced'
grep -Fq 'src/runtime/mod_fmr_surface_evaporation_accepted_publication.f90' .github/workflows/fci-canonical.yml || fail 'publication missing from permanent preservation surface'
grep -Fq 'FCI59_MOVING_ATOMIC_SURFACE_PUBLICATION_PRESERVATION=PASS' .github/workflows/fci-canonical.yml || fail 'FCI59 permanent marker missing'
echo 'FCI59_PERMANENT_CANONICAL_PRESERVATION_GATE=PASS'

# Fetch only the frozen independent verifier authority and materialize its test
# sources into the ephemeral build. Production source always comes from HEAD.
git cat-file -e "$INDEPENDENT^{commit}" 2>/dev/null || git fetch --no-tags origin "$INDEPENDENT"
git show "$INDEPENDENT:integration/f-vq/F-VQ71_STATUS.json" > "$BUILD/F-VQ71_STATUS.json"
grep -Fq '"decision": "QUALIFIED_ATOMIC_SURFACE_EVAPORATION_ACCEPTED_PUBLICATION"' "$BUILD/F-VQ71_STATUS.json" || fail 'independent authority decision mismatch'
grep -Fq '"independently_qualified": true' "$BUILD/F-VQ71_STATUS.json" || fail 'independent authority is not closed qualified'
git show "$INDEPENDENT:tests/fvq/test_fvq71_atomic_surface_publication_independent.f90" > "$BUILD/test_fvq71.f90"
git show "$INDEPENDENT:tests/fvq/fvq71_forbidden_split_surface_publication.f90" > "$BUILD/fvq71_attack.f90"
echo 'FCI59_INDEPENDENT_AUTHORITY_BOUND=PASS'

# Static architecture guards for the new runtime-only seam.
python3 - "$PUBLICATION" "$MATERIALIZER" <<'PY'
from pathlib import Path
import re, sys
p=Path(sys.argv[1]).read_text(encoding='utf-8').lower()
m=Path(sys.argv[2]).read_text(encoding='utf-8').lower()
for token in (
    'public :: fmr_commit_candidate_with_surface_evaporation_publication',
    'call fmr_materialize_candidate_bound_surface_evaporation',
    'call fmr_commit_candidate_with_receipt',
    'call finalize_local_prepared',
):
    if token not in p:
        raise SystemExit(f'missing atomic publication token: {token}')
for forbidden in (
    'public :: fmr_prepare_surface_evaporation_publication',
    'public :: fmr_finalize_surface_evaporation_publication',
    'execution_provenance_id', 'candidate_sequence_value',
    'canonical_mass_accounting_t', 'mass%total_in', 'mass%total_out', 'mass_ledger',
    'day_of', 'month_of', 'year_of', 'midnight', '.swp', 'file_unit', 'pathname', 'modflow'
):
    if forbidden in p:
        raise SystemExit(f'forbidden publication dependency: {forbidden}')
for label,text in [('publication',p),('materializer',m)]:
    if re.search(r'\b(open|read|write|close)\s*\(', text):
        raise SystemExit(f'{label} introduced file I/O')
a=p.index('call fmr_materialize_candidate_bound_surface_evaporation')
b=p.index('call fmr_commit_candidate_with_receipt')
c=p.index('call finalize_local_prepared')
if not a < b < c:
    raise SystemExit('atomic publication ordering drift')
print('FCI59_ATOMIC_PUBLICATION_STRUCTURE=PASS')
print('FCI59_NO_SECOND_MASS_AUTHORITY=PASS')
print('FCI59_NO_IO_CALENDAR_COUPLER_DEPENDENCY=PASS')
PY

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
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/test_fvq71.f90" -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "F-VQ71 replay O$opt"; }
  for marker in \
    FVQ71_AMBIGUOUS_OLD_PROVENANCE_PAIR=REPRODUCED \
    FVQ71_ATOMIC_CROSS_EXECUTOR_POSITIVE=PASS \
    FVQ71_FVQ69_CLASS_STALE_ALTERNATE=PASS_CLOSED \
    FVQ71_CROSS_LINEAGE_PRECOMMIT=PASS_CLOSED \
    FVQ71_NO_MASS_REGRESSION=PASS \
    FVQ71_DECISION=QUALIFIED_ATOMIC_SURFACE_EVAPORATION_ACCEPTED_PUBLICATION \
    FVQ71_INDEPENDENT_ORACLE=PASS; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing independent marker O$opt: $marker"; }
  done
  if gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/fvq71_attack.f90" -o "$OUT/attack.o" >"$OUT/attack.log" 2>&1; then
    cat "$OUT/attack.log" >&2 || true
    fail "historical split API attack compiled at O$opt"
  fi
  test ! -e "$OUT/attack.o" || fail "forbidden attacker object emitted O$opt"
  echo "FCI59_FVQ71_SPLIT_API_HARD_NEGATIVE_O${opt}=PASS_CLOSED"
  echo "FCI59_FVQ71_REPLAY_O${opt}=PASS"
done
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'F-VQ71 O0/O2 replay drift'
}
cat "$BUILD/o0/output.txt"
echo 'FCI59_FVQ71_O0_O2_SEMANTIC_IDENTITY=PASS'

# Architectural disposition for the bounded admission. These are source- and
# runtime-backed claims only; no broader physics completion is inferred here.
echo 'FCI59_INVARIANT_1_ONE_KERNEL=PRESERVED'
echo 'FCI59_INVARIANT_2_KERNEL_IO_SEPARATION=PRESERVED'
echo 'FCI59_INVARIANT_4_COMPACT_PERSISTENT_STATE=PRESERVED_NO_NEW_STATE'
echo 'FCI59_INVARIANT_5_SCRATCH_PER_WORKER=PRESERVED_PRIVATE_LOCAL_CARRIER'
echo 'FCI59_INVARIANT_7_TRANSACTIONAL_STEPS=PASS_ATOMIC_COMMIT_PUBLICATION'
echo 'FCI59_INVARIANT_9_GENERIC_TIME=PRESERVED'
echo 'FCI59_INVARIANT_13_MASS_CONSERVATION=PRESERVED_NO_SECOND_MASS_AUTHORITY'
echo 'FCI59_INVARIANT_16_MULTISWAP=PRESERVED_CROSS_EXECUTOR_POSITIVE'
echo 'FCI59_INVARIANT_22_SOLVER_INTERNAL_ISOLATION=PRESERVED'
echo 'FCI59_INVARIANT_23_PHYSICS_POLICY_SEPARATION=PRESERVED'
echo 'FCI59_INVARIANT_25_REFERENCE_MODE=PRESERVED'
echo 'FCI59_INVARIANT_26_DIAGNOSTICS=PRESERVED_EXPLICIT_STATUS'
echo 'FCI59_INVARIANT_27_OPTIONAL_COST=PRESERVED_PUBLICATION_ONLY_WHEN_CALLED'
echo 'FCI59_INVARIANT_29_NO_SILENT_DEPENDENCIES=PASS'
echo 'FCI59_INVARIANT_30_ARCHITECTURE_AUDIT=PASS'
echo 'FCI59_ADMISSION_GATE=PASS'
