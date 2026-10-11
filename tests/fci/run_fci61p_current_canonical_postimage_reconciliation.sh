#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

fail(){ echo "FCI61P_POSTIMAGE_GATE_FAIL $*" >&2; exit 161; }
PRE=e7b512cb4d7f400ed8e1d7aeb24f6dfe165ac557
COMPOSITION=c7444233b0f23d4f0a845ef5639287e77099291b
ADMISSION=0ac2f09642f71269ee43301cfedde4f2dd95ade6
POSTIMAGE=eb2b2b17b2d54eeab22c4cba922426d8168e56a9
OWNER=52c1a9aebddc435ef3792378f958305a96308ed0
VQ73=ea40e2d850aa9b4b23b25ba6b4a63ffd39811001
STATUS=integration/f-ci/F-CI61P_STATUS.json
CANONICAL_WORKFLOW=.github/workflows/fci-canonical.yml
OLD_WORKFLOW_BLOB=2f26be69f2a760027a880bbea6a8967336992f32
RECONCILED_WORKFLOW_BLOB=22b151d2ff2dd0d31924ccf2e989ec19e8f3ee0e

for object in "$PRE" "$COMPOSITION" "$ADMISSION" "$POSTIMAGE" "$OWNER" "$VQ73"; do git cat-file -e "$object^{commit}"; done
[[ "$(git rev-parse "$POSTIMAGE^1")" == "$PRE" ]] || fail 'postimage first parent is not frozen pre-admission canonical'
[[ "$(git rev-parse "$POSTIMAGE^2")" == "$ADMISSION" ]] || fail 'postimage second parent is not exact green F-CI61 admission head'
[[ "$(git rev-list --parents -n1 "$POSTIMAGE" | awk '{print NF-1}')" -eq 2 ]] || fail 'canonical admission is not a true two-parent merge'
git merge-base --is-ancestor "$COMPOSITION" "$POSTIMAGE" || fail 'qualified PM14 composition is not reachable from canonical postimage'
git merge-base --is-ancestor "$POSTIMAGE" HEAD || fail 'postimage qualification is not descended from admitted canonical postimage'
LIVE_CANONICAL="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$LIVE_CANONICAL" == "$POSTIMAGE" ]] || fail "live canonical drift expected=$POSTIMAGE actual=$LIVE_CANONICAL"
echo 'FCI61P_TRUE_TWO_PARENT_PROMOTION_AND_LIVE_POSTIMAGE_LOCK=PASS'

declare -A PROD_BLOBS=(
  [src/process/mod_drainage_empirical_interflow_response.f90]=eb53096b678d08b76d3fb1adb2247bc2a58ee748
  [src/process/mod_drainage_ernst_ipos45_preparation.f90]=fa1d5d400bb32be42e78889c0ff2a3bcab335142
  [src/process/mod_drainage_ernst_ipos45_response.f90]=b00ef0ae1f10182af2d0a8ea636d10b196e93379
  [src/process/mod_drainage_hooghoudt_equivalent_depth.f90]=6b7b2bb1fd259879d3f26c46abfc071ea2b2f108
  [src/process/mod_drainage_hooghoudt_ipos1_response.f90]=89f26e2d2b77bef5bdd0c5fdb2ce9ca1f03206fa
  [src/process/mod_drainage_hooghoudt_ipos23_response.f90]=5637ddb4d33141f00b4ebf737d1c7f7fe1824164
  [src/process/mod_drainage_multilevel_aggregation.f90]=70d35512ef7c5958f7e4bf284cba104a7b641fdb
  [src/process/mod_drainage_process.f90]=dbacd49da3bb0b94f822f9ee0478d15183e9c0fa
  [src/process/mod_drainage_tabulated_response.f90]=738f57c334910ab73bc8870e3aa8dda1c1a48c7a
  [src/runtime/mod_fmr_drainage_response_binding.f90]=76c2a2ea569a4e85e490ebd2e7fb89c28d8b3fb5
  [src/runtime/mod_fmr_serialized_reference_backend.f90]=0f09c0df1559ece894356b146b64d872470c0a32
)
for p in "${!PROD_BLOBS[@]}"; do
  want="${PROD_BLOBS[$p]}"
  [[ "$(git rev-parse "$COMPOSITION:$p")" == "$want" ]] || fail "composition blob drift $p"
  [[ "$(git rev-parse "$POSTIMAGE:$p")" == "$want" ]] || fail "canonical postimage blob drift $p"
  [[ "$(git rev-parse "HEAD:$p")" == "$want" ]] || fail "postimage qualification blob drift $p"
  [[ "$(git rev-parse "$OWNER:$p")" == "$want" ]] || fail "owner authority mismatch $p"
  [[ "$(git rev-parse "$VQ73:$p")" == "$want" ]] || fail "VQ73 authority mismatch $p"
done
[[ -z "$(git diff --name-only "$POSTIMAGE..HEAD" -- src reference)" ]] || fail 'F-CI61P changes production/reference source'
echo 'FCI61P_EXACT_11_CANONICAL_POSTIMAGE_BLOBS=PASS'

