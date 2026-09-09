#!/usr/bin/env python3
import json
import math
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLAN = ROOT / 'integration/f-vq/F-VQ32_QUALIFICATION_PLAN.json'
PLAN_BLOB = 'e47b71d25133902967294583801df720cac9cd63'


def require(ok, label):
    if not ok:
        raise SystemExit('FVQ32_FAIL ' + label)


def blob_at(ref, path):
    return subprocess.check_output(['git', 'rev-parse', f'{ref}:{path}'], cwd=ROOT, text=True).strip()


def load_at(ref, path):
    return json.loads(subprocess.check_output(['git', 'show', f'{ref}:{path}'], cwd=ROOT, text=True))

require(blob_at('HEAD', 'integration/f-vq/F-VQ32_QUALIFICATION_PLAN.json') == PLAN_BLOB, 'frozen plan drift')
p = json.loads(PLAN.read_text())
require(p['work_unit'] == 'F-VQ32', 'plan identity')
require(p['frozen_before_execution'] is True, 'plan not frozen')
require(p['candidate_lock']['id'] == 'F_SI26_EXPLICIT_HEAD_INDICATOR_BUDGET_RATIO', 'candidate id drift')
require(p['candidate_lock']['formula'] == 'C_h=B_inf/H_budget', 'candidate formula drift')
require(p['candidate_lock']['default_H_budget'] is None, 'hidden default budget')
require(p['candidate_lock']['empirical_multiplier'] is None, 'empirical multiplier present')
require(p['candidate_lock']['nonlinear_true_error_bound_claim'] is False, 'nonlinear bound overclaim')

for name, lock in p['source_locks'].items():
    ref = lock.get('commit', 'HEAD')
    got = blob_at(ref, lock['path'])
    require(got == lock['blob'], f'source lock {name}: {got} != {lock["blob"]}')
print('FVQ32_G01_SOURCE_AND_CANDIDATE_LOCK=PASS')

fsi26 = json.loads((ROOT/'integration/f-si/F-SI26_CLOSEOUT.json').read_text())
require(fsi26['decision'] == 'SCIENTIFIC_NORMALIZATION_CANDIDATE_READY_FOR_INDEPENDENT_QUALIFICATION', 'F-SI26 decision drift')
require(fsi26['candidate']['formula'] == 'C_h=B_inf/H_budget', 'F-SI26 formula drift')
require(fsi26['candidate']['default_H_budget'] is None, 'F-SI26 default budget drift')

fkt09 = json.loads((ROOT/'integration/f-kt/F-KT09_DECISION_CONTRACT.json').read_text())
cmode = fkt09['candidate_mode']
require(cmode['certificate_indicator'] == 'dimensionless real scalar', 'F-KT09 indicator type')
require('indicator <= 1' in cmode['generic_acceptance'], 'F-KT09 <=1 shape')
require(cmode['unavailable_semantics'] == 'FAIL_CLOSED_TEMPORAL_REJECTION', 'F-KT09 unavailable semantics')
require(fkt09['hard_constraints']['numeric_temporal_limits_selected'] is False, 'F-KT09 numeric limit unexpectedly selected')
print('FVQ32_G10_FKT09_COMPATIBILITY_NO_ACTIVATION=PASS')

# Independent scalar dissipative reconstruction. These x points are frozen in
# the VQ32 plan and are intentionally distinct from the owner test matrix.
xs = [float(x) for x in p['independent_exact_linear_matrix']['x_values']]
budgets = [float(h) for h in p['synthetic_budget_probe_set_cm']]
require(xs == [0.015625, 0.0625, 0.25, 1.0, 4.0, 16.0], 'exact-linear matrix drift')
require(budgets == [0.01, 0.1, 1.0], 'synthetic budget matrix drift')

