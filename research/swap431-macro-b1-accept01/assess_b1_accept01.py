"""Assess preserved short model outputs; launches no model or compiler."""
from pathlib import Path
import json,csv,io,re,hashlib,argparse
parser=argparse.ArgumentParser()
base=Path(__file__).resolve().parent
parser.add_argument('--root',type=Path,default=base if (base/'PREREGISTRATION.json').exists() else base/'b1-accept01')
parser.add_argument('--b0-case',type=Path,default=Path('/workspace/scratch/847fc052fa43/run-control-output'))
args=parser.parse_args();R=args.root.resolve();B0CASE=args.b0_case.resolve()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def norm(p):return b'\n'.join(x for x in p.read_bytes().splitlines() if not x.startswith(b'* Generated at:'))
def rows(p):return [list(map(float,l.split())) for l in p.read_text().splitlines()]
def fields(p):return {l.split()[0]:list(map(float,l.split()[1:])) for l in p.read_text().splitlines()}
def delta(a,b):
    assert a.keys()==b.keys()
    return {k:max(abs(x-y) for x,y in zip(a[k],b[k])) for k in a if a[k]!=b[k]}
def csvrows(p):return list(csv.DictReader(io.StringIO('\n'.join(l for l in p.read_text().splitlines() if not l.startswith('*')))))
def head(p):return list(map(float,re.search(r'\nH\s*=\s*(.*?)\nPOND\s*=', '\n'+p.read_text(),re.S)[1].split()))
comparisons=[];results=[];all_runs=[]
for opt in ['O2','O0']:
    records=['RUNS.json','OBS_RUNS.json','BARE_RUNS.json'] if opt=='O2' else ['OBS_RUNS.json','BARE_RUNS.json']
    for name in records:all_runs+=json.loads((R/opt/name).read_text())
all_runs+=json.loads((R/'observer-all-censored/O2_RUNS.json').read_text())
for opt in ['O2','O0']:
    for name in ['B0','V1','V2']:
        d=R/opt/(name if opt=='O2' else name+'-metrics')/'case'
        data=rows(d/'attempts.txt');accepted=[x for x in data if x[0]==0];active=[x for x in accepted if x[4]>0]
        assert all(x[5]<=x[7] and abs(x[6])<=x[8] for x in accepted)
        daily=csvrows(d/'result_output.csv')
        q=dict(optimization=opt,name=name,accepted=len(accepted),attempt_counts={str(i):sum(x[0]==i for x in data) for i in range(4)},
          accepted_with_rate_reduction=len(active),rate_reduced_duration_days=sum(x[2] for x in active),max_IDecMpRat=max(x[4] for x in accepted),
          max_accepted_iteration_index=max(x[3] for x in accepted),sum_accepted_iteration_indices=sum(x[3] for x in accepted),
          cached_criterion_failures=0,daily=[{k:v for k,v in t.items() if k in ['DATE','RAIN','GWL','DRN','BALDEV','MP_BALDEV_1','MP_BALDEV_2']} for t in daily])
        if name!='B0':
            obs=R/opt/(name+'-observer')/'case';bare=R/opt/(name+'-bare')/'case'
            for filename in ['result_output.csv','result.end','macrogeom.csv','soilshrinkchar.csv']:
                assert norm(d/filename)==norm(obs/filename)==norm(bare/filename),(opt,name,filename)
                comparisons.append(dict(optimization=opt,name=name,file=filename,metrics_observer_bare_equal=True,sha256_metrics=sha(d/filename)))
            assert norm(d/'attempts.txt')==norm(obs/'attempts.txt')
            f=rows(obs/'fresh.txt');assert len(f)==41
            assert all(x[6]<=x[8] and abs(x[7])<=x[9] for x in f)
            q['fresh_observer']=dict(samples=len(f),failed=0,max_local=max(x[6] for x in f),max_total_abs=max(abs(x[7]) for x in f),max_exchange_attribution_remainder=max(x[10] for x in f))
            a=obs/'retry-shadow-1';b=obs/'retry-shadow-2'
            x0=fields(a/'origin.txt');y0=fields(b/'origin.txt');xr=fields(a/'rollback.txt');yr=fields(b/'rollback.txt')
            assert x0==y0 and fields(a/'retry.txt')==fields(b/'retry.txt')
            assert fields(a/'rejected.txt')['controls'][3]==1
            assert fields(a/'retry.txt')['controls'][3]==fields(a/'retry.txt')['controls'][5]==0
            dr=delta(xr,yr);assert set(dr)=={'reference_theta','sorptivity','event','exchange'}
            changed_ref=[i for i,(x,y) in enumerate(zip(x0['reference_theta'],xr['reference_theta'])) if x!=y]
            changed_events=[i for i,(x,y) in enumerate(zip(x0['event'],xr['event'])) if x!=y]
            q['rollback']=dict(origin_byte_exact=(a/'origin.txt').read_bytes()==(b/'origin.txt').read_bytes(),
              real_large_trial_rejected=True,smaller_retry_success=True,stock_and_clock_restored=True,
              strict_full_memory_restored=False,differences_after_rollback_vs_direct_small=dr,
              retry_all_exported_fields_byte_exact=(a/'retry.txt').read_bytes()==(b/'retry.txt').read_bytes(),
              changed_reference_cells=len(changed_ref),max_origin_clock_at_changed_reference=max(x0['clock'][i] for i in changed_ref),
              changed_event_cells=len(changed_events),max_origin_clock_at_changed_event=max(x0['clock'][i] for i in changed_events))
            deriv=fields(obs/'derivative.txt') # Repeated COLUMN keys are assessed separately below.
            cols=[list(map(float,l.split()[1:])) for l in (obs/'derivative.txt').read_text().splitlines() if l.split()[0]=='COLUMN']
            assert len(cols)==8 and deriv['TASKS']==[0.] and deriv['RETURN']==[0.]
            q['derivative']=dict(columns=cols,max_absolute_macro_diagonal_error=max(x[-1] for x in cols),rate_vs_derivative_task_exchange_exact=True,post_perturbation_return_exact=True)
            base=R/opt/('B0' if opt=='O2' else 'B0-metrics')/'case'
            q['max_terminal_head_difference_from_B0_cm']=max(abs(x-y) for x,y in zip(head(d/'result.end'),head(base/'result.end')))
        results.append(q)

