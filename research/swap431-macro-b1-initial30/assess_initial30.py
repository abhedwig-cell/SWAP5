"""Bounded negative selection, including exact analytic-update guard audit."""
from pathlib import Path
import json,math,hashlib,collections
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-zero29'
def rows(p):return [list(map(float,s.split())) for s in p.read_text().splitlines()]
def f(p):return {s.split()[0].lower():list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
selection=json.loads((R/'SELECTION.json').read_text());original=rows(R.parent/'swap431-macro-b1-diag19/data/O2/RESUME/attempt_trace.txt')
result=[]
for opt in ['O0','O2']:
 for label,iters in [('F1',2),('F2',1)]:
  d=R/'data'/opt/('TRIAL_'+label);s=selection[label];o=original[s['original_attempt']-1]
  assert o[8]==4 and o[2]==s['time'] and o[3]==s['dt']
  assert o[24]-o[21]==s['original_extra_line_search_trials']
  prior=(d/'prefix_budget.txt').read_text().splitlines();old=(R.parent/'swap431-macro-b1-next18/data'/opt/'RESUME/step_budget.txt').read_text().splitlines()
  assert len(prior)==s['prior_commits'] and prior==old[:len(prior)]
  a=rows(d/'attempt_trace.txt');assert len(a)==1;x=a[0]
  assert x[2]==s['time'] and x[3]==s['dt'] and x[4:7]==[0,0,1]
  assert x[7]==iters and x[8]==0 and x[9:11]==[0,0]
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
  run=json.loads((R/(opt+'_TRIAL_'+label+'_RUN.json')).read_text());assert not run['censored'] and run['returncode']==0 and run['seconds']<20
  result.append(dict(optimization=opt,context=label,seconds=run['seconds'],original_attempt=s['original_attempt'],original_time=s['time'],original_dt=s['dt'],original_prefix_rows_byte_exact=len(prior),original_extra_line_search_trials=s['original_extra_line_search_trials'],candidate_converged=True,iterations=iters,extra_line_search_trials=x[24]-x[21],rank1_active_iterations=active,guard_counts=dict(guards),initially_partial_zero_inflow=initially_partial,max_residual=x[18],sum_residual=x[17],qualifying_active_refusal=False,inventory_error_cm=error,inventory_limit_cm=dt*1e-5))
 ident=json.loads((R/(opt+'_IDENTITY.json')).read_text());assert all(hashlib.sha256((R/n).read_bytes()).hexdigest()==h for n,h in ident['sources'].items())
for label in ['F1','F2']:
 for p in (R/'data/O0'/('TRIAL_'+label)).glob('*.txt'):
  if p.name in ['attempt_trace.txt','cost_trace.txt']:continue
  assert p.read_bytes()==(R/'data/O2'/('TRIAL_'+label)/p.name).read_bytes()
 assert [v[:-1] for v in rows(R/'data/O0'/('TRIAL_'+label)/'attempt_trace.txt')]==[v[:-1] for v in rows(R/'data/O2'/('TRIAL_'+label)/'attempt_trace.txt')]
for p in P.glob('*.f90'):assert (R/p.name).read_bytes()==p.read_bytes()
assert not list((R/'data').glob('*/DIRECT*'))
# Independent observational route must preserve the original trajectory.
scan=R/'data/O2/TRIAL_SCAN'
a=rows(scan/'attempt_trace.txt');assert len(a)==279
for x,y in zip(a,original):assert x[:1]+x[2:-1]==y[:1]+y[2:-1]
pp=(scan/'prefix_budget.txt').read_text().splitlines();assert len(pp)==141
assert pp==(R.parent/'swap431-macro-b1-next18/data/O2/RESUME/step_budget.txt').read_text().splitlines()[:141]
scanrun=json.loads((R/'O2_TRIAL_SCAN_RUN.json').read_text());assert scanrun['returncode']==0 and not scanrun['censored'] and scanrun['seconds']<20
exclude={38}
for unit in ['active27','select28','zero29']:
 for v in json.loads((R.parent/('swap431-macro-b1-'+unit)/'SELECTION.json').read_text()).values():exclude.add(v['original_attempt'])
seen=set();eligible=[]
for v in rows(scan/'domain3_limit.txt'):
 if v[1]!=0 or v[4]!=1 or v[5]!=3:continue
 k=int(v[0]);assert k not in seen;seen.add(k);x=original[k-1]
 if k not in exclude and x[8]==4 and x[3]>1e-5 and x[4]==0 and x[10]==0 and v[17]==0 and v[13]<v[12] and 0<v[23]<1 and v[22]/v[6]>1e-7 and v[18]>v[22] and v[10]==50:
  eligible.append((k,int(x[1])-1,x[2],x[3],x[24]-x[21],v[23]))
audit=json.loads((R/'OBSERVER_AUDIT.json').read_text());assert [list(v) for v in eligible]==audit['eligible']
first=min(eligible,key=lambda v:(-v[4],v[0]));second=min((v for v in eligible if v[1]!=first[1]),key=lambda v:(v[3],v[0]))
assert [first[0],second[0]]==[selection['F1']['original_attempt'],selection['F2']['original_attempt']]==[44,48]
assert len(eligible)==7
ident=json.loads((R/'OBSERVER_O2_IDENTITY.json').read_text())
assert all(hashlib.sha256((R/'observer'/n).read_bytes()).hexdigest()==h for n,h in ident['sources'].items())
# The observer changes only the bounded driver and trace gates, never candidate sources.
import difflib
patch=''
for p in R.glob('*.f90'):
 op=R/'observer'/p.name
 if p.name in ['soilwater_native.f90','macrorate_node.f90']:
  patch+=''.join(difflib.unified_diff(p.read_text().splitlines(True),op.read_text().splitlines(True),fromfile='candidate/'+p.name,tofile='observer/'+p.name))
 else:assert p.read_bytes()==op.read_bytes()
# Patch file orders soilwater before macrorate.
expected=''
for n in ['soilwater_native.f90','macrorate_node.f90']:
 expected+=''.join(difflib.unified_diff((R/n).read_text().splitlines(True),(R/'observer'/n).read_text().splitlines(True),fromfile='candidate/'+n,tofile='observer/'+n))
assert expected==(R/'observer_only.patch').read_text()
q=dict(work_unit='SWAP431-MACRO-B1-INITIAL30',decision='STRICT_INITIAL_PARTIAL_CONTEXTS_CONFIRMED_NO_ACTIVE_REFUSAL',model_routes=5,hard_timeout_seconds=20,all_uncensored=True,O0_O2_non_timing_byte_exact=True,candidate_physics_harness_criteria_changes=False,active_refusal_rollback_direct_qualification=False,reason='Both new original contexts start zero inflow and partially limited. Candidate converges2/1iterations with rank1 active throughout. No real refusal; rollback/direct remains unqualified.',official_promotion=False,observer_seconds=scanrun['seconds'],observer_original_attempts=279,observer_original_budget_rows=141,new_initially_eligible_contexts=7,selected_original_attempts=[44,48],results=result)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q,indent=2))
