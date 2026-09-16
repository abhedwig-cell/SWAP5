#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

OLD_CANONICAL=d201904a85f3b595e028242978e52c02f5122a09
PROMOTED=536042620038014057427a7915c212a3ac78f84d
FCI44=b7996d73845588368aba93bdbb85374e07b97bd7
PROMOTED_TREE=e928582d868298156ad0d3b949d6ef6622ec6b6f
REFERENCE_TREE=9d08625217d7c0a7385df9da6a04183bcd9cb9e6
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
FCI44_EVIDENCE_BLOB=68e45bea3667a726330f58d1550bb18de9aa4ff7
FCI44_STATUS_BLOB=35670302f5bc4e8b9710c3921c304d26fea8a5ad
FCI44_AUDIT_BLOB=8b2187f7853859ade3815e3677ed2cdf6e50cb77
TEST=tests/fci/test_fci44_application_accuracy_contract_admission.f90
BUILD="${RUNNER_TEMP:-/tmp}/fci44p-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD/o0" "$BUILD/o2"

fail() { echo "FCI44P_GATE_FAIL $*" >&2; exit 45; }
need_commit() {
  local sha="$1"
  git cat-file -e "${sha}^{commit}" 2>/dev/null || git fetch --no-tags origin "$sha" >/dev/null 2>&1 || fail "cannot fetch $sha"
}
for sha in "$OLD_CANONICAL" "$PROMOTED" "$FCI44"; do need_commit "$sha"; done

# Reconciliation is source-bound to the exact promoted canonical postimage.
git fetch --no-tags origin integration/f-ci-canonical >/dev/null 2>&1 || fail 'cannot fetch canonical'
CANONICAL_HEAD="$(git rev-parse origin/integration/f-ci-canonical)"
[[ "$CANONICAL_HEAD" == "$PROMOTED" ]] || fail "canonical moved during reconciliation: expected $PROMOTED got $CANONICAL_HEAD"
test "$(git rev-parse ${PROMOTED}^{tree})" = "$PROMOTED_TREE" || fail 'promoted canonical tree drift'
test "$(git rev-parse ${PROMOTED}:reference)" = "$REFERENCE_TREE" || fail 'promoted reference tree drift'
echo 'FCI44P_CURRENT_CANONICAL_PIN=PASS'

# Promotion must be the declared true two-parent merge.
read -r merge p1 p2 extra <<<"$(git rev-list --parents -n1 "$PROMOTED")"
[[ "$merge" == "$PROMOTED" && "$p1" == "$OLD_CANONICAL" && "$p2" == "$FCI44" && -z "${extra:-}" ]] || \
  fail "promotion parent set invalid: $merge $p1 $p2 ${extra:-}"
echo 'FCI44P_TRUE_TWO_PARENT_PROMOTION=PASS'

# Scientific/production delta remains exactly the single qualified F-GC10 seam.
mapfile -t src_delta < <(git diff --name-only "$OLD_CANONICAL".."$PROMOTED" -- src)
[[ "${#src_delta[@]}" -eq 1 && "${src_delta[0]}" == "$MODULE" ]] || fail "unexpected promoted src delta: ${src_delta[*]:-none}"
test "$(git rev-parse ${PROMOTED}:$MODULE)" = "$MODULE_BLOB" || fail 'promoted module blob drift'
test "$(git rev-parse HEAD:$MODULE)" = "$MODULE_BLOB" || fail 'reconciliation branch changed module blob'
git diff --quiet "$PROMOTED"..HEAD -- src || fail 'F-CI44P changed production source'
git diff --quiet "$PROMOTED"..HEAD -- reference || fail 'F-CI44P changed frozen reference source'
echo 'FCI44P_EXACT_ONE_BLOB_PROMOTED_SOURCE_SCOPE=PASS'
echo 'FCI44P_NO_PRODUCTION_OR_REFERENCE_DELTA=PASS'

# F-CI44 evidence and admission authority must be present byte-identically in the promoted postimage.
test "$(git rev-parse ${PROMOTED}:integration/f-ci/F-CI44_EVIDENCE.json)" = "$FCI44_EVIDENCE_BLOB" || fail 'F-CI44 evidence drift'
test "$(git rev-parse ${PROMOTED}:integration/f-ci/F-CI44_STATUS.json)" = "$FCI44_STATUS_BLOB" || fail 'F-CI44 status drift'
test "$(git rev-parse ${PROMOTED}:integration/f-ci/F-CI44_ARCHITECTURE_AUDIT.json)" = "$FCI44_AUDIT_BLOB" || fail 'F-CI44 architecture audit drift'
git show ${PROMOTED}:integration/f-ci/F-CI44_STATUS.json | grep -Fq 'QUALIFIED_FGC10_APPLICATION_ACCURACY_CONTRACT_FOR_CURRENT_CANONICAL_ADMISSION' || fail 'F-CI44 decision missing'
echo 'FCI44P_FCI44_AUTHORITY_PRESERVED=PASS'

