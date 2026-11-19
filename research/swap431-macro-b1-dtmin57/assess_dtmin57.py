"""Model-free full-array audit; no alternative residual/operator calls."""
from pathlib import Path
from collections import Counter
import json,csv,hashlib,math
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-diag56'
def rows(p):return [[float(v) for v in l.split()] for l in p.read_text().splitlines() if l.strip()]
def fields(p):return {l.split()[0].lower():list(map(float,l.split()[1:])) for l in p.read_text().splitlines() if l.strip()}
def save(n,q):(R/n).write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8')
def cap(h,d):
 m=max(abs(v)/max(1,abs(x)) for x,v in zip(h,d));return m,1 if m<=1 else 1/m
# Boundary algebra is not a model route and cannot qualify physical convergence.
cases=[('mixed_switch_and_sign',[0,.999999999,1,-1,2,-2],[2,2,2,2,4,4]),('cap_inactive',[0,2],[.1,.2]),('cap_exact_one',[0,2],[1,2]),('cap_active',[.1,10],[3,-60]),('zero_direction',[0,2],[0,0]),('near_zero',[1e-20,-1e-20],[1e-18,-1e-18])]
synthetic=[]
for name,h,d in cases:
 m,q=cap(h,d);norms=[]
 for k in range(4):
  factor=3.**(-k);alpha=q*factor;new=[x-alpha*v for x,v in zip(h,d)];norm=max(abs(x-y)/max(1,abs(x)) for x,y in zip(h,new));assert norm<=factor+1e-14;norms.append(norm)
  if k==0:assert alpha==q
  if k and any(d):assert alpha<q*3.**(-(k-1))
  if q==1:assert new==[x-factor*v for x,v in zip(h,d)]
 synthetic.append(dict(name=name,M=m,alpha0=q,mixed_step_norms=norms,passed=True))
