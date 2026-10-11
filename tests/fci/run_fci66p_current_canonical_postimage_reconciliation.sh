#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fci66p-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail(){ echo "FCI66P_POSTIMAGE_GATE_FAIL $*" >&2; exit 166; }

PRE="d44b2eb48e7187f8ddc622a5f2329d7a24c24aa0"
ADMISSION="cabed28c6b9996666df1dc39ce34758177745f3f"
POSTIMAGE="87893112dd9bfb9e37f48a2f851b85e6f23b9951"
POSTIMAGE_TREE="43b17ed75d38b3f5f9f5ab3e6196496a73580d07"
RUNTIME_BLOB="b12327aa6e77bdbf4586fe0bed82cf0e7704f237"
TX_BLOB="d5a71a526efaebd82054580c3186f8e3545db331"
CONTRACTS_BLOB="3cbb81b25626e6574ae83416f088dc52882f91fc"
CANONICAL_WORKFLOW=".github/workflows/fci-canonical.yml"
STATUS="integration/f-ci/F-CI66P_STATUS.json"

for object in "$PRE" "$ADMISSION" "$POSTIMAGE"; do
  git cat-file -e "$object^{commit}" || fail "missing authority $object"
done
[[ "$(git rev-parse "$POSTIMAGE^1")" == "$PRE" ]] || fail 'postimage first parent mismatch'
[[ "$(git rev-parse "$POSTIMAGE^2")" == "$ADMISSION" ]] || fail 'postimage second parent mismatch'
[[ "$(git rev-list --parents -n1 "$POSTIMAGE" | awk '{print NF-1}')" -eq 2 ]] || fail 'F-CI66 promotion is not a true two-parent merge'
[[ "$(git rev-parse "$POSTIMAGE^{tree}")" == "$POSTIMAGE_TREE" ]] || fail 'postimage tree mismatch'
[[ "$(git rev-parse "$ADMISSION^{tree}")" == "$POSTIMAGE_TREE" ]] || fail 'promoted tree differs from exact final green F-CI66 tree'
git merge-base --is-ancestor "$POSTIMAGE" HEAD || fail 'reconciliation is not descended from admitted postimage'
LIVE="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$LIVE" == "$POSTIMAGE" ]] || fail "live canonical drift expected=$POSTIMAGE actual=$LIVE"
echo 'FCI66P_TRUE_TWO_PARENT_PROMOTION_AND_LIVE_POSTIMAGE_LOCK=PASS'

[[ "$(git rev-parse "$POSTIMAGE:src/runtime/mod_canonical_interval_runtime.f90")" == "$RUNTIME_BLOB" ]] || fail 'admitted runtime blob mismatch'
[[ "$(git rev-parse "HEAD:src/runtime/mod_canonical_interval_runtime.f90")" == "$RUNTIME_BLOB" ]] || fail 'reconciliation runtime drift'
[[ "$(git rev-parse "HEAD:src/transaction/mod_transaction_reference.f90")" == "$TX_BLOB" ]] || fail 'transaction source drift'
[[ "$(git rev-parse "HEAD:src/runtime/mod_canonical_contracts.f90")" == "$CONTRACTS_BLOB" ]] || fail 'canonical contracts drift'
[[ -z "$(git diff --name-only "$POSTIMAGE..HEAD" -- src reference)" ]] || fail 'F-CI66P changes production/reference source'
echo 'FCI66P_EXACT_CANONICAL_RUNTIME_POSTIMAGE=PASS'

allowed=(
  .github/workflows/fci-canonical.yml
  .github/workflows/fci66p-current-canonical-postimage-reconciliation.yml
  integration/f-ci/F-CI66P_STATUS.json
  tests/fci/run_fci66p_current_canonical_postimage_reconciliation.sh
)
mapfile -t changed < <(git diff --name-only "$POSTIMAGE..HEAD")
for path in "${changed[@]}"; do
  ok=0
  for candidate in "${allowed[@]}"; do
    [[ "$path" == "$candidate" ]] && ok=1 && break
  done
  [[ "$ok" -eq 1 ]] || fail "unexpected reconciliation path: $path"
