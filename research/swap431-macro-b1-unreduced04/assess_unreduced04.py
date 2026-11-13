"""No-model assessment of the bounded single-origin unscaled experiment."""
from pathlib import Path
import json,math,sys

R=Path(__file__).resolve().parent
def read(p):return {s.split()[0]:list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
def delta(a,b,keys):
    return {k:max(abs(x-y) for x,y in zip(a[k],b[k])) for k in keys if a[k]!=b[k]}
def save(p,x):p.write_text(json.dumps(x,indent=2)+'\n')
results=[]
stockkeys=['theta','fraction','macro_total','macro_sat','macro_domain','macro_compartment','macro_volume','macro_bottom','clock']
memorykeys=['event','reference','sorptivity']
for opt in ['O2','O0']:
    d=R/'data'/opt/'preserved';a=read(d/'origin.txt')
    old=read(R.parent/'swap431-macro-b1-inventory03/data'/opt/'origin.txt')
    assert all(a[k]==old[k] for k in old),'Not the saved original context'
    run=json.loads((R/(opt+'_preserved_RUN.json')).read_text())
    assert run['returncode']==0 and not run['censored'] and run['seconds']<20
    words=(d/'outcome.txt').read_text().split()
    assert words[0]=='ORIGINAL_REDUCTION_REQUIRED' and int(words[1])==4
    assert not (d/'trial.txt').exists() and not (d/'committed.txt').exists()
    assert len(list(d.glob('solver_*.txt')))==4
    rows=[]
    for i in range(1,5):
        begin=read(d/('begin_'+str(i)+'.txt'));ret=read(d/('returned_'+str(i)+'.txt'));roll=read(d/('rollback_'+str(i)+'.txt'))
        s=read(d/('solver_'+str(i)+'.txt'))
        assert s['outcome']==[4.,61.,1.] # no acceptance; full original 60 iterations; unscaled coefficient
        assert s['controls'][2]==0 and s['controls'][0]==a['controls'][0]
        assert begin['policy'][1]==1. # preserved inherited retry flag selects the original doubled budget
        dt=s['controls'][1]
        expected=[0.0001414213562373095,4.714045207910317e-5,1.5713484026367723e-5,1e-5][i-1]
        assert dt==expected and dt>=1e-5
        local=max(map(abs,s['residual']));total=math.fsum(s['residual'])
        assert local>s['controls'][5] and abs(total)>s['controls'][6]
        n=int(s['controls'][3]);grad=[(s['h'][j-1]-s['h'][j])/(.5*(s['dz'][j-1]+s['dz'][j]))+1 for j in range(1,n)]
        assert grad==s['hgrad'][1:n]
        q=[s['boundary'][0]]+[-k*g for k,g in zip(s['kmean'][1:n],grad)]+[s['boundary'][1]]
        reconstructed=[(s['theta'][j]-s['thetm1'][j])*s['fraction'][j]*s['dz'][j]/dt+s['sink'][j]-s['source'][j]+s['qroot'][j]+q[j]-q[j+1]-s['qexchange'][j] for j in range(n)]
        remainder=max(abs(x-y) for x,y in zip(reconstructed,s['residual']))
        assert remainder<64*sys.float_info.epsilon
        assert not delta(a,roll,stockkeys)
        assert a['controls'][0]==roll['controls'][0] # no accepted time advance
        if i<4:
            assert ret['controls'][2]==0 and ret['controls'][7]==1
        else:
            assert ret['controls'][2]==1 and ret['policy']==[1.,1.,0.]
        nd=int(ret['controls'][4]);pair=[sum(ret['macro_exchange'][j*nd:(j+1)*nd]) for j in range(n)]
        pairerr=max(abs(x-y) for x,y in zip(pair,ret['matrix_exchange']))
        assert pairerr<=64*sys.float_info.epsilon*max(1,max(map(abs,ret['matrix_exchange'])))
        rows.append(dict(attempt=i,dt=dt,iterations=60,solver_level=0,used_reduction_factor=1.,accepted=False,
            last_local_residual=local,last_total_residual=total,local_limit=s['controls'][5],total_limit=s['controls'][6],
            independently_reconstructed_residual_error=remainder,paired_exchange_error=pairerr,
            stocks_geometry_theta_clock_restored=True,rollback_process_memory_differences=delta(a,roll,memorykeys)))
    assert not delta(a,read(d/'rollback_4.txt'),stockkeys+memorykeys)
    results.append(dict(optimization=opt,model_seconds=run['seconds'],outcome=words[0],accepted_steps=0,
        origin_matches_INVENTORY03=True,full_original_iteration_budget_preserved=True,attempts=rows,
        final_measured_stock_and_process_memory_exact=True,committed_inventory_change=0.))
for p in (R/'data/O2/preserved').glob('*.txt'):
    assert p.read_bytes()==(R/'data/O0/preserved'/p.name).read_bytes()
report=dict(work_unit='SWAP431-MACRO-B1-UNREDUCED04',baseline='f1271cc1d99e611dbc287cc6ca8c11dfc46c732c',
    decision='B1_CANDIDATE_NOT_READY',decision_scope='Unreduced physical B1 reference under the existing V1 solver/criteria/dt limits',
    result='UNREDUCED_V1_FAILS_ALL_FOUR_ORIGINAL_DT_ATTEMPTS_AND_REQUESTS_REDUCTION_AT_DTMIN',
    O0_O2_vectors_byte_exact=True,final_model_routes=2,pilot_model_routes=2,model_cap_seconds=20,
    final_max_model_seconds=max(x['model_seconds'] for x in results),
    source_equations_criteria_and_reduction_law_unchanged=True,experimental_policy='Only select IDecMpRat=0 at the saved origin; preserve retry flag and refuse requested scaled fallback after actual rollback.',
    official_reference_changed=False,production_changed=False,additional_memory_patch=False,accepted_unreduced_steps=0,
    no_direct_control_run='No smaller trial accepted, so the preregistered conditional accepted-retry control was not selected.',
    pilot_explanation='Initial two routes cleared the inherited retry flag, shortening nonminimum iterations to30. Their failures, binaries and vectors are preserved separately and do not qualify the final result. Final routes preserve the flag and run the full60 iterations at all4 dt values.',
    bounds=['One saved original wet context only','No proof that no unscaled mathematical root exists','No proof of failure of all possible numerical methods','Last rejected residuals are the original solver residuals with currently used exchange, not new acceptance certificates','No dry-event/restart/whole-trajectory qualification','Original reduction law unchanged; no official B1 promotion'],
    results=results,
    next_safe_step='Retain reduced V1 as excluded numerical research evidence. Separately diagnose why the existing V1 iteration stagnates in this one original context (freeze/line-search/local active-set), without starting a new general solver or historical campaign. If justified, compare the already existing active-coupling V2 on the same context under a separate bounded contract; not executed here.')
save(R/'RESULT.json',report)
print(json.dumps(report,indent=2))
