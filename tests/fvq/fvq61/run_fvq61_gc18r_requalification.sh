#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

canonical="9770a659d5a93d9abe1341815b57c0fb2fea15ec"
owner="cfa4e9dcd9a283d85ade316651d34cac93958a4a"
composition="f8260c2ca19473f9e8192fc5f6db80342d07e2bd"
frozen_fvq60="773b1dec23957f2d86648b82ab76f8daede2cbbc"
source_blob="f0fc25592624360802713a9487813d119e7dc4e9"
coupling_blob="fc598d14eabafcb025bb55621f7b00d6d1816f10"
base_regression_blob="a57203009662ca38d1c16b5f72fb158d7518e0b2"

# Provenance is reconstructed independently. The verifier composition must keep
# current canonical first and the owner candidate second; later verifier-only
# commits may descend from that immutable composition.
git merge-base --is-ancestor "$composition" HEAD
test "$(git rev-parse "$composition^1")" = "$canonical"
test "$(git rev-parse "$composition^2")" = "$owner"
git merge-base --is-ancestor "$canonical" HEAD
git merge-base --is-ancestor "$owner" HEAD
test -n "$(git cat-file -t "$frozen_fvq60")"

# Lock the production candidate and the already-admitted typed groundwater
# interface by content, not by owner evidence claims.
test "$(git rev-parse HEAD:src/runtime/mod_groundwater_exchange_service_contract.f90)" = "$source_blob"
test "$(git rev-parse HEAD:src/runtime/mod_groundwater_coupling_contract.f90)" = "$coupling_blob"
test "$(git rev-parse HEAD:tests/fgc/test_fgc18_groundwater_exchange_service.f90)" = "$base_regression_blob"

mapfile -t production_delta < <(git diff --name-only "$canonical..$owner" -- src reference)
test "${#production_delta[@]}" -eq 1
test "${production_delta[0]}" = "src/runtime/mod_groundwater_exchange_service_contract.f90"

