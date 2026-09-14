#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-eb-i20r2-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"; trap 'rm -rf "$BUILD"' EXIT; cd "$ROOT"
fail(){ echo "EB_I20R2_GATE_FAIL $*" >&2; exit 222; }

CANONICAL="b162e98cc4ad6f85b741a21bd41f3db3d213559b"
PARENT="8bb56b95b401dad52dc5410b60e9d392be92e286"
BLOCKER="30551be4dd9ef9d4a698ff0cd5a701e17503fe9e"
TYPES="src/kernel/mod_energy_conservation_types.f90"
LEDGER="src/runtime/mod_energy_conservation_ledger.f90"
TYPES_BLOB="15a6a9c5c5da6ad0d535c27772e57a23e618658d"
PRE_LEDGER_BLOB="84355db95e0b47f2d231422a4bc050d89b712e5b"

git fetch -q origin integration/f-ci-canonical qualification/f-vq82-eb-i20r1-cross-ledger-provenance-independent-qualification
[[ "$(git rev-parse origin/integration/f-ci-canonical)" == "$CANONICAL" ]] || fail 'canonical drift'
[[ "$(git merge-base "$PARENT" HEAD)" == "$PARENT" ]] || fail 'not descended from exact EB-I20R1 authority'
[[ "$(git rev-parse origin/qualification/f-vq82-eb-i20r1-cross-ledger-provenance-independent-qualification)" == "$BLOCKER" ]] || fail 'F-VQ82 blocker authority drift'
changed_parent="$(git diff --name-only "$PARENT..HEAD" -- src | LC_ALL=C sort)"
[[ "$changed_parent" == "$LEDGER" ]] || fail 'R2 production source delta not exactly energy ledger'
changed_canonical="$(git diff --name-only "$CANONICAL..HEAD" -- src | LC_ALL=C sort)"
[[ "$changed_canonical" == $'src/kernel/mod_energy_conservation_types.f90\nsrc/runtime/mod_energy_conservation_ledger.f90' ]] || fail 'unexpected canonical production source delta'
[[ -z "$(git diff --name-only "$CANONICAL..HEAD" -- reference)" ]] || fail 'reference delta'
[[ "$(git rev-parse HEAD:$TYPES)" == "$TYPES_BLOB" ]] || fail 'energy types drift'
[[ "$(git rev-parse HEAD:$LEDGER)" != "$PRE_LEDGER_BLOB" ]] || fail 'R2 ledger was not materialized'
echo 'EB_I20R2_SCOPE_LOCK=PASS'

! grep -Eq '^[[:space:]]*error stop' "$LEDGER" || fail 'batch-fatal error stop remains'
grep -Fq 'owner_instance_id' "$LEDGER" || fail 'prepared owner identity missing'
grep -Fq 'prepared_owner_instance_id' "$LEDGER" || fail 'ledger-owned prepared owner identity missing'
grep -Fq 'owner_instance_id_value' "$LEDGER" || fail 'active trial owner identity missing'
grep -Fq 'if (owner_instance_id <= 0_int64' "$LEDGER" || fail 'invalid owner fail-closed guard missing'
grep -Fq 'prepared%owner_instance_id /= self%prepared_owner_instance_id' "$LEDGER" || fail 'owner match guard missing'
grep -Fq 'unique among simultaneously live logical ledger owners' "$LEDGER" || fail 'explicit uniqueness contract missing'
! grep -Eiq '^[[:space:]]*save\b|atomic_|random_number|system_clock' "$LEDGER" || fail 'hidden/global owner identity mechanism detected'
echo 'EB_I20R2_EXPLICIT_OWNER_CONTRACT_STATIC=PASS'

STRICT=(-std=f2008 -Wall -Wextra -Werror -ffree-line-length-none -fcheck=all -fbacktrace)
BASE=(-std=f2008 -Wall -Wextra -Werror -Wno-error=compare-reals -ffree-line-length-none -fcheck=all -fbacktrace)
BASE_MODULES=(src/transaction/mod_transaction_reference.f90 src/runtime/mod_canonical_contracts.f90 src/runtime/mod_canonical_interval_runtime.f90 src/kernel/mod_kernel_transactions.f90 src/runtime/mod_fmr_accepted_commit_receipt.f90)

