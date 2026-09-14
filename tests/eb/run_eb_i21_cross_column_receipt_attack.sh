#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-eb-i21-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"; trap 'rm -rf "$BUILD"' EXIT; cd "$ROOT"
fail(){ echo "EB_I21_GATE_FAIL $*" >&2; exit 221; }

CANONICAL="b162e98cc4ad6f85b741a21bd41f3db3d213559b"
FVQ84="25e18edc016606fe78b742c4f252e330975ed409"
TYPES="src/kernel/mod_energy_conservation_types.f90"
LEDGER="src/runtime/mod_energy_conservation_ledger.f90"
RECEIPT="src/runtime/mod_fmr_accepted_commit_receipt.f90"
TYPES_BLOB="15a6a9c5c5da6ad0d535c27772e57a23e618658d"
LEDGER_BLOB="e71820784780e4a45a7024dbc437c71f0fb7d0c4"
RECEIPT_BLOB="6798b3296b426950bf028814585c3f5de9be950b"

git fetch -q origin integration/f-ci-canonical qualification/f-vq84-eb-i20r2-explicit-owner-identity-independent-qualification
[[ "$(git rev-parse origin/integration/f-ci-canonical)" == "$CANONICAL" ]] || fail 'canonical drift'
[[ "$(git rev-parse origin/qualification/f-vq84-eb-i20r2-explicit-owner-identity-independent-qualification)" == "$FVQ84" ]] || fail 'F-VQ84 authority drift'
[[ "$(git merge-base "$FVQ84" HEAD)" == "$FVQ84" ]] || fail 'EB-I21 not descended from exact F-VQ84 authority'
[[ "$(git rev-parse HEAD:$TYPES)" == "$TYPES_BLOB" ]] || fail 'energy types blob drift'
[[ "$(git rev-parse HEAD:$LEDGER)" == "$LEDGER_BLOB" ]] || fail 'energy ledger blob drift'
[[ "$(git rev-parse HEAD:$RECEIPT)" == "$RECEIPT_BLOB" ]] || fail 'accepted receipt blob drift'
[[ -z "$(git diff --name-only "$FVQ84..HEAD" -- src reference)" ]] || fail 'EB-I21 audit modified production/reference source'
echo 'EB_I21_AUDIT_SCOPE_AND_BLOBS=PASS'

# The currently admitted receipt intentionally exposes no column/owner identity.
! grep -Fq 'column_id' "$RECEIPT" || fail 'receipt contract unexpectedly acquired column identity; audit needs redesign'
! grep -Fq 'owner_instance_id' "$RECEIPT" || fail 'receipt contract unexpectedly acquired owner identity; audit needs redesign'
echo 'EB_I21_RECEIPT_HAS_NO_OWNER_OR_COLUMN_IDENTITY=CONFIRMED'

STRICT=(-std=f2008 -Wall -Wextra -Werror -ffree-line-length-none -fcheck=all -fbacktrace)
BASE=(-std=f2008 -Wall -Wextra -Werror -Wno-error=compare-reals -ffree-line-length-none -fcheck=all -fbacktrace)
BASE_MODULES=(src/transaction/mod_transaction_reference.f90 src/runtime/mod_canonical_contracts.f90 src/runtime/mod_canonical_interval_runtime.f90 src/kernel/mod_kernel_transactions.f90 src/runtime/mod_fmr_accepted_commit_receipt.f90)

compile_attack(){
  local opt="$1" out="$2" module_src obj
  local objects=()
  mkdir -p "$out"
  for module_src in "${BASE_MODULES[@]}"; do
    obj="$out/$(basename "${module_src%.*}").o"
    gfortran "${BASE[@]}" -O"$opt" -J "$out" -I "$out" -c "$module_src" -o "$obj"
    objects+=("$obj")
  done
  for module_src in "$TYPES" "$LEDGER"; do
    obj="$out/$(basename "${module_src%.*}").o"
    gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c "$module_src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c tests/fvq/mod_fvq84_receipt_model.f90 -o "$out/model.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c tests/eb/test_eb_i21_cross_column_receipt_attack.f90 -o "$out/test.o"
  gfortran -O"$opt" "${objects[@]}" "$out/model.o" "$out/test.o" -o "$out/test"
  "$out/test" > "$out/out.txt"
}

compile_attack 0 "$BUILD/o0"
compile_attack 2 "$BUILD/o2"
cmp "$BUILD/o0/out.txt" "$BUILD/o2/out.txt" || fail 'O0/O2 attack observation differs'
cat "$BUILD/o0/out.txt"
for marker in \
  'EBI21_DISTINCT_PHYSICAL_COLUMNS_SCALAR_RECEIPT_ALIAS=CONFIRMED' \
  'EBI21_OWN_HANDLE_FOREIGN_COLUMN_RECEIPT_ACCEPTED=BLOCKER_CONFIRMED' \
  'EBI21_RUNTIME_OWNER_ID_ALONE_INSUFFICIENT=CONFIRMED' \
  'EBI21_CROSS_COLUMN_RECEIPT_ATTACK_ORACLE=PASS_NEGATIVE_EVIDENCE'; do
  grep -Fq "$marker" "$BUILD/o0/out.txt" || fail "missing marker: $marker"
done
echo 'EB_I21_ATTACK_O0_O2_IDENTITY=PASS'

FVQ67_TAG=ebi21 bash tests/fvq/run_fvq67_mass_completeness_independent.sh > "$BUILD/mass.txt"
grep -Fq 'FVQ67_EBI21_O0_O2_IDENTITY=PASS' "$BUILD/mass.txt" || fail 'F-KT18 mass O0/O2 preservation missing'
grep -Fq 'FVQ67_REJECTED_COMMITTED_STATE_BITWISE_IMMUTABLE=PASS' "$BUILD/mass.txt" || fail 'F-KT18 rejected-state immutability missing'
echo 'EB_I21_FKT18_MASS_PRESERVATION=PASS'

git diff --check "$FVQ84..HEAD"
echo 'EB_I21_AUDIT_DECISION=RUNTIME_OWNER_BINDING_ALONE_INSUFFICIENT_RECEIPT_ASSOCIATION_REQUIRED'
echo 'EB_I21_CANONICAL_ADMISSION=NOT_AUTHORIZED'
