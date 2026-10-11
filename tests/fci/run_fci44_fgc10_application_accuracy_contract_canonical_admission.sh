#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=d201904a85f3b595e028242978e52c02f5122a09
BASE_TREE=e2045ccb17092d60cf266b98124ad6171c088b96
BASE_REF=9d08625217d7c0a7385df9da6a04183bcd9cb9e6
COMPOSITION=2c2c1f3ef00b467284e480d8b39b399523e3fc83
COMPOSITION_TREE=28767f0fb6cb9513ebc7e2aeeba7eb6111076ceb
FGC10=a1201dc870e4f5088f50b8d00e92e83457743174
FGC10_CLOSEOUT_BLOB=5fb26cbf003721791f38bbc7b78f5073886645c4
MODULE=src/runtime/mod_coupling_application_accuracy_contract.f90
MODULE_BLOB=c07d573d21e7d013ab962c0a9d28102ab7b5cdfc
CANONICAL_CONTRACTS=src/runtime/mod_canonical_contracts.f90
CANONICAL_CONTRACTS_BLOB=c06aa869a0bd479df4c7d6e1d0b4f5c07a207144
TRANSACTION=src/transaction/mod_transaction_reference.f90
TRANSACTION_BLOB=2fd932b74dbd0ffc0ec089f49e632b7ac8852df4
BACKEND=src/runtime/mod_fmr_serialized_reference_backend.f90
BACKEND_BLOB=9af5a494526810324dc00706b444e448e770cba9
INDICATOR=src/solver/mod_reference_richards_temporal_indicator.f90
INDICATOR_BLOB=fe8f87d11257d4c6bc019f1d628ac41ba3106d4e
TEST=tests/fci/test_fci44_application_accuracy_contract_admission.f90
BUILD="${RUNNER_TEMP:-/tmp}/fci44-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD/o0" "$BUILD/o2"

fail() { echo "FCI44_GATE_FAIL $*" >&2; exit 44; }
need_commit() {
  local sha="$1"
  git cat-file -e "${sha}^{commit}" 2>/dev/null || git fetch --no-tags origin "$sha" >/dev/null 2>&1 || fail "cannot fetch $sha"
}
for sha in "$BASE" "$COMPOSITION" "$FGC10"; do need_commit "$sha"; done

# Admission is valid only while the exact current canonical base is still current.
git fetch --no-tags origin integration/f-ci-canonical >/dev/null 2>&1 || fail 'cannot fetch canonical'
CANONICAL_HEAD="$(git rev-parse origin/integration/f-ci-canonical)"
[[ "$CANONICAL_HEAD" == "$BASE" ]] || fail "canonical race: expected $BASE got $CANONICAL_HEAD"
test "$(git rev-parse ${BASE}^{tree})" = "$BASE_TREE" || fail 'canonical base tree drift'
test "$(git rev-parse ${BASE}:reference)" = "$BASE_REF" || fail 'canonical reference tree drift'
echo 'FCI44_PREPROMOTION_CANONICAL_RACE_GUARD=PASS'

# Composition is a direct one-source-blob child of current canonical.
test "$(git rev-parse ${COMPOSITION}^)" = "$BASE" || fail 'composition is not direct child of canonical base'
test "$(git rev-parse ${COMPOSITION}^{tree})" = "$COMPOSITION_TREE" || fail 'composition tree drift'
test "$(git rev-parse ${COMPOSITION}:$MODULE)" = "$MODULE_BLOB" || fail 'composition module blob drift'
test "$(git rev-parse HEAD:$MODULE)" = "$MODULE_BLOB" || fail 'qualification governance changed admitted module'
git diff --quiet "$COMPOSITION"..HEAD -- src || fail 'post-composition qualification changed production source'
mapfile -t delta < <(git diff --name-only "$BASE".."$COMPOSITION" -- src)
[[ "${#delta[@]}" -eq 1 && "${delta[0]}" == "$MODULE" ]] || fail "unexpected production delta: ${delta[*]:-none}"
test "$(git rev-parse HEAD:reference)" = "$BASE_REF" || fail 'reference tree changed'
echo 'FCI44_EXACT_ONE_BLOB_PRODUCTION_SCOPE=PASS'
echo 'FCI44_REFERENCE_IMMUTABLE=PASS'

