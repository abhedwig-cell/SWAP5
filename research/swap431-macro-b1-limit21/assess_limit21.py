"""Read-only potential, availability and branch reconstruction on original evidence."""
from pathlib import Path
import math,json,hashlib,collections
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-node20'
def read(p):return [list(map(float,s.split())) for s in p.read_text().splitlines()]
results=[]
for opt in ['O0','O2']:
 d=R/'data'/opt/'RESUME';old=P/'data'/opt/'RESUME'
 for name in ['node_iterations.txt','node_operator.txt','node_absorption.txt','step_budget.txt','begin.txt','context_begin.txt','ledger_begin.txt','ledger_installed.txt','native_installed.txt','own.end']:
  assert (d/name).read_bytes()==(old/name).read_bytes(),name
 a=read(d/'attempt_trace.txt');b=read(old/'attempt_trace.txt');assert len(a)==52
 assert [x[:-1] for x in a]==[x[:-1] for x in b]
 rows=read(d/'domain3_limit.txt');assert len(rows)==672 and all(len(x)==43 for x in rows)
 assert set(x[0] for x in rows)=={38,50,51,52}
 groups=collections.defaultdict(list)
 for x in rows:groups[(x[0],x[3])].append(x)
 assert len(groups)==224
 errors=[]
 for key,triplet in groups.items():
  assert [x[5] for x in triplet]==[1,2,3]
  before,decision,after=triplet
  x=before
  assert x[20]==1 # no inflow correction in any selected domain3 evaluation
  assert x[37]==decision[37]==after[37]==0 # no excess surface inflow redistribution
  assert abs(x[13]-min(x[15],x[12]))<1e-15
  assert abs(x[17]-sum(x[24:28]))<1e-15
  assert abs(x[18]-sum(x[28:30]))<1e-15
  assert abs(x[19]-(x[12]+x[17]-x[18]))<1e-15
  excess=max(0,x[13]-x[19]);assert abs(excess-x[21])<1e-15
  assert x[21]==decision[22]==after[22] # no intervening redistribution
  factor=1.
  if excess/x[6]>1e-7:
   factor=max(0,1-excess/x[18]) if x[18]>excess else 0.
  assert decision[23]==after[23]==factor
  assert decision[39]==int(excess/x[6]>1e-7)
  assert decision[40]==int(x[18]>excess)
  assert abs(x[41]-(x[12]+x[20]*x[17]-x[13]))<1e-15
  assert abs(after[31]-factor*x[30]/x[6])<1e-15
  assert abs(after[35]*x[6]-factor*x[18])<1e-15
  final_stock=x[12]+after[36]*x[6]-after[35]*x[6]
  assert final_stock>=x[13]-1e-15 and final_stock<=x[14]+1e-7
  errors.append(final_stock-x[13])
 # Reused vector rates must have an observed original source evaluation.
 op=read(d/'node_operator.txt');pairs=[]
 for att in [38,50,51,52]:
  selected=[x for x in op if x[0]==att];fresh=selected[-1];cached=selected[-2]
  obs=[x for x in rows if x[0]==att and x[5]==3]
  last=obs[-1];prior=[x for x in obs if x[2]<=cached[2]][-1]
  assert last[1]==fresh[1] and last[2]==fresh[2]
  assert last[31]==fresh[35] and prior[31]==cached[35]
  if att!=52:
   assert prior[23]==1 and prior[41]>prior[18]
   assert last[23]<1e-10 and last[41]==0 and last[17]==0
   assert last[34]>.008 and prior[9]<prior[11] and last[9]>last[11]
  pairs.append(dict(attempt=att,cached_rate_source=prior,fresh_evaluation=last,cached_F52=cached[20],fresh_F52=fresh[20]))
 run=json.loads((R/(opt+'_RESUME_RUN.json')).read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20
 ident=json.loads((R/(opt+'_IDENTITY.json')).read_text())
 assert all(hashlib.sha256((R/n).read_bytes()).hexdigest()==h for n,h in ident['sources'].items())
 results.append(dict(optimization=opt,seconds=run['seconds'],records=len(rows),complete_rate_evaluations=len(groups),original_52_attempts_and_42_commits_exact=True,all_original_operator_iteration_traces_exact=True,availability_rule_and_branch_reconstructed=True,redistribution_active=False,minimum_reconstructed_stock_margin_cm=min(errors),pairs=pairs))
assert (R/'data/O0/RESUME/domain3_limit.txt').read_bytes()==(R/'data/O2/RESUME/domain3_limit.txt').read_bytes()
for p in P.glob('*.f90'):
 if p.name not in ['diag_state.f90','macrorate_node.f90']:assert (R/p.name).read_bytes()==p.read_bytes()
q=dict(work_unit='SWAP431-MACRO-B1-LIMIT21',decision='DIAGNOSIS_ONLY_ORIGINAL_MINIMUM_STOCK_CONSTRAINT_ACTIVE',model_routes=2,hard_timeout_seconds=20,all_new_traces_O0_O2_byte_exact=True,physics_solver_BAL_policy_changes=False,full_second_period_qualification=False,official_promotion=False,results=results)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
print(json.dumps(dict(decision=q['decision'],routes=[{k:v for k,v in x.items() if k!='pairs'} for x in results]),indent=2))
