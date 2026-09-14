#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq83-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"; trap 'rm -rf "$BUILD"' EXIT; cd "$ROOT"
fail(){ echo "FVQ83_GATE_FAIL $*" >&2; exit 283; }

CANONICAL="b162e98cc4ad6f85b741a21bd41f3db3d213559b"
OWNER="5b1c5ef0f9a1e28ef48e84fac638e63268e198d0"
MATERIALIZED_SOURCE="e0837bdb9ce8ae2ab92bd32c975b08997d44e93b"
NEGATIVE_AUTHORITY="30551be4dd9ef9d4a698ff0cd5a701e17503fe9e"
TYPES="src/kernel/mod_energy_conservation_types.f90"
LEDGER="src/runtime/mod_energy_conservation_ledger.f90"
TYPES_BLOB="15a6a9c5c5da6ad0d535c27772e57a23e618658d"
LEDGER_BLOB="e71820784780e4a45a7024dbc437c71f0fb7d0c4"

git fetch -q origin integration/f-ci-canonical work/eb-i20r2-explicit-ledger-owner-identity-remediation \
  qualification/f-vq82-eb-i20r1-cross-ledger-provenance-independent-qualification
[[ "$(git rev-parse origin/integration/f-ci-canonical)" == "$CANONICAL" ]] || fail 'canonical drift'
[[ "$(git rev-parse origin/work/eb-i20r2-explicit-ledger-owner-identity-remediation)" == "$OWNER" ]] || fail 'EB-I20R2 owner authority drift'
[[ "$(git rev-parse origin/qualification/f-vq82-eb-i20r1-cross-ledger-provenance-independent-qualification)" == "$NEGATIVE_AUTHORITY" ]] || fail 'F-VQ82 negative authority drift'
[[ "$(git merge-base "$OWNER" HEAD)" == "$OWNER" ]] || fail 'verifier not descended from exact EB-I20R2 owner authority'
[[ "$(git merge-base "$MATERIALIZED_SOURCE" "$OWNER")" == "$MATERIALIZED_SOURCE" ]] || fail 'owner status does not descend from materialized source'
changed="$(git diff --name-only "$CANONICAL..$OWNER" -- src | LC_ALL=C sort)"
[[ "$changed" == $'src/kernel/mod_energy_conservation_types.f90\nsrc/runtime/mod_energy_conservation_ledger.f90' ]] || fail 'owner production delta not exactly two energy modules'
[[ -z "$(git diff --name-only "$CANONICAL..$OWNER" -- reference)" ]] || fail 'owner reference delta'
[[ "$(git rev-parse "$OWNER:$TYPES")" == "$TYPES_BLOB" ]] || fail 'energy types blob drift'
[[ "$(git rev-parse "$OWNER:$LEDGER")" == "$LEDGER_BLOB" ]] || fail 'energy ledger blob drift'
[[ -z "$(git diff --name-only "$OWNER..HEAD" -- src reference)" ]] || fail 'verifier modified production/reference source'
grep -Fq '"status": "OWNER_POSTIMAGE_QUALIFIED_PENDING_INDEPENDENT_NOT_CANONICAL_ADMISSION"' qualification/EB-I20R2_STATUS.json || fail 'owner status classification drift'
echo 'FVQ83_SCOPE_PROVENANCE_AND_BLOBS=PASS'

! grep -Eq '^[[:space:]]*error stop' "$LEDGER" || fail 'batch-fatal error stop remains'
grep -Fq 'owner_instance_id' "$LEDGER" || fail 'prepared owner identity missing'
grep -Fq 'prepared%owner_instance_id /= self%prepared_owner_instance_id' "$LEDGER" || fail 'owner identity match guard missing'
grep -Fq 'unique among simultaneously live logical ledger owners' "$LEDGER" || fail 'caller uniqueness contract missing'
! grep -Eiq '^[[:space:]]*save\b|atomic_|random_number|system_clock' "$LEDGER" || fail 'hidden/global owner identity mechanism detected'
echo 'FVQ83_EXPLICIT_OWNER_IDENTITY_STATIC=PASS'

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
  gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c tests/fvq/mod_fvq83_receipt_model.f90 -o "$out/model.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c tests/fvq/test_fvq83_explicit_owner_identity_attack.f90 -o "$out/test.o"
  gfortran -O"$opt" "${objects[@]}" "$out/model.o" "$out/test.o" -o "$out/test"
  "$out/test" > "$out/out.txt"
}

