"""Audit only the two completed original D2 model routes; no model calls."""
from pathlib import Path
from collections import Counter
import json,csv,math
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-dtmin57'
def rows(p):return [[float(v) for v in l.split()] for l in p.read_text().splitlines() if l.strip()]
def fields(p):return {l.split()[0].lower():list(map(float,l.split()[1:])) for l in p.read_text().splitlines() if l.strip()}
def save(n,q):(R/n).write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8')
def records(p):
 a=rows(p);assert len(a)%4==0;return [a[i:i+4] for i in range(0,len(a),4)]
oldline='h(i) = hold(i) - difh(i) * factmax1';newline='h(i) = hold(i) - (difh(i) * factmax1) * factor'
for f in R.glob('*.f90'):
 if f.name!='head_diag.f90':assert f.read_bytes()==(P/f.name).read_bytes()
s=(R/'head_diag.f90').read_text();assert s.count(newline)==1 and s.replace(newline,oldline)==(P/'head_diag.f90').read_text()
audit=[];progress=[];result=[]
for opt in ['O0','O2']:
 d=R/'data'/opt/'RESTART_D2';old=P/'data'/opt/'RESTART_D2';run=json.loads((R/(opt+'_RESTART_D2_RUN.json')).read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20
 rs=records(d/'dtmin57_trials.txt');previous=records(old/'dtmin57_trials.txt');assert len(rs)==254 and rs[:168]==previous[:168] and rs[168]!=previous[168]
 assert rs[168][0][:3]==[2,31,2]
 # Complete first attempt and first30 iterations of floor retry unchanged in every numeric diagnostic.
 prefix_names=['node_iterations.txt','iteration_nodes.txt','operator_nodes.txt','guard41_trace.txt','guard41_domains.txt','jac24_trace.txt','jac37_trace.txt','domain3_limit.txt','provider49_trace.txt','geometry53_trace.txt','inactive51_trace.txt']
 for n in prefix_names:
  assert [x for x in rows(d/n) if x[0]==1 or (x[0]==2 and x[1]<=30)]==[x for x in rows(old/n) if x[0]==1 or (x[0]==2 and x[1]<=30)],n
 assert (d/'solver_1.txt').read_bytes()==(old/'solver_1.txt').read_bytes()
 assert (d/'own.end').read_bytes()==(old/'own.end').read_bytes()
 at=rows(d/'attempt_trace.txt');assert len(at)==2 and at[0][:-1]==rows(old/'attempt_trace.txt')[0][:-1]
 assert [at[1][3],at[1][6],at[1][7],at[1][19]]==[1e-5,1,61,52]
 assert 'NATIVE55_FOLLOW_SCALED_REQUEST_EXCLUDED' in (d/'outcome.txt').read_text()
 assert not rows(d/'step_budget.txt') and not rows(d/'inventory_trace.txt') and not (d/'follow.end').exists()
 assert (d/'ledger_initial.txt').read_bytes()==(d/'ledger_final.txt').read_bytes()
 ini=fields(d/'context_initial.txt');end=fields(d/'context_final.txt');assert {k for k in ini if ini[k]!=end[k]}=={'dt','dtold'}
 assert fields(d/'final.txt')['controls'][0]==ini['t1900'][0]
 ni=rows(d/'node_iterations.txt');nd=rows(d/'iteration_nodes.txt');gt=rows(d/'guard41_trace.txt');assert len(gt)==90 and all(x[2]==-3 and x[3]==1 for x in gt)
 special=[];maxerror=0;iteration_trials={}
 for header,hold,dif,actual in rs:
  attempt,it,k,n,floor,maxit,factor,oldobj,obj,fmax,dt=header;assert len(hold)==len(dif)==len(actual)==int(n)==112
  M=max(abs(v)/max(1,abs(h)) for h,v in zip(hold,dif));q=1 if M<=1 else 1/M;sp=bool(floor and it>maxit)
  expected=[h-(v*q)*factor for h,v in zip(hold,dif)] if sp else [h-factor*v for h,v in zip(hold,dif)]
  error=max(abs(h-e) for h,e in zip(actual,expected));assert error<1e-12;maxerror=max(maxerror,error)
  norm=max(abs(h-e)/max(1,abs(h)) for h,e in zip(hold,actual))
  if sp:
   assert norm<=factor+1e-12;special.append((header,M,q));iteration_trials.setdefault(int(it),[]).append((hold,dif,actual,factor))
  audit.append([opt,int(attempt),int(it),int(k),int(sp),factor,M,q,q*factor if sp else factor,norm,error,oldobj,obj,fmax])
 duplicates=0
 for it,batch in iteration_trials.items():
  assert all(x[:2]==batch[0][:2] for x in batch)
  assert len({tuple(x[2]) for x in batch})==len(batch)
  duplicates+=len(batch)-len({tuple(x[2]) for x in batch})
 assert len(special)==87 and duplicates==0
 attempts=[]
 for a in [1,2]:
  ends=[x for x in ni if x[0]==a and x[2]==4];tr=[x for x in ni if x[0]==a and x[2]==3];best=min(ends,key=lambda x:x[15]);last=ends[-1]
  assert len(ends)==(30 if a==1 else 60) and not any(x[0]==a and x[2] in [5,6] for x in ni)
  nodecounts=Counter()
  for x in ends:
   ns=[y for y in nd if y[0]==a and y[1]==x[1] and y[2]==4];mx=max(ns,key=lambda y:abs(y[8]));assert abs(abs(mx[8])-x[15])<1e-15;nodecounts[int(mx[4])]+=1
   progress.append([opt,a,int(x[1]),x[15],x[14],x[16],int(mx[4]),int(x[3]>4),int(x[16]>x[17])])
  attempts.append(dict(attempt=a,dt=at[a-1][3],iterations=len(ends),real_line_trials=len(tr),provider_evaluations=int(at[a-1][20]),best_Fmax=best[15],best_iteration=int(best[1]),final_Fmax=last[15],final_sum_F=last[14],final_worst_node=int(at[a-1][19]),end_worst_node_counts=dict(nodecounts),exhausted_iterations=[int(x[1]) for x in ends if x[3]>4],fresh_convergence_checks=0))
 solver=fields(d/'solver_2.txt');assert solver['controls'][5:7]==[1e-6,1e-5]
 res=solver['residual'];assert max(abs(v) for v in res)==at[1][18] and abs(sum(res)-at[1][17])<1e-12
 op=rows(d/'operator_nodes.txt');operator_error=max(abs(x[10]-sum(x[11:18])) for x in op);assert operator_error<1e-12
 oldat=rows(old/'attempt_trace.txt')[1]
 result.append(dict(optimization=opt,seconds=run['seconds'],returncode=0,censored=False,source_one_expression_only_verified=True,full_array_trials=len(rs),unchanged_full_trial_prefix=168,first_changed_trial=[2,31,2],special_dtmin_trials=len(special),special_M_range=[min(x[1] for x in special),max(x[1] for x in special)],cap_active_trials=sum(x[2]<1 for x in special),step_formula_max_abs_error_cm=maxerror,repeated_identical_trial_states=duplicates,operator_sum_max_error=operator_error,attempts=attempts,local_residual_limit=1e-6,total_residual_limit=1e-5,final_Fmax_improvement_factor=oldat[18]/at[1][18],final_sum_improvement_factor=oldat[17]/at[1][17],scaled_request_IDecMpRat=int(fields(d/'final.txt')['controls'][2]),FrReduQ=fields(d/'final.txt')['policy'][0],follow_hostcommits=0,rollback_native_context_exact_except_dt_dtold=True,no_time_or_ledger_advance=True))
x=R/'data/O0/RESTART_D2';y=R/'data/O2/RESTART_D2';names=[p.name for p in x.glob('*.txt') if p.name not in ['attempt_trace.txt','cost_trace.txt']]
for n in names:assert (x/n).read_bytes()==(y/n).read_bytes(),n
assert [a[:-1] for a in rows(x/'attempt_trace.txt')]==[a[:-1] for a in rows(y/'attempt_trace.txt')]
assert result[0]['attempts']==result[1]['attempts']
for name,cols,data in [('STEP_AUDIT.csv',['opt','attempt','iteration','trial','special_dtmin_branch','factor','M','alpha0','effective_alpha','mixed_step_norm','formula_error_cm','old_objective','actual_objective','actual_Fmax'],audit),('ITERATION_PROGRESS.csv',['opt','attempt','iteration','Fmax','sum_F','objective','worst_node','exhausted','objective_worsened'],progress)]:
 with (R/name).open('w',newline='',encoding='utf-8') as f:w=csv.writer(f);w.writerow(cols);w.writerows(data)
q=dict(work_unit='SWAP431-MACRO-B1-DTMIN58',decision='MINIMAL_PRODUCT_UPDATE_VERIFIED_O0_O2_CONVERGENCE_NOT_REACHED',model_routes=2,hard_seconds_per_route=20,O0_O2_physical_and_full_array_traces_exact=True,physical_text_files_compared=len(names),product_update_implemented=True,product_update_tested=True,convergence_qualified=False,accepted_follow_qualified=False,physics_clock_Jacobian_guards_criteria_dt_reduction_budgets_unchanged=True,rollback_to_native_origin_qualified_for_actual_refusal=True,forced_rejection_direct_smaller_retry_not_selected=True,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',results=result)
save('RESULT.json',q);save('STATUS.json',dict(q,stage='TESTED_MINIMAL_IMPLEMENTATION_RETAINED_REFUSAL',recovery='REPORT.md; RESULT.json; MINIMAL.patch; CODEX_FOLLOWUP.md; EVIDENCE.json',no_broad_campaign=True,official_promotion=False))
print(json.dumps(result,indent=2))