compile_stack(){
  local opt="$1" out="$2"; mkdir -p "$out"; STACK_OBJECTS=()
  for src in "${BASE_MODULES[@]}"; do
    local obj="$out/$(basename "${src%.*}").o"
    gfortran "${BASE[@]}" -O"$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    STACK_OBJECTS+=("$obj")
  done
  for src in "$TYPES" "$LEDGER"; do
    local obj="$out/$(basename "${src%.*}").o"
    gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    STACK_OBJECTS+=("$obj")
  done
}

run_test_pair(){
  local name="$1" src="$2" marker="$3"
  for opt in 0 2; do
    local out="$BUILD/${name}-o${opt}"; compile_stack "$opt" "$out"
    gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c "$src" -o "$out/test.o"
    gfortran -O"$opt" "${STACK_OBJECTS[@]}" "$out/test.o" -o "$out/test"
    "$out/test" > "$out/out.txt"
    grep -Fq "$marker" "$out/out.txt" || fail "$name marker O$opt"
  done
  cmp "$BUILD/${name}-o0/out.txt" "$BUILD/${name}-o2/out.txt" || fail "$name O0/O2 mismatch"
  cat "$BUILD/${name}-o0/out.txt"
}

python3 tests/eb/_normalize_eb_i20r2_owner_identity_fixture.py \
  tests/eb/test_eb_i20r_batch_safe_ledger_failclosed.f90 "$BUILD/i20r_failclosed.f90"
run_test_pair i20r "$BUILD/i20r_failclosed.f90" 'EBI20R_BATCH_SAFE_LEDGER_FAILCLOSED_TEST PASS'
echo 'EB_I20R2_EB_I20R_BATCH_SAFE_PRESERVATION=PASS'

python3 tests/eb/_normalize_eb_i20r2_owner_identity_fixture.py \
  tests/eb/test_eb_i20r1_cross_ledger_prepared_provenance.f90 "$BUILD/i20r1_provenance.f90"
run_test_pair i20r1 "$BUILD/i20r1_provenance.f90" 'EBI20R1_CROSS_LEDGER_PREPARED_PROVENANCE_TEST PASS'
echo 'EB_I20R2_EB_I20R1_PROVENANCE_PRESERVATION=PASS'

python3 tests/eb/_normalize_eb_i20r_current_fixture.py \
  tests/eb/test_ebi01_energy_ledger_receipt_integration.f90 "$BUILD/receipt_current.f90"
python3 tests/eb/_normalize_eb_i20r2_owner_identity_fixture.py \
  "$BUILD/receipt_current.f90" "$BUILD/receipt_owner.f90"
run_test_pair receipt "$BUILD/receipt_owner.f90" 'EBI01_ENERGY_LEDGER_RECEIPT_INTEGRATION_TEST PASS'
echo 'EB_I20R2_ACCEPTED_RECEIPT_AND_ROLLBACK_PRESERVATION=PASS'

run_test_pair owner tests/eb/test_eb_i20r2_explicit_owner_identity.f90 'EBI20R2_EXPLICIT_OWNER_IDENTITY_TEST PASS'
grep -Fq 'EBI20R2_SAME_TRANSACTION_FOREIGN_OWNER_ABORT_FAIL_CLOSED=PASS' "$BUILD/owner-o0/out.txt" || fail 'same-transaction foreign owner abort not fail closed'
echo 'EB_I20R2_OWNER_ISOLATION_O0_O2=PASS'

FVQ67_TRANSACTION_SOURCE="$ROOT/src/transaction/mod_transaction_reference.f90" FVQ67_TAG=ebi20r2 \
  bash tests/fvq/run_fvq67_mass_completeness_independent.sh > "$BUILD/fvq67.txt"
grep -Fq 'FVQ67_EBI20R2_O0_O2_IDENTITY=PASS' "$BUILD/fvq67.txt" || fail 'F-VQ67 O0/O2 marker'
grep -Fq 'FVQ67_REJECTED_COMMITTED_STATE_BITWISE_IMMUTABLE=PASS' "$BUILD/fvq67.txt" || fail 'F-VQ67 immutable marker'
echo 'EB_I20R2_FKT18_MASS_PRESERVATION=PASS'

git diff --check "$PARENT..HEAD"
echo "EB_I20R2_LEDGER_BLOB=$(git rev-parse HEAD:$LEDGER)"
echo 'EB_I20R2_OWNER_QUALIFICATION=PASS'
