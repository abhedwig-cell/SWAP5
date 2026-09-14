#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-eb-i20-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail(){ echo "EB_I20_GATE_FAIL $*" >&2; exit 220; }

CANONICAL="b162e98cc4ad6f85b741a21bd41f3db3d213559b"
I01_TYPES_BLOB="15a6a9c5c5da6ad0d535c27772e57a23e618658d"
I01_LEDGER_BLOB="aba5a63a10d7f37cb89e31882851d0f4e9b99ffa"
I01_RECEIPT_FIXTURE_BLOB="3b641de50247b17c8f6f62f3e1c8019a62bf8593"
TRANSACTION_BLOB="d5a71a526efaebd82054580c3186f8e3545db331"
FVQ67_RUN_BLOB="e8a02be90ee30f8f8d48ea023c1ceecc7981b6e3"
FVQ67_TEST_BLOB="1210bb4f80de32abd3e24ed0c73a78cdddea36b5"
TYPES="src/kernel/mod_energy_conservation_types.f90"
LEDGER="src/runtime/mod_energy_conservation_ledger.f90"
HIST_RECEIPT_TEST="tests/eb/test_ebi01_energy_ledger_receipt_integration.f90"
NORMALIZED_RECEIPT_TEST="$BUILD/test_ebi01_energy_ledger_receipt_integration_current_fkt18.f90"

git fetch -q origin integration/f-ci-canonical
LIVE="$(git rev-parse origin/integration/f-ci-canonical)"
[[ "$LIVE" == "$CANONICAL" ]] || fail "live canonical drift expected=$CANONICAL actual=$LIVE"
[[ "$(git merge-base "$CANONICAL" HEAD)" == "$CANONICAL" ]] || fail 'workunit is not rooted in exact current canonical'
echo 'EB_I20_CURRENT_CANONICAL_LOCK=PASS'

changed_src="$(git diff --name-only "$CANONICAL..HEAD" -- src | LC_ALL=C sort)"
expected_src=$'src/kernel/mod_energy_conservation_types.f90\nsrc/runtime/mod_energy_conservation_ledger.f90'
[[ "$changed_src" == "$expected_src" ]] || { printf 'unexpected source delta:\n%s\n' "$changed_src" >&2; fail 'production source scope'; }
[[ -z "$(git diff --name-only "$CANONICAL..HEAD" -- reference)" ]] || fail 'reference source changed'
[[ "$(git rev-parse "HEAD:$TYPES")" == "$I01_TYPES_BLOB" ]] || fail 'EB-I01 energy types blob drift'
[[ "$(git rev-parse "HEAD:$LEDGER")" == "$I01_LEDGER_BLOB" ]] || fail 'EB-I01 ledger blob drift'
[[ "$(git rev-parse "HEAD:$HIST_RECEIPT_TEST")" == "$I01_RECEIPT_FIXTURE_BLOB" ]] || fail 'historical EB-I01 receipt fixture drift'
[[ "$(git rev-parse "HEAD:src/transaction/mod_transaction_reference.f90")" == "$TRANSACTION_BLOB" ]] || fail 'current F-KT18 transaction authority drift'
[[ "$(git rev-parse "HEAD:tests/fvq/run_fvq67_mass_completeness_independent.sh")" == "$FVQ67_RUN_BLOB" ]] || fail 'pinned F-VQ67 runner drift'
[[ "$(git rev-parse "HEAD:tests/fvq/test_fvq67_mass_completeness_attack.f90")" == "$FVQ67_TEST_BLOB" ]] || fail 'pinned F-VQ67 attack oracle drift'
echo 'EB_I20_EXACT_IMMUTABLE_I01_SOURCE_RECOMPOSITION=PASS'
echo 'EB_I20_FKT18_FVQ67_MASS_AUTHORITY_LOCK=PASS'

for src in "$TYPES" "$LEDGER"; do
  if grep -Eiq '^[[:space:]]*use[[:space:]].*(groundwater_interface_mass_ledger|groundwater_coupling)' "$src"; then
    fail "energy accounting depends on groundwater-specific mass authority: $src"
  fi
  if grep -Eiq '^[[:space:]]*(open|read|write|close)[[:space:]]*\(' "$src"; then
    fail "I/O primitive found in energy accounting source: $src"
  fi
done
echo 'EB_I20_KERNEL_RUNTIME_IO_AND_COUPLING_SEPARATION=PASS'

