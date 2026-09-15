#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fci64p-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail(){ echo "FCI64P_POSTIMAGE_GATE_FAIL $*" >&2; exit 264; }

PRE="b162e98cc4ad6f85b741a21bd41f3db3d213559b"
ADMISSION="a7d8cff4719194c9ea2770902f1713649f59483f"
POSTIMAGE="52d66ba612096184327f58a076ef22bd0119e237"
OWNER="5d6cea2e6de577fb0267008b2a391770b5bd7a10"
VQ85="f0a6d6f83cda86706bec58d2d3557ade1e6b9eaa"
OLD_MOVING_AUTH="e16262d0d9af3c83f40234ab669f0faa66e12519"
STATUS="integration/f-ci/F-CI64P_STATUS.json"
CANONICAL_WORKFLOW=".github/workflows/fci-canonical.yml"

declare -A BLOBS=(
  [src/kernel/mod_energy_conservation_types.f90]=15a6a9c5c5da6ad0d535c27772e57a23e618658d
  [src/runtime/mod_energy_conservation_ledger.f90]=cc166e82e51d8e0738fee51b4517626d0a2e890f
  [src/runtime/mod_fmr_owned_commit_receipt.f90]=2ab067d160715ff7358dd31efaa12694ef95852c
  [src/runtime/mod_fmr_serialized_multiswap_runtime.f90]=1aa2454048d0e480becaee34f596f20f1a7bd66e
)

for object in "$PRE" "$ADMISSION" "$POSTIMAGE" "$OWNER" "$VQ85"; do
  git cat-file -e "$object^{commit}" || fail "missing authority $object"
done
[[ "$(git rev-parse "$POSTIMAGE^1")" == "$PRE" ]] || fail 'postimage first parent mismatch'
[[ "$(git rev-parse "$POSTIMAGE^2")" == "$ADMISSION" ]] || fail 'postimage second parent mismatch'
[[ "$(git rev-list --parents -n1 "$POSTIMAGE" | awk '{print NF-1}')" -eq 2 ]] || fail 'F-CI64 admission is not a true two-parent merge'
[[ "$(git rev-parse "$POSTIMAGE^{tree}")" == "$(git rev-parse "$ADMISSION^{tree}")" ]] || fail 'promoted tree differs from exact final green F-CI64 tree'
git merge-base --is-ancestor "$POSTIMAGE" HEAD || fail 'reconciliation not descended from admitted postimage'
LIVE="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$LIVE" == "$POSTIMAGE" ]] || fail "live canonical drift expected=$POSTIMAGE actual=$LIVE"
echo 'FCI64P_TRUE_TWO_PARENT_PROMOTION_AND_LIVE_POSTIMAGE_LOCK=PASS'

for path in "${!BLOBS[@]}"; do
  blob="${BLOBS[$path]}"
  [[ "$(git rev-parse "$POSTIMAGE:$path")" == "$blob" ]] || fail "postimage blob mismatch $path"
  [[ "$(git rev-parse "$VQ85:$path")" == "$blob" ]] || fail "F-VQ85 authority blob mismatch $path"
  [[ "$(git rev-parse "HEAD:$path")" == "$blob" ]] || fail "reconciliation source drift $path"
done
[[ -z "$(git diff --name-only "$POSTIMAGE..HEAD" -- src reference)" ]] || fail 'F-CI64P changes production/reference source'
echo 'FCI64P_EXACT_FOUR_CANONICAL_POSTIMAGE_BLOBS=PASS'

allowed=(
  integration/f-ci/F-CI64P_STATUS.json
  tests/fci/run_fci64p_current_canonical_postimage_reconciliation.sh
  .github/workflows/fci64p-current-canonical-postimage-reconciliation.yml
  .github/workflows/fci64p-materialize-moving-current.yml
  .github/workflows/fci-canonical.yml
)
mapfile -t changed < <(git diff --name-only "$POSTIMAGE..HEAD")
for path in "${changed[@]}"; do
  ok=0
  for candidate in "${allowed[@]}"; do
    [[ "$path" == "$candidate" ]] && ok=1 && break
  done
  [[ "$ok" -eq 1 ]] || fail "unexpected reconciliation path: $path"
done
echo 'FCI64P_RECONCILIATION_SCOPE_ALLOWLIST=PASS'

grep -Fq "AUTH=$POSTIMAGE" "$CANONICAL_WORKFLOW" || fail 'moving-current authority not advanced to F-CI64 postimage'
if grep -Fq "AUTH=$OLD_MOVING_AUTH" "$CANONICAL_WORKFLOW"; then
  fail 'stale F-CI63 moving-current authority remains active'
fi
for path in "${!BLOBS[@]}"; do
  grep -Fq "$path" "$CANONICAL_WORKFLOW" || fail "F-CI64 source absent from moving dependency surface: $path"
done
grep -Fq 'FCI63_MOVING_BOTTOM_ENERGY_PUBLICATION_PRESERVATION=PASS' "$CANONICAL_WORKFLOW" || fail 'F-CI63 moving preservation marker lost'
grep -Fq 'FCI64_MOVING_ENERGY_LEDGER_OWNED_RECEIPT_PRESERVATION=PASS' "$CANONICAL_WORKFLOW" || fail 'F-CI64 moving preservation marker absent'
grep -Fq 'FCI62_MOVING_PRESCRIBED_QBOT_TEMPORAL_RUNTIME_PRESERVATION=PASS' "$CANONICAL_WORKFLOW" || fail 'F-CI62 moving preservation marker lost'
echo 'FCI64P_MOVING_CURRENT_AUTHORITY_RECONCILIATION=PASS'

