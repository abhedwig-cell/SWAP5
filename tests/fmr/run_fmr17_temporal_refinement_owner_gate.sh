#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

FVQ27=1dc8219beda37fbcd6fd4232c964208fa0f17c8f
FSI20_HANDOFF=81919d5373fb1976e228b32ae213a4685c0e4f9b
FVQ28=d8bcb1c90e897812ae8b91295be98e58023e10fb
FMR16=a19bf5ab988523f9ea8b6f9b03098603ede80b49

fail() { echo "FMR17_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$FSI20_HANDOFF" HEAD || fail 'F-SI20 negative handoff is not an ancestor'
git diff --quiet "$FVQ27" -- src || fail 'production source drift from exact F-VQ27 postimage'
echo 'FMR17_PRODUCTION_SOURCE_IMMUTABILITY_TO_FVQ27=PASS'

tmp="${TMPDIR:-/tmp}/swap5-fmr17-owner-$$"
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

git show "$FVQ28:integration/f-vq/F-VQ28_GATE_A_EVIDENCE.json" > "$tmp/gate-a.json"
git show "$FVQ28:integration/f-vq/F-VQ28_GATE_B_EVIDENCE.json" > "$tmp/gate-b.json"
git show "$FMR16:integration/f-mr/F-MR16_STATUS.json" > "$tmp/fmr16.json"
git show "$FSI20_HANDOFF:integration/f-si/F-SI20_FVQ28_NEGATIVE_QUALIFICATION_HANDOFF.json" > "$tmp/handoff.json"

python3 - "$tmp/gate-a.json" "$tmp/gate-b.json" "$tmp/fmr16.json" "$tmp/handoff.json" <<'PY'
import json, sys
A,B,M,H=[json.load(open(p)) for p in sys.argv[1:]]
assert A['gate_A_decision']=='PASS_BOUNDED_FIXED_HORIZON_PROFILE_CANDIDATE_REQUIRES_RUNTIME_SHAPE_TRANSLATION'
assert A['results']['all_cases_hard_mass_gate']=='PASS'
assert A['results']['all_resolved_raw_head_defect_curves_monotone_nonincreasing'] is True
assert A['results']['bounded_profile_candidate'] is True
assert A['results']['maximum_persistent_conservative_entry_N']==16
assert A['source_controls']['o0_o2_identity']=='PASS'
assert B['decision']=='FAIL_TRANSLATION_EXISTING_RETRY_TOPOLOGY_DOES_NOT_PRESERVE_CONSERVATIVE_RELATION'
assert B['resolved_relationship']['underconservative_attempts']==36
assert B['resolved_relationship']['cases_losing_a_previously_conservative_relation_on_retry']==10
assert B['same_endpoint_reference']['hard_mass_gate']=='PASS'
assert B['hard_constraints_preserved']['fkt_transaction_semantics_changed'] is False
assert M['status']=='CLOSED_READINESS_BLOCKED_FSI_SOURCE_THEORY_QUALIFIED_RICHARDS_TEMPORAL_ERROR_REQUIRED'
assert H['owner_exit']=='SEPARATE_OWNER_RUNTIME_POLICY_WORKUNIT_REQUIRED_IF_NONSTATIONARY_PRESCRIBED_HEAD_TEMPORAL_ACCEPTANCE_IS_TO_PROCEED'
assert H['owner_consequence']['simple_binary_to_raw_head_metric_replacement_allowed'] is False
print('FMR17_FVQ28_GATE_A_SAME_HORIZON_CANDIDATE=PASS')
print('FMR17_FVQ28_GATE_B_EXISTING_RETRY_TRANSLATION_REJECTED=PASS')
print('FMR17_FMR16_FSI20_OWNER_BOUNDARY_LOCK=PASS')
PY

python3 - <<'PY'
from pathlib import Path
p=Path('src/transaction/mod_transaction_reference.f90').read_text()
start=p.index('    function temporal_error_iface(self, full_state, half_state) result(value)')
end=p.index('    end function temporal_error_iface', start)
iface=p[start:end]
assert 't0' not in iface
assert 't1' not in iface
assert 'forcing' not in iface.lower()
assert 'config' not in iface.lower()
assert 'checkpoint' not in iface.lower()
assert 'solver' not in iface.lower()
required=[
    'attempt_t1 = t0 + attempt_dt',
    'midpoint = t0 + 0.5_real64 * attempt_dt',
    'terr = model%temporal_error(full_state, half_state)',
    'attempt_dt = attempt_dt * policy%retry_scale',
]
for token in required:
    assert token in p, token
print('FMR17_CURRENT_TEMPORAL_CALLBACK_FINAL_STATES_ONLY=PASS')
print('FMR17_CURRENT_RETRY_SHORTENS_ATTEMPT_ENDPOINT=PASS')
print('FMR17_DEEP_SAME_HORIZON_REFINEMENT_NOT_EXPRESSIBLE_THROUGH_CURRENT_CALLBACK=PASS')
PY

python3 - <<'PY'
from pathlib import Path
p=Path('src/runtime/mod_canonical_interval_runtime.f90').read_text()
assert 'The externally committed physical state remains untouched until the full' in p
assert 'call move_alloc(working, committed)' in p
assert 'result%diagnostics%external_commits = 1' in p
print('FMR17_EXISTING_OUTER_TRANSACTION_ISOLATION_CONTRACT=PASS')
PY

echo 'FMR17_MASS_GATE_RELAXED=NO'
echo 'FMR17_PHYSICS_CHANGED=NO'
echo 'FMR17_TRANSACTION_SEMANTICS_CHANGED=NO'
echo 'FMR17_TEMPORAL_TOLERANCE_SELECTED=NO'
echo 'FMR17_OWNER_RESOLUTION=FKT_GENERIC_TRANSACTION_REFINEMENT_SEAM_REQUIRED_IF_SAME_HORIZON_CANDIDATE_PROCEEDS'
echo 'FMR17_TEMPORAL_REFINEMENT_OWNER_GATE PASS'
