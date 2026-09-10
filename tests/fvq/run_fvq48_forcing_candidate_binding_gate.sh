#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq48-$$"
BASE=e3964ec0ef312f974461aeac70fb9bc5720803e3
OWNER_HANDOFF=c908621d10868b5e265a8835ea2c0c56ee202ef6
CANDIDATE=95e31ca4aa7d9a6a3cfe5f563c2a5ef02255125c
SOURCE=src/runtime/mod_fmr_root_uptake_attribution_receipt.f90
SOURCE_BLOB=886d251908126693b6fe035e065a872ce5ff4e29
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FVQ48_GATE_FAIL $*" >&2; exit 1; }

# Qualification branch must remain source-clean relative to canonical.
git diff --quiet "$BASE"..HEAD -- src || fail 'qualification branch carries production src changes'
echo 'FVQ48_CLEAN_CANONICAL_BRANCH_NO_SRC_DELTA=PASS'

# Acquire candidate only through the exact pinned authority, never by using the
# owner branch as qualification source history.
if ! git cat-file -e "$CANDIDATE^{commit}" 2>/dev/null; then
  git fetch --no-tags origin "$CANDIDATE" >/dev/null 2>&1 || \
    git fetch --no-tags origin work/f-mr30-restricted-root-uptake-attribution-receipt >/dev/null 2>&1
fi
git cat-file -e "$CANDIDATE^{commit}" 2>/dev/null || fail 'pinned F-MR30 candidate commit unavailable'
git show "$CANDIDATE:$SOURCE" > "$BUILD/mod_fmr_root_uptake_attribution_receipt.f90" || fail 'cannot materialize pinned candidate source'
[[ "$(git hash-object "$BUILD/mod_fmr_root_uptake_attribution_receipt.f90")" == "$SOURCE_BLOB" ]] || \
  fail 'candidate production blob mismatch'
mapfile -t owner_src_delta < <(git diff --name-only "$BASE" "$CANDIDATE" -- src | sort)
[[ "${#owner_src_delta[@]}" -eq 1 && "${owner_src_delta[0]}" == "$SOURCE" ]] || \
  fail 'owner candidate production delta is not exactly the receipt module'
echo 'FVQ48_EXACT_PINNED_CANDIDATE_BLOB=PASS'
echo 'FVQ48_OWNER_CANDIDATE_EXACT_ONE_SOURCE_DELTA=PASS'

COMMON=(-std=f2008 -Wall -Wextra -ffree-line-length-none -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
STRICT=(-std=f2008 -Wall -Wextra -Werror -ffree-line-length-none -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULES=(
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  tests/fvq/mod_fvq48_independent_root_attribution_backend.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  objects=()
  for src in "${MODULES[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  obj="$OUT/mod_fmr_root_uptake_attribution_receipt.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    "$BUILD/mod_fmr_root_uptake_attribution_receipt.f90" -o "$obj"
  objects+=("$obj")
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fvq/test_fvq48_forcing_candidate_binding.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt" 2>&1 || { cat "$OUT/out.txt" >&2; fail "independent HN1 control execution O$opt"; }
  grep -Fq 'FVQ48_VALID_MATCHING_FORCING_CONTROL=PASS' "$OUT/out.txt" || {
    cat "$OUT/out.txt" >&2
    fail "matching-forcing control missing at O$opt"
  }
done

cmp -s "$BUILD/o0/out.txt" "$BUILD/o2/out.txt" || {
  echo '--- O0 ---' >&2; cat "$BUILD/o0/out.txt" >&2
  echo '--- O2 ---' >&2; cat "$BUILD/o2/out.txt" >&2
  fail 'O0/O2 independent sentinel output drift'
}
echo 'FVQ48_O0_O2_SENTINEL_IDENTITY=PASS'
cat "$BUILD/o0/out.txt"

if grep -Fq 'FVQ48_HN1_FORCING_CANDIDATE_BINDING=FAIL_OPEN' "$BUILD/o0/out.txt"; then
  echo 'FVQ48_HARD_NEGATIVE_HN1_REPRODUCED=PASS'
  echo 'FVQ48_REMAINING_MATRIX=UNRUN_AFTER_HARD_NEGATIVE'
  echo 'FVQ48_DECISION=NOT_QUALIFIED'
  exit 48
fi

if grep -Fq 'FVQ48_HN1_FORCING_CANDIDATE_BINDING=FAIL_CLOSED' "$BUILD/o0/out.txt"; then
  echo 'FVQ48_HARD_NEGATIVE_HN1=PASS'
  echo 'FVQ48_DECISION=PENDING_REMAINING_MATRIX'
  exit 2
fi

fail 'HN1 produced no recognized disposition'
