#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-}"
case "$MODE" in
  semantic|nonlinear) ;;
  *) echo "usage: $0 {semantic|nonlinear}" >&2; exit 2 ;;
esac

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
TMP="${TMPDIR:-/tmp}/swap5-fci21-vq32-authority-$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

SOURCE_COMMIT=a0331164a8dfc2642becdbe96cab969eabead392
POSTIMAGE=integration/f-ci/F-CI21_MATERIALIZED_SOURCE_POSTIMAGE.json
POSTIMAGE_BLOB=868cf8c52c02a6a9b40bd09ad9f51b7c0b635de4
AUTH_BRANCH=qualification/f-vq32-richards-head-budget-normalization
AUTH_REF=refs/remotes/origin/fci21-vq32-authority

fail() { echo "FCI21_VQ32_REPLAY_FAIL:$MODE:$*" >&2; exit 1; }

git merge-base --is-ancestor "$SOURCE_COMMIT" HEAD || fail 'materialized source commit not in history'
[[ "$(git rev-parse HEAD:$POSTIMAGE)" == "$POSTIMAGE_BLOB" ]] || fail 'materialized-source postimage manifest drift'
git diff --quiet "$SOURCE_COMMIT" HEAD -- src || fail 'F-CI21 production source drift after materialization'
[[ "$(git rev-parse HEAD:src/solver/mod_reference_richards_temporal_indicator.f90)" == fe8f87d11257d4c6bc019f1d628ac41ba3106d4e ]] || fail 'production indicator postimage drift'
[[ "$(git rev-parse HEAD:tests/fsi/test_fsi25_reference_indicator_production_seam.f90)" == c125c6a2ab706920b7e2a5c6f1c855520b192223 ]] || fail 'current F-SI25 direct driver drift'
echo "FCI21_VQ32_POSTIMAGE_LOCK=PASS:MODE=$MODE"

git fetch --quiet --no-tags origin "$AUTH_BRANCH:$AUTH_REF"

check_auth() {
  local path="$1" blob="$2"
  [[ "$(git rev-parse "$AUTH_REF:$path")" == "$blob" ]] || fail "authority drift $path"
}

check_auth integration/f-vq/F-VQ32_QUALIFICATION_PLAN.json e47b71d25133902967294583801df720cac9cd63
check_auth integration/f-vq/F-VQ32_INDEPENDENT_EVIDENCE.json f27cfd22f16cea16bee8c8a27e0c34b23c5dcc53
check_auth integration/f-vq/F-VQ32_CLOSEOUT.json 51b075c6f72880897416bdcfd92549bd68d26b7b
check_auth integration/f-vq/F-VQ32_OWNER_HANDOFF.json f7b7cce171b3b1829d7005c5ab7abae7c44ba4a9
check_auth tests/fvq/test_fvq32_head_budget_semantics.py 2ee6cd20b19c9a3e4f0a36f3f98efb1b1791e5be
check_auth tests/fvq/run_fvq32_fresh_head_budget_normalization.sh 699c6fb50a57f3a811e411ad05c88a55922bc737
check_auth integration/f-si/F-SI26_CLOSEOUT.json a07afb736ef3dd4a4fd937c9b04f83bcf77e70c0
check_auth integration/f-si/F-SI26_OWNER_EVIDENCE.json 42ba1920cbce0a89952f521d56d20995b102db9c
check_auth integration/f-si/F-SI26_OWNER_HANDOFF.json 3bdeae8ea0c6938bfb28a9d1aa2df8ae24e5b520
check_auth integration/f-kt/F-KT09_DECISION_CONTRACT.json 7957c07ba3a1e31469f315b437f9ac3248a860e0
check_auth integration/f-vq/F-VQ31_CLOSEOUT.json 82064e357abe5d941850fcaa4eb8dcdf49e1b4af
check_auth tests/fkt/test_fkt10_transactional_fvq30_replay.f90 c42765b89b5dd9140aa492ab56abbbf2077be50e

echo "FCI21_VQ32_AUTHORITY_BLOB_LOCK=PASS:MODE=$MODE"

git show "$AUTH_REF:integration/f-vq/F-VQ32_QUALIFICATION_PLAN.json" > "$TMP/plan.json"
git show "$AUTH_REF:integration/f-vq/F-VQ32_CLOSEOUT.json" > "$TMP/closeout.json"
python3 - "$TMP/plan.json" "$TMP/closeout.json" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); c=json.load(open(sys.argv[2]))
assert p['frozen_before_execution'] is True
assert p['candidate_lock']['formula']=='C_h=B_inf/H_budget'
assert p['candidate_lock']['default_H_budget'] is None
assert p['candidate_lock']['empirical_multiplier'] is None
assert p['synthetic_budget_probe_set_cm']==[0.01,0.1,1.0]
assert p['independent_exact_linear_matrix']['x_values']==[0.015625,0.0625,0.25,1.0,4.0,16.0]
assert p['fresh_nonlinear_production_matrix']['case_count']==12
assert c['decision']=='QUALIFIED_INDEPENDENT_EXPLICIT_HEAD_BUDGET_NORMALIZATION_READY_FOR_SEPARATE_PRODUCTION_POLICY_BINDING'
assert c['qualification_summary']['production_src_changed'] is False
assert c['qualification_summary']['post_result_tuning'] is False
print('FCI21_VQ32_FROZEN_CONTRACT=PASS:LINEAR=6:NONLINEAR=12:BUDGETS=3')
print('FCI21_VQ32_AUTHORITY_DECISION=PASS')
PY