python3 - "$ADMISSION" "$VQ85" "$STATUS" <<'PY'
import json, pathlib, subprocess, sys
admission, vq, status_path = sys.argv[1:]
def at(commit, path):
    return json.loads(subprocess.check_output(['git','show',f'{commit}:{path}'], text=True))
a = at(admission, 'integration/f-ci/F-CI64_STATUS.json')
v = at(vq, 'qualification/F-VQ85_STATUS.json')
assert a['decision'] == 'QUALIFIED_F_CI64_READY_FOR_CANONICAL_PROMOTION'
assert a['ready_for_canonical_promotion'] is True
assert a['canonical_admission'] is False
assert a['postimage_reconciled'] is False
assert a['architecture_invariants'] == '30_OF_30_NO_ADVERSE_ADMISSION_DELTA'
assert a['qualification_evidence']['independent_cross_column_receipt_attack'] == 'PASS'
assert a['qualification_evidence']['FMR44R_prescribed_qbot_and_mass_preserved'] == 'PASS'
assert a['qualification_evidence']['O0_O2_semantic_identity'] == 'PASS'
assert v['status'] == 'QUALIFIED_INDEPENDENT_EVIDENCE_NOT_CANONICAL_ADMISSION'
assert v['workflow']['conclusion'] == 'success'
assert v['decision'] == 'QUALIFIED_FOR_F_CI_ADMISSION_REVIEW'
assert v['unchanged_generic_contracts']['generic_receipt_owner_identity_added'] is False
assert v['unchanged_generic_contracts']['kernel_transaction_source_changed_from_canonical'] is False
if pathlib.Path(status_path).exists():
    s = json.loads(pathlib.Path(status_path).read_text())
    assert s['decision'] == 'QUALIFIED_F_CI64P_CURRENT_CANONICAL_POSTIMAGE_RECONCILIATION'
    assert s['production_canonical_admitted'] is True
    assert s['postimage_reconciled'] is True
    assert s['moving_current_preservation_reconciled'] is True
    assert s['full_energy_balance_complete'] is False
print('FCI64P_FCI64_AND_FVQ85_AUTHORITY_RECONCILIATION=PASS')
PY

# Recompile the independent ownership attack against the actual promoted source.
STRICT=(-std=f2008 -Wall -Wextra -Werror -ffree-line-length-none -fcheck=all -fbacktrace)
BASE=(-std=f2008 -Wall -Wextra -Werror -Wno-error=compare-reals -ffree-line-length-none -fcheck=all -fbacktrace)
BASE_MODULES=(
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
)
compile_attack(){
  local opt="$1" out="$2" src obj
  mkdir -p "$out"; local objects=()
  for src in "${BASE_MODULES[@]}"; do
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${BASE[@]}" -O"$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  for src in src/runtime/mod_fmr_owned_commit_receipt.f90 src/kernel/mod_energy_conservation_types.f90 src/runtime/mod_energy_conservation_ledger.f90; do
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c tests/fvq/mod_fvq84_receipt_model.f90 -o "$out/model.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c tests/fvq/test_fvq85_runtime_owned_receipt_independent.f90 -o "$out/test.o"
  gfortran -O"$opt" "${objects[@]}" "$out/model.o" "$out/test.o" -o "$out/test"
  "$out/test" > "$out/out.txt"
}
compile_attack 0 "$BUILD/attack-o0"
compile_attack 2 "$BUILD/attack-o2"
cmp -s "$BUILD/attack-o0/out.txt" "$BUILD/attack-o2/out.txt" || fail 'receipt attack O0/O2 semantic drift'
cat "$BUILD/attack-o0/out.txt"
for marker in \
  'FVQ85_INVALID_OWNER_PRECOMMIT_FAIL_CLOSED=PASS' \
  'FVQ85_REAL_COLUMNS_SCALAR_RECEIPT_ALIAS_REPRODUCED=PASS' \
  'FVQ85_GENERIC_RECEIPT_EXPORT_COMPATIBILITY=PASS' \
  'FVQ85_FOREIGN_COLUMN_RECEIPT_FAIL_CLOSED=PASS' \
  'FVQ85_RIGHTFUL_OWNER_COMMIT_EXACTLY_ONCE=PASS' \
  'FVQ85_RUNTIME_OWNED_RECEIPT_INDEPENDENT_ORACLE=PASS'; do
  grep -Fq "$marker" "$BUILD/attack-o0/out.txt" || fail "missing postimage receipt marker: $marker"
done
echo 'FCI64P_INDEPENDENT_PROMOTED_RECEIPT_ATTACK_O0_O2=PASS'

# The promoted tree is byte-identical to the exact final green admission tree,
# so the admission preservation evidence applies to the canonical postimage.
[[ "$(git rev-parse "$POSTIMAGE^{tree}")" == "426291c690546ab5faaa96e1498e991372f2c3e7" ]] || fail 'unexpected promoted tree'
[[ "$(git rev-parse "$ADMISSION^{tree}")" == "426291c690546ab5faaa96e1498e991372f2c3e7" ]] || fail 'unexpected admission tree'
echo 'FCI64P_PROMOTED_TREE_EQUALS_GREEN_ADMISSION_TREE=PASS'

git diff --quiet -- src reference || fail 'postimage reconciliation mutated production/reference source'
git diff --check "$POSTIMAGE..HEAD"
echo "FCI64P_EXACT_HEAD=$(git rev-parse HEAD)"
echo 'F-CI64P CURRENT-CANONICAL POSTIMAGE RECONCILIATION GATE PASS'
