#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fkt20-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FKT20_GATE_FAIL $*" >&2; exit 120; }

BASE=c6ebf7bec2cbe39c984d266e01142d11cf0b1540
KERNEL=src/kernel/mod_kernel_transactions.f90
RECEIPT=src/runtime/mod_fmr_accepted_commit_receipt.f90
MATERIALIZER=src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90
PUBLICATION=src/runtime/mod_fmr_surface_evaporation_accepted_publication.f90

# F-KT20 is a narrow provenance remediation on top of the owner-qualified
# F-PM10 candidate. No physics, reference source, solver, committed-state codec,
# or mass-accounting implementation may change here.
test "$(git merge-base "$BASE" HEAD)" = "$BASE" || fail 'branch no longer descends from frozen F-PM10 owner candidate'
mapfile -t src_delta < <(git diff --name-only "$BASE"..HEAD -- src | sort)
expected=("$KERNEL" "$RECEIPT" "$PUBLICATION" "$MATERIALIZER")
mapfile -t expected_sorted < <(printf '%s\n' "${expected[@]}" | sort)
[[ "${src_delta[*]}" == "${expected_sorted[*]}" ]] || fail "unexpected src delta: ${src_delta[*]:-none}"
git diff --quiet "$BASE"..HEAD -- reference || fail 'reference source changed'
git diff --quiet "$BASE"..HEAD -- src/process src/solver || fail 'physics or solver source changed'
echo 'FKT20_BOUNDED_SOURCE_SCOPE=PASS'

python3 - "$KERNEL" "$RECEIPT" "$MATERIALIZER" "$PUBLICATION" <<'PY'
from pathlib import Path
import re, sys
k, r, m, p = [Path(x).read_text(encoding='utf-8').lower() for x in sys.argv[1:]]

required_kernel = [
    'execution_provenance_id_value',
    'candidate_sequence_value',
    'exact_attempt_provenance_bound',
    'procedure, public :: bind_execution_provenance',
    'procedure, public :: exact_attempt_provenance',
    'kernel_commit_status_execution_provenance_mismatch',
    'execution_provenance_rejections',
]
for token in required_kernel:
    if token not in k:
        raise SystemExit(f'missing F-KT20 kernel token: {token}')

required_receipt = [
    'execution_provenance_id_value',
    'candidate_sequence_value',
    'exact_attempt_provenance',
]
for token in required_receipt:
    if token not in r:
        raise SystemExit(f'missing exact receipt provenance token: {token}')

required_surface = [
    'exact_attempt_provenance',
    'execution_provenance_id_value',
    'candidate_sequence_value',
]
for label, text in [('materializer', m), ('publication', p)]:
    for token in required_surface:
        if token not in text:
            raise SystemExit(f'{label} missing exact provenance token: {token}')

# Exact attempt provenance is runtime metadata only. It must not be added to
# committed/checkpoint/restart carriers or mass-accounting terms.
committed_start = k.index('type, extends(transaction_state_t), public :: kernel_committed_state_t')
committed_end = k.index('end type kernel_committed_state_t', committed_start)
committed = k[committed_start:committed_end]
checkpoint_start = k.index('type, public :: kernel_checkpoint_t')
checkpoint_end = k.index('end type kernel_checkpoint_t', checkpoint_start)
checkpoint = k[checkpoint_start:checkpoint_end]
for label, text in [('committed', committed), ('checkpoint', checkpoint)]:
    for forbidden in ('execution_provenance_id_value', 'candidate_sequence_value', 'exact_attempt_provenance_bound'):
        if forbidden in text:
            raise SystemExit(f'{label} illegally gained exact-attempt persistent provenance: {forbidden}')

for label, text in [('kernel', k), ('receipt', r), ('materializer', m), ('publication', p)]:
    for forbidden in ('mass%total_in', 'mass%total_out', 'mass_ledger', 'day_of', 'month_of', 'year_of', 'midnight', '.swp', 'pathname', 'modflow'):
        if forbidden in text:
            raise SystemExit(f'{label} forbidden token: {forbidden}')
    if re.search(r'\b(open|read|write|close)\s*\(', text):
        raise SystemExit(f'{label} introduced file I/O')

print('FKT20_EXACT_PROVENANCE_RUNTIME_ONLY=PASS')
print('FKT20_NO_PERSISTENT_STATE_GROWTH=PASS')
print('FKT20_NO_PHYSICS_OR_MASS_AUTHORITY_CHANGE=PASS')
print('FKT20_NO_IO_CALENDAR_OR_MODFLOW_DEPENDENCY=PASS')
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
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fkt/test_fkt20_exact_candidate_attempt_provenance.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "owner oracle O$opt"; }
  for marker in \
    FKT20_EXECUTION_DOMAIN_BINDING=PASS \
    FKT20_SAME_TUPLE_DISTINCT_EXACT_CANDIDATES=PASS \
    FKT20_FVQ69_HN5_CLOSED=PASS \
    FKT20_GENERIC_FKT_PRESERVED_SURFACE_FAILS_CLOSED=PASS \
    FKT20_CROSS_EXECUTOR_COMMIT_REJECTED=PASS \
    FKT20_NO_MASS_BOOKING_CHANGE=PASS \
    'FKT20_OWNER_TEST PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing marker O$opt: $marker"; }
  done
  echo "FKT20_OWNER_ORACLE_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 owner observation drift'
}
cat "$BUILD/o0/output.txt"
echo 'FKT20_OWNER_ORACLE_O0_O2_EXACT_IDENTITY=PASS'
echo 'FKT20_OWNER_GATE=PASS'
