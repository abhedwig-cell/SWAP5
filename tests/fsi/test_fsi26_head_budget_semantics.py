#!/usr/bin/env python3
import json
import math
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / 'integration/f-si/F-SI26_WORK_UNIT_CONTRACT.json'
ASSESSMENT = ROOT / 'integration/f-si/F-SI26_GATE_A_B_C_SEMANTIC_ASSESSMENT.json'


def require(ok, label):
    if not ok:
        raise SystemExit('FSI26_FAIL ' + label)


def git_blob(ref, path):
    return subprocess.check_output(['git','rev-parse',f'{ref}:{path}'], cwd=ROOT, text=True).strip()

c = json.loads(CONTRACT.read_text())
a = json.loads(ASSESSMENT.read_text())

require(c['work_unit'] == 'F-SI26', 'contract identity')
require(a['selected_candidate']['id'] == 'F_SI26_EXPLICIT_HEAD_INDICATOR_BUDGET_RATIO', 'selected candidate')
require(a['selected_candidate']['formula'] == 'C_h=B_inf/H_budget', 'candidate formula')
require(a['selected_candidate']['default_budget'] is None, 'no default budget')
require(a['production_source_modified'] is False, 'no production source modification claim')
require(a['scientific_application_tolerance_selected'] is False, 'no scientific application tolerance')
require(a['production_acceptance_enabled'] is False, 'no production acceptance')

for name, lock in c['source_locks'].items():
    ref = lock.get('commit','HEAD')
    got = git_blob(ref, lock['path'])
    require(got == lock['blob'], f'source lock {name}: got {got} expected {lock["blob"]}')
print('FSI26_GATE_A_SOURCE_LOCKS=PASS')

# F-KT09 is deliberately generic: it owns only the dimensionless <=1 decision seam.
fkt09 = json.loads((ROOT/'integration/f-kt/F-KT09_DECISION_CONTRACT.json').read_text())
cmode = fkt09['candidate_mode']
require(cmode['certificate_indicator'] == 'dimensionless real scalar', 'F-KT09 dimensionless contract')
require('indicator <= 1' in cmode['generic_acceptance'], 'F-KT09 <=1 acceptance shape')
require(cmode['unavailable_semantics'] == 'FAIL_CLOSED_TEMPORAL_REJECTION', 'F-KT09 unavailable fail closed')
require(fkt09['hard_constraints']['numeric_temporal_limits_selected'] is False, 'F-KT09 owns no limit')
print('FSI26_GATE_H_FKT09_COMPATIBILITY=PASS')

# Exact-linear reconstruction from the already qualified F-VQ30 oracle.  The test
# does not fit a budget: it chooses synthetic positive budgets only to verify the
# algebraic implication B_inf/H<=1 => exact_inf/H<=1 whenever B_inf is the
# theorem-qualified exact-linear infinity bound.
DZ = [0.5,0.5,1.0,1.0]
CAP = 0.001
K = 0.01
EIG1 = 0.25619777153614321838009463228648061698
EIG2 = 1.5788967897778011939109549498314371066
L1 = 2.5619777153614321838009463228648061698
L2 = 15.788967897778011939109549498314371066
V1 = [0.6752098721931038,0.5887162399055651,0.4268087132525549,0.1555537453920313]
V2 = [-0.85993755826055324873547636713317468951,-0.18106123318707904408753054543225232895,0.64075359180253965173186093246533823150,0.45088462765653286067989087747721881613]


def mnorm(x):
    return math.sqrt(sum(CAP*DZ[i]*x[i]*x[i] for i in range(4)))


def maxabs(x):
    return max(abs(v) for v in x)

rows=[]
for x in [0.025,0.1,0.4,1.6,6.4]:
    amp=10.0
    ube=[amp*v/(1.0+x) for v in V1]
    uexact=[amp*v*math.exp(-x) for v in V1]
    eraw=[0.5*amp*v*x*x/(1.0+x) for v in V1]
    delta=[0.5*amp*v*x*x/(1.0+x)**2 for v in V1]
    exact=[ube[i]-uexact[i] for i in range(4)]
    bm=min(mnorm(eraw),2.0*mnorm(delta))
    binf=bm/math.sqrt(min(CAP*d for d in DZ))
    exact_inf=maxabs(exact)
    require(exact_inf <= binf + 2e-12, f'exact-linear single-mode bound x={x}')
    rows.append((f'single-{x}',binf,exact_inf))

amp1=5.0
amp2=L1*amp1*V1[1]/(-L2*V2[1])
for dt in [0.0125,0.05,0.2,0.8,1.6]:
    x1=L1*dt; x2=L2*dt
    ube=[amp1*V1[j]/(1.0+x1)+amp2*V2[j]/(1.0+x2) for j in range(4)]
    uexact=[amp1*V1[j]*math.exp(-x1)+amp2*V2[j]*math.exp(-x2) for j in range(4)]
    eraw=[0.5*amp1*V1[j]*x1*x1/(1.0+x1)+0.5*amp2*V2[j]*x2*x2/(1.0+x2) for j in range(4)]
    delta=[0.5*amp1*V1[j]*x1*x1/(1.0+x1)**2+0.5*amp2*V2[j]*x2*x2/(1.0+x2)**2 for j in range(4)]
    exact=[ube[j]-uexact[j] for j in range(4)]
    bm=min(mnorm(eraw),2.0*mnorm(delta))
    binf=bm/math.sqrt(min(CAP*d for d in DZ))
    exact_inf=maxabs(exact)
    require(exact_inf <= binf + 2e-12, f'exact-linear multimode bound dt={dt}')
    rows.append((f'multi-{dt}',binf,exact_inf))

