#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
fail(){ echo "FCI62P_POSTIMAGE_GATE_FAIL $*" >&2; exit 162; }

PRE=e79b0272edb544ec4c8000a4d6869274f1ab3ae5
ADMISSION=9745433b4ff7e6eb1337b58e0d861e73a9f1ade8
POSTIMAGE=46ed64aba280bf721bce6f99446d0dd4ed00e38f
FSI38=4658b9f45c9a92f93a6a4b59c5c8aee33820ad94
FMR44R=acb63559b5246db33b1958bb0c5bc8c1ba2055c0
VQ75=efecaeaa48661c9188bea220deb1f5b615ecfd99
OLD_AUTH=c7444233b0f23d4f0a845ef5639287e77099291b
STATUS=integration/f-ci/F-CI62P_STATUS.json
CANONICAL_WORKFLOW=.github/workflows/fci-canonical.yml

for object in "$PRE" "$ADMISSION" "$POSTIMAGE" "$FSI38" "$FMR44R" "$VQ75"; do git cat-file -e "$object^{commit}" || fail "missing authority $object"; done
[[ "$(git rev-parse "$POSTIMAGE^1")" == "$PRE" ]] || fail 'postimage first parent mismatch'
[[ "$(git rev-parse "$POSTIMAGE^2")" == "$ADMISSION" ]] || fail 'postimage second parent mismatch'
[[ "$(git rev-list --parents -n1 "$POSTIMAGE" | awk '{print NF-1}')" -eq 2 ]] || fail 'canonical admission is not true two-parent merge'
git merge-base --is-ancestor "$POSTIMAGE" HEAD || fail 'reconciliation not descended from admitted postimage'
LIVE="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$LIVE" == "$POSTIMAGE" ]] || fail "live canonical drift expected=$POSTIMAGE actual=$LIVE"
echo 'FCI62P_TRUE_TWO_PARENT_PROMOTION_AND_LIVE_POSTIMAGE_LOCK=PASS'

solver=src/solver/mod_reference_richards_temporal_indicator.f90
adapter=src/adapter/mod_b110_serialized_context_binding.f90
runtime=src/runtime/mod_fmr_serialized_reference_backend.f90
[[ "$(git rev-parse "$POSTIMAGE:$solver")" == "$(git rev-parse "$FSI38:$solver")" ]] || fail 'F-SI38 solver blob mismatch'
[[ "$(git rev-parse "$POSTIMAGE:$adapter")" == "$(git rev-parse "$FMR44R:$adapter")" ]] || fail 'F-MR44R adapter blob mismatch'
[[ "$(git rev-parse "$POSTIMAGE:$runtime")" == "$(git rev-parse "$FMR44R:$runtime")" ]] || fail 'F-MR44R backend blob mismatch'
for p in "$solver" "$adapter" "$runtime"; do
  [[ "$(git rev-parse "HEAD:$p")" == "$(git rev-parse "$POSTIMAGE:$p")" ]] || fail "postimage reconciliation source drift $p"
  [[ "$(git rev-parse "$VQ75:$p")" == "$(git rev-parse "$POSTIMAGE:$p")" ]] || fail "VQ75 source mismatch $p"
done
[[ -z "$(git diff --name-only "$POSTIMAGE..HEAD" -- src reference)" ]] || fail 'F-CI62P changes production/reference source'
echo 'FCI62P_EXACT_THREE_CANONICAL_POSTIMAGE_BLOBS=PASS'

allowed=(
  integration/f-ci/F-CI62P_STATUS.json
  tests/fci/run_fci62p_current_canonical_postimage_reconciliation.sh
  .github/workflows/fci62p-current-canonical-postimage-reconciliation.yml
  .github/workflows/fci-canonical.yml
)
mapfile -t changed < <(git diff --name-only "$POSTIMAGE..HEAD")
for path in "${changed[@]}"; do
  ok=0
  for candidate in "${allowed[@]}"; do [[ "$path" == "$candidate" ]] && ok=1 && break; done
  [[ "$ok" -eq 1 ]] || fail "unexpected reconciliation path: $path"
done
echo 'FCI62P_RECONCILIATION_SCOPE_ALLOWLIST=PASS'

grep -Fq "AUTH=$POSTIMAGE" "$CANONICAL_WORKFLOW" || fail 'moving-current authority not advanced to F-CI62 postimage'
if grep -Fq "AUTH=$OLD_AUTH" "$CANONICAL_WORKFLOW"; then fail 'stale F-CI61 moving-current authority remains active'; fi
for p in "$solver" "$adapter" "$runtime"; do grep -Fq "$p" "$CANONICAL_WORKFLOW" || fail "F-CI62 source absent from moving dependency surface: $p"; done
grep -Fq 'FCI62_MOVING_PRESCRIBED_QBOT_TEMPORAL_RUNTIME_PRESERVATION=PASS' "$CANONICAL_WORKFLOW" || fail 'F-CI62 moving preservation marker absent'
echo 'FCI62P_MOVING_CURRENT_AUTHORITY_RECONCILIATION=PASS'

python3 - "$ADMISSION" "$VQ75" "$STATUS" <<'PY'
import json, pathlib, subprocess, sys
admission,vq,status_path=sys.argv[1:]
def at(commit,path): return json.loads(subprocess.check_output(['git','show',f'{commit}:{path}'],text=True))
a=at(admission,'integration/f-ci/F-CI62_STATUS.json')
v=at(vq,'qualification/F-VQ75_STATUS.json')
assert a['decision']=='QUALIFIED_F_CI62_READY_FOR_CANONICAL_PROMOTION'
assert a['ready_for_canonical_promotion'] is True
assert a['canonical_admission'] is False
assert a['architecture_invariants']=='30_OF_30_NO_ADVERSE_ADMISSION_DELTA'
assert abs(a['qualification_evidence']['positive_qbot_mass_residual_cm']) <= 1.0e-12
assert v['decision']=='QUALIFIED_FOR_CURRENT_CANONICAL_ADMISSION_REVIEW'
assert v['conclusion']=='success'
assert v['independent_evidence']['production_delta_exactly_three_files'] is True
assert v['independent_evidence']['reference_source_changed'] is False
assert abs(v['independent_evidence']['positive_qbot_mass_residual_cm']) <= 1.0e-12
if pathlib.Path(status_path).exists():
    s=json.loads(pathlib.Path(status_path).read_text())
    assert s['decision']=='QUALIFIED_F_CI62P_CURRENT_CANONICAL_POSTIMAGE_RECONCILIATION'
    assert s['production_canonical_admitted'] is True
    assert s['postimage_reconciled'] is True
    assert s['moving_current_preservation_reconciled'] is True
    assert s['EB_I18_energy_publication_qualified'] is False
print('FCI62P_FCI62_AND_VQ75_AUTHORITY_RECONCILIATION=PASS')
PY

bash tests/fvq/run_fvq75_prescribed_qbot_temporal_runtime_independent.sh
echo 'FCI62P_VQ75_POSTIMAGE_RUNTIME_REPLAY=PASS'

git diff --check "$POSTIMAGE..HEAD"
echo "FCI62P_EXACT_HEAD=$(git rev-parse HEAD)"
echo 'F-CI62P CURRENT-CANONICAL POSTIMAGE RECONCILIATION GATE PASS'
