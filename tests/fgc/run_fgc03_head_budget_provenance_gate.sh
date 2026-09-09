#!/usr/bin/env bash
set -euo pipefail

PLAN="integration/f-gc/F-GC03_POLICY_PLAN.json"
CONTRACT="integration/f-gc/F-GC03_HEAD_ACCURACY_BUDGET_PROVENANCE_CONTRACT.json"

expect_blob() {
  local path="$1" expected="$2"
  local got
  got="$(git hash-object "$path")"
  [[ "$got" == "$expected" ]] || { echo "FGC03_FAIL blob $path expected=$expected got=$got"; exit 1; }
}

expect_blob "$PLAN" "8e51f7a577dd3f3f24a7d6125f80b0cc86274044"
expect_blob "$CONTRACT" "ef7465473c0cb6f88f7c192cee4aad3185718969"
expect_blob "integration/f-gc/F-GC01_INTERFACE_CONTRACT.json" "fb1d0df4c78cffb74dabaa7ef1c2ff1bf992763c"
expect_blob "integration/f-gc/F-GC02_PHYSICAL_COUPLING_FAILURE_DIAGNOSIS.json" "2ac62f9d87ee774d50ef48309ef1ac4c9a1ed466"
expect_blob "tests/fgc/test_fgc02_physical_coupling.f90" "d8c3863a1acb08eb60712c7dd58bafc4cc5de5a6"

git fetch --quiet --no-tags origin \
  refs/heads/work/f-kt11-richards-head-budget-certificate-policy:refs/remotes/origin/work/f-kt11-richards-head-budget-certificate-policy
git fetch --quiet --no-tags origin \
  refs/heads/qualification/f-vq34-remediated-richards-head-budget-certificate:refs/remotes/origin/qualification/f-vq34-remediated-richards-head-budget-certificate

[[ "$(git rev-parse 'origin/work/f-kt11-richards-head-budget-certificate-policy:integration/f-kt/F-KT11_FVQ34_HANDOFF.json')" == \
   "51890fca7138021385f3366167ade92ef6daffb4" ]] || { echo "FGC03_FAIL F-KT11 handoff blob"; exit 1; }
[[ "$(git rev-parse 'origin/qualification/f-vq34-remediated-richards-head-budget-certificate:integration/f-vq/F-VQ34_CLOSEOUT.json')" == \
   "2bf2c2e790abac2ee4dc3cd6ee51c5e579859270" ]] || { echo "FGC03_FAIL F-VQ34 closeout blob"; exit 1; }

python3 - <<'PY'
import json, math, pathlib, subprocess

plan = json.loads(pathlib.Path('integration/f-gc/F-GC03_POLICY_PLAN.json').read_text())
contract = json.loads(pathlib.Path('integration/f-gc/F-GC03_HEAD_ACCURACY_BUDGET_PROVENANCE_CONTRACT.json').read_text())
gc01 = json.loads(pathlib.Path('integration/f-gc/F-GC01_INTERFACE_CONTRACT.json').read_text())
gc02 = json.loads(pathlib.Path('integration/f-gc/F-GC02_PHYSICAL_COUPLING_FAILURE_DIAGNOSIS.json').read_text())

def git_json(spec):
    return json.loads(subprocess.check_output(['git','show',spec], text=True))

kt = git_json('origin/work/f-kt11-richards-head-budget-certificate-policy:integration/f-kt/F-KT11_FVQ34_HANDOFF.json')
vq = git_json('origin/qualification/f-vq34-remediated-richards-head-budget-certificate:integration/f-vq/F-VQ34_CLOSEOUT.json')

assert plan['frozen_facts']['default_budget_exists'] is False
assert plan['frozen_facts']['F_VQ34_selects_application_budget'] is False
assert plan['frozen_facts']['F_GC01_numeric_coupling_head_tolerance_exists'] is False
assert plan['frozen_facts']['F_GC02_pre_result_numeric_Richards_H_budget_exists'] is False
assert plan['frozen_facts']['predictor_perturbation_is_accuracy_budget'] is False
assert plan['frozen_facts']['old_transaction_temporal_tolerance_is_Richards_H_budget'] is False
assert plan['frozen_facts']['B_inf_is_proven_true_error_upper_bound'] is False