STRICT=(-std=f2008 -Wall -Wextra -Werror -ffree-line-length-none -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
BASELINE=(-std=f2008 -Wall -Wextra -Werror -Wno-error=compare-reals -ffree-line-length-none -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
BASE_MODULES=(
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
)

for opt in 0 2; do
  OUT="$BUILD/types-o$opt"; mkdir -p "$OUT"
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TYPES" -o "$OUT/types.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/eb/test_ebi01_energy_conservation_types.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/types.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt" 2>&1 || { cat "$OUT/out.txt" >&2; fail "energy types O$opt"; }
  for marker in \
    'EBI01_INTERNAL_TRANSFER_CANCELS_IN_OUTER_CV=PASS' \
    'EBI01_NESTED_CONTROL_VOLUMES_CLOSE=PASS' \
    'EBI01_UNDECLARED_TRANSFER_ENDPOINT_REJECTED=PASS' \
    'EBI01_INVALID_ACCOUNTING_INPUT_REJECTED=PASS' \
    'EBI01_ENERGY_CONSERVATION_TYPES_TEST PASS'; do
    grep -Fq "$marker" "$OUT/out.txt" || fail "missing energy types marker O$opt: $marker"
  done
done
cmp "$BUILD/types-o0/out.txt" "$BUILD/types-o2/out.txt" || fail 'energy types O0/O2 mismatch'
echo 'EB_I20_ENERGY_TYPES_O0_O2_IDENTITY=PASS'

# EB-I01 predates the current fail-closed mass-completeness and model-level
# storage-accounting provenance. Preserve the historical fixture byte-for-byte
# in Git and normalize only this temporary build copy. No physical mass,
# storage or energy quantity is changed.
cp "$HIST_RECEIPT_TEST" "$NORMALIZED_RECEIPT_TEST"
python3 - "$NORMALIZED_RECEIPT_TEST" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text(encoding='utf-8')

old_iso = 'use, intrinsic :: iso_fortran_env, only: real64'
new_iso = 'use, intrinsic :: iso_fortran_env, only: real64, int64'
if s.count(old_iso) != 1:
    raise SystemExit(f'EB-I20 iso_fortran_env anchor count={s.count(old_iso)}')
s = s.replace(old_iso, new_iso, 1)

old_use = 'use mod_transaction_reference, only: transaction_state_t, trial_outcome_t'
new_use = 'use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE'
if s.count(old_use) != 1:
    raise SystemExit(f'EB-I20 current-TX use anchor count={s.count(old_use)}')
s = s.replace(old_use, new_use, 1)

binding_anchor = '    procedure :: storage => ebi01_storage\n    procedure :: temporal_error => ebi01_temporal_error\n'
binding_insert = '    procedure :: storage => ebi01_storage\n    procedure :: storage_accounting_status => ebi01_storage_accounting_status\n    procedure :: temporal_error => ebi01_temporal_error\n'
if s.count(binding_anchor) != 1:
    raise SystemExit(f'EB-I20 storage binding anchor count={s.count(binding_anchor)}')
s = s.replace(binding_anchor, binding_insert, 1)

mass_anchor = '    outcome%mass_in = transfer_mass\n'
mass_insert = mass_anchor + '    outcome%mass_accounting_complete = .true.\n    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE\n'
if s.count(mass_anchor) != 1:
    raise SystemExit(f'EB-I20 current-TX mass anchor count={s.count(mass_anchor)}')
s = s.replace(mass_anchor, mass_insert, 1)

storage_end = '  end function ebi01_storage\n\n'
storage_status = '''  end function ebi01_storage\n\n  subroutine ebi01_storage_accounting_status(self, state, complete, missing_mask)\n    class(ebi01_model_t), intent(in) :: self\n    class(transaction_state_t), intent(in) :: state\n    logical, intent(out) :: complete\n    integer(int64), intent(out) :: missing_mask\n\n    complete = .false.\n    missing_mask = TX_MASS_MISSING_NONE\n    if (self%scale < 0.0_real64) return\n    select type (state)\n    type is (ebi01_state_t)\n      complete = .true.\n    class default\n      complete = .false.\n    end select\n  end subroutine ebi01_storage_accounting_status\n\n'''
if s.count(storage_end) != 1:
    raise SystemExit(f'EB-I20 storage function end anchor count={s.count(storage_end)}')
s = s.replace(storage_end, storage_status, 1)

p.write_text(s, encoding='utf-8')
PY
grep -Fq 'outcome%mass_accounting_complete = .true.' "$NORMALIZED_RECEIPT_TEST" || fail 'normalized completeness marker missing'
grep -Fq 'outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE' "$NORMALIZED_RECEIPT_TEST" || fail 'normalized missing-contribution marker missing'
grep -Fq 'procedure :: storage_accounting_status => ebi01_storage_accounting_status' "$NORMALIZED_RECEIPT_TEST" || fail 'normalized storage-accounting binding missing'
grep -Fq 'complete = .true.' "$NORMALIZED_RECEIPT_TEST" || fail 'normalized storage-accounting completeness missing'
echo 'EB_I20_FIXTURE_CURRENT_MASS_AND_STORAGE_COMPLETENESS_NORMALIZATION=PASS'

for opt in 0 2; do
  OUT="$BUILD/receipt-o$opt"; mkdir -p "$OUT"; objects=()
  for src in "${BASE_MODULES[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${BASELINE[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  for src in "$TYPES" "$LEDGER"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$NORMALIZED_RECEIPT_TEST" -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt" 2>&1 || { cat "$OUT/out.txt" >&2; fail "receipt integration O$opt"; }
  for marker in \
    'EBI01_UNREGISTERED_INTERNAL_COMPONENT_REJECTED=PASS' \
    'EBI01_REAL_FKT_RECEIPT_PUBLISHES_ENERGY_ONCE=PASS' \
    'EBI01_ROLLBACK_PUBLISHES_NO_ENERGY=PASS' \
    'EBI01_ROLLBACK_REPLAY_FROM_SAME_COMMITTED_ORIGIN=PASS' \
    'EBI01_EXISTING_FKT_MASS_PATH_PRESERVED=PASS' \
    'EBI01_ENERGY_LEDGER_RECEIPT_INTEGRATION_TEST PASS'; do
    grep -Fq "$marker" "$OUT/out.txt" || fail "missing receipt marker O$opt: $marker"
  done
done
cmp "$BUILD/receipt-o0/out.txt" "$BUILD/receipt-o2/out.txt" || fail 'receipt integration O0/O2 mismatch'
echo 'EB_I20_TRANSACTIONAL_RECEIPT_O0_O2_IDENTITY=PASS'

# Independent preservation of the current transaction mass-completeness
# contract. This exact F-VQ67 attack oracle is pinned byte-for-byte and runs
# against the exact current canonical transaction source.
FVQ67_TRANSACTION_SOURCE="$ROOT/src/transaction/mod_transaction_reference.f90" \
FVQ67_TAG=ebi20 bash tests/fvq/run_fvq67_mass_completeness_independent.sh > "$BUILD/fvq67.txt" 2>&1 || {
  cat "$BUILD/fvq67.txt" >&2
  fail 'F-VQ67 current mass-completeness preservation'
}
for marker in \
  'FVQ67_EBI20_O0=PASS' \
  'FVQ67_EBI20_O2=PASS' \
  'FVQ67_EBI20_O0_O2_IDENTITY=PASS' \
  'FVQ67_ZERO_RESIDUAL_INCOMPLETE_FAIL_CLOSED=PASS' \
  'FVQ67_COMPLETE_IN_TOLERANCE_ACCEPTS=PASS' \
  'FVQ67_REJECTED_COMMITTED_STATE_BITWISE_IMMUTABLE=PASS' \
  'FVQ67_RETRY_NO_PHYSICAL_ACCUMULATION=PASS' \
  'FVQ67_GENERIC_TIME_TRANSACTION=PASS'; do
  grep -Fq "$marker" "$BUILD/fvq67.txt" || fail "missing F-VQ67 marker: $marker"
done
echo 'EB_I20_CURRENT_FKT18_MASS_COMPLETENESS_PRESERVATION=PASS'

# Characterize, do not silently alter, current architectural debt in the old
# ledger. Error-stop call sites are reported for the follow-up admission review.
ERROR_STOP_COUNT="$(grep -Ec '^[[:space:]]*error stop' "$LEDGER" || true)"
echo "EB_I20_LEDGER_ERROR_STOP_COUNT=$ERROR_STOP_COUNT"

git diff --check "$CANONICAL..HEAD"
echo "EB_I20_EXACT_HEAD=$(git rev-parse HEAD)"
echo 'EB_I20_CURRENT_CANONICAL_REQUALIFICATION=PASS'
