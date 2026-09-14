#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
fail(){ echo "FTB12P_POSTIMAGE_FAIL $*" >&2; exit 113; }

PRE='6425fb3290da637357e47618b459f4caf65a78d8'
FTB12_HEAD='22992cec833ef25537bc201aac96d88bf932b299'
CANON='1211bd5f4a4f9b1aee110e8e38cadad7ee52ae4f'
CANON_TREE='e4080f87678f583970f000ad14bfd6363ff64c4c'
PM19='84edf5b728795cb62b43b0a2376d3bd8e3d5a5a3'
VQ76='5ee4920ffe680c920b64996159060fc1f509fcd8'

FTB12_WORKFLOW_BLOB='e7870789793ce84d5a04e355baa2dfe53981e172'
FTB12_STATUS_BLOB='7270e15e33d679d70a56ec7c795911b84094b4d8'
FTB12_MANIFEST_BLOB='a304fbce213c53c5cee799fa79ce22076bb178b5'
FTB12_RUNNER_BLOB='99c7ad975b137bad5b46df48b3916881350b6bb1'
PM19_STATUS_BLOB='1d237b26f31c5e83fa7b299e01f47bd9ec6d5ff4'
PM19_COMPLETION_BLOB='f4ddf0b9ed945ccb6f8a66c4611de624d10dc4a8'
PM19_AUDIT_BLOB='dd49912365425f6d3cc9ce8b070a671eb010d751'
VQ76_STATUS_BLOB='c61081dbede3518d5625714926246cf438106222'

LIVE="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$LIVE" == "$CANON" ]] || fail "live canonical drift expected=$CANON actual=$LIVE"
[[ "$(git rev-parse "$CANON^{tree}")" == "$CANON_TREE" ]] || fail 'canonical tree drift'
git merge-base --is-ancestor "$CANON" HEAD || fail 'F-TB12P is not descended from exact admitted postimage'
echo 'FTB12P_EXACT_LIVE_POSTIMAGE=PASS'

# The F-TB12 admission must be the exact true two-parent merge.
PARENTS="$(git rev-list --parents -n1 "$CANON")"
[[ "$PARENTS" == "$CANON $PRE $FTB12_HEAD" ]] || fail "unexpected F-TB12 merge lineage: $PARENTS"
echo 'FTB12P_TRUE_TWO_PARENT_ADMISSION_LINEAGE=PASS'

# Admission is metadata/testbank-only and contains exactly the four qualified F-TB12 files.
EXPECTED_ADMISSION="$(printf '%s\n' \
  '.github/workflows/f-tb12-drainage-v1-permanent-preservation-adoption.yml' \
  'integration/f-tb/F-TB12_STATUS.json' \
  'testbank/manifests/F-TB12_DRAINAGE_V1_PERMANENT_PRESERVATION_ADOPTION.json' \
  'testbank/runners/run_ftb12_drainage_v1_permanent_preservation.sh' | sort)"
ACTUAL_ADMISSION="$(git diff --name-only "$PRE..$CANON" | sort)"
[[ "$ACTUAL_ADMISSION" == "$EXPECTED_ADMISSION" ]] || { echo "$ACTUAL_ADMISSION" >&2; fail 'unexpected F-TB12 canonical admission file set'; }
[[ "$(git rev-parse "$CANON:.github/workflows/f-tb12-drainage-v1-permanent-preservation-adoption.yml")" == "$FTB12_WORKFLOW_BLOB" ]] || fail 'F-TB12 workflow blob drift'
[[ "$(git rev-parse "$CANON:integration/f-tb/F-TB12_STATUS.json")" == "$FTB12_STATUS_BLOB" ]] || fail 'F-TB12 status blob drift'
[[ "$(git rev-parse "$CANON:testbank/manifests/F-TB12_DRAINAGE_V1_PERMANENT_PRESERVATION_ADOPTION.json")" == "$FTB12_MANIFEST_BLOB" ]] || fail 'F-TB12 manifest blob drift'
[[ "$(git rev-parse "$CANON:testbank/runners/run_ftb12_drainage_v1_permanent_preservation.sh")" == "$FTB12_RUNNER_BLOB" ]] || fail 'F-TB12 runner blob drift'
echo 'FTB12P_EXACT_ADMITTED_FTB12_PACKAGE=PASS'

# Production, reference and ordinary tests are bit-identical across the admission merge.
[[ "$(git rev-parse "$PRE:src")" == "$(git rev-parse "$CANON:src")" ]] || fail 'src tree changed across F-TB12 admission'
[[ "$(git rev-parse "$PRE:reference")" == "$(git rev-parse "$CANON:reference")" ]] || fail 'reference tree changed across F-TB12 admission'
[[ "$(git rev-parse "$PRE:tests")" == "$(git rev-parse "$CANON:tests")" ]] || fail 'tests tree changed across F-TB12 admission'
[[ "$(git rev-parse "$CANON:src")" == 'd6e7a1ea2da1067a9f56ead1e710cf8911de5474' ]] || fail 'postimage src tree unexpected'
[[ "$(git rev-parse "$CANON:reference")" == '9d08625217d7c0a7385df9da6a04183bcd9cb9e6' ]] || fail 'postimage reference tree unexpected'
[[ "$(git rev-parse "$CANON:tests")" == '9e97ea6d9d1a5d4ce5f685d4cdbc116c0dcaf476' ]] || fail 'postimage tests tree unexpected'
echo 'FTB12P_SOURCE_REFERENCE_TESTS_BIT_IDENTICAL=PASS'

