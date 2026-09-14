#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq85-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"; trap 'rm -rf "$BUILD"' EXIT; cd "$ROOT"
fail(){ echo "FVQ85_GATE_FAIL $*" >&2; exit 285; }

CANONICAL="b162e98cc4ad6f85b741a21bd41f3db3d213559b"
OWNER="5d6cea2e6de577fb0267008b2a391770b5bd7a10"
TYPES="src/kernel/mod_energy_conservation_types.f90"
LEDGER="src/runtime/mod_energy_conservation_ledger.f90"
OWNED="src/runtime/mod_fmr_owned_commit_receipt.f90"
RUNTIME="src/runtime/mod_fmr_serialized_multiswap_runtime.f90"
GENERIC_RECEIPT="src/runtime/mod_fmr_accepted_commit_receipt.f90"
KERNEL_TX="src/kernel/mod_kernel_transactions.f90"
TYPES_BLOB="15a6a9c5c5da6ad0d535c27772e57a23e618658d"
LEDGER_BLOB="cc166e82e51d8e0738fee51b4517626d0a2e890f"
OWNED_BLOB="2ab067d160715ff7358dd31efaa12694ef95852c"
RUNTIME_BLOB="1aa2454048d0e480becaee34f596f20f1a7bd66e"
GENERIC_RECEIPT_BLOB="6798b3296b426950bf028814585c3f5de9be950b"

git fetch -q origin integration/f-ci-canonical work/eb-i21r-runtime-bound-accepted-receipt-remediation
[[ "$(git rev-parse origin/integration/f-ci-canonical)" == "$CANONICAL" ]] || fail 'canonical drift'
[[ "$(git rev-parse origin/work/eb-i21r-runtime-bound-accepted-receipt-remediation)" == "$OWNER" ]] || fail 'owner authority drift'
[[ "$(git merge-base "$OWNER" HEAD)" == "$OWNER" ]] || fail 'verifier not descended from exact EB-I21R owner authority'

changed_src="$(git diff --name-only "$CANONICAL..$OWNER" -- src | LC_ALL=C sort)"
expected_src=$'src/kernel/mod_energy_conservation_types.f90\nsrc/runtime/mod_energy_conservation_ledger.f90\nsrc/runtime/mod_fmr_owned_commit_receipt.f90\nsrc/runtime/mod_fmr_serialized_multiswap_runtime.f90'
[[ "$changed_src" == "$expected_src" ]] || { printf '%s\n' "$changed_src" >&2; fail 'canonical-to-owner production delta not exactly four files'; }
[[ -z "$(git diff --name-only "$CANONICAL..$OWNER" -- reference)" ]] || fail 'owner reference delta'
[[ -z "$(git diff --name-only "$OWNER..HEAD" -- src reference)" ]] || fail 'independent verifier modified production/reference source'
[[ "$(git rev-parse "$OWNER:$TYPES")" == "$TYPES_BLOB" ]] || fail 'energy type blob drift'
[[ "$(git rev-parse "$OWNER:$LEDGER")" == "$LEDGER_BLOB" ]] || fail 'energy ledger blob drift'
[[ "$(git rev-parse "$OWNER:$OWNED")" == "$OWNED_BLOB" ]] || fail 'owned receipt blob drift'
[[ "$(git rev-parse "$OWNER:$RUNTIME")" == "$RUNTIME_BLOB" ]] || fail 'serialized runtime blob drift'
[[ "$(git rev-parse "$OWNER:$GENERIC_RECEIPT")" == "$GENERIC_RECEIPT_BLOB" ]] || fail 'generic receipt blob drift'
[[ "$(git rev-parse "$CANONICAL:$GENERIC_RECEIPT")" == "$GENERIC_RECEIPT_BLOB" ]] || fail 'generic receipt changed relative to canonical'
git diff --quiet "$CANONICAL..$OWNER" -- "$KERNEL_TX" || fail 'generic kernel transaction contract changed'
echo 'FVQ85_SCOPE_PROVENANCE_AND_BLOBS=PASS'