q = contract['quantities']
assert q['coupling_head_residual_tolerance']['native_unit'] == 'm'
assert q['coupling_head_residual_tolerance']['maps_automatically_to_H_budget'] is False
assert q['richards_temporal_head_budget']['native_unit'] == 'cm pressure head'
assert q['richards_temporal_head_budget']['default'] is None
assert q['richards_temporal_head_budget']['must_be_finite_positive'] is True
assert q['predictor_head_perturbation']['maps_automatically_to_H_budget'] is False
assert q['nonlinear_solver_tolerance']['maps_automatically_to_H_budget'] is False

required = set(contract['budget_provenance_record']['required_fields'])
assert {'value_cm','provenance_id','policy_version','scope_id','frozen_source_identity'} <= required
assert contract['unit_policy']['explicit_conversion_factor_m_to_cm'] == 100.0
assert contract['unit_policy']['automatic_derivation_from_coupling_tolerance'] is False
assert contract['error_claim_boundary']['B_inf_is_proven_nonlinear_true_error_bound'] is False
assert contract['error_claim_boundary']['C_h_le_1_proves_total_application_head_error_within_budget'] is False
assert contract['error_claim_boundary']['coupling_and_temporal_errors_may_be_rigorously_added_without_separate_proof'] is False

assert gc01['convergence']['head_tolerance_explicit_per_contract'] is True
# The frozen contract requires an explicit tolerance but contains no numeric value.
assert not any(isinstance(v, (int,float)) and not isinstance(v, bool) for v in gc01['convergence'].values())
fixture = gc02['failing_fixture']
assert fixture['t0'] == 4100.125
assert fixture['t1'] == 4100.375
assert fixture['initial_profile_head_cm'] == -75.0
assert fixture['corrector_bottom_head_cm'] == -75.0
assert fixture['predictor_bottom_head_cm'] == -74.99
assert fixture['transaction_temporal_tolerance'] == 0.0
assert math.isclose(fixture['predictor_bottom_head_cm'] - fixture['corrector_bottom_head_cm'], 0.01, rel_tol=0.0, abs_tol=2e-14)

assert kt['fixed_semantics']['no_default_budget'] is True
assert kt['independent_requirements']['no_application_budget_selection'] is True
assert kt['gc02_release'] is False
assert vq['qualified_semantics']['default_H_budget'] is None
assert 'does not select, recommend or qualify a numeric H_budget' in vq['hard_nonclaims'][0]
assert vq['downstream_handoff']['GC02_release'] is False
assert contract['current_policy_state']['numeric_H_budget_selected'] is False
assert contract['current_policy_state']['FGC02_execution_authorized'] is False
assert contract['current_policy_state']['F_VQ35_execution_authorized'] is False
assert contract['frozen_FGC02_reexecution_release_condition']['currently_satisfied'] is False

for forbidden in [
    'CURRENT_TRIAL_B_INF_OR_FUNCTION_OF_B_INF',
    'F_VQ34_QUALIFICATION_ONLY_BUDGET_CONSTRUCTION',
    'FGC02_PREDICTOR_HEAD_PERTURBATION',
    'LEGACY_BINARY_TRANSACTION_TEMPORAL_TOLERANCE',
    'NONLINEAR_NEWTON_TOLERANCE',
    'UNQUALIFIED_COUPLING_HEAD_RESIDUAL_TOLERANCE',
    'MATERIAL_SPECIFIC_POST_HOC_TUNING']:
    assert forbidden in contract['nonadmissible_provenance_classes']

print('FGC03_G01_SOURCE_AND_CHRONOLOGY_LOCKS=PASS')
print('FGC03_G02_EXPLICIT_QUANTITY_AND_UNIT_SEPARATION=PASS')
print('FGC03_G03_ADMISSIBLE_PROVENANCE_CLASSES_DEFINED=PASS')
print('FGC03_G04_FORBIDDEN_POST_HOC_DERIVATIONS_FAIL_CLOSED=PASS')
print('FGC03_G05_NO_DEFAULT_OR_HIDDEN_0P01CM=PASS')
print('FGC03_G06_NO_TRUE_ERROR_BOUND_OVERCLAIM=PASS')
print('FGC03_G07_RUNTIME_DIAGNOSTIC_PROVENANCE_CONTRACT=PASS')
print('FGC03_G08_FGC02_REEXECUTION_RELEASE_CONDITION_DEFINED=PASS')
print('FGC03_G09_CORE_INVARIANT_POLICY_SEPARATION=PASS')
print('FGC03_NUMERIC_APPLICATION_H_BUDGET_PRESENT=NO')
print('FGC03_FGC02_EXECUTION_AUTHORIZED=NO')
print('FGC03_HEAD_BUDGET_PROVENANCE_POLICY_GATE PASS')
PY
