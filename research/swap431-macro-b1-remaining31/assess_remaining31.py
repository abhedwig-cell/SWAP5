"""Bounded negative selection, including exact analytic-update guard audit."""
from pathlib import Path
import json,math,hashlib,collections
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-initial30'
def rows(p):return [list(map(float,s.split())) for s in p.read_text().splitlines()]
def f(p):return {s.split()[0].lower():list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
selection=json.loads((R/'SELECTION.json').read_text());original=rows(R.parent/'swap431-macro-b1-diag19/data/O2/RESUME/attempt_trace.txt')
result=[]
for opt in ['O0','O2']:
 for label,iters in [('G1',2),('G2',2),('G3',2),('G4',2),('G5',2)]:
  d=R/'data'/opt/('TRIAL_'+label);s=selection[label];o=original[s['original_attempt']-1]
  assert o[8]==4 and o[2]==s['time'] and o[3]==s['dt']
  assert o[24]-o[21]==s['original_extra_line_search_trials']
  prior=(d/'prefix_budget.txt').read_text().splitlines();old=(R.parent/'swap431-macro-b1-next18/data'/opt/'RESUME/step_budget.txt').read_text().splitlines()
  assert len(prior)==s['prior_commits'] and prior==old[:len(prior)]
  a=rows(d/'attempt_trace.txt');assert len(a)==1;x=a[0]
  assert x[2]==s['time'] and x[3]==s['dt'] and x[4:7]==[0,0,1]
  assert x[7]==iters and x[8]==0 and x[9:11]==[0,0] and x[12:17]==[0,0,0,0,0] and x[25]==1 and x[24]-x[21]==0
  j=rows(d/'jac24_trace.txt');assert len(j)==iters
  active=sum(v[2] for v in j);assert active==iters
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
  assert all(v[17]==0 for v in limits)
  assert guards['eligible_partial_zero_inflow']==active
  for v,jv in zip(limits,j):
   eligible=v[17]==0 and v[13]<v[12] and 0<v[23]<1 and v[22]/v[6]>1e-7 and v[18]>v[22] and v[10]==50
   assert eligible==bool(jv[2])
  initially_partial=bool(j[0][2]);assert initially_partial
  observer=rows(P/'data/O2/TRIAL_SCAN/domain3_limit.txt')
  first=next(v for v in observer if v[0]==s['original_attempt'] and v[1]==0 and v[4]==1 and v[5]==3)
  initial=next(v for v in rows(d/'domain3_limit.txt') if v[1]==0 and v[4]==1 and v[5]==3)
  assert first[6:]==initial[6:]
  for col,key in [(17,'initial_inflow'),(13,'initial_minimum_stock'),(12,'initial_water_stock'),(23,'initial_factor'),(9,'initial_GWL')]:
   assert first[col]==s[key]
  bb=rows(d/'step_budget.txt');assert len(bb)==1;v=bb[0];dt=v[1];assert dt==s['dt'] and v[16]==1
  begin=f(d/'begin_1.txt');end=f(d/'committed.txt');cb=f(d/'context_begin_1.txt');ce=f(d/'context_committed.txt')
  matrix=math.fsum((y-z)*dz*fr for z,y,dz,fr in zip(begin['theta'],end['theta'],begin['dz'],begin['fraction']))
  macro=math.fsum(y-z for z,y in zip(begin['macro_domain'],end['macro_domain']))
  stock=matrix+macro+end['pond'][0]-begin['pond'][0]+ce['sicact'][0]-cb['sicact'][0]
  external=dt*(v[2]+v[3]+v[4]-v[5]-v[6]-v[7]-v[8]+v[9]-v[10]+v[11]-v[12])-v[13]
  error=stock-external;assert abs(error)<dt*1e-5 and abs(error-x[17]*dt)<1e-15
  domain_errors=[]
  for domain in range(5):
   de=end['macro_domain'][domain]-begin['macro_domain'][domain]-dt*(v[17+domain]+v[22+domain]-v[27+domain]-(v[12] if domain==0 else 0))
   assert abs(de)<1e-13;domain_errors.append(de)
  lb=f(d/'ledger_begin_1.txt');le=f(d/'ledger_committed.txt')
  for key,col in [('cgrai',2),('cgird',3),('crunon',4),('caintc',5),('cepd',6),('cevap',7),('cqrot',8),('cqbot',9),('cqdra',10),('cqssdi',11),('cqmpoutdrrap',12)]:
   assert abs(le[key][0]-lb[key][0]-dt*v[col])<1e-12
  run=json.loads((R/(opt+'_TRIAL_'+label+'_RUN.json')).read_text());assert not run['censored'] and run['returncode']==0 and run['seconds']<20
  result.append(dict(optimization=opt,context=label,seconds=run['seconds'],original_attempt=s['original_attempt'],original_time=s['time'],original_dt=s['dt'],original_prefix_rows_byte_exact=len(prior),original_extra_line_search_trials=s['original_extra_line_search_trials'],candidate_converged=True,iterations=iters,extra_line_search_trials=x[24]-x[21],rank1_active_iterations=active,guard_counts=dict(guards),initially_partial_zero_inflow=initially_partial,max_residual=x[18],sum_residual=x[17],qualifying_active_refusal=False,domain_errors_cm=domain_errors,inventory_error_cm=error,inventory_limit_cm=dt*1e-5))
 ident=json.loads((R/(opt+'_IDENTITY.json')).read_text());assert all(hashlib.sha256((R/n).read_bytes()).hexdigest()==h for n,h in ident['sources'].items())
for label in ['G1','G2','G3','G4','G5']:
 for p in (R/'data/O0'/('TRIAL_'+label)).glob('*.txt'):
  if p.name in ['attempt_trace.txt','cost_trace.txt']:continue
  assert p.read_bytes()==(R/'data/O2'/('TRIAL_'+label)/p.name).read_bytes()
 assert [v[:-1] for v in rows(R/'data/O0'/('TRIAL_'+label)/'attempt_trace.txt')]==[v[:-1] for v in rows(R/'data/O2'/('TRIAL_'+label)/'attempt_trace.txt')]
for p in P.glob('*.f90'):assert (R/p.name).read_bytes()==p.read_bytes()
assert not list((R/'data').glob('*/DIRECT*'))
# Inherit the INITIAL30 observational evidence; never rerun the original scan.
meta=json.loads((P/'EVIDENCE.json').read_text())
assert hashlib.sha256((P/meta['file']).read_bytes()).hexdigest()==meta['sha256']=='69e8e0512bcf544a3d830acaba8642289cae74fe4b6edc4d5d1a12b6d18c861c'
pool={v[0] for v in json.loads((P/'OBSERVER_AUDIT.json').read_text())['eligible']}
used={v['original_attempt'] for k,v in json.loads((P/'SELECTION.json').read_text()).items() if k!='SCAN'}
remaining=sorted(pool-used)
assert remaining==[36,40,41,43,46]==[v['original_attempt'] for v in selection.values()]
# Together with INITIAL30, every identified new strict-initial member was tested.
prev=json.loads((P/'RESULT.json').read_text())
assert prev['active_refusal_rollback_direct_qualification'] is False
assert all(v['candidate_converged'] and v['initially_partial_zero_inflow'] for v in prev['results'])
q=dict(work_unit='SWAP431-MACRO-B1-REMAINING31',decision='FINITE_INITIAL30_POOL_EXHAUSTED_NO_ACTIVE_REFUSAL',model_routes=10,hard_timeout_seconds=20,all_uncensored=True,O0_O2_non_timing_byte_exact=True,candidate_physics_harness_criteria_changes=False,active_refusal_rollback_direct_qualification=False,reason='All five remaining original strict-initial zero inflow partial contexts converge2iterations with rank1 active throughout. Together with INITIAL30, all seven identified new pool members tested, none refused. Active rollback/direct remains unqualified.',official_promotion=False,no_new_observer=True,initial30_pool_members=7,previously_tested_original_attempts=[44,48],selected_original_attempts=remaining,untested_pool_members=[],finite_pool_exhausted=True,results=result)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q,indent=2))
