"""Read-only reconstruction of the original selected node52 operator."""
from pathlib import Path
import json,math,hashlib,collections
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-diag19'
def read(p):return [list(map(float,s.split())) for s in p.read_text().splitlines()]
results=[]
for opt in ['O0','O2']:
 d=R/'data'/opt/'RESUME';old=P/'data'/opt/'RESUME'
 run=json.loads((R/(opt+'_RESUME_RUN.json')).read_text())
 assert run['returncode']==0 and not run['censored'] and run['seconds']<20
 assert (d/'step_budget.txt').read_text().splitlines()==(old/'step_budget.txt').read_text().splitlines()[:42]
 a=read(d/'attempt_trace.txt');prior=read(old/'attempt_trace.txt')
 assert len(a)==52 and [x[:-1] for x in a]==[x[:-1] for x in prior[:52]]
 for n in ['begin','context_begin','ledger_begin','ledger_installed','native_installed']:
  assert (d/(n+'.txt')).read_bytes()==(old/(n+'.txt')).read_bytes()
 assert (d/'own.end').read_bytes()==(old/'own.end').read_bytes()
 v=read(d/'node_operator.txt');it=read(d/'node_iterations.txt')
 assert len(v)==197 and all(len(x)==73 for x in v)
 assert len(it)==591 and all(len(x)==28 for x in it)
 assert not (d/'node_absorption.txt').read_bytes()
 reconstruction=max(abs(sum(x[13:20])-x[20]) for x in v);assert reconstruction<1e-14
 for x in v:
  assert abs(x[19]+sum(x[23:28]))<1e-14
  assert x[13]==0 and x[15]==0 and x[16]==0
  assert all(q==0 for q in x[28:33]) # no unsaturated absorption rate
  for j in range(5):
   assert abs(x[23+j]-(x[28+j]+x[33+j]-x[38+j]-x[43+j]))<1e-14
 checks=[]
 for att in [38,50,51,52]:
  z=[x for x in v if x[0]==att];t=[x for x in it if x[0]==att]
  pairs=[]
  for fresh in z:
   if fresh[1]==0 or fresh[3]!=1:continue
   idx=z.index(fresh);before=z[idx-1]
   assert before[1]==fresh[1] and before[3]==2
   assert before[6:19]==fresh[6:19]
   assert abs((fresh[20]-before[20])-(fresh[19]-before[19]))<1e-14
   pairs.append(dict(iteration=fresh[1],h52_cm=fresh[7],cached_F52=before[20],fresh_F52=fresh[20],delta_F52=fresh[20]-before[20],delta_minus_exchange=fresh[19]-before[19],delta_exchange_by_domain=[fresh[23+j]-before[23+j] for j in range(5)],matrix_terms=before[13:19],minus_exchange_before=before[19],minus_exchange_after=fresh[19],saturated_out_to_matrix_domain3_before=before[35],saturated_out_to_matrix_domain3_after=fresh[35],saturated_in_from_matrix_domains12_before=before[38:40],saturated_in_from_matrix_domains12_after=fresh[38:40],macro_cache_flag_before=before[21]))
  last=pairs[-1]
  assert a[att-1][19]==(50 if att==52 else 52)
  assert len([x for x in t if x[2]==4])==({38:30,50:30,51:60,52:3}[att])
  if att!=52:
   assert abs(last['cached_F52'])<1e-6 and abs(last['fresh_F52'])>1e-6
   assert last['macro_cache_flag_before']==1
   assert last['saturated_out_to_matrix_domain3_before']>.009
   assert last['saturated_out_to_matrix_domain3_after']<1e-12
  else:
   assert last['delta_F52']==0 and abs(a[att-1][17])<1e-5 and a[att-1][8]==0
  checks.append(dict(attempt=att,begin_time=z[0][4],used_dt=z[0][5],used_flux_factor=z[0][22],actual_iterations=len([x for x in t if x[2]==4]),fresh_checks=len(pairs),h52_range_cm=[min(x[7] for x in z),max(x[7] for x in z)],theta52_values=sorted(set(x[9] for x in z)),pairs=pairs))
 identity=json.loads((R/(opt+'_IDENTITY.json')).read_text())
 assert all(hashlib.sha256((R/n).read_bytes()).hexdigest()==h for n,h in identity['sources'].items())
 results.append(dict(optimization=opt,seconds=run['seconds'],attempts_exact_to_DIAG19=52,commits_exact_to_DIAG19=42,operator_records=len(v),iteration_records=len(it),absorption_records=0,max_operator_reconstruction_error=reconstruction,checks=checks))
for n in ['node_operator','node_iterations','node_absorption','begin','context_begin','ledger_begin','ledger_installed','native_installed','step_budget']:
 assert (R/'data/O0/RESUME'/(n+'.txt')).read_bytes()==(R/'data/O2/RESUME'/(n+'.txt')).read_bytes()
for p in P.glob('*.f90'):
 if p.name not in ['head_diag.f90','diag_state.f90']:assert (R/p.name).read_bytes()==p.read_bytes()
q=dict(work_unit='SWAP431-MACRO-B1-NODE20',decision='DIAGNOSIS_ONLY_ORIGINAL_COUPLED_FREEZE_REFRESH_CYCLE',model_routes=2,hard_timeout_seconds=20,no_censored=True,operator_traces_O0_O2_byte_exact=True,physics_solver_BAL_policy_changes=False,full_second_period_qualification=False,official_promotion=False,results=results)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
print(json.dumps(dict(decision=q['decision'],routes=[dict(optimization=x['optimization'],seconds=x['seconds'],operator_records=x['operator_records'],iteration_records=x['iteration_records'],max_error=x['max_operator_reconstruction_error']) for x in results]),indent=2))