# F-TB12P itself is strictly an evidence/gate overlay.
[[ -z "$(git diff --name-only "$CANON..HEAD" -- src reference tests)" ]] || fail 'F-TB12P changes src/reference/tests'
EXPECTED_P="$(printf '%s\n' \
  '.github/workflows/f-tb12p-postimage-reconciliation.yml' \
  'integration/f-tb/F-TB12P_ARCHITECTURE_AUDIT.json' \
  'integration/f-tb/F-TB12P_POSTIMAGE_RECONCILIATION.json' \
  'testbank/runners/run_ftb12p_postimage_reconciliation.sh' | sort)"
ACTUAL_P="$(git diff --name-only "$CANON..HEAD" | sort)"
[[ "$ACTUAL_P" == "$EXPECTED_P" ]] || { echo "$ACTUAL_P" >&2; fail 'F-TB12P contains files outside its exact evidence/gate allowlist'; }
echo 'FTB12P_METADATA_ONLY_DELTA=PASS'

# Exact scientific/completion authority chain is still immutable.
[[ "$(git rev-parse "$PM19:integration/f-pm/F-PM19_STATUS.json")" == "$PM19_STATUS_BLOB" ]] || fail 'F-PM19 status authority drift'
[[ "$(git rev-parse "$PM19:integration/f-pm/F-PM19_DRAINAGE_V1_FINAL_COMPLETION.json")" == "$PM19_COMPLETION_BLOB" ]] || fail 'F-PM19 completion authority drift'
[[ "$(git rev-parse "$PM19:integration/f-pm/F-PM19_ARCHITECTURE_AUDIT.json")" == "$PM19_AUDIT_BLOB" ]] || fail 'F-PM19 architecture authority drift'
[[ "$(git rev-parse "$VQ76:integration/f-vq/F-VQ76_STATUS.json")" == "$VQ76_STATUS_BLOB" ]] || fail 'F-VQ76 status authority drift'
echo 'FTB12P_DRAINAGE_AUTHORITIES_EXACT=PASS'

python3 <<'PY'
import json
from pathlib import Path
s=json.loads(Path('integration/f-tb/F-TB12_STATUS.json').read_text())
m=json.loads(Path('testbank/manifests/F-TB12_DRAINAGE_V1_PERMANENT_PRESERVATION_ADOPTION.json').read_text())
p=json.loads(Path('integration/f-tb/F-TB12P_POSTIMAGE_RECONCILIATION.json').read_text())
a=json.loads(Path('integration/f-tb/F-TB12P_ARCHITECTURE_AUDIT.json').read_text())
# Historical pre-admission snapshot must remain untouched.
assert s['decision']=='QUALIFIED_DRAINAGE_V1_PERMANENT_TESTBANK_PRESERVATION_ADOPTED'
assert s['canonical_admitted'] is False and s['postimage_reconciled'] is False and s['closed'] is False
assert s['ownership']['production_source_changed'] is False
assert s['ownership']['reference_source_changed'] is False
assert s['ownership']['mass_conservation_concession'] is False
assert m['adopted_capability']['decision']=='QUALIFIED_DRAINAGE_V1_100_PERCENT_COMPLETE'
assert m['adopted_capability']['frozen_denominator_variants']==8
assert m['adopted_capability']['scope_reduced'] is False
assert m['adopted_capability']['scope_expanded'] is False
assert m['horizontal_hard_gates']['waivable'] is False
# Postimage authority carries the post-promotion truth.
assert p['decision']=='FTB12_POSTIMAGE_RECONCILED_AND_CANONICALLY_ADMITTED'
assert p['admission']['true_two_parent_merge'] is True
assert p['production_source_changed'] is False and p['reference_source_changed'] is False and p['tests_source_changed'] is False
assert p['mass_conservation_concession'] is False
assert p['post_admission_evidence']['canonical_push_qualification']['conclusion']=='success'
assert p['post_admission_evidence']['canonical_push_qualification']['moving_current_preservation']=='success'
assert p['post_admission_evidence']['canonical_pr_qualification']['conclusion']=='success'
assert p['post_admission_evidence']['canonical_pr_qualification']['moving_current_preservation']=='success'
assert all(p['post_admission_evidence'][k]['conclusion']=='success' for k in ('wof43a_moving_preservation','fsi35_postimage_preservation','vq_reference_qualification','documentation'))
assert p['drainage']['adopted'] is True
assert p['drainage']['permanently_preserved'] is True
assert p['drainage']['canonically_admitted'] is True
assert p['drainage']['postimage_reconciled'] is True
assert p['drainage']['drainage_v1_100_percent_complete'] is True
assert p['drainage']['bounded_to_frozen_eight_variant_denominator'] is True
assert p['drainage']['fully_implicit_drainage_solver_coupling_claimed'] is False
assert p['drainage']['broader_reverse_exchange_claimed'] is False
# Explicit invariant reconciliation.
assert a['invariant_count']==30 and len(a['invariants'])==30
assert [x['id'] for x in a['invariants']]==list(range(1,31))
assert all(x['status']=='PRESERVED' for x in a['invariants'])
assert a['all_invariants_pass_or_preserved'] is True and a['adverse_invariants']==[]
assert a['production_change'] is False and a['reference_change'] is False and a['tests_source_change'] is False
assert a['scope_reduction'] is False and a['scope_expansion'] is False
assert a['mass_conservation_concession'] is False
print('FTB12P_MACHINE_READABLE_POSTIMAGE_AND_INVARIANTS=PASS')
PY

git diff --check "$CANON..HEAD"
LIVE_END="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$LIVE_END" == "$CANON" ]] || fail "canonical moved during F-TB12P qualification expected=$CANON actual=$LIVE_END"
echo "FTB12P_EXACT_HEAD=$(git rev-parse HEAD)"
echo 'F-TB12P FTB12_POSTIMAGE_RECONCILED_AND_CANONICALLY_ADMITTED=PASS'