rows = []
for x in xs:
    y_be = 1.0/(1.0+x)
    y_exact = math.exp(-x)
    exact_error = abs(y_be-y_exact)
    e_raw = 0.5*x*x/(1.0+x)
    double_defect = x*x/(1.0+x)**2
    b_inf = min(e_raw, double_defect)
    require(math.isfinite(b_inf) and b_inf >= 0.0, f'finite B_inf x={x}')
    require(exact_error <= b_inf + 64.0*math.ulp(max(1.0,b_inf,exact_error)), f'exact-linear bound x={x}')
    certs = []
    for H in budgets:
        C = b_inf/H
        require(math.isfinite(C) and C >= 0.0, f'finite C x={x} H={H}')
        require((C <= 1.0) == (b_inf <= H), f'threshold equivalence x={x} H={H}')
        if C <= 1.0:
            require(exact_error <= H + 64.0*math.ulp(max(1.0,H,exact_error)), f'exact-linear budget implication x={x} H={H}')
        certs.append(C)
    require(abs(certs[0]/10.0-certs[1]) <= 64.0*math.ulp(max(1.0,abs(certs[1]))), f'decade scaling 0.01->0.1 x={x}')
    require(abs(certs[1]/10.0-certs[2]) <= 64.0*math.ulp(max(1.0,abs(certs[2]))), f'decade scaling 0.1->1 x={x}')
    rows.append((x, exact_error, b_inf, certs))
print(f'FVQ32_G02_EXACT_LINEAR_CASES={len(rows)}')
print('FVQ32_G02_INDEPENDENT_EXACT_LINEAR_RECONSTRUCTION=PASS')
print('FVQ32_G03_DIMENSIONLESS_BUDGET_ALGEBRA=PASS')


def cert(binf, H):
    if binf is None:
        return None
    if not (math.isfinite(binf) and binf >= 0.0):
        return None
    if not (math.isfinite(H) and H > 0.0):
        return None
    return binf/H

for H in [0.0, -1.0, math.inf, math.nan]:
    require(cert(0.125, H) is None, f'invalid budget {H}')
for B in [-1.0, math.inf, math.nan]:
    require(cert(B, 0.1) is None, f'invalid B_inf {B}')
require(cert(None, 0.1) is None, 'unavailable B_inf')
require(abs(cert(0.125, 0.5)-0.25) <= 1e-15, 'valid normalization')
print('FVQ32_G04_INVALID_INPUT_FAIL_CLOSED=PASS')

fvq28 = load_at('d8bcb1c90e897812ae8b91295be98e58023e10fb', 'integration/f-vq/F-VQ28_STATUS.json')
fvq29 = load_at('394d064a0dad0a7f7852b129bae99713b9aeb4c0', 'integration/f-vq/F-VQ29_STATUS.json')
require(fvq28['gate_B']['underconservative_resolved_attempts'] == 36, 'F-VQ28 negative attempt count')
require(fvq28['qualified_interpretation']['existing_retry_shortening_is_safe_translation_of_gate_A'] is False, 'F-VQ28 retry warning')
require(fvq28['qualified_interpretation']['universal_absolute_tolerance_admitted'] is False, 'F-VQ28 absolute tolerance admission drift')
require(fvq29['status'] == 'COMPLETE_FAIL_CLOSED_FINITE_REFERENCE_NOT_STRONG_ENOUGH_FOR_ERROR_BOUND_QUALIFICATION', 'F-VQ29 fail-closed status')
require(fvq29['not_qualified']['defect_to_remaining_error_upper_bound'] is True, 'F-VQ29 error-bound nonqualification')
require(fvq29['not_qualified']['application_or_scientific_temporal_tolerance'] is True, 'F-VQ29 tolerance nonqualification')
print('FVQ32_G09_NEGATIVE_EVIDENCE_PRESERVED=PASS')

# Ensure VQ32 has not changed product source while qualifying normalization.
srcdiff = subprocess.check_output(['git','diff','--name-only',p['base_commit']+'..HEAD','--','src'], cwd=ROOT, text=True).strip()
require(srcdiff == '', 'production source changed in F-VQ32')
print('FVQ32_G08_NONLINEAR_CLAIM_BOUNDARY=PASS')
print('FVQ32_VQ_OWNED_SEMANTIC_GATE PASS')
