"""Assess the versioned STATE02 vectors; no models or compilers launched."""
from pathlib import Path
import json, hashlib, csv

R=Path(__file__).resolve().parent
def fields(p):
    return {s.split()[0]:list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
def differences(a,b):
    assert a.keys()==b.keys()
    assert all(len(a[k])==len(b[k]) for k in a)
    return {k:max(abs(x-y) for x,y in zip(a[k],b[k])) for k in a if a[k]!=b[k]}
def save(p,x):p.write_text(json.dumps(x,indent=2)+'\n')
results=[];memory=[]
# Existing selected times are additionally checked against the archived attempts
# by state02 provenance recovery; no archived numerical result is rewritten here.
for opt in ['O2','O0']:
    a=R/'data'/opt/'reject1';b=R/'data'/opt/'direct1'
    origin=fields(a/'origin.txt');rollback=fields(a/'rollback.txt')
    assert len(origin)==19
    assert origin==fields(b/'origin.txt')
    assert fields(a/'rejected.txt')['controls'][3:6:2]==[1.,0.]
    dr=differences(rollback,fields(b/'rollback.txt'))
    assert set(dr)=={'reference_theta','sorptivity','event','exchange'}
    for label in ['retry','committed']:
        assert fields(a/(label+'.txt'))==fields(b/(label+'.txt'))
        assert (a/(label+'.txt')).read_bytes()==(b/(label+'.txt')).read_bytes()
    retry=fields(a/'retry.txt');commit=fields(a/'committed.txt')
    assert retry['controls'][3]==retry['controls'][5]==0
    assert max(commit['clock'])>max(retry['clock'])
    memory.append(dict(optimization=opt,origin_exact=True,real_rejection=True,rollback_differences=dr,
        retry_all_19_groups_exact=True,committed_all_19_groups_exact=True,
        retry_dt=retry['controls'][1],max_clock_before_commit=max(retry['clock']),max_clock_after_commit=max(commit['clock']),
        harmful_memory_effect_demonstrated=False,dry_event_closure_qualified=False))
    for i in range(1,12):
        x=fields(R/'data'/opt/('rate'+str(i))/'rate.txt');ctx=x['context']
        assert ctx[0]==i and ctx[3:5]==[1.,.1]
        assert x['heads_unchanged']==[0.,0.]
        assert x['stock']==x['unreduced_stock'] and x['clock']==x['unreduced_clock']
        local=max(map(abs,x['accepted_f']));total=abs(sum(x['accepted_f']))
        uloc=max(map(abs,x['unreduced_f']));utot=abs(sum(x['unreduced_f']))
        assert local<=ctx[5] and total<=ctx[6]
        assert uloc>ctx[5] and utot>ctx[6]
        assert x['attribution'][0]<1e-14
        pair=max(abs(a-b) for a,b in zip(x['accepted_pair'],x['accepted_q']))
        upair=max(abs(a-b) for a,b in zip(x['unreduced_pair'],x['unreduced_q']))
        assert pair==upair==0
        rate=x['accepted_budget_rates'];urate=x['unreduced_budget_rates']
        budget=lambda v:ctx[2]*(v[0]+v[1]-v[2]-v[3])
        results.append(dict(optimization=opt,index=i,t1900=ctx[1],dt=ctx[2],local_reduced=local,total_abs_reduced=total,
            local_unreduced=uloc,total_abs_unreduced=utot,local_limit=ctx[5],total_limit=ctx[6],
            max_exchange_change=max(abs(a-b) for a,b in zip(x['accepted_q'],x['unreduced_q'])),
            attribution_remainder=x['attribution'][0],paired_exchange_remainder=pair,unreduced_paired_exchange_remainder=upair,
            accepted_budget_rates=rate,unreduced_budget_rates=urate,
            predicted_macro_stock_increment_reduced_cm=budget(rate),predicted_macro_stock_increment_unreduced_cm=budget(urate),
            stock_not_committed_by_diagnostic=True))
for sub in ['reject1','direct1']+['rate'+str(i) for i in range(1,12)]:
    for p in (R/'data/O0'/sub).glob('*.txt'):
        if p.name=='attempts.txt':continue # historical trace from censored pilot
        assert p.read_bytes()==(R/'data/O2'/sub/p.name).read_bytes(),str(p)
final_runs=[json.loads(p.read_text()) for p in R.glob('O[02]_*_RUN.json')]
assert len(final_runs)==26 and all(x['returncode']==0 and not x['censored'] and x['seconds']<20 for x in final_runs)
pilots=[json.loads(p.read_text()) for p in (R/'pilot-six').glob('*_RUN.json')]
censored=[json.loads(p.read_text()) for p in (R/'censored-trace').glob('*_RUN.json')]
assert len(pilots)==6 and all(x['returncode']==0 and not x['censored'] for x in pilots)
assert len(censored)==3 and all(x['censored'] and 20<=x['seconds']<21 for x in censored)
sel=[x for x in results if x['optimization']=='O2']
report=dict(work_unit='SWAP431-MACRO-B1-STATE02',baseline='87792cdee54380424b9e1efb62ac272cdde1ab76',
    decision='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',
    question1='Immediate rollback is incomplete, but all 19 observed groups become exact at the real wet retry and accepted clock update. No harmful persistent-memory defect demonstrated. Dry/event-end history remains unqualified.',
    question2='All 11 existing reduced accepted states satisfy reduced criteria and fail both original unreduced criteria at identical heads/history. Reduction changes accepted exchange and macro stock rate; it is not solely a Newton aid.',
    question3='V1 may continue only as candidate for the existing reduced numerical approximation, with explicit exclusions. It is not qualified as an unreduced physical reference or a B1.12 successor.',
    production_fortran_changes=0,experimental_rollback_corrections=0,diagnostic_fortran=['headcalc_probe.f90','soilwater_probe.f90'],
    compiler='GNU Fortran 16.2.0 MSYS2 UCRT64 native Windows',O0_O2_vectors_byte_exact=True,
    final_model_routes=26,final_max_route_seconds=max(x['seconds'] for x in final_runs),
    censored_trace_pilot_routes=3,successful_previous_pilot_routes=6,
    total_new_model_routes=35,total_model_wall_seconds=sum(x['seconds'] for x in final_runs+pilots+censored),
    water_conservation='Matrix/domain exchange is exactly paired in all 22 operator probes. Stock and clock stay unchanged during counterfactual evaluation. Budget increments are diagnostic predictions, not committed unreduced states; no independent whole-step water-inventory audit.',
    sum_dt_selected=sum(x['dt'] for x in sel),
    exclusions=['No original unreduced acceptance on the eleven reduced steps','No qualified original dry/event-end rejection context','No whole-trajectory, independent restart, or all-mode qualification','No canonical/B0/B1.12/release changes'],
    memory=memory,rates=results,
    next_step='First agree whether a B1 reference may retain the original rate-reduction approximation. If yes, qualify one original wet-to-dry/event-end rejection with positive sorption clock and accepted continuation plus own restart. If unreduced convergence is required, this V1 route is not ready; independently investigate retry-without-reduction on the first saved context, without altering reduction policy in this round.')
save(R/'RESULT.json',report)
with (R/'RATE_COMPARISON.csv').open('w',newline='') as f:
    names=[k for k in sel[0] if not isinstance(sel[0][k],list)]
    w=csv.DictWriter(f,fieldnames=names,extrasaction='ignore');w.writeheader();w.writerows(sel)
print(json.dumps({k:v for k,v in report.items() if k not in ['memory','rates','exclusions']},indent=2))
