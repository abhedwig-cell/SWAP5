#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq81-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"; trap 'rm -rf "$BUILD"' EXIT; cd "$ROOT"
fail(){ echo "FVQ81_FAIL $*" >&2; exit 81; }

CANONICAL="b162e98cc4ad6f85b741a21bd41f3db3d213559b"
OWNER="34c4545cc3dea96c9d13988c491b387c8c2a19fd"
TYPES_BLOB="15a6a9c5c5da6ad0d535c27772e57a23e618658d"
LEDGER_BLOB="a6aea349308e8b6b0aedaaa22a64e41f9101b48d"
TX_BLOB="d5a71a526efaebd82054580c3186f8e3545db331"

git fetch -q origin integration/f-ci-canonical
test "$(git rev-parse origin/integration/f-ci-canonical)" = "$CANONICAL" || fail 'canonical drift'
test "$(git merge-base "$OWNER" HEAD)" = "$OWNER" || fail 'verifier not rooted in exact EB-I20R owner authority'
test -z "$(git diff --name-only "$OWNER..HEAD" -- src reference)" || fail 'independent verifier changed production/reference source'
changed_src="$(git diff --name-only "$CANONICAL..HEAD" -- src | LC_ALL=C sort)"
test "$changed_src" = $'src/kernel/mod_energy_conservation_types.f90\nsrc/runtime/mod_energy_conservation_ledger.f90' || fail 'canonical source delta is not exactly the two energy modules'
test -z "$(git diff --name-only "$CANONICAL..HEAD" -- reference)" || fail 'reference source changed'
test "$(git rev-parse HEAD:src/kernel/mod_energy_conservation_types.f90)" = "$TYPES_BLOB" || fail 'energy types blob drift'
test "$(git rev-parse HEAD:src/runtime/mod_energy_conservation_ledger.f90)" = "$LEDGER_BLOB" || fail 'energy ledger blob drift'
test "$(git rev-parse HEAD:src/transaction/mod_transaction_reference.f90)" = "$TX_BLOB" || fail 'transaction authority drift'
echo 'FVQ81_SCOPE_PROVENANCE_AND_BLOBS=PASS'

if grep -Eq '^[[:space:]]*error stop' src/runtime/mod_energy_conservation_ledger.f90; then
  fail 'batch-fatal error stop remains in production energy ledger'
fi
grep -Fq 'subroutine energy_ledger_commit_prepared(self, prepared, receipt, record, status)' src/runtime/mod_energy_conservation_ledger.f90 || fail 'commit status API absent'
grep -Fq 'subroutine energy_ledger_abort_prepared(self, prepared, status)' src/runtime/mod_energy_conservation_ledger.f90 || fail 'abort status API absent'
echo 'FVQ81_NONTERMINATING_FAIL_CLOSED_API=PASS'

BASE=(-std=f2008 -Wall -Wextra -Werror -Wno-error=compare-reals -ffree-line-length-none -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
STRICT=(-std=f2008 -Wall -Wextra -Werror -ffree-line-length-none -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
TEST=(-std=f2008 -Wall -Wextra -Werror -Wno-compare-reals -ffree-line-length-none -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULES=(
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
)

for opt in 0 2; do
  out="$BUILD/o$opt"; mkdir -p "$out"; objs=()
  for src in "${MODULES[@]}"; do
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${BASE[@]}" -O"$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objs+=("$obj")
  done
  for src in src/kernel/mod_energy_conservation_types.f90 src/runtime/mod_energy_conservation_ledger.f90; do
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objs+=("$obj")
  done
  gfortran "${TEST[@]}" -O"$opt" -J "$out" -I "$out" -c tests/fvq/test_fvq81_energy_ledger_independent.f90 -o "$out/test.o"
  gfortran -O"$opt" "${objs[@]}" "$out/test.o" -o "$out/test"
  "$out/test" > "$out/out.txt" 2>&1 || { cat "$out/out.txt" >&2; fail "independent oracle O$opt"; }
  for marker in \
    'FVQ81_INVALID_RECEIPT_NO_PUBLICATION=PASS' \
    'FVQ81_ACCEPTED_RECEIPT_PUBLISHES_EXACT_PROVENANCE=PASS' \
    'FVQ81_DOUBLE_PUBLICATION_FAIL_CLOSED=PASS' \
    'FVQ81_STALE_RECEIPT_AND_ROLLBACK_NO_LEAK=PASS' \
    'FVQ81_STALE_GENERATION_NONTERMINATING=PASS' \
    'FVQ81_CONTROL_VOLUME_CONSERVATION_INDEPENDENT=PASS' \
    'FVQ81_ENERGY_LEDGER_INDEPENDENT_ORACLE=PASS'; do
    grep -Fq "$marker" "$out/out.txt" || fail "missing independent marker O$opt: $marker"
  done
done
cmp "$BUILD/o0/out.txt" "$BUILD/o2/out.txt" || fail 'independent oracle O0/O2 output mismatch'
echo 'FVQ81_INDEPENDENT_O0_O2_SEMANTIC_IDENTITY=PASS'

FVQ67_TRANSACTION_SOURCE="$ROOT/src/transaction/mod_transaction_reference.f90" FVQ67_TAG=fvq81 \
  bash tests/fvq/run_fvq67_mass_completeness_independent.sh > "$BUILD/fvq67.txt" 2>&1 || {
    cat "$BUILD/fvq67.txt" >&2; fail 'F-VQ67 mass-completeness cross-check';
  }
grep -Fq 'FVQ67_FVQ81_O0_O2_IDENTITY=PASS' "$BUILD/fvq67.txt" || fail 'F-VQ67 O0/O2 cross-check marker'
grep -Fq 'FVQ67_ZERO_RESIDUAL_INCOMPLETE_FAIL_CLOSED=PASS' "$BUILD/fvq67.txt" || fail 'F-VQ67 incomplete-mass marker'
grep -Fq 'FVQ67_REJECTED_COMMITTED_STATE_BITWISE_IMMUTABLE=PASS' "$BUILD/fvq67.txt" || fail 'F-VQ67 immutable-state marker'
echo 'FVQ81_FKT18_MASS_COMPLETENESS_CROSSCHECK=PASS'

git diff --check "$OWNER..HEAD"
echo "FVQ81_TESTED_HEAD=$(git rev-parse HEAD)"
echo "FVQ81_TESTED_TREE=$(git rev-parse HEAD^{tree})"
echo 'FVQ81_INDEPENDENT_QUALIFICATION=PASS'
