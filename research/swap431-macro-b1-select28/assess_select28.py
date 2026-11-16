"""Bounded negative selection, including exact analytic-update guard audit."""
from pathlib import Path
import json,math,hashlib,collections
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-active27'
def rows(p):return [list(map(float,s.split())) for s in p.read_text().splitlines()]
def f(p):return {s.split()[0].lower():list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
selection=json.loads((R/'SELECTION.json').read_text());original=rows(R.parent/'swap431-macro-b1-diag19/data/O2/RESUME/attempt_trace.txt')
result=[]
for opt in ['O0','O2']:
 for label,iters in [('D1',12),('D2',24),('D3',7)]:
  d=R/'data'/opt/('TRIAL_'+label);s=selection[label];o=original[s['original_attempt']-1]
  assert o[8]==4 and o[2]==s['time'] and o[3]==s['dt']
  assert o[24]-o[21]==s['original_extra_line_search_trials']
  prior=(d/'prefix_budget.txt').read_text().splitlines();old=(R.parent/'swap431-macro-b1-next18/data'/opt/'RESUME/step_budget.txt').read_text().splitlines()
  assert len(prior)==s['prior_commits'] and prior==old[:len(prior)]
  a=rows(d/'attempt_trace.txt');assert len(a)==1;x=a[0]
  assert x[2]==s['time'] and x[3]==s['dt'] and x[4:7]==[0,0,1]
  assert x[7]==iters and x[8]==0 and x[9:11]==[0,0]
  j=rows(d/'jac24_trace.txt');assert len(j)==iters
  active=sum(v[2] for v in j);assert active==(3 if label=='D3' else 0)
  limits=[v for v in rows(d/'domain3_limit.txt') if v[5]==3 and v[4]==2]
  assert len(limits)==iters
  guards=collections.Counter()
  for v in limits:
   if v[17]!=0:guards['positive_potential_inflow']+=1
   elif v[13]>=v[12]:guards['minimum_equals_stock']+=1
   elif v[22]/v[6]<=1e-7:guards['no_active_limit']+=1
   elif v[18]<=v[22]:guards['full_limit']+=1
   elif v[10]!=50:guards['other_GWL_bracket']+=1
   else:guards['eligible_partial_zero_inflow']+=1
  if label=='D3':assert guards=={'minimum_equals_stock':4,'eligible_partial_zero_inflow':3}
  else:assert guards=={'positive_potential_inflow':iters}
  bb=rows(d/'step_budget.txt');assert len(bb)==1;v=bb[0];dt=v[1];assert dt==s['dt'] and v[16]==1
  begin=f(d/'begin_1.txt');end=f(d/'committed.txt');cb=f(d/'context_begin_1.txt');ce=f(d/'context_committed.txt')
  matrix=math.fsum((y-z)*dz*fr for z,y,dz,fr in zip(begin['theta'],end['theta'],begin['dz'],begin['fraction']))
  macro=math.fsum(y-z for z,y in zip(begin['macro_domain'],end['macro_domain']))
  stock=matrix+macro+end['pond'][0]-begin['pond'][0]+ce['sicact'][0]-cb['sicact'][0]
  external=dt*(v[2]+v[3]+v[4]-v[5]-v[6]-v[7]-v[8]+v[9]-v[10]+v[11]-v[12])-v[13]
  error=stock-external;assert abs(error)<dt*1e-5 and abs(error-x[17]*dt)<1e-15
  run=json.loads((R/(opt+'_TRIAL_'+label+'_RUN.json')).read_text());assert not run['censored'] and run['returncode']==0 and run['seconds']<20
  result.append(dict(optimization=opt,context=label,seconds=run['seconds'],original_attempt=s['original_attempt'],original_time=s['time'],original_dt=s['dt'],original_prefix_rows_byte_exact=len(prior),original_extra_line_search_trials=s['original_extra_line_search_trials'],candidate_converged=True,iterations=iters,extra_line_search_trials=x[24]-x[21],rank1_active_iterations=active,guard_counts=dict(guards),max_residual=x[18],sum_residual=x[17],qualifying_active_refusal=False,inventory_error_cm=error,inventory_limit_cm=dt*1e-5))
 ident=json.loads((R/(opt+'_IDENTITY.json')).read_text());assert all(hashlib.sha256((R/n).read_bytes()).hexdigest()==h for n,h in ident['sources'].items())
for label in ['D1','D2','D3']:
 for p in (R/'data/O0'/('TRIAL_'+label)).glob('*.txt'):
  if p.name in ['attempt_trace.txt','cost_trace.txt']:continue
  assert p.read_bytes()==(R/'data/O2'/('TRIAL_'+label)/p.name).read_bytes()
 assert [v[:-1] for v in rows(R/'data/O0'/('TRIAL_'+label)/'attempt_trace.txt')]==[v[:-1] for v in rows(R/'data/O2'/('TRIAL_'+label)/'attempt_trace.txt')]
for p in P.glob('*.f90'):assert (R/p.name).read_bytes()==p.read_bytes()
assert not list((R/'data').glob('*/DIRECT*'))
q=dict(work_unit='SWAP431-MACRO-B1-SELECT28',decision='NO_QUALIFYING_ACTIVE_REFUSAL_IN_FURTHER_THREE_ORIGINAL_CONTEXTS',model_routes=6,hard_timeout_seconds=20,all_uncensored=True,O0_O2_non_timing_byte_exact=True,candidate_physics_harness_criteria_changes=False,active_refusal_rollback_direct_qualification=False,reason='All three candidate heads converge; D1/D2 have potential inflow excluding rank1, D3 activates3times and converges7iterations. No refusal fabricated.',official_promotion=False,results=result)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q,indent=2))
