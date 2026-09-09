#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

CANONICAL_BRANCH="integration/f-ci-canonical"
EXPECTED_CANONICAL="3144c35eb8c60f822cc363dc48c21591e14b4cf4"
EXPECTED_CANONICAL_TREE="a0c1a4f135589b2b6304427b29341317e867c522"
FCI21_BRANCH="integration/f-ci21-temporal-certificate-materialization"
FCI21_HEAD="697755068253cfb5a2f838c63894e1609a85ff51"
FCI21_TREE="130d329a73b76e35eba43b57f441e017115cbea2"
EXPECTED_SRC_TREE="3446aa1d0d80861b22f7e74c7ad51bcedef4f479"
EXPECTED_REFERENCE_TREE="9d08625217d7c0a7385df9da6a04183bcd9cb9e6"
EXPECTED_CANONICAL_MANIFEST_BLOB="cad946641cd671b4582550ac8cca813c647e9b36"
EXPECTED_FCI21_STATUS_BLOB="3d0d891aee18744c998f9beedf2fa7851edc4c0a"
EXPECTED_FCI21_CLOSEOUT_BLOB="57f670c02a58cd21fc442a076c7a2ad06087254a"
EXPECTED_VQ33_RECONCILIATION_BLOB="70557a81132639b71739fe56a5f34f8bca92e3ef"
EXPECTED_VQ34_REPLAY_BLOB="578fbfdd2a2b137a4119335beb648af0e90d283c"

fail() {
  echo "FCI22_ADMISSION_FAIL $*" >&2
  exit 1
}

# Reconcile mutable remote refs, not stale local assumptions.
git fetch --quiet origin \
  "+refs/heads/${CANONICAL_BRANCH}:refs/remotes/origin/${CANONICAL_BRANCH}" \
  "+refs/heads/${FCI21_BRANCH}:refs/remotes/origin/${FCI21_BRANCH}"

LIVE_CANONICAL="$(git rev-parse "refs/remotes/origin/${CANONICAL_BRANCH}")"
LIVE_FCI21="$(git rev-parse "refs/remotes/origin/${FCI21_BRANCH}")"
[[ "$LIVE_CANONICAL" == "$EXPECTED_CANONICAL" ]] || fail "canonical drift: expected $EXPECTED_CANONICAL got $LIVE_CANONICAL"
[[ "$LIVE_FCI21" == "$FCI21_HEAD" ]] || fail "closed F-CI21 branch drift: expected $FCI21_HEAD got $LIVE_FCI21"
[[ "$(git rev-parse "$LIVE_CANONICAL^{tree}")" == "$EXPECTED_CANONICAL_TREE" ]] || fail "canonical tree mismatch"
[[ "$(git rev-parse "$FCI21_HEAD^{tree}")" == "$FCI21_TREE" ]] || fail "F-CI21 tree mismatch"
echo 'FCI22_G01_LIVE_REF_LOCKS=PASS'

# F-CI21 must be a strict linear fast-forward descendant of the pinned canonical base.
MERGE_BASE="$(git merge-base "$EXPECTED_CANONICAL" "$FCI21_HEAD")"
[[ "$MERGE_BASE" == "$EXPECTED_CANONICAL" ]] || fail "unexpected merge base $MERGE_BASE"
read -r BEHIND AHEAD < <(git rev-list --left-right --count "$EXPECTED_CANONICAL...$FCI21_HEAD")
[[ "$BEHIND" == "0" ]] || fail "F-CI21 is behind canonical by $BEHIND commits"
[[ "$AHEAD" == "214" ]] || fail "unexpected frozen F-CI21 ahead count $AHEAD"
git merge-base --is-ancestor "$FCI21_HEAD" HEAD || fail "qualification head is not a descendant of frozen F-CI21"
echo 'FCI22_G02_LINEAR_FAST_FORWARD_LINEAGE=PASS'