allcsv=[];result=[];legacy_names=[]
for opt in ['O0','O2']:
 d=R/'data'/opt/'RESTART_D2';old=P/'data'/opt/'RESTART_D2';run=json.loads((R/(opt+'_RESTART_D2_RUN.json')).read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20
 names=[p.name for p in old.glob('*.txt') if p.name not in ['attempt_trace.txt','cost_trace.txt']]
 for n in names:assert (d/n).read_bytes()==(old/n).read_bytes(),(opt,n)
 assert (d/'own.end').read_bytes()==(old/'own.end').read_bytes()
 assert [x[:-1] for x in rows(d/'attempt_trace.txt')]==[x[:-1] for x in rows(old/'attempt_trace.txt')]
 assert not rows(d/'step_budget.txt') and not (d/'follow.end').exists()
 assert (d/'ledger_initial.txt').read_bytes()==(d/'ledger_final.txt').read_bytes()
 initial=fields(d/'context_initial.txt');final=fields(d/'context_final.txt');assert {k for k in initial if initial[k]!=final[k]}=={'dt','dtold'}
 a=rows(d/'dtmin57_trials.txt');assert len(a)==4*227
 records=[];phase=[];maxerr=0;counter=0;capactive=0
 for at in range(0,len(a),4):
  header,hold,direction,actual=a[at:at+4];attempt,it,k,n,floor,maxit,factor,oldobj,obj,fmax,dt=header;n=int(n);assert n==112 and len(hold)==len(direction)==len(actual)==n
  M,q=cap(hold,direction);special=bool(floor and it>maxit);alpha=q if special else factor
  predicted=[h-v*alpha for h,v in zip(hold,direction)];err=max(abs(x-y) for x,y in zip(actual,predicted));assert err<1e-12;maxerr=max(maxerr,err)
  assert factor==3.**(-(int(k)-1))
  observed=max(abs(x-y)/max(1,abs(x)) for x,y in zip(hold,actual))
  proposed=q*factor if special else factor
  different=max(abs(x-(h-v*proposed)) for x,h,v in zip(actual,hold,direction))>1e-12
  if special:
   assert observed<=1+1e-12;phase.append((header,hold,direction,actual,M,q,observed));capactive+=q<1;counter+=different
  leading=max(range(n),key=lambda i:abs(direction[i])/max(1,abs(hold[i])))+1
  allcsv.append([opt,int(attempt),int(it),int(k),int(special),factor,M,q,alpha,proposed,observed,leading,err,int(different),oldobj,obj,fmax])
  records.append((header,hold,direction,actual))
 assert len(phase)==60 and capactive==0 and counter==30
 assert all(h[1]>30 and h[0]==2 and q==1 for h,_,_,_,_,q,_ in phase)
 repeated=[]
 for it in range(31,61):
  batch=[x for x in phase if x[0][1]==it]
  if len(batch)>1:
   assert len(batch)==4 and all(x[1:4]==batch[0][1:4] for x in batch);repeated.append(it)
 assert repeated==[31,34,37,40,43,46,49,52,55,58]
 result.append(dict(optimization=opt,seconds=run['seconds'],returncode=0,censored=False,parent_physical_text_files_exact=len(names),attempts_exact_except_elapsed=True,full_array_trials=227,full_array_nodes=112,original_update_max_abs_error_cm=maxerr,post_MaxIt_dtmin_trials=len(phase),post_MaxIt_dtmin_iterations=30,post_MaxIt_M_range=[min(x[4] for x in phase),max(x[4] for x in phase)],post_MaxIt_alpha0_range=[1,1],relative_cap_active_trials=capactive,duplicate_four_trial_iterations=repeated,redundant_evaluations=30,model_free_product_would_change_logged_trials=counter,product_first_trial_unchanged=True,zero_follow_commits=True,unchanged_refusal_and_scaling_request=True))
 legacy_names=names
x=R/'data/O0/RESTART_D2';y=R/'data/O2/RESTART_D2'
for n in legacy_names+['dtmin57_trials.txt']:assert (x/n).read_bytes()==(y/n).read_bytes(),n
p=R.parent/'swap431-macro-b1-native55'
for f in R.glob('*.f90'):
 if f.name!='head_diag.f90':assert f.read_bytes()==(p/f.name).read_bytes()
# Prove instrumentation postimage is precisely the recorded insertion.
s=(R/'head_diag.f90').read_text();start=s.index('! DTMIN57 observer only:');end=s.index('tr=0;fac=0;hh=h(47);dh=0;',start);s=s[:start]+s[end:];assert s==(p/'head_diag.f90').read_text()
with (R/'FULL_STEP_AUDIT.csv').open('w',newline='',encoding='utf-8') as f:
 w=csv.writer(f);w.writerow(['opt','attempt','iteration','actual_trial','special_dtmin_branch','nominal_factor','M','alpha0','actual_alpha','proposed_alpha_algebra_only','actual_mixed_step_norm','M_leading_node','original_update_error_cm','algebraically_different','old_objective','actual_objective','actual_Fmax']);w.writerows(allcsv)
q=dict(work_unit='SWAP431-MACRO-B1-DTMIN57',decision='DTMIN_CAP_AND_BACKTRACKING_PRODUCT_CONTRACT_BOUNDED_O0_O2',model_routes=2,hard_seconds_per_route=20,observer_only=True,solver_policy_unchanged=True,source_insertion_only_verified=True,O0_O2_full_arrays_byte_exact=True,contract_algebra_cases=synthetic,historical_author_intent='UNKNOWN; legacy source proves behavior, general owner document does not specifically define macro dtmin exception',contract_status='BOUNDED_PROPOSED_NUMERICAL_CORRECTION_CONTRACT_NOT_IMPLEMENTED',corrected_solver_convergence_qualified=False,accepted_follow_qualified=False,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',results=result)
save('RESULT.json',q);save('STATUS.json',dict(q,stage='QUALIFIED_OBSERVED_BEHAVIOR_AND_ALGEBRA_ONLY',recovery='INTENT_CONTRACT.md; REPORT.md; RESULT.json; CODEX_FOLLOWUP.md; EVIDENCE.json',no_broad_campaign=True,official_promotion=False))
print(json.dumps(result,indent=2))