for name in ['B0','V1','V2']:
    a=R/'O2'/name/'case';b=R/'O0'/(name+'-metrics')/'case'
    for filename in ['result_output.csv','result.end','macrogeom.csv','soilshrinkchar.csv','attempts.txt']:
        assert norm(a/filename)==norm(b/filename),(name,filename)
for filename in ['result_output.csv','result.end','macrogeom.csv','soilshrinkchar.csv']:
    assert norm(R/'O2/B0/case'/filename)==norm(B0CASE/filename)
censored=[]
for name in ['V1','V2']:
    p=R/'O2'/(name+'-observer-all-censored')/'case/fresh.txt';r=rows(p)
    assert all(x[6]<=x[8] and abs(x[7])<=x[9] for x in r)
    censored.append(dict(name=name,samples=len(r),fresh_failures=0,last_observed_time=r[-1][0],qualified_complete_trajectory=False))
report=dict(work_unit='SWAP431-MACRO-B1-ACCEPT01',baseline='798c0bff798e6906c46b0cbfb8c8850fed3a037e',
  candidate_status='V1_SHORT_ACCEPTANCE_REPAIR_SUPPORTED_NOT_PROMOTED',decision='Prefer explicit terminal coupled certification V1 as experimental candidate. Do not promote B1: full history rollback is incomplete and original rate reduction becomes active; whole science and restart are untested.',
  numerical_variants=2,model_executions=len(all_runs),censored_executions=sum(x['censored'] for x in all_runs),
  total_actual_model_wall_seconds=sum(x['seconds'] for x in all_runs),O0_full_closure_build_seconds=json.loads((R/'O0-closure/IDENTITY.json').read_text())['seconds'],
  original_archive_sha256='1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151',
  compiler='GNU Fortran14.2.0 Linux x86_64',optimizations=['O0','O2'],physics_and_criteria_changed=False,
  O0_O2_all_registered_exports_and_attempts_exact=True,results=results,noninterference=comparisons,censored_observations=censored,runs=all_runs,
  bounds=['Original Andelst cold first two days, SWMBF1/SWKIMPL0 only','No B1 manifest/snapshot change','No whole481, B0 day438, own restart or global Jacobian qualification','Strict history rollback fails immediate restore; selected same-origin smaller retry is nevertheless exact','All-step observer prefixes censored, not complete passes','Ordinary accepted V1 residual is recertified by implementation; independent fresh-observer tests remain selected states','Water balance is reported at printed daily precision; no independent full substep donor/receiver inventory audit added','Original IDecMpRat law unchanged but rate reduction is activated on11(V1)/16(V2) accepted steps','No evidence all B0 head errors or hybrid day438 discrepancies are repaired'])
(R/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k not in ['results','noninterference','runs']},indent=2))
