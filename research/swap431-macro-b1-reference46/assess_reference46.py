"""Read-only audit; launches no models and alters no numerical state."""
from pathlib import Path
import json, math, hashlib, csv, re
R=Path(__file__).resolve().parent; P=R.parent/'swap431-macro-b1-clock45'
W=Path('C:/Users/Veldh012/swap431-reference46-work/native')
def rows(p): return [list(map(float,s.split())) for s in p.read_text().splitlines()]
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
# Reverse only the preregistered observational diff and compare every source.
patch=(R/'OBSERVATION_CHANGES.patch').read_text().splitlines(True)
for p in P.glob('*.f90'):
 s=(R/p.name).read_text()
 if p.name in ['macropore_native.f90','macrorate_node.f90']:
  section=''.join(patch).split('+++ REFERENCE46/'+p.name+'\n',1)[1].split('--- CLOCK45/',1)[0]
  for h in re.split(r'@@[^\n]*\n',section)[1:]:
   lines=h.splitlines(True); old=''.join(x[1:] for x in lines if x[:1] in [' ','-']); new=''.join(x[1:] for x in lines if x[:1] in [' ','+'])
   assert s.count(new)==1,(p.name,'ambiguous hunk'); s=s.replace(new,old,1)
 assert s==p.read_text(),p.name
results=[]; events=[]
for opt in ['O0','O2']:
 d=R/'data'/opt/'TRAJ'; old=P/'data'/opt/'TRAJ'
 a=rows(d/'attempt_trace.txt'); c=rows(d/'clock45_trace.txt'); z=rows(d/'reference46_trace.txt'); h=rows(d/'history44_trace.txt')
 assert len(a)==len(c)==len(z)==360 and all(len(x)==28 for x in z)
 assert [x[:-1] for x in a]==[x[:-1] for x in rows(old/'attempt_trace.txt')]
 for p in old.glob('*.txt'):
  if p.name not in ['attempt_trace.txt','cost_trace.txt']: assert p.read_bytes()==(d/p.name).read_bytes(),p.name
 ids={int(x[0]) for x in h if x[12]==0 and x[13]==0}; assert ids==set(range(36,126))
 selected=[]
 for v,x in zip(z,c):
  if int(x[0]) not in ids: continue
  assert v[0]==v[3]==x[0] and v[4]==x[45] and v[5]==a[int(x[0])-1][20] and v[7]==v[26]==1
  assert v[1:3]==x[1:3] and v[8]==x[61] and v[11]==x[62]
  assert x[60]==0 and x[65]==x[62] and x[51]>0 and x[55]==1 and 0<x[30]<1
  active=v[15]*((v[11]-v[12])/(v[13]-v[14]))**v[16]
  assert active==v[9]
  ds=math.sqrt(v[8]+v[2])-math.sqrt(v[8])
  coeff=v[17]*v[18]*(4/v[20])*v[21]*v[22]
  pre=active*v[17]*v[18]*(4*v[19]/v[20])*v[21]*ds
  assert math.isclose(pre,v[23],rel_tol=1e-14) and v[23]<4
  assert v[24]==v[22]*v[23] and v[25]==v[24]==x[39]
  shadow=coeff*v[10]*ds; limited=x[30]*shadow
  actual=x[51]*x[2]/(v[27]*v[19])
  assert shadow>1e6*math.ulp(v[11]) and limited>0 and actual>0
  assert v[10]>0 and v[22]>0 and x[59]>0 and x[64]>x[61]
  q=dict(optimization=opt,attempt=int(v[0]),time=v[1],dt=v[2],initial_sorptivity=v[10],active_sorptivity=active,RATE_contact=v[22],END_contact=x[60],reference_before=x[62],reference_after=x[65],native_increment=x[65]-x[62],RATE_theoretical_shadow=shadow,stock_limited_shadow=limited,actual_theta_contribution=actual)
  selected.append(q); events.append(q)
 run=json.loads((R/(opt+'_TRAJ_RUN.json')).read_text()); assert run['returncode']==0 and not run['censored'] and run['seconds']<20
 ident=json.loads((R/(opt+'_IDENTITY.json')).read_text()); assert all(sha(R/n)==h for n,h in ident['sources'].items()) and sha(W/opt/'native09.exe')==ident['exe_sha256']
 def stat(k): return dict(min=min(v[k] for v in selected),max=max(v[k] for v in selected),sum=math.fsum(v[k] for v in selected))
 results.append(dict(optimization=opt,seconds=run['seconds'],events=90,attempt_range=[36,125],parent_numeric_outputs_exact=True,native_reference_increment=stat('native_increment'),RATE_theoretical_shadow=stat('RATE_theoretical_shadow'),stock_limited_shadow=stat('stock_limited_shadow'),actual_theta_contribution=stat('actual_theta_contribution'),reference_value=selected[0]['reference_before']))
for p in (R/'data/O0/TRAJ').glob('*.txt'):
 if p.name not in ['attempt_trace.txt','cost_trace.txt']: assert p.read_bytes()==(R/'data/O2/TRAJ'/p.name).read_bytes(),p.name
assert [x[:-1] for x in rows(R/'data/O0/TRAJ/attempt_trace.txt')]==[x[:-1] for x in rows(R/'data/O2/TRAJ/attempt_trace.txt')]
with (R/'SAME90_REFERENCE_AUDIT.csv').open('w',newline='',encoding='utf-8') as f:
 w=csv.DictWriter(f,fieldnames=list(events[0])); w.writeheader(); w.writerows(events)
q=dict(work_unit='SWAP431-MACRO-B1-REFERENCE46',decision='BOUNDED_THEORETICAL_REFERENCE_END_CONTACT_INCONSISTENCY_CONFIRMED_NO_REPAIR_O0_O2',source_checkpoint='1d3386188',model_routes=2,hard_timeout_seconds=20,extra_provider_evaluations=0,source_physics_exact_parent=True,O0_O2_non_timing_byte_exact=True,clock_continuation_remains_justified=True,shadow_is_not_implemented_or_uniquely_prescribed_replacement=True,no_physics_reference_clock_solver_budget_change=True,full_period_new_restart_or_general_admission=False,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',official_promotion=False,results=results)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8'); print(json.dumps(q,indent=2))