# F-GC10 is the immutable donor/admission-review authority.
test "$(git rev-parse ${FGC10}:$MODULE)" = "$MODULE_BLOB" || fail 'F-GC10 module donor drift'
test "$(git rev-parse ${FGC10}:integration/f-gc/F-GC10_CLOSEOUT.json)" = "$FGC10_CLOSEOUT_BLOB" || fail 'F-GC10 closeout blob drift'
git show ${FGC10}:integration/f-gc/F-GC10_CLOSEOUT.json | grep -Fq 'QUALIFIED_F_GC09_APPLICATION_ACCURACY_CONTRACT_FOR_CANONICAL_ADMISSION_WITH_EXPLICIT_TEMPORAL_INDICATOR_BINDING' || fail 'F-GC10 qualified decision missing'
git show ${FGC10}:integration/f-gc/F-GC10_CLOSEOUT.json | grep -Fq '"production_coupling_admission": false' || fail 'F-GC10 production coupling hold missing'
git show ${FGC10}:integration/f-gc/F-GC10_CLOSEOUT.json | grep -Fq '"numeric_policy_qualified": false' || fail 'F-GC10 numeric policy hold missing'
git show ${FGC10}:integration/f-gc/F-GC10_CLOSEOUT.json | grep -Fq '"mass_conservation_relaxed": false' || fail 'F-GC10 mass hold missing'
echo 'FCI44_FGC10_AUTHORITY_PINNED=PASS'

# Current canonical consumers must be exactly the postimage qualified by F-GC10.
test "$(git rev-parse HEAD:$CANONICAL_CONTRACTS)" = "$CANONICAL_CONTRACTS_BLOB" || fail 'canonical contract blob drift'
test "$(git rev-parse HEAD:$TRANSACTION)" = "$TRANSACTION_BLOB" || fail 'transaction core blob drift'
test "$(git rev-parse HEAD:$BACKEND)" = "$BACKEND_BLOB" || fail 'serialized reference backend blob drift'
test "$(git rev-parse HEAD:$INDICATOR)" = "$INDICATOR_BLOB" || fail 'Richards temporal indicator blob drift'
grep -Fq 'canonical runtime and F-KT transaction core deliberately do not attach' "$CANONICAL_CONTRACTS" || fail 'generic carrier semantics missing'
grep -Fq 'model owns that interpretation and must normalize its native indicator' "$CANONICAL_CONTRACTS" || fail 'model-owned normalization contract missing'
grep -Fq 'self%temporal_indicator_budget_supplied = config%model_temporal_indicator_budget_available' "$BACKEND" || fail 'budget availability binding missing'
grep -Fq 'self%temporal_indicator_budget = config%model_temporal_indicator_budget' "$BACKEND" || fail 'budget value binding missing'
grep -Fq 'self%last_observation%temporal_head_budget = self%temporal_indicator_budget' "$BACKEND" || fail 'native head-budget diagnostic binding missing'
grep -Fq 'normalized_indicator = indicator_result%head_inf_bound / self%temporal_indicator_budget' "$BACKEND" || fail 'native-head budget normalization missing'
grep -Fq 'outcome%temporal_indicator = normalized_indicator' "$BACKEND" || fail 'dimensionless certificate transfer missing'
grep -Fq 'indicator_result%head_inf_bound = bounded_norm/sqrt(indicator_result%min_mass_weight)' "$INDICATOR" || fail 'native Richards head indicator construction missing'
echo 'FCI44_CURRENT_CANONICAL_CONSUMER_BINDING=PASS'
echo 'FCI44_DIMENSIONLESS_CERTIFICATE_NORMALIZATION=PASS'

