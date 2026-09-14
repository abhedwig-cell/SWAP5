#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-eb-i20r-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"; trap 'rm -rf "$BUILD"' EXIT; cd "$ROOT"
fail(){ echo "EB_I20R_GATE_FAIL $*" >&2; exit 221; }

CANONICAL="b162e98cc4ad6f85b741a21bd41f3db3d213559b"
AUDIT="d1485274f7cccb6971a1576267c839e7484d9af1"
TYPES="src/kernel/mod_energy_conservation_types.f90"
LEDGER="src/runtime/mod_energy_conservation_ledger.f90"
TYPES_BLOB="15a6a9c5c5da6ad0d535c27772e57a23e618658d"

git fetch -q origin integration/f-ci-canonical
[[ "$(git rev-parse origin/integration/f-ci-canonical)" == "$CANONICAL" ]] || fail 'canonical drift'
[[ "$(git merge-base "$AUDIT" HEAD)" == "$AUDIT" ]] || fail 'not descended from EB-I20 audit'
changed="$(git diff --name-only "$CANONICAL..HEAD" -- src | LC_ALL=C sort)"
[[ "$changed" == $'src/kernel/mod_energy_conservation_types.f90\nsrc/runtime/mod_energy_conservation_ledger.f90' ]] || fail 'unexpected source delta'
[[ -z "$(git diff --name-only "$CANONICAL..HEAD" -- reference)" ]] || fail 'reference delta'
[[ "$(git rev-parse HEAD:$TYPES)" == "$TYPES_BLOB" ]] || fail 'energy types drift'
echo 'EB_I20R_SCOPE_LOCK=PASS'

! grep -Eq '^[[:space:]]*error stop' "$LEDGER" || fail 'batch-fatal error stop remains'
grep -Fq 'subroutine energy_ledger_commit_prepared(self, prepared, receipt, record, status)' "$LEDGER" || fail 'commit status API missing'
grep -Fq 'subroutine energy_ledger_abort_prepared(self, prepared, status)' "$LEDGER" || fail 'abort status API missing'
echo 'EB_I20R_BATCH_FATAL_PATHS_REMOVED=PASS'

STRICT=(-std=f2008 -Wall -Wextra -Werror -ffree-line-length-none -fcheck=all -fbacktrace)
BASE=(-std=f2008 -Wall -Wextra -Werror -Wno-error=compare-reals -ffree-line-length-none -fcheck=all -fbacktrace)
BASE_MODULES=(src/transaction/mod_transaction_reference.f90 src/runtime/mod_canonical_contracts.f90 src/runtime/mod_canonical_interval_runtime.f90 src/kernel/mod_kernel_transactions.f90 src/runtime/mod_fmr_accepted_commit_receipt.f90)

compile_stack(){
  local opt="$1" out="$2"; mkdir -p "$out"; STACK_OBJECTS=()
  for src in "${BASE_MODULES[@]}"; do
    local obj="$out/$(basename "${src%.*}").o"; gfortran "${BASE[@]}" -O"$opt" -J "$out" -I "$out" -c "$src" -o "$obj"; STACK_OBJECTS+=("$obj")
  done
  for src in "$TYPES" "$LEDGER"; do
    local obj="$out/$(basename "${src%.*}").o"; gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c "$src" -o "$obj"; STACK_OBJECTS+=("$obj")
  done
}

for opt in 0 2; do
  out="$BUILD/failclosed-o$opt"; compile_stack "$opt" "$out"
  gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c tests/eb/test_eb_i20r_batch_safe_ledger_failclosed.f90 -o "$out/test.o"
  gfortran -O"$opt" "${STACK_OBJECTS[@]}" "$out/test.o" -o "$out/test"
  "$out/test" > "$out/out.txt"
  grep -Fq 'EBI20R_BATCH_SAFE_LEDGER_FAILCLOSED_TEST PASS' "$out/out.txt" || fail "failclosed marker O$opt"
done
cmp "$BUILD/failclosed-o0/out.txt" "$BUILD/failclosed-o2/out.txt" || fail 'failclosed O0/O2 mismatch'
echo 'EB_I20R_FAILCLOSED_O0_O2_IDENTITY=PASS'

python3 tests/eb/_normalize_eb_i20r_current_fixture.py tests/eb/test_ebi01_energy_ledger_receipt_integration.f90 "$BUILD/receipt_current.f90"
for opt in 0 2; do
  out="$BUILD/receipt-o$opt"; compile_stack "$opt" "$out"
  gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c "$BUILD/receipt_current.f90" -o "$out/test.o"
  gfortran -O"$opt" "${STACK_OBJECTS[@]}" "$out/test.o" -o "$out/test"
  "$out/test" > "$out/out.txt"
  grep -Fq 'EBI01_ENERGY_LEDGER_RECEIPT_INTEGRATION_TEST PASS' "$out/out.txt" || fail "historical receipt marker O$opt"
done
cmp "$BUILD/receipt-o0/out.txt" "$BUILD/receipt-o2/out.txt" || fail 'historical receipt O0/O2 mismatch'
echo 'EB_I20R_ACCEPTED_RECEIPT_AND_ROLLBACK_SEMANTICS_PRESERVED=PASS'

FVQ67_TRANSACTION_SOURCE="$ROOT/src/transaction/mod_transaction_reference.f90" FVQ67_TAG=ebi20r bash tests/fvq/run_fvq67_mass_completeness_independent.sh > "$BUILD/fvq67.txt"
grep -Fq 'FVQ67_EBI20R_O0_O2_IDENTITY=PASS' "$BUILD/fvq67.txt" || fail 'F-VQ67 O0/O2 marker'
grep -Fq 'FVQ67_REJECTED_COMMITTED_STATE_BITWISE_IMMUTABLE=PASS' "$BUILD/fvq67.txt" || fail 'F-VQ67 immutable marker'
echo 'EB_I20R_FKT18_MASS_PRESERVATION=PASS'

git diff --check "$CANONICAL..HEAD"
echo "EB_I20R_LEDGER_BLOB=$(git rev-parse HEAD:$LEDGER)"
echo 'EB_I20R_OWNER_QUALIFICATION=PASS'