# Consumer semantics remain exactly the postimage qualified by F-GC10/F-CI44.
test "$(git rev-parse ${PROMOTED}:$CANONICAL_CONTRACTS)" = "$CANONICAL_CONTRACTS_BLOB" || fail 'canonical contracts drift'
test "$(git rev-parse ${PROMOTED}:$TRANSACTION)" = "$TRANSACTION_BLOB" || fail 'transaction core drift'
test "$(git rev-parse ${PROMOTED}:$BACKEND)" = "$BACKEND_BLOB" || fail 'serialized backend drift'
test "$(git rev-parse ${PROMOTED}:$INDICATOR)" = "$INDICATOR_BLOB" || fail 'Richards indicator drift'
grep -Fq 'self%temporal_indicator_budget_supplied = config%model_temporal_indicator_budget_available' "$BACKEND" || fail 'budget availability binding missing'
grep -Fq 'self%temporal_indicator_budget = config%model_temporal_indicator_budget' "$BACKEND" || fail 'budget value binding missing'
grep -Fq 'normalized_indicator = indicator_result%head_inf_bound / self%temporal_indicator_budget' "$BACKEND" || fail 'head-domain normalization missing'
grep -Fq 'outcome%temporal_indicator = normalized_indicator' "$BACKEND" || fail 'dimensionless certificate transfer missing'
echo 'FCI44P_CONSUMER_BINDING_PRESERVED=PASS'
echo 'FCI44P_DIMENSIONLESS_CERTIFICATE_PATH_PRESERVED=PASS'

# Branch-local reconciliation may add only F-CI44P tests/workflow/integration metadata.
mapfile -t branch_delta < <(git diff --name-only "$PROMOTED"..HEAD | sort)
for path in "${branch_delta[@]}"; do
  case "$path" in
    tests/fci/run_fci44p_current_canonical_postimage_reconciliation.sh|\
    .github/workflows/fci44p-current-canonical-postimage-reconciliation.yml|\
    integration/f-ci/F-CI44P_*.json) ;;
    *) fail "unexpected F-CI44P branch delta: $path" ;;
  esac
done
echo 'FCI44P_RECONCILIATION_SCOPE=PASS'

git diff --check "$PROMOTED" -- tests/fci integration/f-ci .github/workflows || fail 'diff check failed'
echo 'FCI44P_DIFF_CHECK=PASS'

# Replay the admitted contract behavior on the promoted current-canonical source postimage.
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
compile_and_run() {
  local opt="$1" dir="$2"
  gfortran "${COMMON[@]}" "$opt" -J "$dir" -I "$dir" -c "$TRANSACTION" -o "$dir/transaction.o"
  gfortran "${COMMON[@]}" "$opt" -J "$dir" -I "$dir" -c "$CANONICAL_CONTRACTS" -o "$dir/contracts.o"
  gfortran "${COMMON[@]}" -Werror "$opt" -J "$dir" -I "$dir" -c "$MODULE" -o "$dir/application_contract.o"
  gfortran "${COMMON[@]}" -Werror "$opt" -J "$dir" -I "$dir" -c "$TEST" -o "$dir/test.o"
  gfortran "$opt" "$dir/transaction.o" "$dir/contracts.o" "$dir/application_contract.o" "$dir/test.o" -o "$dir/fci44p.exe"
  "$dir/fci44p.exe" > "$dir/output.txt"
  "$dir/fci44p.exe" > "$dir/output-repeat.txt"
  cmp "$dir/output.txt" "$dir/output-repeat.txt" || fail "repeated-run nondeterminism $opt"
}
compile_and_run -O0 "$BUILD/o0"
compile_and_run -O2 "$BUILD/o2"
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || fail 'O0/O2 output drift'
cat "$BUILD/o0/output.txt"
echo 'FCI44P_REPEATED_RUN_DETERMINISM_O0_O2=PASS'
echo 'FCI44P_NUMERIC_H_APP=NOT_SET'
echo 'FCI44P_NUMERIC_A_TEMPORAL=NOT_SET'
echo 'FCI44P_APPLICATION_CLASS_ACCURACY=NOT_QUALIFIED'
echo 'FCI44P_PRODUCTION_SWAP_MODFLOW_ADMISSION=NOT_MADE'
echo 'FCI44P_MASS_CONSERVATION_RELAXED=NO'
echo 'FCI44P_POSTIMAGE_RECONCILIATION_GATE=PASS'
