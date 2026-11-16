"""Read-only assessment of one localized current-operator experiment."""
from pathlib import Path
import json,math,hashlib,collections
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-limit21'
def read(p):return [list(map(float,s.split())) for s in p.read_text().splitlines()]
q=[]
for opt in ['O0','O2']:
 d=R/'data'/opt/'RESUME';old=P/'data'/opt/'RESUME'
 run=json.loads((R/(opt+'_RESUME_RUN.json')).read_text());assert not run['censored'] and run['returncode']==0 and run['seconds']<20
 assert (d/'step_budget.txt').read_text().splitlines()==(old/'step_budget.txt').read_text().splitlines()[:36]
 a=read(d/'attempt_trace.txt');b=read(old/'attempt_trace.txt');assert len(a)==38
 assert [x[:-1] for x in a[:37]]==[x[:-1] for x in b[:37]]
 assert a[-1][0:7]==b[37][0:7]
 assert a[-1][8]==4 and a[-1][7]==31 and a[-1][9:12]==[1,0,0]
 for n in ['begin','context_begin','ledger_begin','ledger_installed','native_installed']:
  assert (d/(n+'.txt')).read_bytes()==(old/(n+'.txt')).read_bytes()
 op=read(d/'node_operator.txt');it=read(d/'node_iterations.txt');lim=read(d/'domain3_limit.txt')
 baseline=[x for x in read(old/'node_operator.txt') if x[0]==38]
 assert op[0]==baseline[0]
 assert all(x[0]==38 and x[21]==0 and x[22]==1 for x in op)
 assert len(op)==a[-1][20]==a[-1][22]==59
 assert a[-1][21]==a[-1][23]==30 and a[-1][25]==0
 assert len([x for x in it if x[2]==4])==30
 assert all(x[18]==0 for x in it)
 assert max(abs(sum(x[13:20])-x[20]) for x in op)<1e-14
 assert abs(op[-1][20])==a[-1][18] and a[-1][19]==52
 assert len(lim)==267
 stage3=[x for x in lim if x[5]==3]
 assert len(stage3)==89
 for x in stage3:
  assert x[37]==0 and x[20]==1
  excess=max(0,x[13]-(x[12]+x[17]-x[18]))
  f=1.
  if excess/x[6]>1e-7:f=max(0,1-excess/x[18]) if x[18]>excess else 0
  assert x[23]==f and abs(x[31]-f*x[30]/x[6])<1e-15
 solver={s.split()[0]:list(map(float,s.split()[1:])) for s in (d/'solver_1.txt').read_text().splitlines()}
 assert solver['outcome']==[4,31,1]
 assert abs(sum(solver['residual'])-a[-1][17])<1e-14
 assert max(map(abs,solver['residual']))==a[-1][18]
 # Headcalc's own normal refusal restores h/theta before the wrapper returns.
 begin={s.split()[0]:s.split()[1:] for s in (d/'target_begin.txt').read_text().splitlines()}
 returned={s.split()[0]:s.split()[1:] for s in (d/'target_return.txt').read_text().splitlines()}
 assert begin['h']==returned['h'] and begin['theta']==returned['theta']
 identity=json.loads((R/(opt+'_IDENTITY.json')).read_text())
 assert all(hashlib.sha256((R/n).read_bytes()).hexdigest()==h for n,h in identity['sources'].items())
 q.append(dict(optimization=opt,run_seconds=run['seconds'],pre_target_accepted_steps_exact=36,pre_target_attempts_exact=37,target_begin_t1900=a[-1][2],target_dt=a[-1][3],actual_iterations=30,target_refused=True,flux_factor=1,final_F52=op[-1][20],final_sum_F=a[-1][17],final_max_abs_F=a[-1][18],max_node=52,original_final_max_abs_F=b[37][18],original_final_sum_F=b[37][17],full_residuals_current=True,no_frozen_vector=True,macro_rate_calls=59,macro_derivative_calls=30,fresh_certifications=0,extra_line_search_trials=a[-1][24]-a[-1][21],limiter_partial_evaluations=sum(0<x[23]<1 for x in stage3),limiter_unlimited_evaluations=sum(x[23]==1 for x in stage3),last_out_factor=stage3[-1][23],normal_head_internal_restore_h_theta_exact=True))
for p in (R/'data/O0/RESUME').glob('*.txt'):
 if p.name in ['cost_trace.txt','attempt_trace.txt']:continue
 assert p.read_bytes()==(R/'data/O2/RESUME'/p.name).read_bytes(),p.name
assert [x[:-1] for x in read(R/'data/O0/RESUME/attempt_trace.txt')]==[x[:-1] for x in read(R/'data/O2/RESUME/attempt_trace.txt')]
for p in P.glob('*.f90'):
 if p.name not in ['head_diag.f90','diag_state.f90','soilwater_native.f90']:assert (R/p.name).read_bytes()==p.read_bytes()
result=dict(work_unit='SWAP431-MACRO-B1-FRESH22',decision='CONTRACT_BOUNDED_CURRENT_OPERATOR_ALONE_INSUFFICIENT',model_routes=2,hard_timeout_seconds=20,non_timing_O0_O2_exact=True,changes='Localized solver freeze handling in target head only; no physical/criteria/dt/retry-policy change',accepted_target=False,head_return_before_host_retry_or_commit=True,full_second_period_qualification=False,official_promotion=False,results=q)
(R/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
