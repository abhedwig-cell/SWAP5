"""Assess preserved V1/V2 logs and the one threshold pair; launches no models."""
from pathlib import Path
import json,math,csv
R=Path(__file__).resolve().parent
cols=json.loads((R/'TRACE_COLUMNS.json').read_text())
def fields(p):return {s.split()[0]:list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
def trace(d):
    rows=[list(map(float,s.split())) for s in (d/'iterations_1.txt').read_text().splitlines()]
    assert all(len(x)==len(cols) for x in rows)
    return [dict(zip(cols,x)) for x in rows]
def save(p,x):p.write_text(json.dumps(x,indent=2)+'\n')
variants=[];probes=[]
for opt in ['O2','O0']:
    for v in ['V1','V2']:
        d=R/'data'/opt/v;a=trace(d)
        before=fields(d/'origin.txt');end=fields(d/'rollback_1.txt')
        old=R.parent/'swap431-macro-b1-unreduced04/data'/opt/'preserved'
        assert before==fields(old/'origin.txt')
        if v=='V1':
            for name in ['origin.txt','begin_1.txt','solver_1.txt','returned_1.txt','rollback_1.txt']:
                assert (d/name).read_bytes()==(old/name).read_bytes(),name
        assert (d/'outcome.txt').read_text().split()[0]=='ONE_ATTEMPT_DIAGNOSTIC_BOUND'
        assert not (d/'trial.txt').exists() and not (d/'committed.txt').exists()
        for key in ['theta','fraction','macro_total','macro_sat','macro_domain','macro_compartment','macro_volume','macro_bottom','clock']:
            assert before[key]==end[key]
        solver=fields(d/'solver_1.txt');assert solver['outcome']==[4.,61.,1.]
        assert solver['controls'][1:3]==[0.0001414213562373095,0.]
        bt=[x for x in a if x['stage']==3]
        last=[next(x for x in reversed(bt) if x['iteration']==i) for i in range(1,61)]
        exhausted=[int(x['iteration']) for x in last if x['objective']>=x['previous_objective'] and x['max_F']>=1e-6]
        assert all(next(x for x in a if x['stage']==1 and x['iteration']==i)['q45']==next(x for x in a if x['stage']==2 and x['iteration']==i)['q45'] for i in range(1,61))
        checks=[x for x in a if x['stage']==5];fresh=[x for x in a if x['stage']==6]
        if v=='V1':
            assert len(checks)==len(fresh)==9 and len(exhausted)==10
            assert all(x['max_F']<=1e-6 and abs(x['sum_F'])<=1e-5 for x in checks)
            assert all(x['max_F']>1e-6 and abs(x['sum_F'])>1e-5 for x in fresh)
            assert all(x['h45']==y['h45'] for x,y in zip(checks,fresh))
        else:
            assert not checks and len(exhausted)==14 and all(x['frozen']==0 for x in a)
        variants.append(dict(optimization=opt,variant=v,accepted=False,iterations=60,
            last_local_used_solver_residual=max(map(abs,solver['residual'])),last_total_used_solver_residual=math.fsum(solver['residual']),
            final_residual_is_frozen=(v=='V1'),line_search_evaluations=len(bt),max_backtrack_evaluations_per_iteration=int(max(x['backtrack'] for x in bt)),
            exhausted_line_search_count=len(exhausted),exhausted_line_search_iterations=exhausted,
            threshold_crossings_in_evaluation_sequence=sum((x['h45']<x['h_entry']-1e-8)!=(y['h45']<y['h_entry']-1e-8) for x,y in zip(bt[1:],bt[:-1])),
            frozen_candidate_evaluations=int(sum(x['frozen'] for x in bt)),provisional_certification_count=len(checks),
            fresh_local_residuals=[x['max_F'] for x in fresh],cached_local_residuals=[x['max_F'] for x in checks],
            local_Jacobian_rate_recalculation_changes_q45=False,measured_stocks_theta_geometry_clock_rollback_exact=True))
    dleft=R/'data'/opt/'LEFT';dright=R/'data'/opt/'RIGHT'
    l=fields(dleft/'solver_1.txt');r=fields(dright/'solver_1.txt')
    lt=trace(dleft)[-1];rt=trace(dright)[-1]
    assert l['outcome'][0]==r['outcome'][0]==8 and l['outcome'][2]==r['outcome'][2]==1
    assert [i for i,(x,y) in enumerate(zip(l['h'],r['h'])) if x!=y]==[44]
    assert [i for i,(x,y) in enumerate(zip(l['qexchange'],r['qexchange'])) if x!=y]==[44]
    assert lt['h45']==-10.0000001 and rt['h45']==-9.9999999
    assert l['residual'][44]<0<r['residual'][44]
    assert lt['q45']==lt['unsat_out45'] and rt['q45']==rt['unsat_out45']
    assert fields(dleft/'origin.txt')==fields(dright/'origin.txt')
    ml=fields(dleft/'probe_memory.txt');mr=fields(dright/'probe_memory.txt');orig=fields(dleft/'origin.txt')
    assert ml['clock']==mr['clock']==orig['clock']
    assert all(ml['reference'][i]==mr['reference'][i] and ml['sorptivity'][i]==mr['sorptivity'][i] for i,t in enumerate(ml['clock']) if t>1e-8)
    probes.append(dict(optimization=opt,h45_left=lt['h45'],h45_right=rt['h45'],q45_left=lt['q45'],q45_right=rt['q45'],
        q45_jump=rt['q45']-lt['q45'],F45_left=l['residual'][44],F45_right=r['residual'][44],F45_jump=r['residual'][44]-l['residual'][44],
        theta45_difference=r['theta'][44]-l['theta'][44],nonexchange_F45_difference=r['residual'][44]-l['residual'][44]+r['qexchange'][44]-l['qexchange'][44],
        all_other_heads_and_exchange_exact=True,clock_and_positive_clock_references_unchanged=True,
        top_saturated=lt['top_saturated'],top_saturated_unchanged=lt['top_saturated']==rt['top_saturated'],
        wet_wall45=lt['wet_wall45'],wet_wall45_unchanged=lt['wet_wall45']==rt['wet_wall45'],operator_diagnostic_only=True))
for profile in ['V1','V2','LEFT','RIGHT']:
    for p in (R/'data/O2'/profile).glob('*.txt'):
        assert p.read_bytes()==(R/'data/O0'/profile/p.name).read_bytes(),str(p)
v1=trace(R/'data/O2/V1');v2=trace(R/'data/O2/V2')
for x,y in zip([x for x in v1 if x['stage']==3 and x['iteration']<=3],[x for x in v2 if x['stage']==3 and x['iteration']<=3]):
    for key in ['max_F','sum_F','objective','h45','q45']:assert x[key]==y[key]
runs=[json.loads(p.read_text()) for p in R.glob('O[02]_*_RUN.json')]
assert len(runs)==8 and all(x['returncode']==0 and not x['censored'] and x['seconds']<20 for x in runs)
result=dict(work_unit='SWAP431-MACRO-B1-STAGNATION05',baseline='6003fd2383dd0c97bb40238936fc38cb1d601471',
    decision='B1_CANDIDATE_NOT_READY',decision_scope='Unreduced physical reference; both existing variants fail at the selected original dt',
    finding='V1 freeze/certification limit cycle is superimposed on an original unsaturated absorption active-set jump near h45=-10cm. Removing freeze with existing V2 leaves threshold-crossing and exhausted line searches; it does not recover convergence.',
    threshold_source='ABSORPTION: H(ic)<cofgen(9,layer)-1e-8 AND HMp>1e-8; otherwise Darcy absorption branch is suppressed; sorption/Darcy selection and available storage bounds remain original.',
    local_jump_measured=True,global_nonexistence_of_unscaled_solution_proven=False,original_physical_law_defect_proven=False,
    last_frozen_V1_norm_not_comparable_as_accuracy_ranking_to_active_V2=True,
    O0_O2_all_raw_profiles_byte_exact=True,V1_observer_noninterference_with_UNREDUCED04_byte_exact=True,
    model_routes=8,max_model_seconds=max(x['seconds'] for x in runs),total_model_seconds=sum(x['seconds'] for x in runs),
    model_censored=0,setup_compile_failures=2,third_general_solver_variant=False,
    production_changed=False,original_laws_limits_tolerances_unchanged=True,additional_memory_patch=False,
    variants=variants,threshold_pair=probes,
    next_safe_step='Separately establish the intended air-entry Darcy-gate/absorption transition contract in the original formulation. Only then select a physically justified local transition correction or numerical event treatment on this same context. No automatic smoothing, dt/tolerance relaxation, third solver or broad campaign.')
save(R/'RESULT.json',result)
with (R/'ITERATION_SUMMARY.csv').open('w',newline='') as f:
    names=['optimization','variant','iterations','last_local_used_solver_residual','last_total_used_solver_residual','final_residual_is_frozen','line_search_evaluations','exhausted_line_search_count','provisional_certification_count']
    w=csv.DictWriter(f,fieldnames=names,extrasaction='ignore');w.writeheader();w.writerows(variants)
print(json.dumps({k:v for k,v in result.items() if k not in ['variants','threshold_pair']},indent=2))