compile_attack 0 "$BUILD/o0"
compile_attack 2 "$BUILD/o2"
cmp "$BUILD/o0/out.txt" "$BUILD/o2/out.txt" || fail 'O0/O2 independent attack observation differs'
echo 'FVQ83_ATTACK_O0_O2_IDENTITY=PASS'
cat "$BUILD/o0/out.txt"

for marker in \
  'FVQ83_NONPOSITIVE_OWNER_FAIL_CLOSED=PASS' \
  'FVQ83_DIFFERENT_PROVENANCE_FOREIGN_ABORT=PASS' \
  'FVQ83_DIFFERENT_PROVENANCE_FOREIGN_COMMIT_REAL_RECEIPT=PASS' \
  'FVQ83_OWN_HANDLE_SEMANTICS_AFTER_DIFFERENT_REJECT=PASS' \
  'FVQ83_SAME_PROVENANCE_DISTINCT_OWNER_FOREIGN_ABORT=PASS' \
  'FVQ83_SAME_PROVENANCE_DISTINCT_OWNER_FOREIGN_COMMIT_REAL_RECEIPT=PASS' \
  'FVQ83_OWN_HANDLE_SEMANTICS_AFTER_SAME_PROVENANCE_REJECT=PASS' \
  'FVQ83_DUPLICATE_OWNER_ID_CALLER_CONTRACT_LIMITATION=CONFIRMED' \
  'FVQ83_DISTINCT_OWNER_INSTANCE_ISOLATION=PASS' \
  'FVQ83_INDEPENDENT_ORACLE=PASS_WITH_CALLER_UNIQUENESS_CONTRACT'; do
  grep -Fq "$marker" "$BUILD/o0/out.txt" || fail "missing independent marker: $marker"
done
echo 'FVQ83_FVQ80_FVQ82_ATTACKS_REMEDIATED_UNDER_OWNER_CONTRACT=PASS'
echo 'FVQ83_DUPLICATE_OWNER_LIMITATION_EXPLICIT=PASS'

FVQ67_TAG=fvq83 bash tests/fvq/run_fvq67_mass_completeness_independent.sh > "$BUILD/mass.txt"
grep -Fq 'FVQ67_FVQ83_O0=PASS' "$BUILD/mass.txt" || fail 'F-KT18 mass O0 preservation missing'
grep -Fq 'FVQ67_FVQ83_O2=PASS' "$BUILD/mass.txt" || fail 'F-KT18 mass O2 preservation missing'
grep -Fq 'FVQ67_FVQ83_O0_O2_IDENTITY=PASS' "$BUILD/mass.txt" || fail 'F-KT18 mass O0/O2 preservation missing'
grep -Fq 'FVQ67_REJECTED_COMMITTED_STATE_BITWISE_IMMUTABLE=PASS' "$BUILD/mass.txt" || fail 'F-KT18 rejected-state immutability missing'
echo 'FVQ83_FKT18_MASS_PRESERVATION=PASS'

bash tests/eb/run_eb_i20r2_explicit_owner_identity_gate.sh > "$BUILD/owner_replay.txt"
grep -Fq 'EB_I20R2_OWNER_QUALIFICATION=PASS' "$BUILD/owner_replay.txt" || fail 'owner preservation replay failed'
echo 'FVQ83_OWNER_GATE_REPLAY=PASS'

[[ -z "$(git diff --name-only "$OWNER..HEAD" -- src reference)" ]] || fail 'verifier source/reference delta appeared during gate'
git diff --check "$OWNER..HEAD"
echo 'FVQ83_NO_NEW_PRODUCTION_OR_REFERENCE_DELTA=PASS'
echo 'FVQ83_INDEPENDENT_QUALIFICATION=PASS_WITH_EXPLICIT_CALLER_UNIQUENESS_CONTRACT'
echo 'FVQ83_DECISION=LEDGER_CONTRACT_QUALIFIED_RUNTIME_OWNER_BINDING_REQUIRED_BEFORE_CANONICAL_ADMISSION'
