#!/usr/bin/env bash
set -euo pipefail

PLAN="integration/f-gc/F-GC04_CHARACTERIZATION_PLAN.json"
GC03="integration/f-gc/F-GC03_CLOSEOUT.json"

expect_blob() {
  local path="$1" expected="$2"
  local got
  got="$(git hash-object "$path")"
  [[ "$got" == "$expected" ]] || {
    echo "FGC04_FAIL blob $path expected=$expected got=$got"
    exit 1
  }
}

expect_blob "$PLAN" "aad2cc77490e6d3ad1e3cc4fde0d4753b30a738f"
expect_blob "$GC03" "33e56ca3dd0c55fec1bdd70019cca0096e5d53c2"

fetch_ref() {
  local branch="$1"
  git fetch --quiet --no-tags origin \
    "refs/heads/${branch}:refs/remotes/origin/${branch}"
}

fetch_ref qualification/f-vq29-richards-fixed-horizon-error-bound
fetch_ref qualification/f-vq30-bounded-stiffness-aware-temporal-indicator
fetch_ref qualification/f-vq31-transaction-composed-richards-temporal-history
fetch_ref qualification/f-vq32-richards-head-budget-normalization
fetch_ref qualification/f-vq34-remediated-richards-head-budget-certificate

expect_remote_blob() {
  local branch="$1" path="$2" expected="$3"
  local got
  got="$(git rev-parse "refs/remotes/origin/${branch}:${path}")"
  [[ "$got" == "$expected" ]] || {
    echo "FGC04_FAIL remote blob ${branch}:${path} expected=$expected got=$got"
    exit 1
  }
}

expect_remote_blob qualification/f-vq29-richards-fixed-horizon-error-bound \
  integration/f-vq/F-VQ29_STATUS.json \
  d7bbeff65f9d506e5144b3b885930a835a1cef35
expect_remote_blob qualification/f-vq30-bounded-stiffness-aware-temporal-indicator \
  integration/f-vq/F-VQ30_HELD_OUT_EVIDENCE.json \
  39832173174271f4ad97278662467eb4dab13599
expect_remote_blob qualification/f-vq30-bounded-stiffness-aware-temporal-indicator \
  integration/f-vq/F-VQ30_CLOSEOUT.json \
  6663bcc1149f07962bb9921840958d6d7de628a4
expect_remote_blob qualification/f-vq31-transaction-composed-richards-temporal-history \
  integration/f-vq/F-VQ31_INDEPENDENT_EVIDENCE.json \
  b68ba117ae470d4a6b2ca3b55b9c1697cbcd1923
expect_remote_blob qualification/f-vq32-richards-head-budget-normalization \
  integration/f-vq/F-VQ32_INDEPENDENT_EVIDENCE.json \
  f27cfd22f16cea16bee8c8a27e0c34b23c5dcc53
expect_remote_blob qualification/f-vq32-richards-head-budget-normalization \
  integration/f-vq/F-VQ32_CLOSEOUT.json \
  51b075c6f72880897416bdcfd92549bd68d26b7b
expect_remote_blob qualification/f-vq34-remediated-richards-head-budget-certificate \
  integration/f-vq/F-VQ34_CLOSEOUT.json \
  2bf2c2e790abac2ee4dc3cd6ee51c5e579859270

python3 - <<'PY'
import json
import math
import pathlib
import statistics
import subprocess

plan = json.loads(pathlib.Path('integration/f-gc/F-GC04_CHARACTERIZATION_PLAN.json').read_text())
gc03 = json.loads(pathlib.Path('integration/f-gc/F-GC03_CLOSEOUT.json').read_text())

loaded_specs = []
def remote_json(branch, path):
    spec = f'refs/remotes/origin/{branch}:{path}'
    loaded_specs.append(spec)
    return json.loads(subprocess.check_output(['git', 'show', spec], text=True))

vq29 = remote_json('qualification/f-vq29-richards-fixed-horizon-error-bound',
                   'integration/f-vq/F-VQ29_STATUS.json')
vq30e = remote_json('qualification/f-vq30-bounded-stiffness-aware-temporal-indicator',
                    'integration/f-vq/F-VQ30_HELD_OUT_EVIDENCE.json')
