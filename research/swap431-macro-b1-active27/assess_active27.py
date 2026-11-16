"""Read-only bounded selection audit; never invents a qualifying active refusal."""
from pathlib import Path
import json,hashlib,math
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-reject26';D=R.parent/'swap431-macro-b1-diag19'
def rows(p):return [list(map(float,s.split())) for s in p.read_text().splitlines()]
def f(p):return {s.split()[0].lower():list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
selection=json.loads((R/'SELECTION.json').read_text());reference=rows(D/'data/O2/RESUME/attempt_trace.txt')
results=[];suitable=[]
for opt in ['O0','O2']:
 for label in ['C1','C2','C3']:
  d=R/'data'/opt/('TRIAL_'+label);s=selection[label]
  original=reference[s['original_attempt']-1]
  assert original[8]==4 and original[2]==s['time'] and original[3]==s['dt']
  prefix=(d/'prefix_budget.txt').read_text().splitlines()
  baseline=(R.parent/'swap431-macro-b1-next18/data'/opt/'RESUME/step_budget.txt').read_text().splitlines()
  assert len(prefix)==s['prior_commits'] and prefix==baseline[:len(prefix)]
  a=rows(d/'attempt_trace.txt');trace=rows(d/'jac24_trace.txt')
  assert a[0][2]==s['time'] and a[0][3]==s['dt'] and a[0][4]==0
  active=[sum(t[2]==1 for t in trace if t[0]==x[0]) for x in a]
  valid=any(x[8]==4 and n>0 for x,n in zip(a,active))
  if valid:suitable.append((opt,label))
  if label in ['C1','C3']:
   assert len(a)==1 and a[0][8]==0 and active[0]==1
   assert a[0][7]==(5 if label=='C1' else 2)
  else:
   assert len(a)==2 and a[0][8]==4 and a[0][7]==31 and a[0][9:11]==[1,0]
   assert active==[0,0] and a[1][8]==0 and a[1][7]==3
   assert a[1][3]==a[0][3]/3
  begin='begin_'+str(len(a));a0=f(d/(begin+'.txt'));b=f(d/'committed.txt');ca=f(d/('context_'+begin+'.txt'));cb=f(d/'context_committed.txt')
  x=rows(d/'step_budget.txt');assert len(x)==1;x=x[0];dt=x[1]
  matrix=math.fsum((v-u)*dz*fr for u,v,dz,fr in zip(a0['theta'],b['theta'],a0['dz'],a0['fraction']))
  macro=math.fsum(v-u for u,v in zip(a0['macro_domain'],b['macro_domain']))
  stock=matrix+macro+b['pond'][0]-a0['pond'][0]+cb['sicact'][0]-ca['sicact'][0]
  flux=dt*(x[2]+x[3]+x[4]-x[5]-x[6]-x[7]-x[8]+x[9]-x[10]+x[11]-x[12])-x[13]
  error=stock-flux;assert abs(error)<dt*1e-5
  assert x[16]==1 and a[-1][8]==0 and abs(a[-1][17])<1e-5 and a[-1][18]<1e-6
  run=json.loads((R/(opt+'_TRIAL_'+label+'_RUN.json')).read_text())
  assert run['returncode']==0 and not run['censored'] and run['seconds']<20
  results.append(dict(optimization=opt,context=label,seconds=run['seconds'],original_attempt=s['original_attempt'],original_begin_time=s['time'],original_dt=s['dt'],unchanged_original_prefix_rows=len(prefix),candidate_attempts=len(a),candidate_first_outcome='REFUSED' if a[0][8]==4 else 'CONVERGED',candidate_first_iterations=30 if a[0][8]==4 else int(a[0][7]),rank1_active_iterations_per_attempt=active,qualifying_active_refusal=valid,first_max_residual=a[0][18],first_sum_residual=a[0][17],accepted_step_dt=dt,accepted_commit_time=x[0],inventory_error_cm=error,inventory_limit_cm=dt*1e-5))
 for label in ['C1','C2','C3']:
  for p in (R/'data/O0'/('TRIAL_'+label)).glob('*.txt'):
   if p.name in ['cost_trace.txt','attempt_trace.txt']:continue
   assert p.read_bytes()==(R/'data/O2'/('TRIAL_'+label)/p.name).read_bytes(),str(p)
  assert [x[:-1] for x in rows(R/'data/O0'/('TRIAL_'+label)/'attempt_trace.txt')]==[x[:-1] for x in rows(R/'data/O2'/('TRIAL_'+label)/'attempt_trace.txt')]
 ident=json.loads((R/(opt+'_IDENTITY.json')).read_text())
 assert all(hashlib.sha256((R/n).read_bytes()).hexdigest()==h for n,h in ident['sources'].items())
assert not suitable and not list((R/'data').glob('*/DIRECT*'))
for p in P.glob('*.f90'):
 if p.name!='soilwater_native.f90':assert p.read_bytes()==(R/p.name).read_bytes(),p.name
q=dict(work_unit='SWAP431-MACRO-B1-ACTIVE27',decision='NO_SUITABLE_ACTIVE_REFUSAL_IN_THREE_SELECTED_ORIGINAL_CONTEXTS',model_routes=6,selected_original_contexts=3,hard_timeout_seconds=20,all_uncensored=True,O0_O2_non_timing_byte_exact=True,candidate_physics_criteria_dt_reduction_changes=False,active_refusal_rollback_direct_qualification=False,reason='C1 andC3 converge with update active; C2 genuinely refuses but update inactive. Direct comparison not launched without qualifying active refusal.',official_promotion=False,results=results)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q,indent=2))
