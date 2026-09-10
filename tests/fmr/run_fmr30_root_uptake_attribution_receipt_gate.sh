#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr30-$$"
BASE=e3964ec0ef312f974461aeac70fb9bc5720803e3
CANDIDATE=95e31ca4aa7d9a6a3cfe5f563c2a5ef02255125c
SOURCE=src/runtime/mod_fmr_root_uptake_attribution_receipt.f90
SOURCE_BLOB=886d251908126693b6fe035e065a872ce5ff4e29
mkdir -p "$BUILD/o0" "$BUILD/o2" "$BUILD/real"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FMR30_GATE_FAIL $*" >&2; exit 1; }

mapfile -t src_delta < <(git diff --name-only "$BASE"..HEAD -- src | sort)
printf '%s\n' "${src_delta[@]}" > "$BUILD/src-delta.txt"
printf '%s\n' "$SOURCE" > "$BUILD/expected-src-delta.txt"
cmp -s "$BUILD/src-delta.txt" "$BUILD/expected-src-delta.txt" || {
  cat "$BUILD/src-delta.txt" >&2
  fail 'production delta is not exactly one F-MR30 receipt module'
}
git diff --quiet "$CANDIDATE"..HEAD -- src || fail 'production source mutated after F-MR30 candidate'
[[ "$(git rev-parse "HEAD:$SOURCE")" == "$SOURCE_BLOB" ]] || fail 'F-MR30 production blob drift'
echo 'FMR30_EXACT_ONE_SOURCE_PRODUCTION_DELTA=PASS'
echo 'FMR30_PRODUCTION_SOURCE_IMMUTABLE_AFTER_CANDIDATE=PASS'

python3 - "$SOURCE" <<'PY'
from pathlib import Path
import re, sys
text = Path(sys.argv[1]).read_text(encoding='utf-8')
code = '\n'.join(line.split('!', 1)[0] for line in text.splitlines()).lower()
for forbidden in ('mass_in', 'mass_out', 'canonical_mass_accounting', 'accepted_total_in',
                  'accepted_total_out', 'storage_change'):
    if forbidden in code:
        raise SystemExit(f'mass-ledger mutation surface: {forbidden}')
if re.search(r'^\s*(allocate|deallocate)\s*\(', code, flags=re.M):
    raise SystemExit('unexpected dynamic allocation')
for forbidden in ('modflow', 'headcalc', 'newton', 'jacobian'):
    if forbidden in code:
        raise SystemExit(f'forbidden dependency: {forbidden}')
for pattern in (r'\bread\s*\(', r'\bwrite\s*\(', r'\bopen\s*\(', r'\bclose\s*\('):
    if re.search(pattern, code):
        raise SystemExit(f'forbidden I/O surface: {pattern}')
print('FMR30_ATTRIBUTION_ONLY_NO_MASS_LEDGER_MUTATION=PASS')
print('FMR30_RECEIPT_ALLOCATION_FREE=PASS')
print('FMR30_NO_IO_OR_SOLVER_INTERNAL_DEPENDENCY=PASS')
PY

COMMON=(-std=f2008 -Wall -Wextra -ffree-line-length-none -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
STRICT=(-std=f2008 -Wall -Wextra -Werror -ffree-line-length-none -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
UNIT_MODULES=(
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  tests/fmr/mod_fmr30_root_attribution_test_backend.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  objects=()
  for src in "${UNIT_MODULES[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  obj="$OUT/mod_fmr_root_uptake_attribution_receipt.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$SOURCE" -o "$obj"
  objects+=("$obj")
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fmr/test_fmr30_root_uptake_attribution_receipt.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt" 2>&1 || { cat "$OUT/out.txt" >&2; fail "F-MR30 unit oracle O$opt"; }
  for marker in \
    FMR30_INVALID_ROOT_FORCING_FAIL_CLOSED=PASS \
    FMR30_PRECOMMIT_PUBLICATION_REJECTED=PASS \
    FMR30_PROVENANCE_MISMATCH_FAIL_CLOSED=PASS \
    FMR30_TIME_MISMATCH_FAIL_CLOSED=PASS \
    FMR30_REAL_COMMIT_ROOT_ATTRIBUTION=PASS \
    FMR30_ATTRIBUTION_EQUALS_ALREADY_BOOKED_ROOT_MASS_OUT=PASS \
    FMR30_NO_DUPLICATE_MASS_BOOKING=PASS \
    'FMR30_ROOT_UPTAKE_ATTRIBUTION_RECEIPT_TEST PASS'; do
    grep -Fq "$marker" "$OUT/out.txt" || { cat "$OUT/out.txt" >&2; fail "missing O$opt marker $marker"; }
  done
done
cmp -s "$BUILD/o0/out.txt" "$BUILD/o2/out.txt" || fail 'F-MR30 O0/O2 oracle output drift'
echo 'FMR30_O0_O2_ORACLE_IDENTITY=PASS'

# Compile the production module against the real canonical serialized backend,
# not the focused test double, to prove the forcing-type dependency is exact.
REAL_MODULES=(
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
  src/process/mod_root_water_uptake_process.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
)
OUT="$BUILD/real"
for src in "${REAL_MODULES[@]}"; do
  obj="$OUT/$(basename "${src%.*}").o"
  gfortran "${COMMON[@]}" -O2 -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
done
gfortran "${STRICT[@]}" -O2 -J "$OUT" -I "$OUT" -c "$SOURCE" -o "$OUT/fmr30-real.o"
echo 'FMR30_REAL_CANONICAL_BACKEND_STRICT_COMPILE=PASS'

echo 'FMR30_RESTRICTED_ROOT_UPTAKE_ATTRIBUTION_RECEIPT_GATE PASS'
