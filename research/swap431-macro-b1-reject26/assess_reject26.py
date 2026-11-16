"""Read-only genuine refusal, original rollback and direct smaller retry comparison."""
from pathlib import Path
import json,math,hashlib
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-commit25';OLD=R.parent/'swap431-macro-b1-retry07'
def f(p):return {s.split()[0].lower():list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
def rows(p):return [list(map(float,s.split())) for s in p.read_text().splitlines()]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
results=[]
different={'macro_exchange','macro_rapid','matrix_exchange','boundary_rates','event','reference','sorptivity'}
for opt in ['O0','O2']:
 t=R/'data'/opt/'TRIAL';d=R/'data'/opt/'DIRECT'
 assert (t/'origin.txt').read_bytes()==(OLD/'data'/opt/'B_TRIAL/origin.txt').read_bytes()
 for n in ['origin','context_origin','ledger_origin','accepted_return','context_accepted_return','ledger_accepted_return','committed','context_committed','ledger_committed','step_budget']:
  assert (t/(n+'.txt')).read_bytes()==(d/(n+'.txt')).read_bytes(),n
 assert (t/'solver_2.txt').read_bytes()==(d/'solver_1.txt').read_bytes()
 tr=rows(t/'attempt_trace.txt');dr=rows(d/'attempt_trace.txt')
 assert len(tr)==2 and len(dr)==1
 large,small=tr
 assert large[2]==small[2] and large[3]==2e-5 and small[3]==1e-5
 assert large[7]==31 and large[8]==4 and large[9]==1 and large[10]==0 and large[4:7]==[0,0,1]
 assert small[7]==6 and small[8]==0 and small[9:11]==[0,0] and small[4:7]==[0,0,1]
 assert small[2:-1]==dr[0][2:-1]
 origin=f(t/'origin.txt');rb=f(t/'rollback_1.txt');smallbegin=f(t/'begin_2.txt');directbegin=f(d/'begin_1.txt')
 assert rb['controls'][:7]==origin['controls'][:7] and rb['controls'][7]==1
 instantdiff={k for k in origin if origin[k]!=rb[k]}
 assert instantdiff==different|{'controls'}
 assert {k for k in smallbegin if smallbegin[k]!=directbegin[k]}==different
 for n in ['ledger_begin_1','ledger_returned_1','ledger_rollback_1','ledger_begin_2','ledger_returned_2']:
  assert (t/(n+'.txt')).read_bytes()==(t/'ledger_origin.txt').read_bytes()
 balances=[]
 for mode,dd,begin in [('TRIAL',t,'begin_2'),('DIRECT',d,'begin_1')]:
  a=f(dd/(begin+'.txt'));b=f(dd/'committed.txt');ca=f(dd/('context_'+begin+'.txt'));cb=f(dd/'context_committed.txt')
  la=f(dd/('ledger_'+begin+'.txt'));lb=f(dd/'ledger_committed.txt')
  xx=rows(dd/'step_budget.txt');assert len(xx)==1;x=xx[0];dt=x[1]
  assert dt==1e-5 and x[16]==1 and b['controls'][0]==x[0] and abs(x[0]-a['controls'][0]-dt)<5e-12
  assert all(v[2]==0 for v in rows(dd/'jac24_trace.txt'))
  limits=[v for v in rows(dd/'domain3_limit.txt') if v[5]==3]
  assert all(v[23]==1 and v[22]==0 for v in limits)
  matrix=math.fsum((v-u)*dz*fr for u,v,dz,fr in zip(a['theta'],b['theta'],a['dz'],a['fraction']))
  macro=math.fsum(v-u for u,v in zip(a['macro_domain'],b['macro_domain']))
  pond=b['pond'][0]-a['pond'][0];can=cb['sicact'][0]-ca['sicact'][0]
  external=dt*(x[2]+x[3]+x[4]-x[5]-x[6]-x[7]-x[8]+x[9]-x[10]+x[11]-x[12])-x[13]
  error=matrix+macro+pond+can-external
  assert abs(error)<dt*1e-5 and abs(error-small[17]*dt)<1e-15
  domains=[]
  for j in range(5):
   e=b['macro_domain'][j]-a['macro_domain'][j]-dt*(x[17+j]+x[22+j]-x[27+j]-(x[12] if j==0 else 0))
   assert abs(e)<1e-13;domains.append(e)
  for key,col in [('cgrai',2),('cgird',3),('crunon',4),('caintc',5),('cepd',6),('cevap',7),('cqrot',8),('cqbot',9),('cqdra',10),('cqssdi',11),('cqmpoutdrrap',12)]:
   assert abs(lb[key][0]-la[key][0]-dt*x[col])<1e-12
  run=json.loads((R/(opt+'_'+mode+'_RUN.json')).read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20
  assert 'REJECT26_HOST_COMMITTED' in (dd/'outcome.txt').read_text()
  balances.append(dict(mode=mode,seconds=run['seconds'],committed_time=x[0],used_dt_days=dt,matrix_change_cm=matrix,macro_change_cm=macro,canopy_change_cm=can,external_cm=external,inventory_error_cm=error,original_total_residual_integral_limit_cm=dt*1e-5,domain_errors_cm=domains))
 identity=json.loads((R/(opt+'_IDENTITY.json')).read_text());assert all(sha(R/n)==h for n,h in identity['sources'].items())
 results.append(dict(optimization=opt,original_B_inventory_byte_exact=True,real_refusal=True,large_iterations=30,large_final_max_residual=large[18],large_final_sum_residual=large[17],retry_iterations=6,retry_final_max_residual=small[18],retry_final_sum_residual=small[17],original_rollback_physical_core_exact=True,immediate_rollback_differences=sorted(instantdiff),small_retry_pre_head_work_differences=sorted(different),accepted_solver_full_dump_exact_to_direct=True,accepted_context_ledger_commit_budget_byte_exact_to_direct=True,rank1_update_active=False,active_update_refusal_qualification=False,balances=balances))
for mode in ['TRIAL','DIRECT']:
 for p in (R/'data/O0'/mode).glob('*.txt'):
  if p.name in ['cost_trace.txt','attempt_trace.txt']:continue
  assert p.read_bytes()==(R/'data/O2'/mode/p.name).read_bytes(),str(p)
 assert [v[:-1] for v in rows(R/'data/O0'/mode/'attempt_trace.txt')]==[v[:-1] for v in rows(R/'data/O2'/mode/'attempt_trace.txt')]
for p in P.glob('*.f90'):
 if p.name not in ['soilwater_native.f90','diag_state.f90','head_diag.f90']:assert (R/p.name).read_bytes()==p.read_bytes(),p.name
q=dict(work_unit='SWAP431-MACRO-B1-REJECT26',decision='PASS_ORIGINAL_B_REFUSAL_ROLLBACK_DIRECT_RETRY_WITH_ACTIVE_UPDATE_EXCLUSION',model_routes=4,hard_timeout_seconds=20,all_uncensored=True,non_timing_O0_O2_byte_exact=True,physics_criteria_dt_reduction_policy_changes=False,rank1_algorithm_changes=False,scope='Full candidate evaluated in originalB, rank1 inactive there; no proof of refusal while update active, no nextstep/restart/period admission',official_promotion=False,results=results)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q,indent=2))
