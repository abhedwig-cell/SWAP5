#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq84-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"; trap 'rm -rf "$BUILD"' EXIT; cd "$ROOT"
fail(){ echo "FVQ84_GATE_FAIL $*" >&2; exit 284; }

CANONICAL="b162e98cc4ad6f85b741a21bd41f3db3d213559b"
OWNER="7750b496499b3b9b3ce7e5a82695d9367182477c"
TYPES="src/kernel/mod_energy_conservation_types.f90"
LEDGER="src/runtime/mod_energy_conservation_ledger.f90"
TYPES_BLOB="15a6a9c5c5da6ad0d535c27772e57a23e618658d"
LEDGER_BLOB="e71820784780e4a45a7024dbc437c71f0fb7d0c4"

git fetch -q origin integration/f-ci-canonical work/eb-i20r2-explicit-ledger-owner-identity-remediation
[[ "$(git rev-parse origin/integration/f-ci-canonical)" == "$CANONICAL" ]] || fail 'canonical drift'
[[ "$(git rev-parse origin/work/eb-i20r2-explicit-ledger-owner-identity-remediation)" == "$OWNER" ]] || fail 'owner authority drift'
[[ "$(git merge-base "$OWNER" HEAD)" == "$OWNER" ]] || fail 'verifier not descended from exact owner authority'
changed="$(git diff --name-only "$CANONICAL..$OWNER" -- src | LC_ALL=C sort)"
[[ "$changed" == $'src/kernel/mod_energy_conservation_types.f90\nsrc/runtime/mod_energy_conservation_ledger.f90' ]] || fail 'owner production delta not exactly two energy modules'
[[ -z "$(git diff --name-only "$CANONICAL..$OWNER" -- reference)" ]] || fail 'owner reference delta'
[[ "$(git rev-parse "$OWNER:$TYPES")" == "$TYPES_BLOB" ]] || fail 'energy types blob drift'
[[ "$(git rev-parse "$OWNER:$LEDGER")" == "$LEDGER_BLOB" ]] || fail 'energy ledger blob drift'
[[ -z "$(git diff --name-only "$OWNER..HEAD" -- src reference)" ]] || fail 'verifier modified production/reference source'
echo 'FVQ84_SCOPE_AND_BLOBS=PASS'

! grep -Eq '^[[:space:]]*error stop' "$LEDGER" || fail 'batch-fatal error stop remains'
grep -Fq 'owner_instance_id' "$LEDGER" || fail 'explicit owner argument absent'
grep -Fq 'prepared%owner_instance_id /= self%prepared_owner_instance_id' "$LEDGER" || fail 'owner provenance guard absent'
grep -Fq 'unique among simultaneously live logical ledger owners' "$LEDGER" || fail 'runtime uniqueness obligation undocumented'
! grep -Eiq '^[[:space:]]*save\b|atomic_|random_number|system_clock' "$LEDGER" || fail 'hidden/global owner identity mechanism detected'
echo 'FVQ84_EXPLICIT_OWNER_CONTRACT_STATIC=PASS'

STRICT=(-std=f2008 -Wall -Wextra -Werror -ffree-line-length-none -fcheck=all -fbacktrace)
BASE=(-std=f2008 -Wall -Wextra -Werror -Wno-error=compare-reals -ffree-line-length-none -fcheck=all -fbacktrace)
BASE_MODULES=(src/transaction/mod_transaction_reference.f90 src/runtime/mod_canonical_contracts.f90 src/runtime/mod_canonical_interval_runtime.f90 src/kernel/mod_kernel_transactions.f90 src/runtime/mod_fmr_accepted_commit_receipt.f90)

compile_oracle(){
  local opt="$1" out="$2" module_src obj
  mkdir -p "$out"; local objects=()
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
  gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c tests/fvq/test_fvq84_explicit_owner_identity_independent.f90 -o "$out/test.o"
  gfortran -O"$opt" "${objects[@]}" "$out/model.o" "$out/test.o" -o "$out/test"
  "$out/test" > "$out/out.txt"
}

compile_oracle 0 "$BUILD/o0"
compile_oracle 2 "$BUILD/o2"
cmp "$BUILD/o0/out.txt" "$BUILD/o2/out.txt" || fail 'O0/O2 independent oracle differs'
echo 'FVQ84_ORACLE_O0_O2_IDENTITY=PASS'
cat "$BUILD/o0/out.txt"

for marker in \
  'FVQ84_INVALID_OWNER_ID_FAIL_CLOSED=PASS' \
  'FVQ84_DISTINCT_OWNER_FOREIGN_ABORT_FAIL_CLOSED=PASS' \
  'FVQ84_DISTINCT_OWNER_FOREIGN_COMMIT_FAIL_CLOSED=PASS' \
  'FVQ84_VALID_OWNER_COMMIT_EXACTLY_OWN_LEDGER=PASS' \
  'FVQ84_VALID_OWNER_ABORT_EXACTLY_OWN_LEDGER=PASS' \
  'FVQ84_DUPLICATE_OWNER_ID_ALIAS_OBSERVED=EXPECTED_CALLER_CONTRACT_VIOLATION' \
  'FVQ84_LEDGER_MODULE_CONTRACT=PASS_WITH_RUNTIME_UNIQUENESS_OBLIGATION' \
  'FVQ84_INDEPENDENT_ORACLE=PASS'; do
  grep -Fq "$marker" "$BUILD/o0/out.txt" || fail "missing marker: $marker"
done
echo 'FVQ84_LEDGER_OWNER_ISOLATION=PASS'
echo 'FVQ84_RUNTIME_OWNER_UNIQUENESS_OBLIGATION=EXPLICIT_NOT_QUALIFIED_HERE'

FVQ67_TAG=fvq84 bash tests/fvq/run_fvq67_mass_completeness_independent.sh > "$BUILD/mass.txt"
grep -Fq 'FVQ67_FVQ84_O0=PASS' "$BUILD/mass.txt" || fail 'F-KT18 mass O0 preservation missing'
grep -Fq 'FVQ67_FVQ84_O2=PASS' "$BUILD/mass.txt" || fail 'F-KT18 mass O2 preservation missing'
grep -Fq 'FVQ67_FVQ84_O0_O2_IDENTITY=PASS' "$BUILD/mass.txt" || fail 'F-KT18 mass O0/O2 preservation missing'
grep -Fq 'FVQ67_REJECTED_COMMITTED_STATE_BITWISE_IMMUTABLE=PASS' "$BUILD/mass.txt" || fail 'F-KT18 rejected-state immutability missing'
echo 'FVQ84_FKT18_MASS_PRESERVATION=PASS'

git diff --check "$OWNER..HEAD"
echo 'FVQ84_INDEPENDENT_QUALIFICATION=QUALIFIED_LEDGER_CONTRACT_PENDING_RUNTIME_OWNER_BINDING'
echo 'FVQ84_CANONICAL_ADMISSION=NOT_AUTHORIZED_BY_THIS_VERIFIER'
