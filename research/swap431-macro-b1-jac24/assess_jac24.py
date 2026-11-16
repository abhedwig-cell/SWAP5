"""Read-only calibration, rank-one solve and coupled head qualification."""
from pathlib import Path
import hashlib,json,math
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-fresh22';S=R.parent/'swap431-macro-b1-sense23'
def read(p):return [list(map(float,s.split())) for s in p.read_text().splitlines()]
def fields(p):return {s.split()[0]:list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
 return h.hexdigest()
results=[]
for opt in ['O0','O2']:
 d=R/'data'/opt/'RESUME';old=P/'data'/opt/'RESUME'
 run=json.loads((R/(opt+'_RESUME_RUN.json')).read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20
 for n in ['begin','context_begin','ledger_begin','ledger_installed','native_installed','target_begin','context_target_begin']:
  assert (d/(n+'.txt')).read_bytes()==(old/(n+'.txt')).read_bytes(),n
 assert (d/'step_budget.txt').read_bytes()==(old/'step_budget.txt').read_bytes()
 a=read(d/'attempt_trace.txt');b=read(old/'attempt_trace.txt');assert len(a)==38
 assert [x[:-1] for x in a[:37]]==[x[:-1] for x in b[:37]]
 x=a[-1];assert x[:7]==b[37][:7]
 assert x[7]==2 and x[8]==0 and x[9:17]==[0]*8 and x[6]==1
 assert abs(x[17])<1e-5 and x[18]<1e-6 and x[19]==51
 assert x[20:26]==[4,2,4,2,2,1] # fresh V1 actually executed
 assert sha(d/'calibration_base.bin')=='aec5d4383614499853fe809018b53844d54d852a205a77f45c28ea28378f62c3'
 assert sha(d/'jac24_current.bin')==sha(d/'jac24_restored.bin')
 cal=fields(d/'jac24_calibration.txt');assert cal['meta'][0]==1
 measured=json.loads((S/'RESULT.json').read_text())['results'][0]['derivatives']
 comparisons=[]
 for j in [50,51,52]:
  pred=(cal['base_q_derivative'][51] if j==52 else 0)-cal['u'][51]*cal['v'][j-1]
  v=next(t['dQ3node52_dh'] for t in measured if t['node']==j and t['epsilon_cm']==5e-5)
  assert abs(pred-v)<1e-8
  comparisons.append(dict(node=j,analytic_domain3_Q52_derivative=pred,finite_difference_reference=v,error=pred-v))
 trace=read(d/'jac24_trace.txt');assert len(trace)==2 and all(len(t)==26 for t in trace)
 assert all(t[2]==1 and t[16]<1e-12 for t in trace)
 assert all(t[14]>1 for t in trace) # measured positive Sherman Morrison denominator
 operator=read(d/'node_operator.txt');assert len(operator)==4
 assert all(t[21]==0 and t[22]==1 for t in operator)
 assert max(abs(sum(t[13:20])-t[20]) for t in operator)<1e-14
 assert operator[-1][6:21]==operator[-2][6:21] # unchanged fresh V1 evaluation
 solver=fields(d/'solver_1.txt');assert solver['outcome']==[0,2,1]
 assert max(map(abs,solver['residual']))==x[18]
 assert abs(sum(solver['residual'])-x[17])<1e-14
 assert x[18]==max(map(abs,solver['residual']))
 assert (d/'target_return.txt').read_bytes()!=(d/'target_begin.txt').read_bytes()
 identity=json.loads((R/(opt+'_IDENTITY.json')).read_text());assert all(sha(R/n)==h for n,h in identity['sources'].items())
 results.append(dict(optimization=opt,seconds=run['seconds'],calibration=comparisons,calibration_trial_state_restored_exact=True,prior_attempts_exact=37,prior_commits_exact=36,target_begin_t1900=x[2],target_dt=x[3],head_converged=True,iterations=2,used_flux_factor=x[6],max_abs_residual=x[18],sum_residual=x[17],fresh_V1_checks=x[25],extra_line_search_trials=x[24]-x[21],rank1_active_iterations=2,rank1_linear_residual_max=max(t[16] for t in trace),Sherman_Morrison_denominators=[t[14] for t in trace],head_return_before_host_commit=True))
for p in (R/'data/O0/RESUME').glob('*.txt'):
 if p.name in ['cost_trace.txt','attempt_trace.txt']:continue
 assert p.read_bytes()==(R/'data/O2/RESUME'/p.name).read_bytes(),p.name
assert [x[:-1] for x in read(R/'data/O0/RESUME/attempt_trace.txt')]==[x[:-1] for x in read(R/'data/O2/RESUME/attempt_trace.txt')]
for n in ['calcgwl_probe.f90','diag_state.f90','probe_state.f90','integral_canopy.f90','ledger_state.f90','macropore_native.f90','meteo_native.f90','native_state.f90','soilwater_native.f90','swap_native.f90','swapoutput_native.f90']:
 assert (R/n).read_bytes()==(S/n).read_bytes(),n
q=dict(work_unit='SWAP431-MACRO-B1-JAC24',decision='LOCAL_HEAD_PASS_ANALYTIC_RANK1_GWL_MINIMUM_STOCK_COUPLING',model_routes=2,hard_timeout_seconds=20,all_uncensored=True,non_timing_O0_O2_byte_exact=True,physical_equations_criteria_dt_reduction_changes=False,solver_change='Current macro operator plus localized analytic domain3 factor gradient and rank1 linear solve; target38 only',qualification_scope='Original target head returned converged before host commit; no rollback/retry/restart or period admission for this candidate',official_promotion=False,results=results)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q,indent=2))
