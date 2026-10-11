#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
fail(){ echo "M1_FINAL_CLOSE_FAIL $*" >&2; exit 1; }

BASE=d91c159c3685d8eedc7c94afc38edf827408c1de
git merge-base --is-ancestor "$BASE" HEAD || fail 'candidate does not descend from M1-C3 canonical admission'

[[ "$(git rev-parse HEAD:src/runtime/mod_canonical_contracts.f90)" == 3962c270a7579b7403764674302445fe15ef5f72 ]] || fail 'criterion 1/2/5 canonical contracts drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_canonical_interval_runtime.f90)" == 0b50dda5caf3b73a82561d7b0ba1e92386a08fee ]] || fail 'criterion 1/2/5 interval runtime drift'
[[ "$(git rev-parse HEAD:src/adapter/mod_canonical_result_text_adapter.f90)" == 410d722fbd6e0bcf7ad3a5cc1fc6c133dd95403a ]] || fail 'criterion 4 serializer drift'
[[ "$(git rev-parse HEAD:src/adapter/mod_b110_production_soil_water_task2.f90)" == 0406d3180262b06a5a393b605cc553a912a26aa0 ]] || fail 'criterion 3 Task2 blob drift'
[[ "$(git rev-parse HEAD:src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90)" == 8a59211335f44034a93d9ecd0d7a8920ee9baa39 ]] || fail 'criterion 3 top adapter blob drift'
[[ "$(git rev-parse HEAD:src/solver/mod_b110_dynamic_top_boundary_provider.f90)" == 42fb85a03e6835a839574bf6d4b4c01472a01236 ]] || fail 'criterion 3 top provider blob drift'
echo 'M1_FINAL_EXACT_CANONICAL_BLOBS=PASS'

python3 - <<'PY'
import json,re
from pathlib import Path
q=json.loads(Path('integration/m1/M1_C3_FINAL_WHOLE_HUPSEL_TYPED_ADAPTER_QUALIFICATION.json').read_text())
assert q['qualification_verdict']=='PASS_FINAL_WHOLE_HUPSEL_TYPED_ADAPTER'
assert q['m1_c3_scientific_gate_pass'] is True
x=q['external_exact_asset_execution']
assert x['reference_run_normal_completion'] is True
assert x['candidate_run_normal_completion'] is True
assert x['typed_accepted_intervals']==32518
assert x['accepted_interval_identity'] is True
assert x['no_accepted_interval_fallback'] is True
assert x['result_bal_exact_reference_identity'] is True
assert x['result_blc_exact_reference_identity'] is True
assert x['signed_zero_difference_remaining'] is False
assert q['owner_qualification']['conclusion']=='success'
assert q['independent_qualification']['conclusion']=='success'

c4=json.loads(Path('integration/m1/M1_C4_CANONICAL_ADMISSION.json').read_text())
assert c4['admission_gate']['result']=='PASS'
assert c4['admission_gate']['evidence_inheritance']=='PASS'

for p in ['src/runtime/mod_canonical_contracts.f90','src/runtime/mod_canonical_interval_runtime.f90']:
    s=Path(p).read_text()
    assert not re.search(r'(?im)^\s*(open|read|write|inquire)\s*\(',s)
    assert not re.search(r'(?i)file_unit|pathname|parser',s)
runtime=Path('src/runtime/mod_canonical_interval_runtime.f90').read_text().lower()
assert 't0' in runtime and 't1' in runtime
print('M1_FINAL_CRITERIA_1_2_4_5_STATIC_AUTHORITY=PASS')
print('M1_FINAL_CRITERION_3_EXACT_WHOLE_HUPSEL_AUTHORITY=PASS')
PY

# Re-run the current moving semantic-preservation chain on the close candidate.
bash tests/fci/run_fci93_fsi35_semantic_successor_preservation.sh
env FKT21_ALLOW_FCI98_SUCCESSOR=1 bash tests/fkt/run_fkt21_qualification.sh
echo 'M1_FINAL_CURRENT_SEMANTIC_PRESERVATION=PASS'

python3 - <<'PY'
import json
from pathlib import Path
s=json.loads(Path('integration/m1/M1_FINAL_CLOSEOUT_20260918.json').read_text())
assert len(s['criteria'])==5
assert all(x['verdict'].startswith('PASS_') for x in s['criteria'])
assert s['overall_verdict']=='M1_CLOSE_CANDIDATE_ALL_FIVE_CRITERIA_PASS'
assert s['production_mutation_in_closeout']=='NONE'
print('M1_FINAL_FIVE_CRITERIA_MATRIX=PASS')
PY

echo 'M1_FINAL_CLOSEOUT_GATE=PASS'