# After the immutable composition, F-VQ61 itself may change only verifier assets.
while IFS= read -r path; do
  case "$path" in
    tests/fvq/fvq61/*|.github/workflows/fvq61-gc18r-r1-requalification.yml|integration/f-vq/F-VQ61_*.json) ;;
    *) echo "FVQ61_SCOPE_FAIL unexpected verifier change: $path" >&2; exit 61 ;;
  esac
done < <(git diff --name-only "$composition..HEAD")

python3 - <<'PY'
from pathlib import Path
s = Path('src/runtime/mod_groundwater_exchange_service_contract.f90').read_text()
low = s.lower()

# B1: every revision successor decision is overflow-safe.
assert 'pure integer(int64) function safe_revision_successor' in s
assert 'if (origin_revision >= huge(0_int64)) return' in s
assert 'next_revision = origin_revision + 1_int64' in s
assert 'candidate_revision_value = safe_revision_successor(checkpoint%origin_revision_value)' in s
assert 'if (candidate_revision_value < 0_int64)' in s
assert 'GW_EXCHANGE_REVISION_EXHAUSTED' in s
for unsafe in [
    'checkpoint%origin_revision_value + 1_int64',
    'self%origin_revision_value + 1_int64',
    'candidate%origin_revision_value + 1_int64',
    'prepared%origin_revision_value + 1_int64'
]:
    assert unsafe not in s
assert s.count('revision_is_successor(') >= 4

# Base F-GC18 ABI stays the four-method interface; prepare is opt-in only.
base = s.split('type, abstract, public :: groundwater_exchange_service_t',1)[1].split('end type groundwater_exchange_service_t',1)[0]
for name in ['capture_backend','trial_backend','commit_backend','discard_backend']:
    assert name in base
for forbidden in ['prepare_backend','commit_prepared_backend','abort_prepared_backend','reservation_slots']:
    assert forbidden not in base
assert 'type, abstract, extends(groundwater_exchange_service_t), public :: groundwater_preparable_exchange_service_t' in s

# B2: wrapper-owned one-shot identity is mandatory and private to the preparable service.
assert 'type(groundwater_reservation_slot_t), allocatable :: reservation_slots(:)' in s
assert 'integer :: free_reservation_slot = 0' in s
assert 'integer(int64) :: generation = 0_int64' in s
assert 'integer :: next_free = 0' in s
assert 'integer :: reservation_slot = 0' in s
assert 'integer(int64) :: reservation_generation = 0_int64' in s
assert 'GW_EXCHANGE_STALE_PREPARED' in s
assert s.count('call consume_prepared_slot(') == 2

# Commit/abort must consume wrapper identity before any backend callback.
def body(name, end_name):
    return s.split(name,1)[1].split(end_name,1)[0]
commit = body('subroutine groundwater_commit_prepared(service, checkpoint, prepared, status)',
              'end subroutine groundwater_commit_prepared')
abort = body('subroutine groundwater_abort_prepared(service, checkpoint, prepared, status)',
             'end subroutine groundwater_abort_prepared')
assert commit.index('call consume_prepared_slot') < commit.index('call service%commit_prepared_backend')
assert abort.index('call consume_prepared_slot') < abort.index('call service%abort_prepared_backend')

# MultiSWAP scaling: no linear free-slot scan. Free-list reserve/release is O(1),
# with geometric growth only when the pool is empty.
assert 'subroutine push_new_free_slots' in s
assert 'subroutine release_prepared_slot' in s
assert 'service%free_reservation_slot = service%reservation_slots(slot)%next_free' in s
assert 'service%reservation_slots(slot)%next_free = service%free_reservation_slot' in s
assert 'growth = max(old_size, INITIAL_RESERVATION_CAPACITY)' in s
assert 'do i = 1, size(service%reservation_slots)' not in s

# Generation exhaustion retires a slot before increment can wrap.
reserve = body('subroutine reserve_prepared_slot(service, slot, generation, status)',
               'end subroutine reserve_prepared_slot')
release = body('subroutine release_prepared_slot(service, slot)',
               'end subroutine release_prepared_slot')
assert 'generation >= huge(0_int64)' in reserve
assert 'generation = service%reservation_slots(slot)%generation + 1_int64' in reserve
assert reserve.index('generation >= huge(0_int64)') < reserve.index('generation = service%reservation_slots(slot)%generation + 1_int64')
assert 'generation < huge(0_int64)' in release

# Storage is opt-in and lazily allocated. No permanent registry exists on the base service.
assert 'if (.not. allocated(service%reservation_slots)) then' in reserve
assert 'reservation_slots' not in base

# No hidden I/O, calendar, direct MODFLOW or legacy-format dependency in the new production contract.
for forbidden in ['modflow', '.swp', 'midnight', 'open(', 'read(', 'write(']:
    assert forbidden not in low

# Prepared backend finalization intentionally has no recoverable status result after
# one-shot wrapper consumption, avoiding a false rollback promise after publication.
assert 'subroutine gw_commit_prepared_backend_ifc(self, prepare_token)' in s
assert 'subroutine gw_abort_prepared_backend_ifc(self, prepare_token)' in s
PY

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

compile_independent() {
  local opt="$1" out="$2" dir="$work/ind-$opt"
  mkdir -p "$dir"
  gfortran "-$opt" -std=f2008 -Wall -Wextra -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -J"$dir" -I"$dir" \
    src/runtime/mod_groundwater_coupling_contract.f90 \
    src/runtime/mod_groundwater_exchange_service_contract.f90 \
    tests/fvq/fvq61/test_fvq61_gc18r_requalification.f90 \
    -o "$dir/fvq61"
  "$dir/fvq61" > "$out"
}

compile_base_regression() {
  local opt="$1" out="$2" dir="$work/base-$opt"
  mkdir -p "$dir"
  gfortran "-$opt" -std=f2008 -Wall -Wextra -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -J"$dir" -I"$dir" \
    src/runtime/mod_groundwater_coupling_contract.f90 \
    src/runtime/mod_groundwater_exchange_service_contract.f90 \
    tests/fgc/test_fgc18_groundwater_exchange_service.f90 \
    -o "$dir/base"
  "$dir/base" > "$out"
}

compile_owner_regression_only() {
  local opt="$1" out="$2" dir="$work/owner-reg-$opt"
  mkdir -p "$dir"
  gfortran "-$opt" -std=f2008 -Wall -Wextra -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -J"$dir" -I"$dir" \
    src/runtime/mod_groundwater_coupling_contract.f90 \
    src/runtime/mod_groundwater_exchange_service_contract.f90 \
    tests/fgc/test_fgc18r_prepared_commit.f90 \
    -o "$dir/owner_reg"
  "$dir/owner_reg" > "$out"
}

compile_independent O0 "$work/ind-o0.txt"
compile_independent O2 "$work/ind-o2.txt"
diff -u "$work/ind-o0.txt" "$work/ind-o2.txt"
for marker in \
  FVQ61_INDEPENDENT_BACKEND \
  FVQ61_COPIED_ABORT_REPLAY_BLOCKED_WITH_TOKEN_REUSE \
  FVQ61_COPIED_COMMIT_REPLAY_BLOCKED \
  FVQ61_NO_DUPLICATE_GROUNDWATER_PUBLICATION \
  FVQ61_INT64_LAST_SUCCESSOR_VALID \
  FVQ61_INT64_EXHAUSTION_PREBACKEND; do
  grep -q "^${marker}=PASS$" "$work/ind-o0.txt"
done

compile_base_regression O0 "$work/base-o0.txt"
compile_base_regression O2 "$work/base-o2.txt"
diff -u "$work/base-o0.txt" "$work/base-o2.txt"
grep -q '^FGC18_TRANSACTIONAL_GW_SERVICE=PASS$' "$work/base-o0.txt"
grep -q '^FGC18_COMMIT_ONCE_AND_STALE_REJECT=PASS$' "$work/base-o0.txt"

# Owner test is retained only as a regression cross-check. It is not counted as
# independent evidence for B1/B2; the independent program above supplies that.
compile_owner_regression_only O0 "$work/owner-o0.txt"
compile_owner_regression_only O2 "$work/owner-o2.txt"
diff -u "$work/owner-o0.txt" "$work/owner-o2.txt"
grep -q '^FGC18R_COPIED_ABORT_REPLAY_REJECTED=PASS$' "$work/owner-o0.txt"
grep -q '^FGC18R_COPIED_COMMIT_REPLAY_REJECTED=PASS$' "$work/owner-o0.txt"
grep -q '^FGC18R_REVISION_INT64_BOUNDARY_FAIL_CLOSED=PASS$' "$work/owner-o0.txt"

cat "$work/ind-o0.txt"
cat "$work/base-o0.txt"
echo "FVQ61_CANONICAL_FIRST_PARENT=PASS:$canonical"
echo "FVQ61_OWNER_SECOND_PARENT=PASS:$owner"
echo "FVQ61_FROZEN_FVQ60_AUTHORITY_PRESENT=PASS:$frozen_fvq60"
echo "FVQ61_PRODUCTION_SCOPE_ONE_FILE=PASS"
echo "FVQ61_FGC17_COUPLING_CONTRACT_LOCK=PASS:$coupling_blob"
echo "FVQ61_FGC18_BASE_REGRESSION=PASS"
echo "FVQ61_OWNER_TEST_USED_AS_REGRESSION_ONLY=PASS"
echo "FVQ61_FREE_LIST_NO_LINEAR_SCAN=PASS"
echo "FVQ61_GENERATION_RETIREMENT_STATIC_CHECK=PASS"
echo "FVQ61_O0_O2_IDENTITY=PASS"