allowed=(
  integration/f-ci/F-CI61P_STATUS.json
  tests/fci/run_fci61p_current_canonical_postimage_reconciliation.sh
  .github/workflows/fci61p-current-canonical-postimage-reconciliation.yml
  .github/workflows/fci-canonical.yml
)
mapfile -t changed < <(git diff --name-only "$POSTIMAGE..HEAD")
for path in "${changed[@]}"; do
  ok=0
  for candidate in "${allowed[@]}"; do [[ "$path" == "$candidate" ]] && ok=1 && break; done
  [[ "$ok" -eq 1 ]] || fail "postimage qualification scope unexpected path: $path"
done
echo 'FCI61P_RECONCILIATION_SCOPE_ALLOWLIST=PASS'

[[ "$(git rev-parse "$POSTIMAGE:$CANONICAL_WORKFLOW")" == "$OLD_WORKFLOW_BLOB" ]] || fail 'unexpected pre-reconciliation canonical workflow blob'
[[ "$(git rev-parse "HEAD:$CANONICAL_WORKFLOW")" == "$RECONCILED_WORKFLOW_BLOB" ]] || fail 'unexpected reconciled canonical workflow blob'
grep -Fq "AUTH=$COMPOSITION" "$CANONICAL_WORKFLOW" || fail 'moving-current authority does not point at exact PM14 composition'
if grep -Fq 'AUTH=2d8b08c06b67132f57b2c757f493d1b31a954a92' "$CANONICAL_WORKFLOW"; then
  fail 'stale F-CI59 moving-current authority remains active'
fi
for p in "${!PROD_BLOBS[@]}"; do
  grep -Fq "$p" "$CANONICAL_WORKFLOW" || fail "newly admitted PM14 source not protected by moving-current gate: $p"
done
grep -Fq 'FCI61_MOVING_DRAINAGE_RESPONSE_RUNTIME_PRESERVATION=PASS' "$CANONICAL_WORKFLOW" || fail 'F-CI61 moving preservation marker absent'
echo 'FCI61P_MOVING_CURRENT_AUTHORITY_RECONCILIATION=PASS'

python3 - "$ADMISSION" "$VQ73" "$STATUS" <<'PY'
import json, pathlib, subprocess, sys
admission,vq,status_path=sys.argv[1:]
def at(commit,path): return json.loads(subprocess.check_output(['git','show',f'{commit}:{path}'],text=True))
a=at(admission,'integration/f-ci/F-CI61_STATUS.json')
v=at(vq,'integration/f-vq/F-VQ73_STATUS.json')
assert a['decision']=='QUALIFIED_F_CI61_READY_FOR_CANONICAL_PROMOTION'
assert a['ready_for_canonical_promotion'] is True
assert a['canonical_admission'] is False
assert a['production_composition']['production_delta']=='EXACT_11_FPM14_BLOBS'
assert a['architecture']['invariants_1_30']=='30_OF_30_NO_ADVERSE_ADMISSION_DELTA'
assert a['architecture']['mass_conservation']=='HARD_PASS_REPLAYED'
assert v['decision']=='QUALIFIED_FPM14_DRAINAGE_RESPONSE_RUNTIME_INDEPENDENTLY'
assert v['independently_qualified'] is True
assert v['results']['hard_mass_closure']=='PASS_TOLERANCE_1E-10'
assert v['results']['drainage_transfer_booking']=='PASS_SINGLE_AUTHORITATIVE_TRIAL_LEDGER_BOOKING'
assert v['results']['generic_noncalendar_interval']=='PASS'
if pathlib.Path(status_path).exists():
    s=json.loads(pathlib.Path(status_path).read_text())
    assert s['decision']=='QUALIFIED_F_CI61P_DRAINAGE_RESPONSE_CURRENT_CANONICAL_POSTIMAGE_RECONCILIATION'
    assert s['production_canonical_admitted'] is True
    assert s['postimage_reconciled'] is True
    assert s['moving_current_preservation_reconciled'] is True
    assert s['drainage_v1_100_percent_complete'] is False
print('FCI61P_FCI61_AND_VQ73_AUTHORITY_RECONCILIATION=PASS')
PY

mkdir -p tests/fvq
for f in run_fvq73_independent_runtime.sh test_fvq73_fpm14_drainage_response_independent.f90; do
  git show "$VQ73:tests/fvq/$f" > "tests/fvq/$f"
done
chmod +x tests/fvq/run_fvq73_independent_runtime.sh
bash tests/fvq/run_fvq73_independent_runtime.sh
echo 'FCI61P_VQ73_POSTIMAGE_RUNTIME_REPLAY=PASS'

git show "$OWNER:tests/fpm/run_fpm14_precomputed_divdra_fixed_weir_preservation.sh" > tests/fpm/run_fpm14_precomputed_divdra_fixed_weir_preservation.sh
chmod +x tests/fpm/run_fpm14_precomputed_divdra_fixed_weir_preservation.sh
bash tests/fpm/run_fpm14_precomputed_divdra_fixed_weir_preservation.sh
echo 'FCI61P_ADMITTED_ROUTE_POSTIMAGE_PRESERVATION=PASS'

git diff --check "$POSTIMAGE..HEAD"
echo "FCI61P_EXACT_HEAD=$(git rev-parse HEAD)"
echo 'F-CI61P CURRENT-CANONICAL POSTIMAGE RECONCILIATION GATE PASS'