# The admitted seam remains runtime/coupler policy only: no I/O, hidden positive
# policy, physical-state ownership, solver internals or mass-tolerance tradeoff.
if grep -Eiq '(^|[^[:alnum:]_])(open|read|write|close)[[:space:]]*\(' "$MODULE"; then
  fail 'application contract contains file I/O'
fi
if grep -Eq 'use[[:space:]]+mod_(kernel|transaction|soil_water|reference_richards)' "$MODULE"; then
  fail 'application contract depends on kernel/solver/transaction internals'
fi
grep -Fq 'logical :: h_app_available = .false.' "$MODULE" || fail 'H_app absence default changed'
grep -Fq 'real(real64) :: h_app_cm = 0.0_real64' "$MODULE" || fail 'H_app scalar default changed'
grep -Fq 'logical :: a_temporal_available = .false.' "$MODULE" || fail 'A_temporal absence default changed'
grep -Fq 'real(real64) :: a_temporal = 0.0_real64' "$MODULE" || fail 'A_temporal scalar default changed'
grep -Fq 'if (.not. self%h_app_externally_qualified) return' "$MODULE" || fail 'H_app qualification guard missing'
grep -Fq 'if (.not. self%a_temporal_externally_qualified) return' "$MODULE" || fail 'A_temporal qualification guard missing'
grep -Fq 'if (self%a_temporal > 1.0_real64) return' "$MODULE" || fail 'A_temporal upper bound missing'
grep -Fq 'config%model_temporal_indicator_budget_available = .false.' "$MODULE" || fail 'stale availability clearing missing'
grep -Fq 'config%model_temporal_indicator_budget = 0.0_real64' "$MODULE" || fail 'stale value clearing missing'
echo 'FCI44_NO_IO_OR_HIDDEN_NUMERIC_POLICY=PASS'
echo 'FCI44_FAIL_CLOSED_AND_STALE_CLEARING=PASS'

git diff --check "$BASE" -- src tests/fci integration/f-ci .github/workflows || fail 'diff check failed'
echo 'FCI44_DIFF_CHECK=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
compile_and_run() {
  local opt="$1" dir="$2"
  gfortran "${COMMON[@]}" "$opt" -J "$dir" -I "$dir" -c "$TRANSACTION" -o "$dir/transaction.o"
  gfortran "${COMMON[@]}" "$opt" -J "$dir" -I "$dir" -c "$CANONICAL_CONTRACTS" -o "$dir/contracts.o"
  gfortran "${COMMON[@]}" -Werror "$opt" -J "$dir" -I "$dir" -c "$MODULE" -o "$dir/application_contract.o"
  gfortran "${COMMON[@]}" -Werror "$opt" -J "$dir" -I "$dir" -c "$TEST" -o "$dir/test.o"
  gfortran "$opt" "$dir/transaction.o" "$dir/contracts.o" "$dir/application_contract.o" "$dir/test.o" -o "$dir/fci44.exe"
  "$dir/fci44.exe" > "$dir/output.txt"
  "$dir/fci44.exe" > "$dir/output-repeat.txt"
  cmp "$dir/output.txt" "$dir/output-repeat.txt" || fail "repeated-run nondeterminism $opt"
}

compile_and_run -O0 "$BUILD/o0"
compile_and_run -O2 "$BUILD/o2"
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || fail 'O0/O2 output drift'
cat "$BUILD/o0/output.txt"
echo 'FCI44_REPEATED_RUN_DETERMINISM_O0_O2=PASS'
echo 'FCI44_NUMERIC_H_APP=NOT_SET'
echo 'FCI44_NUMERIC_A_TEMPORAL=NOT_SET'
echo 'FCI44_APPLICATION_CLASS_ACCURACY=NOT_QUALIFIED'
echo 'FCI44_PRODUCTION_SWAP_MODFLOW_ADMISSION=NOT_MADE'
echo 'FCI44_MASS_CONSERVATION_RELAXED=NO'
echo 'FCI44_CANONICAL_ADMISSION_GATE=PASS'
