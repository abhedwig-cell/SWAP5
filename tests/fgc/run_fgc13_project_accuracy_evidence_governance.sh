#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

CANONICAL="c7379b6b5b5f529ff96de3087379712bd665276a"
APPLICATION_MODULE="src/runtime/mod_coupling_application_accuracy_contract.f90"
APPLICATION_BLOB="c07d573d21e7d013ab962c0a9d28102ab7b5cdfc"
SCHEMA="integration/f-gc/templates/project_accuracy_contract_evidence_v1.schema.json"
PROFILE="integration/f-gc/templates/project_accuracy_contract_governance_v1.json"
VALIDATOR="tests/fgc/validate_fgc13_project_accuracy_contract.py"
FIXTURES="tests/fgc/fixtures/fgc13"

fail() {
  echo "FGC13_GATE_FAIL: $*" >&2
  exit 1
}

git cat-file -e "${CANONICAL}^{commit}" || fail "canonical base unavailable"
git merge-base --is-ancestor "$CANONICAL" HEAD || fail "branch is not descended from F-CI45P canonical authority"
[[ "$(git rev-parse HEAD:$APPLICATION_MODULE)" == "$APPLICATION_BLOB" ]] || fail "canonical application-accuracy contract blob drifted"
echo "FGC13_CANONICAL_CONTRACT_LOCK=PASS"

src_delta="$(git diff --name-only "${CANONICAL}"..HEAD -- src || true)"
[[ -z "$src_delta" ]] || fail "production source changed: $src_delta"
echo "FGC13_NO_PRODUCTION_SOURCE_DELTA=PASS"

python3 - <<'PY'
import json
paths = [
    'integration/f-gc/F-GC13_PRE_REGISTRATION.json',
    'integration/f-gc/templates/project_accuracy_contract_evidence_v1.schema.json',
    'integration/f-gc/templates/project_accuracy_contract_governance_v1.json',
    'tests/fgc/fixtures/fgc13/accepted_fraction_packet.json',
    'tests/fgc/fixtures/fgc13/accepted_direct_budget_packet.json',
    'tests/fgc/fixtures/fgc13/rejection_matrix.json',
]
for path in paths:
    with open(path, encoding='utf-8') as handle:
        json.load(handle)
print('FGC13_JSON_ARTIFACTS=PASS')
PY

python3 - <<'PY'
import json
schema = json.load(open('integration/f-gc/templates/project_accuracy_contract_evidence_v1.schema.json', encoding='utf-8'))
profile = json.load(open('integration/f-gc/templates/project_accuracy_contract_governance_v1.json', encoding='utf-8'))
assert schema['properties']['schema_id']['const'] == 'SWAP5_PROJECT_ACCURACY_CONTRACT_EVIDENCE_V1'
assert set(schema['properties']['project']['properties']['qoi_kind']['enum']) == {'GROUNDWATER_HEAD','GROUNDWATER_DRAWDOWN'}
provenance_required = set(schema['$defs']['provenance']['required'])
assert 'evidence_basis_kind' in provenance_required
assert 'source_digest_sha256' in provenance_required
assert schema['$defs']['provenance']['properties']['source_digest_sha256']['pattern'] == '^[0-9a-f]{64}$'
assert profile['ownership']['kernel_policy_selection'] is False
assert profile['ownership']['kernel_file_parsing'] is False
assert profile['provenance_integrity']['source_digest_sha256_required'] is True
assert profile['provenance_integrity']['evidence_basis_classification_required'] is True
assert profile['fail_closed_behavior']['positive_budget_on_reject'] is False
assert profile['fail_closed_behavior']['mass_conservation_policy_change'] is False
assert len(profile['forbidden_substitutions']) >= 6
print('FGC13_SCHEMA_PROFILE_CONSISTENCY=PASS')
print('FGC13_CLASSIFIED_IMMUTABLE_PROVENANCE=PASS')
PY

fraction_output="$(python3 "$VALIDATOR" "$FIXTURES/accepted_fraction_packet.json")"
direct_output="$(python3 "$VALIDATOR" "$FIXTURES/accepted_direct_budget_packet.json")"
grep -q '^FGC13_PACKET_DECISION=ACCEPT$' <<<"$fraction_output" || fail "fraction fixture rejected"
grep -q '^FGC13_PACKET_DECISION=ACCEPT$' <<<"$direct_output" || fail "direct-budget fixture rejected"

python3 - "$fraction_output" "$direct_output" <<'PY'
import json, math, sys
fraction = json.loads(sys.argv[1].splitlines()[-1])
direct = json.loads(sys.argv[2].splitlines()[-1])
assert fraction['qoi_kind'] == 'GROUNDWATER_HEAD'
assert fraction['qoi_kind_value'] == 1
assert math.isclose(fraction['h_app_cm'], 8.0)
assert math.isclose(fraction['a_temporal'], 0.25)
assert math.isclose(fraction['model_temporal_indicator_budget_cm'], 2.0)
assert fraction['source_policy_mode'] == 'FRACTION_OF_APPLICATION_REQUIREMENT'
assert direct['qoi_kind'] == 'GROUNDWATER_DRAWDOWN'
assert direct['qoi_kind_value'] == 2
assert math.isclose(direct['h_app_cm'], 10.0)
assert math.isclose(direct['a_temporal'], 0.2)
assert math.isclose(direct['model_temporal_indicator_budget_cm'], 2.0)
assert direct['source_policy_mode'] == 'DIRECT_HEAD_ERROR_BUDGET_CM'
print('FGC13_POSITIVE_MAPPING_ORACLES=PASS')
PY

python3 "$VALIDATOR" \
  --rejection-matrix "$FIXTURES/rejection_matrix.json" \
  --fixtures-dir "$FIXTURES"

echo "FGC13_FORBIDDEN_POLICY_SUBSTITUTIONS=PASS"
echo "FGC13_EXTERNAL_PROVENANCE_SEPARATION=PASS"
echo "FGC13_DIRECT_BUDGET_REPARAMETERIZATION=PASS"
echo "FGC13_MASS_CONSERVATION_RELAXED=NO"
echo "FGC13_PROJECT_ACCURACY_EVIDENCE_GOVERNANCE_GATE PASS"
