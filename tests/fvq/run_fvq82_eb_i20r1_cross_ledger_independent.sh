#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq82-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"; trap 'rm -rf "$BUILD"' EXIT; cd "$ROOT"
fail(){ echo "FVQ82_GATE_FAIL $*" >&2; exit 282; }

CANONICAL="b162e98cc4ad6f85b741a21bd41f3db3d213559b"
OWNER="8bb56b95b401dad52dc5410b60e9d392be92e286"
TYPES="src/kernel/mod_energy_conservation_types.f90"
LEDGER="src/runtime/mod_energy_conservation_ledger.f90"
TYPES_BLOB="15a6a9c5c5da6ad0d535c27772e57a23e618658d"
LEDGER_BLOB="84355db95e0b47f2d231422a4bc050d89b712e5b"

git fetch -q origin integration/f-ci-canonical work/eb-i20r1-cross-ledger-prepared-provenance-remediation
[[ "$(git rev-parse origin/integration/f-ci-canonical)" == "$CANONICAL" ]] || fail 'canonical drift'
[[ "$(git merge-base "$OWNER" HEAD)" == "$OWNER" ]] || fail 'verifier not descended from exact EB-I20R1 authority'
changed="$(git diff --name-only "$CANONICAL..$OWNER" -- src | LC_ALL=C sort)"
[[ "$changed" == $'src/kernel/mod_energy_conservation_types.f90\nsrc/runtime/mod_energy_conservation_ledger.f90' ]] || fail 'owner production delta not exactly two energy modules'
[[ -z "$(git diff --name-only "$CANONICAL..$OWNER" -- reference)" ]] || fail 'owner reference delta'
[[ "$(git rev-parse "$OWNER:$TYPES")" == "$TYPES_BLOB" ]] || fail 'energy types blob drift'
[[ "$(git rev-parse "$OWNER:$LEDGER")" == "$LEDGER_BLOB" ]] || fail 'energy ledger blob drift'
[[ -z "$(git diff --name-only "$OWNER..HEAD" -- src reference)" ]] || fail 'verifier modified production/reference source'
echo 'FVQ82_SCOPE_AND_BLOBS=PASS'

! grep -Eq '^[[:space:]]*error stop' "$LEDGER" || fail 'batch-fatal error stop remains'
grep -Fq 'prepared%generation /= self%prepared_generation' "$LEDGER" || fail 'generation provenance guard missing'
grep -Fq 'prepared%lineage_id /= self%prepared_lineage_id' "$LEDGER" || fail 'lineage provenance guard missing'
grep -Fq 'prepared%origin_revision_value /= self%prepared_origin_revision_value' "$LEDGER" || fail 'revision provenance guard missing'
grep -Fq 'same_fkt_time(prepared%t0_value, self%prepared_t0_value)' "$LEDGER" || fail 't0 provenance guard missing'
grep -Fq 'same_fkt_time(prepared%t1_value, self%prepared_t1_value)' "$LEDGER" || fail 't1 provenance guard missing'
echo 'FVQ82_R1_PROVENANCE_GUARDS_STATIC=PASS'

STRICT=(-std=f2008 -Wall -Wextra -Werror -ffree-line-length-none -fcheck=all -fbacktrace)
BASE=(-std=f2008 -Wall -Wextra -Werror -Wno-error=compare-reals -ffree-line-length-none -fcheck=all -fbacktrace)
TESTFLAGS=(-std=f2008 -Wall -Wextra -Werror -Wno-error=unused-variable -ffree-line-length-none -fcheck=all -fbacktrace)
BASE_MODULES=(src/transaction/mod_transaction_reference.f90 src/runtime/mod_canonical_contracts.f90 src/runtime/mod_canonical_interval_runtime.f90 src/kernel/mod_kernel_transactions.f90 src/runtime/mod_fmr_accepted_commit_receipt.f90)

compile_attack(){
  local opt="$1" out="$2"; mkdir -p "$out"; local objects=()
  for src in "${BASE_MODULES[@]}"; do
    local obj="$out/$(basename "${src%.*}").o"
    gfortran "${BASE[@]}" -O"$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  for src in "$TYPES" "$LEDGER"; do
    local obj="$out/$(basename "${src%.*}").o"
    gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c tests/fvq/mod_fvq82_receipt_model.f90 -o "$out/model.o"
  gfortran "${TESTFLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c tests/fvq/test_fvq82_cross_ledger_instance_attack.f90 -o "$out/test.o"
  gfortran -O"$opt" "${objects[@]}" "$out/model.o" "$out/test.o" -o "$out/test"
  "$out/test" > "$out/out.txt"
}

compile_attack 0 "$BUILD/o0"
compile_attack 2 "$BUILD/o2"
cmp "$BUILD/o0/out.txt" "$BUILD/o2/out.txt" || fail 'O0/O2 attack observation differs'
echo 'FVQ82_ATTACK_O0_O2_IDENTITY=PASS'
cat "$BUILD/o0/out.txt"

grep -Fq 'FVQ82_DIFFERENT_PROVENANCE_FOREIGN_ABORT=PASS' "$BUILD/o0/out.txt" || fail 'F-VQ80 abort attack not repelled'
grep -Fq 'FVQ82_DIFFERENT_PROVENANCE_FOREIGN_COMMIT=PASS' "$BUILD/o0/out.txt" || fail 'different-provenance foreign commit not repelled'
grep -Fq 'FVQ82_OWN_HANDLE_SEMANTICS_AFTER_REJECT=PASS' "$BUILD/o0/out.txt" || fail 'own-handle semantics damaged'
echo 'FVQ82_FVQ80_BLOCKER_REMEDIATED=PASS'

FVQ67_TAG=fvq82 bash tests/fvq/run_fvq67_mass_completeness_independent.sh > "$BUILD/mass.txt"
grep -Fq 'FVQ67_FVQ82_O0=PASS' "$BUILD/mass.txt" || fail 'F-KT18 mass O0 preservation missing'
grep -Fq 'FVQ67_FVQ82_O2=PASS' "$BUILD/mass.txt" || fail 'F-KT18 mass O2 preservation missing'
grep -Fq 'FVQ67_FVQ82_O0_O2_IDENTITY=PASS' "$BUILD/mass.txt" || fail 'F-KT18 mass O0/O2 preservation missing'
echo 'FVQ82_FKT18_MASS_PRESERVATION=PASS'

if grep -Fq 'FVQ82_CROSS_LEDGER_INSTANCE_ISOLATION=PASS' "$BUILD/o0/out.txt"; then
  echo 'FVQ82_INDEPENDENT_QUALIFICATION=PASS'
  echo 'FVQ82_DECISION=QUALIFIED_FOR_ADMISSION_REVIEW'
  exit 0
fi

if grep -Fq 'FVQ82_CROSS_LEDGER_INSTANCE_ISOLATION=BLOCKER_SAME_PROVENANCE_ALIAS' "$BUILD/o0/out.txt"; then
  echo 'FVQ82_INDEPENDENT_QUALIFICATION=NOT_QUALIFIED_SAME_PROVENANCE_LEDGER_ALIAS'
  echo 'FVQ82_DECISION=EXPLICIT_LEDGER_INSTANCE_IDENTITY_REQUIRED_BEFORE_ADMISSION'
  exit 0
fi

fail 'independent oracle produced unexpected classification'
