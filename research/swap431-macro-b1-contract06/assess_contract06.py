"""Primary-contract conformance, local pair and independent accepted inventory."""
from pathlib import Path
import json,math,sys,hashlib
R=Path(__file__).resolve().parent
PREV=R.parent/'swap431-macro-b1-stagnation05'
cols=json.loads((R/'ABSORPTION_COLUMNS.json').read_text())
def fields(p):return {s.split()[0]:list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
def absorption(p):
    rows=[list(map(float,s.split())) for s in p.read_text().splitlines()]
    assert all(len(x)==len(cols) for x in rows)
    return [dict(zip(cols,x)) for x in rows]
def save(p,x):p.write_text(json.dumps(x,indent=2)+'\n')
result=[]
for opt in ['O2','O0']:
    identity=json.loads((R/(opt+'_IDENTITY.json')).read_text())
    assert all(hashlib.sha256((R/name).read_bytes()).hexdigest()==digest for name,digest in identity['sources'].items())
    base=R/'data'/opt/'BASE_RIGHT';left=R/'data'/opt/'PATCH_LEFT';right=R/'data'/opt/'PATCH_RIGHT';solve=R/'data'/opt/'PATCH_SOLVE'
    for name in ['origin.txt','begin_1.txt','solver_1.txt','probe_memory.txt']:
        assert (base/name).read_bytes()==(PREV/'data'/opt/'RIGHT'/name).read_bytes()
    for d in [left,right,solve]:assert fields(d/'origin.txt')==fields(base/'origin.txt')
    b=absorption(base/'absorption.txt')[-1];p=absorption(right/'absorption.txt')[-1]
    assert b['node']==45 and b['layer']==5 and b['h']>-10 and b['h']<0
    assert b['theta_s']-b['theta']>1e-8 and b['HMp']>0 and b['k']>0 and b['RecRes']>0
    # Independent documented pressure-gradient requirement, before availability
    # limits: positive conductance and gradient must not yield zero Darcy.
    expected=b['RecRes']*max(0,b['HMp']-b['h'])*b['dt']
    assert b['raw_darcy']==0 and expected>0
    assert p['h']==b['h'] and p['HMp']==b['HMp'] and p['RecRes']==b['RecRes']
    assert abs(p['raw_darcy']-expected)<=64*sys.float_info.epsilon*expected
    assert p['chosen_potential']==max(p['raw_sorp'],p['sorp_factor']*p['raw_darcy'])
    l=fields(left/'solver_1.txt');r=fields(right/'solver_1.txt')
    assert [i for i,(x,y) in enumerate(zip(l['h'],r['h'])) if x!=y]==[44]
    oldleft=fields(PREV/'data'/opt/'LEFT/solver_1.txt');oldright=fields(PREV/'data'/opt/'RIGHT/solver_1.txt')
    oldjump=oldright['qexchange'][44]-oldleft['qexchange'][44];jump=r['qexchange'][44]-l['qexchange'][44]
    assert abs(jump)<1e-7 and abs(oldjump)>.1
    a=fields(solve/'origin.txt');trial=fields(solve/'trial.txt');c=fields(solve/'committed.txt');s=fields(solve/'solver_1.txt')
    assert (solve/'outcome.txt').read_text().split()[0]=='ACCEPTED_UNREDUCED'
    assert s['outcome']==[0.,3.,1.] and s['controls'][2]==0
    assert a['controls'][:3]==[35796.9513533331,0.0001414213562373095,1.]
    dt=s['controls'][1];n=int(s['controls'][3]);nd=int(a['controls'][4])
    assert n==112 and nd==5 and a['fraction']==trial['fraction']==c['fraction']
    grad=[(s['h'][j-1]-s['h'][j])/(.5*(s['dz'][j-1]+s['dz'][j]))+1 for j in range(1,n)]
    assert grad==s['hgrad'][1:n]
    q=[s['boundary'][0]]+[-k*g for k,g in zip(s['kmean'][1:n],grad)]+[s['boundary'][1]]
    changes=[(y-x)*d*f for x,y,d,f in zip(a['theta'],c['theta'],a['dz'],a['fraction'])]
    reconstructed=[changes[j]/dt+s['sink'][j]-s['source'][j]+s['qroot'][j]+q[j]-q[j+1]-s['qexchange'][j] for j in range(n)]
    rem=max(abs(x-y) for x,y in zip(reconstructed,s['residual']));assert rem<64*sys.float_info.epsilon
    local=max(map(abs,s['residual']));total=math.fsum(s['residual'])
    assert local<=s['controls'][5] and abs(total)<=s['controls'][6]
    md=math.fsum(changes);exc=math.fsum(trial['matrix_exchange']);qt,qb,P,I,M,runon,epd,reva=trial['boundary_rates']
    merror=md-dt*(qb-qt-math.fsum(trial['matrix_root'])-math.fsum(trial['matrix_drains'])+math.fsum(trial['matrix_ssdi'])+exc)
    assert abs(merror)<=dt*s['controls'][6]
    domain=[]
    for j in range(nd):
        ex=math.fsum(trial['macro_exchange'][j::nd]);rapid=math.fsum(trial['macro_rapid']) if j==0 else 0
        rate=trial['macro_in_lat'][j]+trial['macro_in_vert'][j]-ex-rapid
        delta=c['macro_domain'][j]-a['macro_domain'][j];envelope=64*sys.float_info.epsilon*max(1,abs(a['macro_domain'][j]))
        assert a['macro_domain'][j]+dt*rate>=0
        assert abs(delta-dt*rate)<=envelope
        assert abs(math.fsum(c['macro_compartment'][j::nd])-c['macro_domain'][j])<=envelope
        domain.append(dict(domain=j+1,change=delta,error_cm=delta-dt*rate))
    pair=[sum(trial['macro_exchange'][j*nd:(j+1)*nd]) for j in range(n)]
    pairerr=max(abs(x-y) for x,y in zip(pair,trial['matrix_exchange']));assert pairerr<64*sys.float_info.epsilon
    mp=math.fsum(x['change'] for x in domain);pd=c['pond'][0]-a['pond'][0]
    surface_error=pd-dt*(P+I+M+runon-epd-reva+qt-math.fsum(trial['macro_in_lat'])-math.fsum(trial['macro_in_vert']))+trial['surface'][0]
    assert abs(surface_error)<=s['controls'][7]
    external=dt*(P+I+M+runon-epd-reva+qb-math.fsum(trial['matrix_root'])-math.fsum(trial['matrix_drains'])+math.fsum(trial['matrix_ssdi'])-math.fsum(trial['macro_rapid']))-trial['surface'][0]
    combined=md+mp+pd-external
    assert abs(combined-dt*total-surface_error)<64*sys.float_info.epsilon*max(1,math.fsum(a['macro_domain']))
    result.append(dict(optimization=opt,baseline_noninterference_exact=True,baseline_contract_violation=dict(node=45,layer=5,head=b['h'],HMp=b['HMp'],theta_deficit=b['theta_s']-b['theta'],conductivity=b['k'],raw_Darcy_actual=0.,raw_Darcy_expected=expected),
        corrected_raw_Darcy=p['raw_darcy'],original_q45_jump=oldjump,corrected_q45_pair_difference=jump,
        accepted_iterations=3,accepted_IDecMpRat=0,accepted_FrReduQ=1.,local_residual=local,total_residual=total,
        accepted_h45=s['h'][44],independent_residual_difference=rem,matrix_change_cm=md,macro_change_cm=mp,
        matrix_balance_error_cm=merror,surface_balance_error_cm=surface_error,combined_balance_error_cm=combined,
        paired_exchange_error=pairerr,domain_inventory=domain,max_clock_begin=max(a['clock']),max_clock_after_commit=max(c['clock'])))
for profile in ['BASE_RIGHT','PATCH_RIGHT','PATCH_LEFT','PATCH_SOLVE']:
    for p in (R/'data/O2'/profile).glob('*.txt'):
        assert p.read_bytes()==(R/'data/O0'/profile/p.name).read_bytes(),str(p)
runs=[json.loads(p.read_text()) for p in R.glob('O[02]_*_RUN.json')]
assert len(runs)==8 and all(x['returncode']==0 and not x['censored'] and x['seconds']<20 for x in runs)
report=dict(work_unit='SWAP431-MACRO-B1-CONTRACT06',baseline='81e00d043ce322a60f4377a93c56e64beed3f90a',
    decision='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',candidate='Existing V1 plus one-line documented unsaturated Darcy-gate repair',
    physical_contract='Pressure-gradient Darcy infiltration where fully water-filled macropore wall contacts unsaturated matrix; retain original sorption/Darcy maximum and stock limits. No additional negative-air-entry exclusion.',
    finding='The gate was deliberately written (GEM comment), but contradicts the documented field-process contract and active zero-head saturation routing in this context. No documented alternate intended zero-transfer interval was found. This is an implementation-to-documented-contract defect, not proof of the exact historical author intent.',
    minimal_experimental_correction_supported=True,official_reference_promoted=False,production_changed=False,
    inherited_physical_formulas_solver_tolerances_dt_limits_and_reduction_law_unchanged=True,
    changed_physical_implementation='Only remove H<h_enpr exclusion from ABSORPTION; outer zone/wet-wall eligibility, HMp gate and nonnegative pressure gradient remain.',
    O0_O2_all_final_raw_profiles_byte_exact=True,final_routes=8,preliminary_routes=3,model_censored=0,
    final_max_model_seconds=max(x['seconds'] for x in runs),final_total_model_seconds=sum(x['seconds'] for x in runs),
    setup_link_errors=1,additional_memory_patch=False,results=result,
    exclusions=['Single original wet context and one selected pressure pair only','No corrected rejected-trial/direct-retry comparison','No original dry-event transition or own restart qualification','No qualification of the phreatic zero-head handoff, other hydraulic modes, tabulated hydraulics, or variable air-entry layers','No full trajectory qualification or B1.12/canonical/release admission','Historical GEM change rationale/complete SVN history unavailable'],
    next_safe_step='Qualify the one-line candidate on one original rejection/rollback/accepted continuation with independent inventory and short own restart; explicitly include dry/event or zero-head handoff when a distinguishing original state is available. Do not begin a broad trajectory or reference promotion.')
save(R/'RESULT.json',report)
print(json.dumps({k:v for k,v in report.items() if k!='results'},indent=2))