OVERLAY=(
  integration/f-vq/F-VQ32_QUALIFICATION_PLAN.json
  integration/f-vq/F-VQ32_INDEPENDENT_EVIDENCE.json
  integration/f-vq/F-VQ32_CLOSEOUT.json
  integration/f-vq/F-VQ32_OWNER_HANDOFF.json
  integration/f-si/F-SI26_CLOSEOUT.json
  integration/f-si/F-SI26_OWNER_EVIDENCE.json
  integration/f-si/F-SI26_OWNER_HANDOFF.json
  integration/f-kt/F-KT09_DECISION_CONTRACT.json
  integration/f-vq/F-VQ31_CLOSEOUT.json
  tests/fvq/test_fvq32_head_budget_semantics.py
  tests/fvq/run_fvq32_fresh_head_budget_normalization.sh
  tests/fkt/test_fkt10_transactional_fvq30_replay.f90
)
for path in "${OVERLAY[@]}"; do
  mkdir -p "$(dirname "$path")"
  git show "$AUTH_REF:$path" > "$path"
done
chmod +x tests/fvq/run_fvq32_fresh_head_budget_normalization.sh tests/fvq/test_fvq32_head_budget_semantics.py

# Adapt only historical replay governance to the already-qualified F-CI21
# postimage. Candidate formula, matrices, budgets and numerical pass rules remain
# byte-for-byte authority data.
python3 - <<'PY'
from pathlib import Path

def replace_one(path, old, new):
    p=Path(path); s=p.read_text()
    if s.count(old) != 1:
        raise SystemExit(f'FCI21_VQ32_HARNESS_ADAPT_FAIL:{path}:expected exactly one token, got {s.count(old)}')
    p.write_text(s.replace(old,new,1))

semantic='tests/fvq/test_fvq32_head_budget_semantics.py'
old="""# Ensure VQ32 has not changed product source while qualifying normalization.\nsrcdiff = subprocess.check_output(['git','diff','--name-only',p['base_commit']+'..HEAD','--','src'], cwd=ROOT, text=True).strip()\nrequire(srcdiff == '', 'production source changed in F-VQ32')\nprint('FVQ32_G08_NONLINEAR_CLAIM_BOUNDARY=PASS')"""
new="""# F-CI21 is a materialized postimage, not a literal VQ32 branch descendant.\n# The outer replay wrapper proves that no src changed after the materialized source\n# commit and locks the production indicator blob. Preserve the original claim boundary\n# without comparing unrelated integration history to the historical VQ32 base.\nrequire(blob_at('HEAD','src/solver/mod_reference_richards_temporal_indicator.f90') == 'fe8f87d11257d4c6bc019f1d628ac41ba3106d4e', 'materialized production indicator drift')\nprint('FVQ32_FCI21_MATERIALIZED_SOURCE_IDENTITY=PASS')\nprint('FVQ32_G08_NONLINEAR_CLAIM_BOUNDARY=PASS')"""
replace_one(semantic, old, new)

runner='tests/fvq/run_fvq32_fresh_head_budget_normalization.sh'
old_guard="assert 'outcome%temporal_certificate_available = .true.' not in backend"
new_guard="""service_start=backend.index('subroutine evaluate_temporal_history_service')\nservice_end=backend.index('end subroutine evaluate_temporal_history_service', service_start)\nservice=backend[service_start:service_end]\nassert 'self%temporal_indicator_budget_supplied = config%model_temporal_indicator_budget_available' in backend\nassert 'self%temporal_indicator_budget_valid = self%temporal_indicator_budget > 0.0_real64' in backend\nassert 'normalized_indicator = indicator_result%head_inf_bound / self%temporal_indicator_budget' in service\nassert 'outcome%temporal_certificate_available = .true.' in service\nassert service.index('else if (.not. self%temporal_indicator_budget_supplied) then') < service.index('outcome%temporal_certificate_available = .true.')\nassert service.index('else if (.not. self%temporal_indicator_budget_valid) then') < service.index('outcome%temporal_certificate_available = .true.')\nassert 'outcome%temporal_indicator = indicator_result%head_inf_bound' not in backend"""
replace_one(runner, old_guard, new_guard)

print('FCI21_VQ32_MATERIALIZED_SOURCE_GUARD_ADAPTATION=PASS_TEST_ONLY')
print('FCI21_VQ32_POST_KT11_BUDGET_GUARD_ADAPTATION=PASS_TEST_ONLY')
PY

git config user.name 'F-CI21 qualification overlay'
git config user.email 'f-ci21-overlay@invalid.local'
git add "${OVERLAY[@]}"
git commit --quiet --no-gpg-sign -m 'ci-only: overlay frozen VQ32 authority with postimage guards'

git diff --quiet "$SOURCE_COMMIT" HEAD -- src || fail 'qualification overlay changed src'
[[ "$(git rev-parse HEAD:integration/f-vq/F-VQ32_QUALIFICATION_PLAN.json)" == e47b71d25133902967294583801df720cac9cd63 ]] || fail 'overlay plan blob mismatch'
[[ "$(git rev-parse HEAD:tests/fkt/test_fkt10_transactional_fvq30_replay.f90)" == c42765b89b5dd9140aa492ab56abbbf2077be50e ]] || fail 'overlay transaction driver mismatch'
echo "FCI21_VQ32_TEST_ONLY_OVERLAY=PASS:MODE=$MODE"

case "$MODE" in
  semantic)
    python3 tests/fvq/test_fvq32_head_budget_semantics.py
    ;;
  nonlinear)
    bash tests/fvq/run_fvq32_fresh_head_budget_normalization.sh
    ;;
esac

echo "FCI21_VQ32_MODE=PASS:$MODE"