for label, binf, exact_inf in rows:
    require(math.isfinite(binf) and binf >= 0.0, f'finite nonnegative B_inf {label}')
    budgets=[0.5*binf if binf>0 else 0.5, binf if binf>0 else 1.0, 2.0*binf if binf>0 else 2.0, 1.0]
    previous=None
    for H in sorted(set(budgets)):
        require(math.isfinite(H) and H>0.0, f'positive synthetic budget {label}')
        C=binf/H
        require(math.isfinite(C) and C>=0.0, f'finite dimensionless certificate {label}')
        if previous is not None:
            # H increases in sorted order, so C cannot increase.
            require(C <= previous + 1e-15, f'budget monotonicity {label}')
        previous=C
        if C <= 1.0:
            require(exact_inf/H <= 1.0 + 2e-12, f'exact-linear budget implication {label}')
print(f'FSI26_GATE_B_EXACT_LINEAR_BUDGET_ROWS={len(rows)}')
print('FSI26_GATE_B_DIMENSIONAL_ALGEBRA=PASS')
print('FSI26_GATE_D_EXACT_LINEAR_ERROR_IMPLICATION=PASS')

# Nonlinear evidence is deliberately treated as transfer characterization, not truth.
fvq30=json.loads((ROOT/'integration/f-vq/F-VQ30_HELD_OUT_EVIDENCE.json').read_text())
agg=fvq30['aggregate_results']
require(agg['B_inf_over_E1_512_min'] > 1.0, 'held-out positive transfer minimum')
require(agg['B_inf_over_E1_512_max'] > 10.0*agg['B_inf_over_E1_512_min'], 'strong state/horizon-dependent conservatism')
require(fvq30['owner_source_lock']['empirical_factor_fitted'] is False, 'no empirical factor')
print('FSI26_GATE_A_NONLINEAR_TRANSFER_RECONCILIATION=PASS')
print('FSI26_GATE_D_NONLINEAR_TRUE_BOUND_CLAIM=NO')

# Existing negative evidence must remain negative and prevents monotone-retry or
# finite-reference-as-truth promotion.
fvq28=json.loads(subprocess.check_output(['git','show','d8bcb1c90e897812ae8b91295be98e58023e10fb:integration/f-vq/F-VQ28_STATUS.json'], cwd=ROOT, text=True))
fvq29=json.loads(subprocess.check_output(['git','show','394d064a0dad0a7f7852b129bae99713b9aeb4c0:integration/f-vq/F-VQ29_STATUS.json'], cwd=ROOT, text=True))
require(fvq28['gate_B']['underconservative_resolved_attempts'] == 36, 'F-VQ28 negative retry evidence')
require(fvq28['qualified_interpretation']['existing_retry_shortening_is_safe_translation_of_gate_A'] is False, 'no monotone retry translation')
require(fvq29['result'] == 'FAIL_CLOSED_FINITE_REFERENCE_NOT_STRONG_ENOUGH_FOR_ERROR_BOUND_QUALIFICATION', 'F-VQ29 fail-closed result')
require(fvq29['qualified']['finite_reference_is_true_error_bound'] is False, 'no finite reference true bound')
print('FSI26_GATE_F_NO_MONOTONE_RETRY_ASSUMPTION=PASS')
print('FSI26_GATE_D_FINITE_REFERENCE_NOT_TRUTH=PASS')

# Candidate config semantics: no hidden default, invalid budget must be unavailable.
def certificate(binf, H):
    if not (math.isfinite(binf) and binf >= 0.0 and math.isfinite(H) and H > 0.0):
        return None
    return binf/H

for bad_H in [0.0,-1.0,float('inf'),float('nan')]:
    require(certificate(0.1,bad_H) is None, 'invalid budget fail closed')
for bad_B in [-1.0,float('inf'),float('nan')]:
    require(certificate(bad_B,0.1) is None, 'invalid indicator fail closed')
require(abs(certificate(0.1,0.2)-0.5) < 1e-15, 'valid budget ratio')
print('FSI26_GATE_G_INVALID_BUDGET_FAIL_CLOSED=PASS')

# F-SI26 itself must not alter production source.
diff=subprocess.check_output(['git','diff','--name-only','0053d5b0a523e494a7fbfcdc55190b946230aa56..HEAD','--','src'], cwd=ROOT, text=True).strip()
require(diff == '', 'F-SI26 production source unchanged')
print('FSI26_GATE_C_NO_PRODUCTION_OR_EMPIRICAL_RESCUE=PASS')
print('FSI26_OWNER_HEAD_BUDGET_SEMANTICS PASS')
