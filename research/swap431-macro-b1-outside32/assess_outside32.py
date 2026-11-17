"""Bounded negative selection, including exact analytic-update guard audit."""
from pathlib import Path
import json,math,hashlib,collections
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-remaining31'
def rows(p):return [list(map(float,s.split())) for s in p.read_text().splitlines()]
def f(p):return {s.split()[0].lower():list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
selection=json.loads((R/'SELECTION.json').read_text());original=rows(R.parent/'swap431-macro-b1-diag19/data/O2/RESUME/attempt_trace.txt')
result=[]
for opt in ['O0','O2']:
 for label,iters in [('H1',6),('H2',2)]:
  d=R/'data'/opt/('TRIAL_'+label);s=selection[label];o=original[s['original_attempt']-1]
  assert o[8]==4 and o[2]==s['time'] and o[3]==s['dt']
  assert o[24]-o[21]==s['original_extra_line_search_trials']
  prior=(d/'prefix_budget.txt').read_text().splitlines();old=(R.parent/'swap431-macro-b1-next18/data'/opt/'RESUME/step_budget.txt').read_text().splitlines()
  assert len(prior)==s['prior_commits'] and prior==old[:len(prior)]
  a=rows(d/'attempt_trace.txt');assert len(a)==1;x=a[0]
  assert x[2]==s['time'] and x[3]==s['dt'] and x[4:7]==[0,0,1]
  assert x[7]==iters and x[8]==0 and x[9:11]==[0,0] and x[12:17]==[0,0,0,0,0] and x[25]==1 and x[24]-x[21]==0
  j=rows(d/'jac24_trace.txt');assert len(j)==iters
  active=sum(v[2] for v in j);assert active=={'H1':3,'H2':1}[label]
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
  initially_partial=bool(j[0][2]);assert not initially_partial
  observer=rows(R/'data/O2/TRIAL_SCAN/domain3_limit.txt')
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
for label in ['H1','H2']:
 for p in (R/'data/O0'/('TRIAL_'+label)).glob('*.txt'):
  if p.name in ['attempt_trace.txt','cost_trace.txt']:continue
  assert p.read_bytes()==(R/'data/O2'/('TRIAL_'+label)/p.name).read_bytes()
 assert [v[:-1] for v in rows(R/'data/O0'/('TRIAL_'+label)/'attempt_trace.txt')]==[v[:-1] for v in rows(R/'data/O2'/('TRIAL_'+label)/'attempt_trace.txt')]
for p in P.glob('*.f90'):assert (R/p.name).read_bytes()==p.read_bytes()
assert not list((R/'data').glob('*/DIRECT*'))
# Preserve the exact original trajectory in one bounded observational route.
scan=R/'data/O2/TRIAL_SCAN';a=rows(scan/'attempt_trace.txt');assert len(a)==660
for x,y in zip(a,original):assert x[:1]+x[2:-1]==y[:1]+y[2:-1]
pp=(scan/'prefix_budget.txt').read_text().splitlines();assert len(pp)==312
assert pp==(R.parent/'swap431-macro-b1-next18/data/O2/RESUME/step_budget.txt').read_text().splitlines()[:312]
scanrun=json.loads((R/'O2_TRIAL_SCAN_RUN.json').read_text());assert scanrun['returncode']==0 and not scanrun['censored'] and scanrun['seconds']<20
exclude={38}
for unit in ['active27','select28','zero29','initial30','remaining31']:
 for k,v in json.loads((R.parent/('swap431-macro-b1-'+unit)/'SELECTION.json').read_text()).items():
  if k!='SCAN':exclude.add(v['original_attempt'])
seen=set();failed=[];guards=collections.Counter()
for v in rows(scan/'domain3_limit.txt'):
 if v[1]!=0 or v[4]!=1 or v[5]!=3:continue
 k=int(v[0]);assert k not in seen and 580<=k<=660;seen.add(k);x=original[k-1]
 if k in exclude or x[8]!=4 or x[3]<=1e-5 or x[4]!=0 or x[10]!=0:continue
 failed.append(k)
 assert v[17]==0 and v[13]==v[12]
 guards['minimum_equals_stock']+=1
assert len(seen)==81 and len(failed)==37 and guards=={'minimum_equals_stock':37}
audit=json.loads((R/'OBSERVER_AUDIT.json').read_text());assert failed==audit['original_new_refusals'] and audit['eligible']==[] and audit['guard_counts']==dict(guards)
first=min(failed,key=lambda n:(-(original[n-1][24]-original[n-1][21]),n))
second=min((n for n in failed if original[n-1][19]!=52 and original[n-1][1]!=original[first-1][1]),key=lambda n:(-(original[n-1][24]-original[n-1][21]),n))
assert [first,second]==[620,610]==[selection['H1']['original_attempt'],selection['H2']['original_attempt']]
revision=json.loads((R/'SCOPE_REVISION.json').read_text());assert revision['changed_numerical_candidate_or_activation_guard'] is False and revision['initial_partial_requirement_not_qualified']
ident=json.loads((R/'OBSERVER_O2_IDENTITY.json').read_text());assert all(hashlib.sha256((R/'observer'/n).read_bytes()).hexdigest()==h for n,h in ident['sources'].items())
import difflib
for p in R.glob('*.f90'):
 if p.name not in ['soilwater_native.f90','macrorate_node.f90']:assert p.read_bytes()==(R/'observer'/p.name).read_bytes()
expected=''
for n in ['soilwater_native.f90','macrorate_node.f90']:
 expected+=''.join(difflib.unified_diff((R/n).read_text().splitlines(True),(R/'observer'/n).read_text().splitlines(True),fromfile='candidate/'+n,tofile='observer/'+n))
assert expected==(R/'observer_only.patch').read_text()
q=dict(work_unit='SWAP431-MACRO-B1-OUTSIDE32',decision='LATER_ACTIVATION_CONFIRMED_IN_TWO_NEW_CONTEXTS_NO_ACTIVE_REFUSAL',model_routes=5,hard_timeout_seconds=20,all_uncensored=True,O0_O2_non_timing_byte_exact=True,candidate_physics_harness_criteria_changes=False,active_refusal_rollback_direct_qualification=False,reason='Observer37new refusals start zero inflow fully constrained, no strict-initial partial context. Revised max2 selection in samewindow tests actual later activation; candidates620/610 converge6/2iterations with rank1active3/1. No true candidate refusal; rollback/direct remains unqualified.',official_promotion=False,observer_seconds=scanrun['seconds'],observer_original_attempts=660,observer_original_budget_rows=312,observation_window=[580,660],initial_records=81,new_original_refusals=37,strict_initial_partial_eligible=0,initial_partial_requirement_not_qualified=True,scope_revision_before_candidate_execution=True,selected_original_attempts=[620,610],results=result)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q,indent=2))