done
echo 'FCI66P_RECONCILIATION_SCOPE_ALLOWLIST=PASS'

python3 - "$POSTIMAGE" "$CANONICAL_WORKFLOW" <<'PY'
from pathlib import Path
import subprocess, sys
postimage, path = sys.argv[1:]
base = subprocess.check_output(['git','show',f'{postimage}:{path}'], text=True)
actual = Path(path).read_text()
old_auth = '          AUTH=24b02660a7924323d1587b4adf77a160c9ef7d04\n'
new_auth = '          AUTH=87893112dd9bfb9e37f48a2f851b85e6f23b9951\n'
assert base.count(old_auth) == 1
expected = base.replace(old_auth, new_auth, 1)
assert actual == expected, 'canonical workflow contains changes outside the exact F-CI66P authority advance'
print('FCI66P_EXACT_CANONICAL_WORKFLOW_TRANSFORMATION=PASS')
PY

grep -Fq "AUTH=$POSTIMAGE" "$CANONICAL_WORKFLOW" || fail 'moving-current authority not advanced to F-CI66 postimage'
! grep -Fq 'AUTH=24b02660a7924323d1587b4adf77a160c9ef7d04' "$CANONICAL_WORKFLOW" || fail 'stale F-CI65 moving-current authority remains active'
grep -Fq 'src/runtime/mod_canonical_interval_runtime.f90' "$CANONICAL_WORKFLOW" || fail 'canonical runtime absent from moving dependency surface'
echo 'FCI66P_MOVING_CURRENT_AUTHORITY_RECONCILIATION=PASS'

python3 - "$ADMISSION" "$STATUS" <<'PY'
import json, pathlib, subprocess, sys
admission, status_path = sys.argv[1:]
a=json.loads(subprocess.check_output(['git','show',f'{admission}:integration/f-ci/F-CI66_STATUS.json'], text=True))
assert a['decision']=='QUALIFIED_F_CI66_READY_FOR_CANONICAL_PROMOTION'
assert a['ready_for_canonical_promotion'] is True
assert a['canonical_admission'] is False
assert a['postimage_reconciled'] is False
assert a['moving_current_preservation_reconciled'] is False
assert a['production_postimage_candidate']['src/runtime/mod_canonical_interval_runtime.f90']=='b12327aa6e77bdbf4586fe0bed82cf0e7704f237'
if pathlib.Path(status_path).exists():
    s=json.loads(pathlib.Path(status_path).read_text())
    assert s['decision']=='QUALIFIED_F_CI66P_CURRENT_CANONICAL_POSTIMAGE_RECONCILIATION'
    assert s['production_canonical_admitted'] is True
    assert s['postimage_reconciled'] is True
    assert s['moving_current_preservation_reconciled'] is True
print('FCI66P_FCI66_AUTHORITY_RECONCILIATION=PASS')
PY

bash tests/fci/run_fci66_window_target_selector_current_canonical_admission.sh >"$BUILD/fci66.log" 2>&1 || { cat "$BUILD/fci66.log" >&2; fail 'F-CI66 promoted replay failed'; }
grep -Fq 'FCI66_WINDOW_TARGET_SELECTOR_GATE PASS' "$BUILD/fci66.log" || fail 'F-CI66 selector fixture pass marker missing'
grep -Fq 'FCI66_CURRENT_CANONICAL_SUBINTERVAL_EXECUTION_POLICY_ADMISSION=PASS' "$BUILD/fci66.log" || fail 'F-CI66 admission pass marker missing'
echo 'FCI66P_PROMOTED_FCI66_O0_O2_REPLAY=PASS'

git diff --quiet "$POSTIMAGE..HEAD" -- src reference || fail 'postimage reconciliation mutated production/reference source'
git diff --check "$POSTIMAGE..HEAD"
echo "FCI66P_EXACT_HEAD=$(git rev-parse HEAD)"
echo 'F-CI66P CURRENT-CANONICAL POSTIMAGE RECONCILIATION GATE PASS'