# Independent architecture inspection. The generic receipt remains column
# agnostic; runtime binds its private owned receipt at the commit callsite.
grep -Fq 'public :: fmr_commit_candidate_with_owned_receipt' "$OWNED" || fail 'owned commit producer missing'
grep -Fq 'deliberately no public routine that can bind an already-existing generic' "$OWNED" || fail 'after-the-fact binding prohibition missing'
! grep -Eiq '^[[:space:]]*save\b|random_number|system_clock|atomic_' "$OWNED" || fail 'hidden/global owner identity mechanism detected'
grep -Fq 'receipt%owner_instance_id() /= prepared%owner_instance_id' "$LEDGER" || fail 'ledger owner association guard missing'
grep -Fq 'fmr_commit_candidate_with_owned_receipt(column%column_id' "$RUNTIME" || fail 'runtime owner not derived from executing logical column'
grep -Fq "receipt%owner_instance_id() /= column_id" "$RUNTIME" || fail 'publication owner guard missing'
! grep -Fq 'owner_instance_id' "$GENERIC_RECEIPT" || fail 'generic accepted receipt was polluted with runtime ownership'
echo 'FVQ85_RUNTIME_KERNEL_OWNERSHIP_SEPARATION=PASS'

STRICT=(-std=f2008 -Wall -Wextra -Werror -ffree-line-length-none -fcheck=all -fbacktrace)
BASE=(-std=f2008 -Wall -Wextra -Werror -Wno-error=compare-reals -ffree-line-length-none -fcheck=all -fbacktrace)
BASE_MODULES=(
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
)

compile_oracle(){
  local opt="$1" out="$2" src obj
  mkdir -p "$out"; local objects=()
  for src in "${BASE_MODULES[@]}"; do
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${BASE[@]}" -O"$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  for src in "$OWNED" "$TYPES" "$LEDGER"; do
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c tests/fvq/mod_fvq84_receipt_model.f90 -o "$out/model.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c tests/fvq/test_fvq85_runtime_owned_receipt_independent.f90 -o "$out/test.o"
  gfortran -O"$opt" "${objects[@]}" "$out/model.o" "$out/test.o" -o "$out/test"
  "$out/test" > "$out/out.txt"
}
compile_oracle 0 "$BUILD/o0"
compile_oracle 2 "$BUILD/o2"
cmp -s "$BUILD/o0/out.txt" "$BUILD/o2/out.txt" || fail 'independent O0/O2 output drift'
cat "$BUILD/o0/out.txt"
for marker in \
  'FVQ85_INVALID_OWNER_PRECOMMIT_FAIL_CLOSED=PASS' \
  'FVQ85_REAL_COLUMNS_SCALAR_RECEIPT_ALIAS_REPRODUCED=PASS' \
  'FVQ85_GENERIC_RECEIPT_EXPORT_COMPATIBILITY=PASS' \
  'FVQ85_FOREIGN_COLUMN_RECEIPT_FAIL_CLOSED=PASS' \
  'FVQ85_RIGHTFUL_OWNER_COMMIT_EXACTLY_ONCE=PASS' \
  'FVQ85_RUNTIME_OWNED_RECEIPT_INDEPENDENT_ORACLE=PASS'; do
  grep -Fq "$marker" "$BUILD/o0/out.txt" || fail "missing independent marker: $marker"
done
echo 'FVQ85_INDEPENDENT_ORACLE_O0_O2=PASS'

# Owner gate is replayed only as preservation evidence after the independent
# oracle above; it is not the independent decision oracle.
bash tests/eb/run_eb_i21r_owned_receipt_gate.sh > "$BUILD/owner-replay.txt" 2>&1 || { cat "$BUILD/owner-replay.txt" >&2; fail 'owner postimage replay'; }
grep -Fq 'EB_I21R_OWNER_QUALIFICATION=PASS' "$BUILD/owner-replay.txt" || fail 'owner qualification marker absent'
grep -Fq 'EB_I21R_BOTTOM_ENERGY_RUNTIME_O0_O2=PASS' "$BUILD/owner-replay.txt" || fail 'bottom-energy preservation marker absent'
grep -Fq 'EB_I21R_FKT18_MASS_PRESERVATION=PASS' "$BUILD/owner-replay.txt" || fail 'F-KT18 mass preservation marker absent'
echo 'FVQ85_OWNER_POSTIMAGE_REPLAY=PASS'

git diff --check "$OWNER..HEAD"
[[ -z "$(git diff --name-only "$OWNER..HEAD" -- src reference)" ]] || fail 'verifier source/reference delta after execution'
echo 'FVQ85_NO_NEW_SOURCE_OR_REFERENCE_DELTA=PASS'
echo 'FVQ85_INDEPENDENT_QUALIFICATION=PASS'
echo 'FVQ85_CANONICAL_ADMISSION=NOT_AUTHORIZED'