vq30c = remote_json('qualification/f-vq30-bounded-stiffness-aware-temporal-indicator',
                    'integration/f-vq/F-VQ30_CLOSEOUT.json')
vq31 = remote_json('qualification/f-vq31-transaction-composed-richards-temporal-history',
                   'integration/f-vq/F-VQ31_INDEPENDENT_EVIDENCE.json')
vq32e = remote_json('qualification/f-vq32-richards-head-budget-normalization',
                    'integration/f-vq/F-VQ32_INDEPENDENT_EVIDENCE.json')
vq32c = remote_json('qualification/f-vq32-richards-head-budget-normalization',
                    'integration/f-vq/F-VQ32_CLOSEOUT.json')
vq34 = remote_json('qualification/f-vq34-remediated-richards-head-budget-certificate',
                   'integration/f-vq/F-VQ34_CLOSEOUT.json')

# G01/G02: frozen source universe only; no target F-GC02 result or physical fixture is loaded.
assert plan['analysis_rules']['no_FGC02_execution'] is True
assert plan['analysis_rules']['no_FGC02_B_inf_read_or_derivation'] is True
assert plan['analysis_rules']['no_target_trial_result_use'] is True
assert all('F-GC02' not in spec and 'fgc02' not in spec.lower() for spec in loaded_specs)
assert len(loaded_specs) == 7

# Extract only independently executed B_inf observations from three disjoint VQ matrices.
v30 = [float(row['B_inf']) for row in vq30e['case_rows']]
v31 = [float(row['direct_B_inf']) for row in vq31['disjoint_case_rows']]
v32 = [float(row['B_inf_cm']) for row in vq32e['fresh_nonlinear_matrix']['rows']]
assert len(v30) == 16
assert len(v31) == 12
assert len(v32) == 12
assert all(math.isfinite(x) and x >= 0.0 for x in v30 + v31 + v32)
values = v30 + v31 + v32
assert len(values) == 40

# Matrix independence and semantics are retained from source-bound evidence.
assert vq30e['qualification_plan']['owner_exact_triplet_overlap'] == 0
assert vq30e['held_out_matrix']['exact_triplet_overlap_with_F_SI24_owner_matrix'] == 0
assert vq31['independent_disjoint_matrix']['exact_triplet_overlap_with_prior_matrices'] == 0
assert vq32e['fresh_nonlinear_matrix']['exact_triplet_overlap_with_prior_owner_or_VQ_matrices'] == 0

# Negative evidence: no true-error bound or scientific/application tolerance can be inferred.
assert vq29['decision_class'] == 'FINITE_REFERENCE_NOT_STRONG_ENOUGH_FOR_ERROR_BOUND_QUALIFICATION'
assert vq29['gate_A_result']['cases_reaching_bound_derivation'] == 0
assert vq29['gate_A_result']['scientific_temporal_tolerance_selected'] is False
assert vq29['not_qualified']['defect_to_remaining_error_upper_bound'] is True
assert vq29['not_qualified']['application_or_scientific_temporal_tolerance'] is True

assert vq30c['held_out_result_shape']['remaining_conservatism'] == 'LARGE_AND_STATE_AND_HORIZON_DEPENDENT'
assert vq30c['held_out_result_shape']['B_inf_over_E1_512_min'] == vq30e['aggregate_results']['B_inf_over_E1_512_min']
assert vq30c['held_out_result_shape']['B_inf_over_E1_512_max'] == vq30e['aggregate_results']['B_inf_over_E1_512_max']
assert any('not qualified as a true general nonlinear error upper bound' in x for x in vq30c['hard_nonclaims'])
assert any('No scientific temporal tolerance is selected' in x for x in vq30c['hard_nonclaims'])

# VQ31 is composition equivalence only, not truth/error calibration.
assert vq31['independent_disjoint_matrix']['truth_or_N512_comparator_used'] is False
assert vq31['independent_disjoint_matrix']['role'] == 'composition equivalence only'
assert any('No scientific temporal normalization or application tolerance is selected' in x for x in vq31['hard_nonclaims'])