# The production/reference candidate is exact and remains immutable through F-CI22.
[[ "$(git rev-parse "$FCI21_HEAD:src")" == "$EXPECTED_SRC_TREE" ]] || fail "frozen F-CI21 src tree mismatch"
[[ "$(git rev-parse "HEAD:src")" == "$EXPECTED_SRC_TREE" ]] || fail "qualification src tree drift"
[[ "$(git rev-parse "$FCI21_HEAD:reference")" == "$EXPECTED_REFERENCE_TREE" ]] || fail "frozen F-CI21 reference tree mismatch"
[[ "$(git rev-parse "HEAD:reference")" == "$EXPECTED_REFERENCE_TREE" ]] || fail "qualification reference tree drift"
git diff --exit-code "$FCI21_HEAD"..HEAD -- src reference >/dev/null || fail "F-CI22 changed src/reference"
echo 'FCI22_G03_EXACT_SRC_REFERENCE_POSTIMAGE=PASS'
echo 'FCI22_G04_QUALIFICATION_SOURCE_IMMUTABILITY=PASS'

# F-CI22 is qualification-only. No unrelated inherited artifact may be edited.
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  case "$path" in
    integration/f-ci/F-CI22_*.json|integration/f-ci/F-CI22_*.md|tests/fci/run_fci22_*.sh|.github/workflows/fci22-*.yml|.github/workflows/fci22-*.yaml) ;;
    *) fail "out-of-scope F-CI22 path delta: $path" ;;
  esac
done < <(git diff --name-only "$FCI21_HEAD"..HEAD)
echo 'FCI22_G04_QUALIFICATION_ONLY_SCOPE=PASS'

# The canonical root manifest is provenance, not a mutable live-head declaration.
[[ "$(git rev-parse "HEAD:integration/f-ci/canonical-source-manifest.json")" == "$EXPECTED_CANONICAL_MANIFEST_BLOB" ]] || fail "canonical source manifest changed"
[[ "$(git rev-parse "$EXPECTED_CANONICAL:integration/f-ci/canonical-source-manifest.json")" == "$EXPECTED_CANONICAL_MANIFEST_BLOB" ]] || fail "canonical source manifest provenance mismatch"
echo 'FCI22_CANONICAL_ROOT_MANIFEST_UNCHANGED=PASS'

# Lock exact F-CI21 closeout authority and the critical positive/negative evidence identities.
[[ "$(git rev-parse "HEAD:integration/f-ci/F-CI21_STATUS.json")" == "$EXPECTED_FCI21_STATUS_BLOB" ]] || fail "F-CI21 status artifact changed"
[[ "$(git rev-parse "HEAD:integration/f-ci/F-CI21_CLOSEOUT.json")" == "$EXPECTED_FCI21_CLOSEOUT_BLOB" ]] || fail "F-CI21 closeout artifact changed"
[[ "$(git rev-parse "HEAD:integration/f-ci/F-CI21_VQ33_FAILURE_KT11_REMEDIATION_RECONCILIATION.json")" == "$EXPECTED_VQ33_RECONCILIATION_BLOB" ]] || fail "VQ33 reconciliation artifact changed"
[[ "$(git rev-parse "HEAD:integration/f-ci/F-CI21_VQ34_REMEDIATED_CERTIFICATE_REPLAY_EVIDENCE.json")" == "$EXPECTED_VQ34_REPLAY_BLOB" ]] || fail "VQ34 replay artifact changed"
echo 'FCI22_G05_FCI21_AUTHORITY_BLOBS=PASS'

python3 - <<'PY'
import json
from pathlib import Path

root = Path('.')
status = json.loads((root/'integration/f-ci/F-CI21_STATUS.json').read_text())
closeout = json.loads((root/'integration/f-ci/F-CI21_CLOSEOUT.json').read_text())
vq33 = json.loads((root/'integration/f-ci/F-CI21_VQ33_FAILURE_KT11_REMEDIATION_RECONCILIATION.json').read_text())
vq34 = json.loads((root/'integration/f-ci/F-CI21_VQ34_REMEDIATED_CERTIFICATE_REPLAY_EVIDENCE.json').read_text())
preserve = json.loads((root/'integration/f-ci/F-CI21_WOF42_MR18_PRESERVATION_EVIDENCE.json').read_text())

assert status['state']['qualified'] is True
assert status['state']['closed'] is True
assert status['state']['canonical_modified'] is False
assert status['canonical_state']['canonical_ref_modified'] is False
assert status['canonical_state']['canonical_admission_required_separately'] is True
assert closeout['state']['qualified'] is True
assert closeout['state']['closed'] is True
assert closeout['state']['canonical_modified'] is False
assert closeout['decision'] == 'CLOSED_QUALIFIED_TEMPORAL_CERTIFICATE_MATERIALIZATION_CANONICAL_REF_UNCHANGED'

