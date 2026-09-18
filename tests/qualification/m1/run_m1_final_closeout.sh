#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"
fail(){ echo "M1_FINAL_CLOSEOUT_FAIL $*" >&2; exit 1; }

BASE=d91c159c3685d8eedc7c94afc38edf827408c1de
LIVE="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$LIVE" == "$BASE" ]] || fail "live canonical moved expected=$BASE actual=$LIVE"
git merge-base --is-ancestor "$BASE" HEAD || fail 'closeout branch does not descend from M1-C3 canonical admission'

mapfile -t changed < <(git diff --name-only "$BASE"..HEAD)
[[ "${#changed[@]}" -eq 3 ]] || { printf '%s\n' "${changed[@]}" >&2; fail 'unexpected closeout delta count'; }
printf '%s\n' "${changed[@]}" | grep -Fxq 'integration/m1/M1_CANONICAL_CLOSEOUT_20260918.json' || fail 'missing closeout record'
printf '%s\n' "${changed[@]}" | grep -Fxq 'tests/qualification/m1/run_m1_final_closeout.sh' || fail 'missing closeout gate'
printf '%s\n' "${changed[@]}" | grep -Fxq '.github/workflows/m1-final-closeout.yml' || fail 'missing closeout workflow'
echo 'M1_FINAL_CLOSEOUT_GOVERNANCE_ONLY_DELTA=PASS'

[[ "$(git rev-parse HEAD:src/runtime/mod_canonical_contracts.f90)" == 3962c270a7579b7403764674302445fe15ef5f72 ]] || fail 'canonical contracts drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_canonical_interval_runtime.f90)" == 0b50dda5caf3b73a82561d7b0ba1e92386a08fee ]] || fail 'canonical interval runtime drift'
[[ "$(git rev-parse HEAD:src/adapter/mod_canonical_result_text_adapter.f90)" == 410d722fbd6e0bcf7ad3a5cc1fc6c133dd95403a ]] || fail 'M1-C4 serializer drift'
[[ "$(git rev-parse HEAD:src/adapter/mod_b110_production_soil_water_task2.f90)" == 0406d3180262b06a5a393b605cc553a912a26aa0 ]] || fail 'M1-C3 Task2 adapter drift'
[[ "$(git rev-parse HEAD:src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90)" == 8a59211335f44034a93d9ecd0d7a8920ee9baa39 ]] || fail 'M1-C3 dynamic-top adapter drift'
[[ "$(git rev-parse HEAD:src/solver/mod_b110_dynamic_top_boundary_provider.f90)" == 42fb85a03e6835a839574bf6d4b4c01472a01236 ]] || fail 'M1-C3 dynamic-top provider drift'
echo 'M1_FINAL_CLOSEOUT_PRODUCTION_BLOBS=PASS'

python3 - <<'PY'
import json
from pathlib import Path
c=json.loads(Path('integration/m1/M1_CANONICAL_CLOSEOUT_20260918.json').read_text())
q=json.loads(Path('integration/m1/M1_C3_FINAL_WHOLE_HUPSEL_TYPED_ADAPTER_QUALIFICATION.json').read_text())
c4=json.loads(Path('integration/m1/M1_C4_CANONICAL_ADMISSION.json').read_text())
assert c['overall_verdict']=='M1_CLOSED_CURRENT_CANONICAL_ALL_FIVE_EXIT_CRITERIA_PASS'
assert c['formal_exit'] is True
assert [x['number'] for x in c['criteria']]==[1,2,3,4,5]
assert all(x['verdict'].startswith('PASS_') for x in c['criteria'])
assert q['qualification_verdict']=='PASS_FINAL_WHOLE_HUPSEL_TYPED_ADAPTER'
assert q['m1_c3_scientific_gate_pass'] is True
e=q['external_exact_asset_execution']
assert e['typed_accepted_intervals']==32518
assert e['accepted_interval_identity'] is True
assert e['result_bal_exact_reference_identity'] is True
assert e['result_blc_exact_reference_identity'] is True
assert e['signed_zero_difference_remaining'] is False
assert c4['criterion_4_claim'].startswith('The exact independently qualified serializer')
assert c4['admission_gate']['result']=='PASS'
print('M1_FINAL_CLOSEOUT_CRITERIA_MATRIX=PASS')
print('M1_FINAL_CLOSEOUT_C3_EXACT_REFERENCE=PASS')
print('M1_FINAL_CLOSEOUT_C4_READONLY_SERIALIZER=PASS')
PY

# Criteria 1,2,5 remain the same typed runtime boundary. Guard against
# accidentally reintroducing historical file/calendar concerns there.
for path in src/runtime/mod_canonical_contracts.f90 src/runtime/mod_canonical_interval_runtime.f90; do
  if grep -Eiq 'pathname|file_unit|open[[:space:]]*\(|read[[:space:]]*\(|parser' "$path"; then
    fail "file/parser semantics entered typed runtime: $path"
  fi
done
grep -Fq 'real(real64) :: t0' src/runtime/mod_canonical_contracts.f90 || fail 'typed real t0 missing'
grep -Fq 'real(real64) :: t1' src/runtime/mod_canonical_contracts.f90 || fail 'typed real t1 missing'
if grep -Eiq 'midnight|calendar|day_aligned|day-aligned' src/runtime/mod_canonical_interval_runtime.f90; then
  fail 'historical day/calendar restriction found in canonical interval runtime'
fi
echo 'M1_FINAL_CLOSEOUT_TYPED_BOUNDARY_STATIC_GUARD=PASS'
echo 'M1_FINAL_CLOSEOUT=PASS'
