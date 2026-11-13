"""Independent inventory from primitive measured states/fluxes; no model calls."""
from pathlib import Path
import json,math,sys

R=Path(__file__).resolve().parent
def read(p):return {s.split()[0]:list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
def save(p,x):p.write_text(json.dumps(x,indent=2)+'\n')
results=[]
for opt in ['O2','O0']:
    d=R/'data'/opt
    a,b,c,s=[read(d/(name+'.txt')) for name in ['origin','trial','committed','solver']]
    run=json.loads((R/(opt+'_RUN.json')).read_text())
    assert run['returncode']==0 and not run['censored'] and run['seconds']<20
    t,dt,level,n,nn,critcp,crittot,critpond=s['controls'];n=int(n);nd=int(a['controls'][4])
    assert n==nn==112 and nd==5 and level==1
    assert a['controls'][:3]==[t,dt,1.] and b['controls'][:3]==c['controls'][:3]==[t,dt,0.]
    assert a['controls'][5:]==[1.,0.,0.] # SWMBF1, SWKIMPL0, no failed step
    assert a['fraction']==b['fraction']==c['fraction']==s['fraction']
    assert a['theta']==a['thetm1']==b['thetm1']==s['thetm1']
    assert s['theta']==b['theta']==c['theta']
    assert all(v==0 for v in b['matrix_immob'])
    assert s['sink']==b['matrix_drains'] and s['source']==b['matrix_ssdi'] and s['qroot']==b['matrix_root']
    # Reconstruct Darcy interface fluxes from heads and cell spacing, NOT the
    # mass-derived q array produced by FLUXES after acceptance.
    grad=[(s['h'][i-1]-s['h'][i])/(.5*(s['dz'][i-1]+s['dz'][i]))+1 for i in range(1,n)]
    assert grad==s['hgrad'][1:n]
    qt,qb=s['boundary'][:2]
    q=[qt]+[-k*g for k,g in zip(s['kmean'][1:n],grad)]+[qb]
    changes=[(y-x)*f*dz for x,y,f,dz in zip(a['theta'],c['theta'],a['fraction'],a['dz'])]
    sinks=b['matrix_drains'];sources=b['matrix_ssdi'];roots=b['matrix_root'];exchange=b['matrix_exchange']
    residual=[changes[i]/dt + sinks[i]-sources[i]+roots[i]+q[i]-q[i+1]-exchange[i] for i in range(n)]
    max_local=max(map(abs,residual));total=math.fsum(residual)
    assert max_local<=critcp and abs(total)<=crittot
    comparison=max(abs(x-y) for x,y in zip(residual,s['residual']))
    assert comparison<=64*sys.float_info.epsilon*max(1,max_local)
    matrix_change=math.fsum(changes)
    mrate=qb-qt-math.fsum(roots)-math.fsum(sinks)+math.fsum(sources)+math.fsum(exchange)
    matrix_error=matrix_change-dt*mrate
    assert abs(matrix_error)<=dt*crittot
    domains=[]
    for j in range(nd):
        ex=math.fsum(b['macro_exchange'][j::nd])
        rapid=math.fsum(b['macro_rapid']) if j==0 else 0.
        rate=b['macro_in_lat'][j]+b['macro_in_vert'][j]-ex-rapid
        delta=c['macro_domain'][j]-a['macro_domain'][j]
        unclamped=a['macro_domain'][j]+dt*rate
        assert unclamped>=0 # no hidden negative-inventory clamp in this step
        scale=max(1.,abs(a['macro_domain'][j]),abs(c['macro_domain'][j]))
        envelope=64*sys.float_info.epsilon*scale
        comp=math.fsum(c['macro_compartment'][j::nd])
        assert abs(delta-dt*rate)<=envelope
        assert abs(comp-c['macro_domain'][j])<=envelope
        domains.append(dict(domain=j+1,begin=a['macro_domain'][j],end=c['macro_domain'][j],change=delta,
            expected_change=dt*rate,inventory_error_cm=delta-dt*rate,compartment_sum=comp,roundoff_envelope_cm=envelope))
    # Validate the cancellation explicitly; do not assume a paired exchange.
    pair=[math.fsum(b['macro_exchange'][i*nd:(i+1)*nd]) for i in range(n)]
    pairerr=max(abs(x-y) for x,y in zip(pair,exchange))
    assert pairerr<=64*sys.float_info.epsilon*max(1,max(map(abs,exchange)))
    lat=math.fsum(b['macro_in_lat']);vert=math.fsum(b['macro_in_vert']);rapid=math.fsum(b['macro_rapid'])
    mpchange=math.fsum(x['change'] for x in domains)
    macro_error=mpchange-dt*(lat+vert-math.fsum(exchange)-rapid)
    precip=math.fsum(b['boundary_rates'][2:5]);runon,epd,reva=b['boundary_rates'][5:]
    runoff=b['surface'][0];pondchange=c['pond'][0]-a['pond'][0]
    surface_error=pondchange-dt*(precip+runon-epd-reva+qt-lat-vert)+runoff
    assert abs(surface_error)<=critpond
    external=dt*(precip+runon-epd-reva+qb-math.fsum(roots)-math.fsum(sinks)+math.fsum(sources)-rapid)-runoff
    combined_change=matrix_change+mpchange+pondchange
    combined_error=combined_change-external
    roundoff=64*sys.float_info.epsilon*max(1,math.fsum(abs(x) for x in a['macro_domain']))
    assert abs(combined_error-dt*total-surface_error)<=roundoff
    old=read(R.parent/'swap431-macro-b1-state02/data'/opt/'rate1/rate.txt')
    assert s['residual']==old['accepted_f'] and exchange==old['accepted_q']
    results.append(dict(optimization=opt,t1900=t,dt=dt,solver_reduction_level=level,postaccept_reduction_level=b['controls'][2],
        exact_STATE02_selected_operator=True,local_residual=max_local,total_residual=total,
        independently_reconstructed_residual_difference=comparison,matrix_change_cm=matrix_change,matrix_error_cm=matrix_error,
        macro_change_cm=mpchange,macro_error_cm=macro_error,surface_change_cm=pondchange,surface_error_cm=surface_error,
        combined_change_cm=combined_change,external_budget_cm=external,combined_error_cm=combined_error,
        paired_exchange_error_cm_per_day=pairerr,domains=domains,clamping_active=False,
        mass_derived_surface_flux_difference=c['matrix_vertical'][0]-qt,model_seconds=run['seconds']))
for name in ['origin','trial','committed','solver']:
    assert (R/'data/O0'/(name+'.txt')).read_bytes()==(R/'data/O2'/(name+'.txt')).read_bytes()
report=dict(work_unit='SWAP431-MACRO-B1-INVENTORY03',baseline='e7c5b44ebe3efd4f1a84f073803f9eab3b2cfa12',
    result='SELECTED_REDUCED_STEP_INDEPENDENT_INVENTORY_PASS',candidate_decision='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',
    reference_recommendation='Require unreduced coupled convergence for the intended physical B1 reference; retain reduced V1 as explicitly separate numerical research variant.',
    official_reference_contract_changed=False,physics_or_solver_policy_changed=False,production_changed=False,
    O0_O2_primitive_vectors_byte_exact=True,final_routes=2,final_routes_censored=0,
    setup_routes=3,setup_full_two_day_windows_inadvertently_completed=2,
    setup_explanation='First selector intercepted a rejected trial where headcalc had just raised IDecMpRat. The second selector missed postaccept because headcalc decreases IDecMpRat after certifying the reduced operator. Both setup misses are preserved; final selector uses the exact entry t/dt/level and a diagnostic pending flag.',
    acceptance_limits='Original local/total/pond criteria unchanged. Macro domain/aggregate reconstruction uses a 64*machine-epsilon*inventory-scale roundoff envelope; no new physical tolerance.',
    results=results,
    exclusions=['Single original reduced wet step only','No dry/event-end rejection or own restart qualification','No unreduced physical convergence','No B1.12/canonical/release promotion'],
    next_safe_step='Owner selects the physical reference contract. Recommendation: unreduced acceptance required. Only then separately preregister a bounded solve/reject experiment at the same first context, with original equations and no silent reduction-policy change.')
save(R/'RESULT.json',report)
print(json.dumps(report,indent=2))