assert status['negative_evidence']['must_remain_failed'] is True
assert status['negative_evidence']['reinterpreted_as_pass'] is False
assert status['negative_evidence']['used_as_positive_evidence'] is False
assert status['negative_evidence']['rejected_backend_materialized'] is False
assert vq33['historical_failed_authority']['must_remain_failed'] is True
assert vq33['interpretation']['F_VQ33_reinterpreted_as_pass'] is False
assert vq33['interpretation']['old_candidate_allowed_as_positive_evidence'] is False
assert vq34['negative_evidence_lock']['F_VQ33_remains_failed'] is True
assert vq34['negative_evidence_lock']['F_VQ33_used_as_positive_evidence'] is False
print('FCI22_G06_VQ33_NEGATIVE_EVIDENCE=PASS')

policy = status['qualified_policy_scope']
assert policy['formula'] == 'C_h=B_inf/H_budget'
assert policy['explicit_H_budget_required'] is True
assert policy['H_budget_must_be_finite_positive'] is True
assert policy['default_H_budget'] is None
assert policy['mass_gate_precedes_certificate_gate'] is True
assert policy['certificate_rejection_preserves_committed_state'] is True
nonclaims = status['hard_nonclaims']
assert nonclaims['application_H_budget_selected'] is False
assert nonclaims['universal_temporal_tolerance_selected'] is False
assert nonclaims['B_inf_general_nonlinear_true_error_bound_qualified'] is False
assert nonclaims['C_h_general_nonlinear_true_error_bound_qualified'] is False
assert nonclaims['shorter_dt_monotonicity_assumed'] is False
assert nonclaims['groundwater_coupling_released'] is False
print('FCI22_G07_SCOPE_AND_NONCLAIMS=PASS')

chain = closeout['closed_qualified_chain']
assert chain['F_WOF42_crop_persistence_preservation'] is True
assert chain['F_MR18_accepted_commit_receipt_preservation'] is True
assert chain['F_MR18_sparse_multiswap_receipt_preservation'] is True
assert preserve['replay_result'] == 'PASS_MATERIALIZED_WOF42_AND_FMR18_BEHAVIOR_PRESERVED'
assert preserve['production_source_changed_by_replay'] is False
print('FCI22_G08_CARRIED_PRESERVATION_SCOPE=PASS')
PY

# Reexecute the current F-CI21 source/compile and semantic reconciliation gate on this exact qualification head.
bash tests/fci/run_fci21_closeout_readiness_gate.sh > /tmp/fci22_fci21_replay.out 2>&1 || {
  cat /tmp/fci22_fci21_replay.out >&2
  fail "F-CI21 closeout-readiness replay failed"
}
grep -Fq 'FCI21_CLOSEOUT_CURRENT_MATERIALIZATION_GATE=PASS' /tmp/fci22_fci21_replay.out || fail "missing F-CI21 materialization replay marker"
grep -Fq 'FCI21_CLOSEOUT_VQ33_NEGATIVE_SENTINEL=PASS' /tmp/fci22_fci21_replay.out || fail "missing VQ33 negative sentinel marker"
grep -Fq 'FCI21_CLOSEOUT_WOF42_MR18_PRESERVATION=PASS' /tmp/fci22_fci21_replay.out || fail "missing WOF42/MR18 preservation marker"
grep -Fq 'FCI21_CLOSEOUT_READINESS_GATE PASS' /tmp/fci22_fci21_replay.out || fail "missing F-CI21 terminal marker"
echo 'FCI22_G09_FCI21_POSTIMAGE_REQUALIFICATION=PASS'

# Reassert immutable postimage after executable qualification.
[[ "$(git rev-parse "HEAD:src")" == "$EXPECTED_SRC_TREE" ]] || fail "post-test src drift"
[[ "$(git rev-parse "HEAD:reference")" == "$EXPECTED_REFERENCE_TREE" ]] || fail "post-test reference drift"
echo 'FCI22_G10_POST_TEST_POSTIMAGE_IMMUTABILITY=PASS'

echo 'FCI22_CANONICAL_ADMISSION_GATE PASS_RESTRICTED_FCI21_POSTIMAGE_READY_FOR_FAST_FORWARD_DECISION'
