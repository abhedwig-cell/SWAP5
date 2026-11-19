"""Model-free diagnosis of exact DTMIN58 replays; no new operator/probe calls."""
from pathlib import Path
from collections import Counter
import json,csv,math
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-dtmin58'
def rows(p):return [[float(v) for v in l.split()] for l in p.read_text().splitlines() if l.strip()]
def fields(p):return {l.split()[0].lower():list(map(float,l.split()[1:])) for l in p.read_text().splitlines() if l.strip()}
def save(n,q):(R/n).write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8')
def span(a):return [min(a),max(a)]
def branch(x):return 'W' if x[13]==x[12] else 'V'
def writecsv(n,columns,data):
 with (R/n).open('w',newline='',encoding='utf-8') as f:w=csv.writer(f);w.writerow(columns);w.writerows(data)
stock=[];direction=[];operators=[];progress=[];result=[]
for f in R.glob('*.f90'):assert f.read_bytes()==(P/f.name).read_bytes()
for opt in ['O0','O2']:
 d=R/'data'/opt/'RESTART_D2';parent=P/'data'/opt/'RESTART_D2';run=json.loads((R/(opt+'_RESTART_D2_RUN.json')).read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20
 names=[p.name for p in parent.glob('*.txt') if p.name not in ['attempt_trace.txt','cost_trace.txt']]
 for n in names:assert (d/n).read_bytes()==(parent/n).read_bytes(),('parent',opt,n)
 at=rows(d/'attempt_trace.txt');assert [x[:-1] for x in at]==[x[:-1] for x in rows(parent/'attempt_trace.txt')]
 assert (d/'own.end').read_bytes()==(parent/'own.end').read_bytes()
 assert not rows(d/'step_budget.txt') and not rows(d/'inventory_trace.txt') and not (d/'follow.end').exists()
 assert (d/'ledger_initial.txt').read_bytes()==(d/'ledger_final.txt').read_bytes()
 ini=fields(d/'context_initial.txt');end=fields(d/'context_final.txt');assert {k for k in ini if ini[k]!=end[k]}=={'dt','dtold'}
 assert 'NATIVE55_FOLLOW_SCALED_REQUEST_EXCLUDED' in (d/'outcome.txt').read_text()
 ni=rows(d/'node_iterations.txt');nd=rows(d/'iteration_nodes.txt');op=rows(d/'operator_nodes.txt');gd=rows(d/'guard41_domains.txt');gt=rows(d/'guard41_trace.txt');li=rows(d/'domain3_limit.txt');j24=rows(d/'jac24_trace.txt')
 lm={(int(x[0]),int(x[2])):x for x in li if x[4]==1 and x[5]==3};om={(int(x[0]),int(x[2]),int(x[6])):x for x in op};jm={(int(x[0]),int(x[1])):x for x in nd if x[2]==2 and x[4]==52}
 assert len(lm)==256 and len(gt)==90 and all(x[2]==-3 and x[3]==1 for x in gt) and all(x[2]==0 for x in j24)
 assert all(x[10:13]==[50,50,-1] for x in gt)
 op_error=[]
 for x in op:
  op_error.extend([abs(x[10]-sum(x[11:18])),abs(x[17]+sum(x[19:24]))])
  op_error.extend(abs(x[19+k]-(x[24+k]+x[29+k]-x[34+k]-x[39+k])) for k in range(5))
 assert max(op_error)<1e-12
 trial=rows(d/'dtmin57_trials.txt');assert len(trial)==4*254;nvec={1:1,2:1};late=[];solve_error=0
 for i in range(0,len(trial),4):
  hd,h,dif,hn=trial[i:i+4];a,it,k=map(int,hd[:3]);nvec[a]+=1;j=jm[a,it];x=om[a,nvec[a],52];base=om[a,int(j[3]),52];l=lm[a,nvec[a]];lb=lm[a,int(j[3])]
  assert x[1]==it and x[7]==hn[51] and base[7]==h[51] and j[8]==base[10]
  M=max(abs(v)/max(1,abs(z)) for z,v in zip(h,dif));q=1 if M<=1 else 1/M;alpha=hd[6]*(q if hd[4] and it>hd[5] else 1)
  Jd=j[9]*dif[50]+j[10]*dif[51]+j[11]*dif[52];solve_error=max(solve_error,abs(Jd-base[10]))
  predicted=base[10]-alpha*Jd;error=x[10]-predicted
  # J's macro self contribution is -dFdhMp; other entries are the matrix part.
  Jmacro=-j[12]*dif[51];macro_error=(x[17]-base[17])+alpha*Jmacro;matrix_error=error-macro_error
  assert abs(l[31]-x[31])<1e-14 and abs(l[30]/l[6]*l[23]-x[31])<1e-14
  # Exact finite product identity q3=P3*f3. This is an identity, not a new operator evaluation.
  P0=lb[30]/lb[6];P1=l[30]/l[6];df=l[23]-lb[23];fixed_factor_part=lb[23]*(P1-P0);factor_part=P1*df
  assert abs((x[31]-base[31])-(fixed_factor_part+factor_part))<1e-14
  assert x[26]==base[26]==x[36]==base[36]==x[41]==base[41]==0 # node52 D3 unsat, matrix/internal incoming
  missing_factor=-factor_part;other_error=error-missing_factor
  row=[opt,a,it,k,nvec[a],alpha,base[10],x[10],Jd,predicted,error,macro_error,matrix_error,missing_factor,other_error,lb[9],l[9],lb[12]-lb[15],l[12]-l[15],branch(lb),branch(l),lb[23],l[23],P0,P1]+[x[19+v]-base[19+v] for v in range(3)]
  direction.append(row)
  if a==2 and it>30:late.append(row)
 assert len(late)==87 and solve_error<1e-12
 # In the actual late Newton directions D3 factor variation explains the node52 mismatch.
 assert max(abs(x[14]) for x in late)<2e-10
 assert all(lm[2,v][11]==lm[2,1][11] for a,v in lm if a==2)
 l2=[x for (a,v),x in lm.items() if a==2];assert len(l2)==169
 assert all(x[10]==50 and 0<x[23]<1 and x[20]==1 and x[39:41]==[1,1] for x in l2)
 factor_error=max(abs(x[23]-(x[12]+x[17]-x[13])/x[18]) for x in l2);assert factor_error<2e-11
 assert max(abs(x[18]-x[28]-x[29]) for x in l2)<1e-20
 doms=[]
 for dom in range(1,6):
  cm=[x[3:] for x in gd if x[0]==2 and x[2]==dom]
  for x in gd:
   if x[0]==2 and x[2]==dom:stock.append([opt,int(x[0]),int(x[1]),dom]+x[3:])
  assert all(x[7]==1 for x in cm)
  doms.append(dict(domain=dom,factor=span([x[15] for x in cm]),stock_W=span([x[0] for x in cm]),minimum_L=span([x[1] for x in cm]),volume_under_GWL=span([x[3] for x in cm]),incoming_I=span([x[4] for x in cm]),matrix_incoming=span([x[11] for x in cm]),potential_outgoing_O=span([x[5] for x in cm]),L_equals_W=sum(x[1]==x[0] for x in cm),L_equals_volume=sum(x[1]==x[3] for x in cm),partial=sum(0<x[15]<1 for x in cm),top_only=sum(x[4]==x[8] for x in cm)))
 ends=[x for x in ni if x[0]==2 and x[2]==4]
 for x in ends:
  ns=[y for y in nd if y[0]==2 and y[1]==x[1] and y[2]==4];mx=max(ns,key=lambda y:abs(y[8]));assert abs(abs(mx[8])-x[15])<1e-15
  progress.append([opt,int(x[1]),x[15],x[14],int(mx[4]),int(x[3]>4),x[16],x[17]])
 for label,it in [('best',53),('after_best',54),('overshoot',55),('final',60)]:
  vec=max(int(x[2]) for x in op if x[0]==2 and x[1]==it)
  for node in [50,51,52,57]:
   x=om[2,vec,node];operators.append([opt,label,it,node,x[7],x[10]]+x[11:18]+x[19:44])
 selected=[dict(iteration=x[2],trial=x[3],alpha=x[5],F0=x[6],F=x[7],linearization_error=x[10],D3_factor_contribution=x[13],unexplained_remainder=x[14],GWL0=x[15],GWL1=x[16],W_minus_V0=x[17],W_minus_V1=x[18],branch0=x[19],branch1=x[20],f3_before=x[21],f3_after=x[22]) for x in late if x[2]==54 or (x[2] in [53,55,60] and x[3]==1) or (x[2]==53 and x[3]==2) or (x[2]==60 and x[3]==3)]
 result.append(dict(optimization=opt,seconds=run['seconds'],returncode=0,censored=False,parent_physical_text_files_exact=len(names),attempts_exact_except_elapsed=True,operator_identities_max_error=max(op_error),tridiagonal_direction_equation_max_error=solve_error,late_real_trials=len(late),late_node52_max_linearization_error=max(abs(x[10]) for x in late),late_D3_factor_identity_max_unexplained_error=max(abs(x[14]) for x in late),late_branch_pairs=dict(Counter(x[19]+'->'+x[20] for x in late)),D3_provider_count=len(l2),D3_factor_identity_max_error=factor_error,D3_provider_factor=span([x[23] for x in l2]),D3_GWL=span([x[9] for x in l2]),D3_native_cell=50,D3_incoming=span([x[17] for x in l2]),D3_potential_unsat_outgoing=span([x[29] for x in l2]),D3_stock_branch_counts=dict(Counter(branch(x) for x in l2)),domains_at_60_Jacobian_states=doms,selected_actual_trials=selected,final_Fmax=at[1][18],final_sum_F=at[1][17],final_worst_node=int(at[1][19]),zero_follow_hostcommits=True,physical_state_and_ledger_restored=True))
x=R/'data/O0/RESTART_D2';y=R/'data/O2/RESTART_D2'
for n in names:assert (x/n).read_bytes()==(y/n).read_bytes(),('O0O2',n)
assert [v[:-1] for v in rows(x/'attempt_trace.txt')]==[v[:-1] for v in rows(y/'attempt_trace.txt')]
writecsv('DIRECTIONAL_OPERATOR.csv',['opt','attempt','iteration','trial','nvec','alpha','F0','actual_F52','J_D52','linear_prediction','actual_minus_prediction','macro_remainder','matrix_remainder','D3_factor_contribution','other_remainder','GWL0','GWL1','WminusV0','WminusV1','Lbranch0','Lbranch1','f3_before','f3_after','P3_before_cm_day','P3_after_cm_day','net_D1_change','net_D2_change','net_D3_change'],direction)
cm=['W','L','maximum','underGWL','incoming','potential_outgoing','trial_stock','FrIn','topvert','toplat','internalin','matrixin','satout','unsatout','rapidout','FrOut','excess','rho','GWL','nativecell','dt','topexcess','IcTop','macrowaterlevel']
writecsv('STOCK_LIMITS.csv',['opt','attempt','iteration','domain']+cm,stock)
writecsv('OPERATORS.csv',['opt','state','iteration','node','head','F','storage','sink','minus_source','root','upper','lower','minus_macro']+[f'{kind}_D{d}' for kind in ['net','unsatout','satout','matrixin','internalin'] for d in range(1,6)],operators)
writecsv('ITERATION_PROGRESS.csv',['opt','iteration','Fmax','sum_F','worst_node','exhausted','objective','old_objective'],progress)
q=dict(work_unit='SWAP431-MACRO-B1-NODE59',decision='NODE52_LATE_LINEARIZATION_MISMATCH_LOCALIZED_TO_D3_OUTFLOW_FACTOR_O0_O2',model_routes=2,hard_seconds_per_route=20,source_and_binary_unchanged=True,O0_O2_and_parent_physical_traces_exact=True,no_new_provider_or_probe_evaluations=True,diagnosis_qualified_for_actual_directions=True,unique_global_cause_or_successful_repair_not_proven=True,no_corrective_implementation=True,accepted_follow_qualified=False,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',results=result)
save('RESULT.json',q);save('STATUS.json',dict(q,stage='TARGETED_DIAGNOSIS_QUALIFIED_NO_REPAIR',recovery='REPORT.md; RESULT.json; DIRECTIONAL_OPERATOR.csv; CODEX_FOLLOWUP.md; EVIDENCE.json',no_broad_campaign=True,official_promotion=False))
print(json.dumps([dict(optimization=x['optimization'],seconds=x['seconds'],late_max_linearization_error=x['late_node52_max_linearization_error'],D3_factor_unexplained=x['late_D3_factor_identity_max_unexplained_error'],late_branch_pairs=x['late_branch_pairs']) for x in result],indent=2))
