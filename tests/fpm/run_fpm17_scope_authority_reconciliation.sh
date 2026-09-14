#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
fail(){ echo "FPM17_SCOPE_RECONCILIATION_FAIL $*" >&2; exit 117; }

CANONICAL='e79b0272edb544ec4c8000a4d6869274f1ab3ae5'
PM13='e5cd87eafb95356ca0d5ef8399fcb64feae78fd2'
PM15='50c933a54e9920735b65e708839b5a8b8aa57ede'

# Pure governance correction: no production/reference mutation.
git merge-base --is-ancestor "$CANONICAL" HEAD || fail 'head not descended from frozen canonical'
git diff --quiet "$CANONICAL"..HEAD -- src reference || fail 'production/reference source changed'
echo 'FPM17_NO_PRODUCTION_REFERENCE_CHANGE=PASS'

[[ "$(git rev-parse "$PM13:integration/f-pm/F-PM13_DRAINAGE_V1_FINAL_COMPLETION.json")" == 'ce4dc39da4a97f070539896e9929f00c475d7ffa' ]] || fail 'PM13 final completion authority drift'
[[ "$(git rev-parse "$PM13:integration/f-pm/F-PM13_DRAINAGE_V1_COMPLETION_AUDIT.md")" == 'e6287ef1dfb4f5fd27e6a635282bd9f232389117' ]] || fail 'PM13 audit authority drift'
[[ "$(git rev-parse "$PM15:integration/f-pm/F-PM15_STATUS.json")" == '97240f1dbca790946060762c10622950d3016a8b' ]] || fail 'PM15 status drift'
echo 'FPM17_AUTHORITY_BLOBS_EXACT=PASS'

python3 - "$PM13" "$PM15" <<'PY'
import json, subprocess, sys
pm13, pm15 = sys.argv[1:]
def load(sha,path):
    return json.loads(subprocess.check_output(['git','show',f'{sha}:{path}'],text=True))
def text(sha,path):
    return subprocess.check_output(['git','show',f'{sha}:{path}'],text=True)

f13=load(pm13,'integration/f-pm/F-PM13_DRAINAGE_V1_FINAL_COMPLETION.json')
a13=text(pm13,'integration/f-pm/F-PM13_DRAINAGE_V1_COMPLETION_AUDIT.md')
s15=load(pm15,'integration/f-pm/F-PM15_STATUS.json')
s17=json.load(open('integration/f-pm/F-PM17_SCOPE_AUTHORITY_RECONCILIATION.json'))

# Frozen denominator and original blockers are exact and unchanged.
assert f13['denominator']['changed'] is False
assert f13['denominator']['scope_reduced'] is False
assert len(f13['denominator']['frozen_variants']) == 8
assert [x['id'] for x in f13['hard_blockers']] == [
    'G1_RUNTIME_COMPOSITION',
    'G2_TRANSACTION_MASS_RESTART_MULTISWAP_DIAGNOSTICS',
    'G3_CANONICAL_ADMISSION_PRESERVATION']

# F-PM13 makes process/Jacobian ownership explicit and its closure route does
# not introduce fully implicit coupling as a completion requirement.
assert 'process code may not access HeadCalc internals or mutate the solver Jacobian' in a13
assert 'no process mutation of solver Jacobian internals' in a13
assert 'solver owns Jacobian assembly and chain rule' in a13
route=f13['minimal_dependency_ordered_closure_route']
assert len(route) == 5
assert not any('fully implicit' in x.lower() for x in route)
assert not any('jacobian chain' in x.lower() for x in route)

# F-PM15 did create a new G1R blocker not present in the frozen authority.
assert s15['remaining_gap']['id'] == 'G1R_FULLY_IMPLICIT_DRAINAGE_RESPONSE_SOLVER_COUPLING'
assert s15['denominator']['authority'].startswith('F-PM13@')
assert s15['denominator']['changed'] is False
assert s15['denominator']['scope_reduced'] is False

# The reconciliation must fail closed against both scope shrink and scope growth.
assert s17['finding']['classification'] == 'F_PM15_SCOPE_EXPANSION_ERROR'
assert s17['finding']['frozen_scope_requires_fully_implicit_coupling'] is False
assert s17['production_disposition']['production_source_changed'] is False
assert s17['production_disposition']['frozen_denominator_changed'] is False
assert s17['production_disposition']['scope_reduced'] is False
assert s17['decision'] == 'F_PM15_G1R_NOT_A_FROZEN_DRAINAGE_V1_EXIT_REQUIREMENT'
assert s17['drainage_v1_100_percent_complete'] is False

print('FPM17_PM13_DENOMINATOR_EXACT=PASS')
print('FPM17_PM13_ORIGINAL_G1_G2_G3_EXACT=PASS')
print('FPM17_PROCESS_JACOBIAN_OWNERSHIP_GUARD=PASS')
print('FPM17_FULLY_IMPLICIT_NOT_PM13_EXIT_REQUIREMENT=PASS')
print('FPM17_FPM15_SCOPE_EXPANSION_CLASSIFIED=PASS')
PY

git diff --check "$CANONICAL"..HEAD
echo 'FPM17_SCOPE_AUTHORITY_RECONCILIATION=PASS'
