"""No model calls: assertions and decompositions of the two preregistered replays."""
from pathlib import Path
from collections import Counter
import json,hashlib,csv,math
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-native55'
def rows(p):return [[float(v.replace('D','E')) for v in l.split()] for l in p.read_text().splitlines() if l.strip()]
def fields(p):return {l.split()[0].lower():list(map(float,l.split()[1:])) for l in p.read_text().splitlines() if l.strip()}
def save(n,q):(R/n).write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8')
def span(a):return [min(a),max(a)]
def counts(a):return dict(sorted(Counter(map(str,a)).items()))
def table(n,cols,a):
 with (R/n).open('w',newline='',encoding='utf-8') as f:
  w=csv.writer(f);w.writerow(cols);w.writerows(a)
progress=[];stock=[];operators=[];results=[]
known=['node_iterations.txt','iteration_nodes.txt','operator_nodes.txt','node_operator.txt','node_absorption.txt','guard41_trace.txt','guard41_heads.txt','guard41_domains.txt','jac24_trace.txt','jac37_trace.txt','domain3_limit.txt','provider49_trace.txt','geometry53_trace.txt','inactive51_trace.txt','solver_1.txt','solver_2.txt','context_initial.txt','context_final.txt','ledger_initial.txt','ledger_final.txt','origin_follow_begin_1.txt','origin_follow_begin_2.txt','native_installed.txt','outcome.txt','own.end']
for opt in ['O0','O2']:
 d=R/'data'/opt/'RESTART_D2';old=P/'data'/opt/'RESTART_D2'
 run=json.loads((R/(opt+'_RESTART_D2_RUN.json')).read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20
 for n in known:assert (d/n).read_bytes()==(old/n).read_bytes(),('replay',opt,n)
 at=rows(d/'attempt_trace.txt');assert [x[:-1] for x in at]==[x[:-1] for x in rows(old/'attempt_trace.txt')]
 assert len(at)==2 and not rows(d/'step_budget.txt') and not (d/'follow.end').exists()
 assert (d/'ledger_initial.txt').read_bytes()==(d/'ledger_final.txt').read_bytes()
 ini=fields(d/'context_initial.txt');end=fields(d/'context_final.txt');assert {k for k in ini if ini[k]!=end[k]}=={'dt','dtold'}
 assert fields(d/'final.txt')['controls'][0]==ini['t1900'][0]
 assert 'NATIVE55_FOLLOW_SCALED_REQUEST_EXCLUDED' in (d/'outcome.txt').read_text()
 ni=rows(d/'node_iterations.txt');nd=rows(d/'iteration_nodes.txt');op=rows(d/'operator_nodes.txt');gt=rows(d/'guard41_trace.txt');gd=rows(d/'guard41_domains.txt');lim=rows(d/'domain3_limit.txt');j24=rows(d/'jac24_trace.txt')
 # Reconstruct actual residuals and domain exchange independently of solver reporting.
 errors=[]
 for x in op:
  errors += [abs(x[10]-sum(x[11:18])),abs(x[17]+sum(x[19:24]))]
  for k in range(5):errors.append(abs(x[19+k]-(x[24+k]+x[29+k]-x[34+k]-x[39+k])))
 assert max(errors)<1e-12
 rr=[]
 for a in [1,2]:
  trace=at[a-1];ends=[x for x in ni if x[0]==a and x[2]==4];trials=[x for x in ni if x[0]==a and x[2]==3];guards=[x for x in gt if x[0]==a];provider=[x for x in lim if x[0]==a and x[4]==1 and x[5]==3]
  assert len(ends)==(30 if a==1 else 60);assert len(provider)==int(trace[20]);assert all(x[2]==-3 and x[3]==1 for x in guards)
  assert all(x[2]==0 for x in j24 if x[0]==a);assert all(x[10:13]==[50,50,-1] for x in guards)
  assert all(x[10]==50 for x in provider)
  worst=[];repeated=[];endmap={int(x[1]):x for x in ends};lastop={}
  for x in op:
   if x[0]==a:lastop[int(x[6])]=x
  for x in ends:
   it=int(x[1]);ns=[y for y in nd if y[0]==a and y[1]==it and y[2]==4];mx=max(ns,key=lambda y:abs(y[8]));assert abs(abs(mx[8])-x[15])<1e-15;worst.append(int(mx[4]))
   ts=[y for y in trials if y[1]==it];g=next(y for y in guards if y[1]==it)
   cs={int(y[2]):y[3:] for y in gd if y[0]==a and y[1]==it}
   identical=len(ts)>1 and len({tuple(y[8:18]) for y in ts})==1
   if identical:repeated.append(it)
   progress.append([opt,a,it,x[5],x[15],x[14],x[16],int(mx[4]),len(ts),ts[-1][7],int(x[3]>4),int(x[16]>=x[17]),int(identical),g[14],cs[2][15],cs[3][15],int(cs[3][1]==cs[3][0]),int(cs[3][1]==cs[3][3])])
  doms=[]
  for dom in range(1,6):
   cs=[y[3:] for y in gd if y[0]==a and y[2]==dom]
   assert all(x[7]==1 and x[21]==0 for x in cs)
   partial=[x for x in cs if 0<x[15]<1]
   factor_error=max([abs(x[15]-(x[0]+x[4]-x[1])/x[5]) for x in partial] or [0])
   assert factor_error<1e-8
   for y in gd:
    if y[0]==a and y[2]==dom:stock.append([opt,a,int(y[1]),dom]+y[3:])
   q=dict(factor_identity_max_error=factor_error,domain=dom,stock_cm=span([x[0] for x in cs]),minimum_cm=span([x[1] for x in cs]),incoming_cm=span([x[4] for x in cs]),outgoing_potential_cm=span([x[5] for x in cs]),available_W_plus_I_minus_L_cm=span([x[0]+x[4]-x[1] for x in cs]),out_factor=span([x[15] for x in cs]),partial=sum(0<x[15]<1 for x in cs),unlimited=sum(x[15]==1 for x in cs),L_equals_W=sum(x[1]==x[0] for x in cs),L_equals_volume=sum(x[1]==x[3] for x in cs),top_only_incoming=sum(x[4]==x[8] for x in cs),matrix_incoming_cm=span([x[11] for x in cs]),unsat_out_potential_cm=span([x[13] for x in cs]))
   doms.append(q)
  for node in [50,51,52,57]:
   x=lastop[node];operators.append([opt,a,node,x[7],x[10]]+x[11:18]+x[19:44])
  best=min(ends,key=lambda x:x[15]);half=[]
  for lo,hi in ([(1,30)] if a==1 else [(1,30),(31,60)]):
   e=[x for x in ends if lo<=x[1]<=hi];half.append(dict(iterations=[lo,hi],best_Fmax=min(x[15] for x in e),actual_trials=sum(lo<=x[1]<=hi for x in trials),exhaustions=sum(x[3]>4 for x in e)))
  # All repeated four-trial heads in dtmin's second half are identical real evaluated states.
  if a==2:assert repeated==[31,34,37,40,43,46,49,52,55,58]
  rr.append(dict(attempt=a,dt=trace[3],iterations=len(ends),actual_provider_evaluations=len(provider),actual_line_trials=len(trials),additional_line_trials=len(trials)-len(ends),exhaustions=sum(x[3]>4 for x in ends),objective_worsenings=sum(x[16]>x[17] for x in ends),repeated_identical_trial_iterations=repeated,initial_Fmax=next(x[15] for x in ni if x[0]==a and x[2]==0),best_end_Fmax=best[15],best_iteration=int(best[1]),final_Fmax=trace[18],final_sum=trace[17],final_worst_node=int(trace[19]),worst_node_counts=counts(worst),jac37_guard_minus3=len(guards),valid_current_provider=len(guards),jac24_active=0,actual_provider_GWL_cm=span([x[9] for x in provider]),actual_provider_native_zone=50,Jac_zone_tuple=[50,50,-1],PeGWL_cm=span([x[13] for x in guards]),h51_cm=span([x[16] for x in guards]),domains=doms,iteration_halves=half))
 results.append(dict(optimization=opt,seconds=run['seconds'],returncode=run['returncode'],censored=False,exact_parent_replay_files=len(known),attempts_exact_except_elapsed=True,operator_decomposition_max_error=max(errors),no_follow_commit_or_ledger_timeadvance=True,final_context_differences=['dt','dtold'],attempts=rr))
d0=R/'data/O0/RESTART_D2';d2=R/'data/O2/RESTART_D2'
for n in known:assert (d0/n).read_bytes()==(d2/n).read_bytes(),('O0O2',n)
assert [x[:-1] for x in rows(d0/'attempt_trace.txt')]==[x[:-1] for x in rows(d2/'attempt_trace.txt')]
assert results[0]['attempts']==results[1]['attempts']
table('ITERATION_PROGRESS.csv',['opt','attempt','iteration','dt_day','Fmax_cm_day','sum_F_cm_day','objective','worst_node','actual_trials','last_nominal_factor','exhausted','nondecreasing_objective','identical_trial_states','GWL_cm','factor_D2','factor_D3','D3_L_equals_W','D3_L_equals_volume'],progress)
cm=['W','L','maximum','underGWL','incoming','outgoing_potential','trialstock','FrIn','topvert_in','toplat_in','internal_in','matrix_in','sat_out','unsat_out','rapid_out','FrOut','excess','rho','GWL','nativecell','dt','topexcess','IcTop','macrowaterlevel']
table('STOCK_LIMITS.csv',['opt','attempt','iteration','domain']+cm,stock)
table('FINAL_OPERATORS.csv',['opt','attempt','node','head_cm','F_cm_day','storage','sink','minus_source','root','upper','lower','minus_macro']+[f'{name}_D{k}' for name in ['net','unsatout','satout','matrixin','internalin'] for k in range(1,6)],operators)
original=Path('C:/Users/Veldh012/swap431-state02-work/audit/build/swap-selected/headcalc.f90')
original_sha=hashlib.sha256(original.read_bytes()).hexdigest()
original_identity=json.loads((R.parent/'swap431-macro-b1-state02/O0_IDENTITY.json').read_text())
assert original_sha==original_identity['original_selected_sources']['headcalc.f90']
q=dict(original_floor_branch_sha256=original_sha,ineffective_backtracking_proven=True,work_unit='SWAP431-MACRO-B1-DIAG56',decision='TARGETED_DIAGNOSIS_REPRODUCED_O0_O2_NO_SOLVER_REPAIR',model_routes=2,hard_seconds_per_route=20,source_and_binary_unchanged=True,parent_and_O0_O2_physical_diagnostics_exact=True,continuous_equivalence_inherited_from_native55=True,corrective_causality_not_proven=True,accepted_follow_qualified=False,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',results=results)
save('RESULT.json',q);save('STATUS.json',dict(q,stage='TESTED_TARGETED_DIAGNOSIS',recovery='REPORT.md; RESULT.json; CODEX_FOLLOWUP.md; EVIDENCE.json',no_physics_solver_clock_dt_reduction_or_budget_rule_changes=True,no_broad_campaign=True,official_promotion=False))
print(json.dumps({k:v for k,v in q.items() if k!='results'},indent=2))