# VQ32's 0.01/0.1/1.0 cm values are explicitly algebraic probes, not application values.
assert vq32e['synthetic_budget_probes']['values_cm'] == [0.01, 0.1, 1.0]
assert vq32e['synthetic_budget_probes']['scientific_or_application_tolerance_admitted'] is False
assert any('test probes, not qualified application tolerances' in x for x in vq32e['hard_nonclaims'])
assert any('No numeric H_budget or universal temporal tolerance is qualified' in x for x in vq32e['hard_nonclaims'])
assert vq32c['decision'] == 'QUALIFIED_INDEPENDENT_EXPLICIT_HEAD_BUDGET_NORMALIZATION_READY_FOR_SEPARATE_PRODUCTION_POLICY_BINDING'

# VQ34 and GC03 preserve the same downstream boundary.
assert vq34['qualified_semantics']['default_H_budget'] is None
assert any('does not select, recommend or qualify a numeric H_budget' in x for x in vq34['hard_nonclaims'])
assert vq34['downstream_handoff']['GC02_release'] is False
assert gc03['decision'] == 'POLICY_CONTRACT_QUALIFIED_NUMERIC_APPLICATION_REQUIREMENT_STILL_MISSING'
assert gc03['not_qualified_or_not_present']['numeric_application_H_budget'] is None
assert gc03['downstream_state']['F_VQ35'] == 'NOT_OPENED_AND_NOT_AUTHORIZED'

# Plan hard boundaries remain intact.
for key in [
    'no_numeric_H_budget_selection', 'no_recommended_H_budget', 'no_universal_default',
    'no_true_error_bound_claim', 'no_monotonic_dt_claim', 'no_coupling_tolerance_equivalence',
    'existing_executed_evidence_only', 'distinguish_indicator_scale_from_application_accuracy_requirement']:
    assert plan['analysis_rules'][key] is True

summary = {
    'VQ30': (len(v30), min(v30), statistics.median(v30), max(v30)),
    'VQ31': (len(v31), min(v31), statistics.median(v31), max(v31)),
    'VQ32': (len(v32), min(v32), statistics.median(v32), max(v32)),
    'ALL': (len(values), min(values), statistics.median(values), max(values)),
}

print('FGC04_G01_SOURCE_LOCKS_AND_TARGET_ISOLATION=PASS')
print('FGC04_G02_NO_FGC02_TARGET_RESULT_ACCESS=PASS')
for name in ('VQ30','VQ31','VQ32','ALL'):
    count, mn, med, mx = summary[name]
    print(f'FGC04_{name}_COUNT={count}')
    print(f'FGC04_{name}_BINF_MIN_CM={mn:.17e}')
    print(f'FGC04_{name}_BINF_MEDIAN_CM={med:.17e}')
    print(f'FGC04_{name}_BINF_MAX_CM={mx:.17e}')
print(f"FGC04_VQ30_BINF_OVER_E1_512_MIN={vq30e['aggregate_results']['B_inf_over_E1_512_min']:.17e}")
print(f"FGC04_VQ30_BINF_OVER_E1_512_MAX={vq30e['aggregate_results']['B_inf_over_E1_512_max']:.17e}")
print('FGC04_VQ30_REMAINING_CONSERVATISM=LARGE_AND_STATE_AND_HORIZON_DEPENDENT')
print('FGC04_G03_QUANTITATIVE_EVIDENCE_EXTRACTED=PASS')
print('FGC04_G04_FVQ29_NEGATIVE_BOUND_EVIDENCE_PRESERVED=PASS')
print('FGC04_G05_INDICATOR_SCALE_NOT_APPLICATION_REQUIREMENT=PASS')
print('FGC04_G06_NO_NUMERIC_SELECTION_OR_RECOMMENDATION=PASS')
print('FGC04_G07_NO_TRUE_ERROR_OR_MONOTONICITY_OVERCLAIM=PASS')
print('FGC04_G08_NEXT_DECISION_BOUNDARY_EXPLICIT=PASS')
print('FGC04_G09_CORE_INVARIANT_AUDIT=PASS')
print('FGC04_APPLICATION_NUMERIC_H_BUDGET_PRESENT=NO')
print('FGC04_FGC02_RELEASE=NO')
print('FGC04_FVQ35_AUTHORIZED=NO')
print('FGC04_INDEPENDENT_HEAD_BUDGET_SCALE_CHARACTERIZATION PASS')
PY
