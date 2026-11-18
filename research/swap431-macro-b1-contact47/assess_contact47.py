"""Read-only audit; launches no models and alters no numerical state."""
from pathlib import Path
import json, math, hashlib, csv, re
R=Path(__file__).resolve().parent; P=R.parent/'swap431-macro-b1-reference46'
W=Path('C:/Users/Veldh012/swap431-contact47-work/native')
def rows(p): return [list(map(float,s.split())) for s in p.read_text().splitlines()]
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
# No Fortran changes, including inherited observers.
for p in P.glob('*.f90'): assert p.read_bytes()==(R/p.name).read_bytes(),p.name
results=[]; events=[]
for opt in ['O0','O2']:
 assert sha(R.parent/'swap431-macro-b1-next18/data'/opt/'PREFIX/midnight.end')=='21bd728c9983d6a0d4e82d6b2fd12729dc02284277a5dab5d296d8edc1dcbf16'
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
  # Independent geometric construction from accepted waterlevel, GWL and cell bounds.
  bottom=x[69]-x[70]/2; top=min(x[69]+x[70]/2,x[48])
  span=max(0.,top-bottom); overlap=max(0.,top-max(bottom,x[33]))
  effective_contact=overlap/x[70]
  assert math.isclose(span/x[70],v[21],rel_tol=1e-12)
  assert math.isclose(effective_contact,v[21]*v[22],rel_tol=1e-12)
  direct=v[17]*v[18]*(4/v[20])*effective_contact*v[10]*ds
  assert math.isclose(direct,shadow,rel_tol=1e-12)
  ratio=shadow*active/v[10]
  assert math.isclose(ratio,v[24]/v[19],rel_tol=1e-14)
  assert math.isclose(actual,x[30]*ratio/v[27],rel_tol=1e-14)
  assert a[int(x[0])-1][6]==1 and v[25]==v[24] # FrReduQ and choice unchanged.
  assert v[23]<4 and 0<limited<shadow and 0<v[21]<1
  double_wet=shadow*v[21]; double_contact=shadow*v[22]
  assert double_wet<shadow and double_contact<shadow
  q=dict(optimization=opt,attempt=int(v[0]),time=v[1],dt=v[2],initial_sorptivity=v[10],active_sorptivity=active,RATE_contact=v[22],END_contact=x[60],reference_before=x[62],reference_after=x[65],native_increment=x[65]-x[62],effective_contact=effective_contact,geometric_relative_error=abs(direct-shadow)/shadow,sorption_law_relative_error=abs(ratio-v[24]/v[19])/(v[24]/v[19]),actual_law_relative_error=abs(actual-x[30]*ratio/v[27])/actual,double_wet_shadow=double_wet,double_contact_shadow=double_contact,RATE_theoretical_shadow=shadow,stock_limited_shadow=limited,actual_theta_contribution=actual)
  selected.append(q); events.append(q)
 run=json.loads((R/(opt+'_TRAJ_RUN.json')).read_text()); assert run['returncode']==0 and not run['censored'] and run['seconds']<20
 ident=json.loads((R/(opt+'_IDENTITY.json')).read_text()); assert all(sha(R/n)==h for n,h in ident['sources'].items()) and sha(W/opt/'native09.exe')==ident['exe_sha256']
 def stat(k): return dict(min=min(v[k] for v in selected),max=max(v[k] for v in selected),sum=math.fsum(v[k] for v in selected))
 results.append(dict(optimization=opt,seconds=run['seconds'],events=90,attempt_range=[36,125],parent_numeric_outputs_exact=True,native_reference_increment=stat('native_increment'),RATE_theoretical_shadow=stat('RATE_theoretical_shadow'),stock_limited_shadow=stat('stock_limited_shadow'),actual_theta_contribution=stat('actual_theta_contribution'),reference_value=selected[0]['reference_before'],max_geometry_relative_error=max(v['geometric_relative_error'] for v in selected),max_sorption_law_relative_error=max(v['sorption_law_relative_error'] for v in selected),max_actual_law_relative_error=max(v['actual_law_relative_error'] for v in selected),effective_contact=stat('effective_contact'),double_wet_shadow=stat('double_wet_shadow'),double_contact_shadow=stat('double_contact_shadow')))
for p in (R/'data/O0/TRAJ').glob('*.txt'):
 if p.name not in ['attempt_trace.txt','cost_trace.txt']: assert p.read_bytes()==(R/'data/O2/TRAJ'/p.name).read_bytes(),p.name
assert [x[:-1] for x in rows(R/'data/O0/TRAJ/attempt_trace.txt')]==[x[:-1] for x in rows(R/'data/O2/TRAJ/attempt_trace.txt')]
with (R/'SAME90_CONTACT_AUDIT.csv').open('w',newline='',encoding='utf-8') as f:
 w=csv.DictWriter(f,fieldnames=list(events[0])); w.writeheader(); w.writerows(events)
q=dict(work_unit='SWAP431-MACRO-B1-CONTACT47',decision='PASS_BOUNDED_RATE_CONTACT_CONTRACT_ALGEBRA_O0_O2_NO_IMPLEMENTATION',source_checkpoint='49334bcb8',model_routes=2,hard_timeout_seconds=20,extra_provider_evaluations=0,source_physics_exact_parent=True,O0_O2_non_timing_byte_exact=True,clock_continuation_remains_justified=True,contract_selected_RATE_geometry_initial_sorptivity_no_stock_factor=True,contract_selection_is_discrete_design_not_unique_manual_requirement=True,reference_repair_fed_back=False,rollback_new_restart_not_tested=True,no_physics_reference_clock_solver_budget_change=True,full_period_new_restart_or_general_admission=False,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',official_promotion=False,results=results)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8'); print(json.dumps(q,indent=2))
