#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fmr43-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FMR43_GATE_FAIL $*" >&2; exit 143; }

BASE=c6ebf7bec2cbe39c984d266e01142d11cf0b1540
PUBLICATION=src/runtime/mod_fmr_surface_evaporation_accepted_publication.f90
MATERIALIZER=src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90
RECEIPT=src/runtime/mod_fmr_accepted_commit_receipt.f90
KERNEL=src/kernel/mod_kernel_transactions.f90
PROCESS=src/process/mod_restricted_surface_evaporation.f90

# F-MR43 replaces the unsafe split accepted-publication seam only. It must not
# carry the later F-KT20 experiment or change process/solver/mass/restart code.
test "$(git merge-base "$BASE" HEAD)" = "$BASE" || fail 'branch no longer descends from frozen F-PM10 base'
mapfile -t src_delta < <(git diff --name-only "$BASE"..HEAD -- src | sort)
[[ "${src_delta[*]}" == "$PUBLICATION" ]] || fail "unexpected production delta: ${src_delta[*]:-none}"
git diff --quiet "$BASE"..HEAD -- reference || fail 'reference source changed'
test "$(git rev-parse HEAD:$MATERIALIZER)" = b8ff1fb1d9434e952163b6955305c6373dd8ac82 || fail 'materializer authority drift'
test "$(git rev-parse HEAD:$RECEIPT)" = 6798b3296b426950bf028814585c3f5de9be950b || fail 'accepted receipt authority drift'
test "$(git rev-parse HEAD:$KERNEL)" = c7c5b7d3357e4e6739c8f647d6232baca45563e6 || fail 'kernel drift or F-KT20 leakage'
test "$(git rev-parse HEAD:$PROCESS)" = a213af4deec2fe854d79120899827852a57237d1 || fail 'surface physics drift'
echo 'FMR43_SINGLE_FILE_PRODUCTION_DELTA=PASS'
echo 'FMR43_NO_FKT20_KERNEL_DEPENDENCY=PASS'

python3 - "$PUBLICATION" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1]).read_text(encoding='utf-8').lower()
required = [
    'public :: fmr_commit_candidate_with_surface_evaporation_publication',
    'call fmr_materialize_candidate_bound_surface_evaporation',
    'call fmr_commit_candidate_with_receipt',
    'call finalize_local_prepared',
    'type :: fmr_prepared_surface_evaporation_publication_t',
    "error stop 'f-mr43: successful candidate commit without ready accepted receipt'",
]
for token in required:
    if token not in p:
        raise SystemExit(f'missing atomic-publication contract token: {token}')
for forbidden_public in (
    'public :: fmr_prepare_surface_evaporation_publication',
    'public :: fmr_finalize_surface_evaporation_publication',
):
    if forbidden_public in p:
        raise SystemExit(f'unsafe split publication API remains public: {forbidden_public}')
# The only order admitted for accepted publication is materialize -> commit ->
# finalize from the local private carrier.
a = p.index('call fmr_materialize_candidate_bound_surface_evaporation')
b = p.index('call fmr_commit_candidate_with_receipt')
c = p.index('call finalize_local_prepared')
if not a < b < c:
    raise SystemExit('atomic publication ordering drift')
# Publication remains attribution, never a second water-mass authority.
for forbidden in ('canonical_mass_accounting_t','mass%total_in','mass%total_out','mass_ledger',
                  'execution_provenance_id','candidate_sequence_value','day_of','month_of','year_of',
                  'midnight','.swp','file_unit','pathname','modflow'):
    if forbidden in p:
        raise SystemExit(f'forbidden publication dependency: {forbidden}')
if re.search(r'\b(open|read|write|close)\s*\(', p):
    raise SystemExit('publication introduced file I/O')
print('FMR43_ATOMIC_ORDER_BY_CONSTRUCTION=PASS')
print('FMR43_UNSAFE_SPLIT_API_NOT_PUBLIC=PASS')
print('FMR43_NO_SECOND_MASS_AUTHORITY=PASS')
print('FMR43_NO_IO_CALENDAR_COUPLER_DEPENDENCY=PASS')
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
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/test_fmr43_atomic_surface_publication.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "owner oracle O$opt"; }
  for marker in \
    FMR43_ATOMIC_CROSS_EXECUTOR_POSITIVE=PASS \
    FMR43_ATOMIC_SECOND_COLUMN_POSITIVE=PASS \
    FMR43_CROSS_CANDIDATE_PRECOMMIT_FAIL_CLOSED=PASS \
    FMR43_MATERIALIZATION_FAILURE_PRECOMMIT_FAIL_CLOSED=PASS \
    FMR43_NO_SECOND_MASS_BOOKING=PASS \
    'FMR43_OWNER_TEST PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing marker O$opt: $marker"; }
  done
  # Compile-time adversarial gate. The historical split prepare/finalize names
  # must be inaccessible to external callers.
  if gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/fmr43_forbidden_split_publication_attack.f90 -o "$OUT/attack.o" >"$OUT/attack.log" 2>&1; then
    cat "$OUT/attack.log" >&2 || true
    fail "forbidden split publication API compiled at O$opt"
  fi
  test ! -e "$OUT/attack.o" || fail "forbidden attacker object emitted at O$opt"
  echo "FMR43_SPLIT_API_HARD_NEGATIVE_O${opt}=PASS_CLOSED"
  echo "FMR43_OWNER_ORACLE_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 owner observation drift'
}
cat "$BUILD/o0/output.txt"
echo 'FMR43_OWNER_O0_O2_SEMANTIC_IDENTITY=PASS'
echo 'FMR43_OWNER_GATE=PASS'
