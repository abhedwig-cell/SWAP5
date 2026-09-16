#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
fail(){ echo "FCI62_ADMISSION_GATE_FAIL $*" >&2; exit 62; }

RESTART=e79b0272edb544ec4c8000a4d6869274f1ab3ae5
FSI38=4658b9f45c9a92f93a6a4b59c5c8aee33820ad94
FMR44R=acb63559b5246db33b1958bb0c5bc8c1ba2055c0
VQ75=efecaeaa48661c9188bea220deb1f5b615ecfd99
PRE=integration/f-ci/F-CI62_PRE_REGISTRATION.json
AUDIT=integration/f-ci/F-CI62_ARCHITECTURE_AUDIT.json
STATUS=integration/f-ci/F-CI62_STATUS.json

for object in "$RESTART" "$FSI38" "$FMR44R" "$VQ75"; do git cat-file -e "$object^{commit}" || fail "missing authority $object"; done
for object in "$FSI38" "$FMR44R" "$VQ75"; do git merge-base --is-ancestor "$object" HEAD || fail "authority not in ancestry $object"; done
LIVE="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$LIVE" == "$RESTART" ]] || fail "live canonical drift expected=$RESTART actual=$LIVE"
[[ "$(git merge-base "$RESTART" HEAD)" == "$RESTART" ]] || fail 'qualification no longer rooted in frozen canonical'
echo 'FCI62_AUTHORITY_AND_LIVE_CANONICAL_LOCKS=PASS'

expected=$'src/adapter/mod_b110_serialized_context_binding.f90\nsrc/runtime/mod_fmr_serialized_reference_backend.f90\nsrc/solver/mod_reference_richards_temporal_indicator.f90'
actual="$(git diff --name-only "$RESTART..$VQ75" -- src reference | LC_ALL=C sort)"
[[ "$actual" == "$expected" ]] || { printf 'expected:\n%s\nactual:\n%s\n' "$expected" "$actual" >&2; fail 'exact production scope'; }
[[ -z "$(git diff --name-only "$VQ75..HEAD" -- src reference)" ]] || fail 'F-CI62 qualification changed src/reference'
[[ "$(git rev-parse "$VQ75:src/solver/mod_reference_richards_temporal_indicator.f90")" == "$(git rev-parse "$FSI38:src/solver/mod_reference_richards_temporal_indicator.f90")" ]] || fail 'F-SI38 solver blob mismatch'
for p in src/adapter/mod_b110_serialized_context_binding.f90 src/runtime/mod_fmr_serialized_reference_backend.f90; do
  [[ "$(git rev-parse "$VQ75:$p")" == "$(git rev-parse "$FMR44R:$p")" ]] || fail "F-MR44R runtime blob mismatch $p"
done
echo 'FCI62_EXACT_THREE_PRODUCTION_BLOBS_LOCKED=PASS'

python3 - "$PRE" "$AUDIT" "$STATUS" <<'PY'
import json, pathlib, sys
pre=json.loads(pathlib.Path(sys.argv[1]).read_text())
a=json.loads(pathlib.Path(sys.argv[2]).read_text())
si=json.loads(pathlib.Path('integration/f-si/F-SI38_STATUS.json').read_text())
mr=json.loads(pathlib.Path('integration/f-mr/F-MR44R_STATUS.json').read_text())
vq=json.loads(pathlib.Path('qualification/F-VQ75_STATUS.json').read_text())
assert pre['canonical_base']['sha']=='e79b0272edb544ec4c8000a4d6869274f1ab3ae5'
assert len(pre['production_scope'])==3
assert pre['scope_guards']['new_physics'] is False
assert pre['scope_guards']['new_application_accuracy_default'] is False
assert len(a['invariants'])==30 and [x['id'] for x in a['invariants']]==list(range(1,31))
assert all(x['assessment']=='NO_ADVERSE_ADMISSION_DELTA' for x in a['invariants'])
assert a['overall']=='30_OF_30_NO_ADVERSE_ADMISSION_DELTA' and a['canonical_admission'] is False
assert si['status']=='QUALIFIED_SOURCE_CAPABILITY_NOT_CANONICAL_ADMITTED'
assert mr['status']=='QUALIFIED_SOURCE_CAPABILITY_NOT_CANONICAL_ADMITTED'
assert mr['qualification_evidence']['exact_head_production_qualification'] is True
assert abs(mr['qualification_evidence']['positive_qbot_mass_residual_cm']) <= 1.0e-12
assert vq['decision']=='QUALIFIED_FOR_CURRENT_CANONICAL_ADMISSION_REVIEW'
assert vq['conclusion']=='success'
assert vq['independent_evidence']['production_delta_exactly_three_files'] is True
assert vq['independent_evidence']['reference_source_changed'] is False
assert abs(vq['independent_evidence']['positive_qbot_mass_residual_cm']) <= 1.0e-12
if pathlib.Path(sys.argv[3]).exists():
    s=json.loads(pathlib.Path(sys.argv[3]).read_text())
    assert s['decision']=='QUALIFIED_F_CI62_READY_FOR_CANONICAL_PROMOTION'
    assert s['ready_for_canonical_promotion'] is True
    assert s['canonical_admission'] is False
print('FCI62_OWNER_INDEPENDENT_AND_30_INVARIANT_AUTHORITIES=PASS')
PY

# Independent executable replay is the admission oracle. It in turn checks
# F-SI38 preservation, serialized positive-qbot transaction/mass/certificate,
# fail-closed nearby modes, O0/O2 identity and zero production patching.
bash tests/fvq/run_fvq75_prescribed_qbot_temporal_runtime_independent.sh
echo 'FCI62_FVQ75_INDEPENDENT_REPLAY=PASS'

git diff --quiet -- src reference || fail 'admission replay mutated production/reference source'
git diff --check "$VQ75..HEAD"
echo "FCI62_EXACT_HEAD=$(git rev-parse HEAD)"
echo 'F-CI62 CURRENT-CANONICAL ADMISSION GATE PASS'
