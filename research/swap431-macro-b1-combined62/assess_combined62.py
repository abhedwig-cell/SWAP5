"""Offline combined Jacobian audit; never calls a solver or model."""
from pathlib import Path
import json,csv,math,sys,hashlib
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-potential61';N=112;epsmach=sys.float_info.epsilon
def rows(p):return [[float(v) for v in s.split()] for s in p.read_text().splitlines() if s.strip()]
def save(n,v):(R/n).write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')
def sha(p):
 with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def points(p):
 a=rows(p);assert len(a)==26*11;return [a[i:i+11] for i in range(0,len(a),11)]
def stable(c):return ((c[0]-c[1])+c[4])/c[5]
def analytic(b):
 c=b[0][4:28];m=b[7];h=b[6];z=b[10];dt=c[20];Hm=b[0][27]
 raw=m[4]*((m[2]-m[1])/(m[2]-m[3]))**m[5]*4*m[6]*m[7]*b[4][49]/m[8]*m[9]*math.sqrt(dt)
 assert m[10]==0 and m[12]==1 and m[14]==50 and raw<1e3*dt*b[4][49]
 span=Hm-(z[49]-.5*b[4][49]);overlap=max(0,Hm-c[18]);B=raw/span;Bp=-B*m[5]*m[0]/(m[2]-m[1])
 den=h[50]-h[49];g0=(z[49]-z[50])*h[50]/den**2;g1=-(z[49]-z[50])*h[49]/den**2
 K=[[0.]*N for _ in range(N)];L=[0.]*N
 for i in range(50,57):K[i][i]=-dt*m[15]*b[9][i]
 if overlap>0:K[49][49]=m[15]*(Bp*overlap-B*g0);K[49][50]=-m[15]*B*g1
 if c[3]<c[0]:L[49]=c[17]*g0;L[50]=c[17]*g1
 Ograd=[sum(K[i][j] for i in range(N)) for j in range(N)]
 v=[-(L[j]+c[15]*Ograd[j])/c[5] for j in range(N)]
 pot=[(s+u)/dt for s,u in zip(b[1],b[2])]
 full=[[-c[15]*K[i][j]/dt-pot[i]*v[j] for j in range(N)] for i in range(N)]
 return c,K,L,Ograd,v,pot,full
matrix=[];fdtable=[];owners=[];results=[]
for opt in ['O0','O2']:
 d=R/'data'/opt/'RESTART_D2';old=P/'data'/opt/'RESTART_D2';run=json.loads((R/(opt+'_RESTART_D2_RUN.json')).read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20
 names=[f.name for f in old.glob('*.txt') if f.name not in ['attempt_trace.txt','cost_trace.txt']]
 for n in names:assert (d/n).read_bytes()==(old/n).read_bytes(),n
 assert [x[:-1] for x in rows(d/'attempt_trace.txt')]==[x[:-1] for x in rows(old/'attempt_trace.txt')]
 a=rows(d/'combined62_local.txt');assert len(a)==18;loc={int(a[i][1]):a[i:i+9] for i in [0,9]};nd=rows(d/'iteration_nodes.txt');pp=[]
 for it in [53,54]:
  rr=points(d/f'potential61_i{it}_points.txt');b=rr[0];c,K,L,Og,v,pot,full=analytic(b);dt=c[20];f=c[15];base=loc[it]
  assert all(x[2]==-3 for x in rows(d/'jac37_trace.txt') if x[0:2]==[2,it])
  assert all(x[2]==0 for x in rows(d/'jac24_trace.txt') if x[0:2]==[2,it])
  assert base[0][0:2]==[2,it] and base[0][2:4]==[35797.290431125148,dt] and base[0][6]==1
  assert base[4]==b[6] and all(x==0 for x in base[1]+base[7]+base[8])
  assert all(x[12]==base[3][int(x[4])-1] for x in nd if x[0:3]==[2,it,2])
  assert [i+1 for i,x in enumerate(base[2]) if x!=0]==list(range(51,58))
  Jloc=[-(u+s) for u,s in zip(base[1],base[2])]
  localerror=max(abs(Jloc[i]-(-f*K[i][i]/dt if i!=49 else 0)) for i in range(N));assert localerror<1e-15
  D=[[full[i][j]-(Jloc[i] if i==j else 0) for j in range(N)] for i in range(N)]
  w=[-f*K[49][j]/dt-(Jloc[49] if j==49 else 0) for j in range(N)]
  spliterror=max(abs(D[i][j]-(-pot[i]*v[j]+(w[j] if i==49 else 0))) for i in range(N) for j in range(N));assert spliterror<1e-15
  rebuild=max(abs(full[i][j]-((Jloc[i] if i==j else 0)+D[i][j])) for i in range(N) for j in range(N));assert rebuild<1e-14
  masserror=max(abs(sum(full[i][j] for i in range(N))-L[j]/dt) for j in range(N));assert masserror<1e-11
  naive=max(abs(x) for x in Jloc);assert naive>0
  if it==53:assert all(x==0 for x in w)
  if it==54:assert w[49]!=0 and w[50]!=0
  # Inspect actual provider restore evidence, not just formula outputs.
  receipt=rows(d/f'potential61_i{it}_restore.txt');assert len(receipt)==25 and all(x[3:]==[1,1,1] for x in receipt)
  for x,y in [('base','restored'),('cache','cache_restored')]:assert sha(d/f'potential61_i{it}_{x}.bin')==sha(d/f'potential61_i{it}_{y}.bin')
  for i in range(N):
   owners.append([opt,it,i+1,base[1][i],base[2][i],Jloc[i]])
   for j in range(N):
    if full[i][j]!=0 or D[i][j]!=0 or (i==j and Jloc[i]!=0):matrix.append([opt,it,i+1,j+1,Jloc[i] if i==j else 0,full[i][j],-pot[i]*v[j],w[j] if i==49 else 0,D[i][j]])
  FDmax=0;boundmax=0;predmax=0;checks=[]
  for node in range(49,58):
   j=node-1
   for e in ([1e-7,5e-8] if node in [50,51,52] else [1e-7]):
    lo=next(x for x in rr if x[0][1]==node and x[0][2]==-e);hi=next(x for x in rr if x[0][1]==node and x[0][2]==e);cm=lo[0][4:28];cp=hi[0][4:28]
    assert lo[3]==b[3]==hi[3] and lo[9]==b[9]==hi[9] and lo[0][27]==b[0][27]==hi[0][27]
    assert (cm[3]<cm[0])==(c[3]<c[0])==(cp[3]<cp[0])
    pm=[(s+u)/dt for s,u in zip(lo[1],lo[2])];ps=[(s+u)/dt for s,u in zip(hi[1],hi[2])]
    assert max(abs(q-cm[15]*p) for q,p in zip(lo[5],pm))<1e-16
    assert max(abs(q-cp[15]*p) for q,p in zip(hi[5],ps))<1e-16
    pfd=[(x-y)/(2*e) for x,y in zip(ps,pm)];pavg=[.5*(x+y) for x,y in zip(ps,pm)]
    Om=.5*(cm[5]+cp[5]);Ofd=(cp[5]-cm[5])/(2*e);Lfd=(cp[1]-cm[1])/(2*e)
    fsavg=.5*(stable(cp)+stable(cm));favg=.5*(cp[15]+cm[15])
    rawbound=(abs(cp[15]-stable(cp))+abs(cm[15]-stable(cm)))/(2*e)
    # Exact finite quotient/product identities propagate endpoint arithmetic and finite-step chain error.
    vb=(abs(Lfd-L[j])+abs(fsavg*(Ofd-Og[j]))+abs((fsavg-f)*Og[j])+abs((Om-c[5])*v[j]))/Om+rawbound
    err=[];bounds=[]
    for i in range(N):
     fdF=-(hi[5][i]-lo[5][i])/(2*e);prediction=(Jloc[i] if i==j else 0)+D[i][j]
     Bnd=abs(favg)*abs(pfd[i]-K[i][j]/dt)+abs(favg-f)*abs(K[i][j]/dt)+abs(pavg[i]-pot[i])*abs(v[j])+abs(pavg[i])*vb
     # Endpoint rate arithmetic is separate from any physical solver criterion.
     Bnd+=16*(math.ulp(hi[5][i])+math.ulp(lo[5][i]))/(2*e)+32*epsmach*max(abs(prediction),1e-300)
     error=abs(fdF-prediction);assert error<=Bnd+2e-12,(opt,it,node,e,i+1,error,Bnd)
     err.append(error);bounds.append(Bnd)
    maximum=max(err);maximum_bound=max(bounds);FDmax=max(FDmax,maximum);boundmax=max(boundmax,maximum_bound);predmax=max(predmax,max(abs(full[i][j]) for i in range(N)))
    checks.append(dict(node=node,epsilon_cm=e,max_fullvector_FD_error=maximum,max_propagated_diagnostic_bound=maximum_bound))
    fdtable.append([opt,it,node,e,maximum,maximum_bound,rawbound,abs(Lfd-L[j])/Om])
  pp.append(dict(iteration=it,branch='W' if it==53 else 'V',measured_local_unsat_D3_max=0,local_owner_diagonal_error=localerror,rank_upper_bound=1 if it==53 else 2,potential_row_support=[50,51] if it==54 else [],rank_split_error=spliterror,reconstruct_error=rebuild,mass_derivative_error=masserror,naive_full_addition_doublecounts_diagonal_max=naive,max_actual_FD_error=FDmax,max_propagated_FD_bound=boundmax,max_full_D3_entry_in_tested_columns=predmax,restore_checks=25,factor_row_df=v[49:57],missing_potential_row=w[49:57],combined_correction_row52=D[51][49:57],combined_correction_row50=D[49][49:57],checks=checks))
 results.append(dict(optimization=opt,seconds=run['seconds'],returncode=0,censored=False,parent_text_files_exact=len(names),original_solver_trajectory_unchanged=True,points=pp))
x=R/'data/O0/RESTART_D2';y=R/'data/O2/RESTART_D2'
for f in x.glob('*.txt'):
 if f.name not in ['attempt_trace.txt','cost_trace.txt']:assert f.read_bytes()==(y/f.name).read_bytes(),f.name
for f in P.glob('*.f90'):
 if f.name!='macrorate_node.f90':assert (R/f.name).read_bytes()==f.read_bytes(),f.name
for name,cols,data in [('COMBINED_MATRIX.csv',['opt','iteration','row','column','actual_local_D3_F_J','full_D3_F_J','factor_outer_product','missing_potential_row','net_augmentation'],matrix),('LOCAL_OWNERSHIP.csv',['opt','iteration','node','actual_dq_unsat_increment','actual_dq_sat_increment','actual_local_D3_F_J'],owners),('COMBINED_FD_AUDIT.csv',['opt','iteration','head_column','epsilon_cm','max_vector_error','max_propagated_bound','raw_factor_roundoff_bound','geometry_L_FD_bound'],fdtable)]:
 with (R/name).open('w',newline='',encoding='utf-8') as f:w=csv.writer(f);w.writerow(cols);w.writerows(data)
q=dict(work_unit='SWAP431-MACRO-B1-COMBINED62',decision='COMBINED_D3_AUGMENTATION_CONTRACT_WITHOUT_DOUBLECOUNT_QUALIFIED_O0_O2',model_routes=2,hard_seconds_per_route=20,real_provider_perturbations_per_route=48,measured_current_local_D3_owner=True,two_outer_product_contract_verified=True,all_active_head_columns_tested=list(range(50,58)),outside_control=49,qualification_envelope='same fixed geometry/material/history/support asFACTOR60/POTENTIAL61',provider_and_trajectory_O0_O2_exact=True,no_Jacobian_update_used_by_solver=True,physics_clock_and_budget_rules_unchanged=True,convergence_new_linear_solve_or_accepted_step_not_qualified=True,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',results=results)
save('RESULT.json',q);save('STATUS.json',dict(q,stage='COMBINED_CONDITIONAL_CONTRACT_QUALIFIED_NO_SOLVE_IMPLEMENTATION',recovery='COMBINED_CONTRACT.md; REPORT.md; RESULT.json; COMBINED_MATRIX.csv; CODEX_FOLLOWUP.md; EVIDENCE.json',no_broad_campaign=True,official_promotion=False))
print(json.dumps([dict(opt=x['optimization'],seconds=x['seconds'],points=[dict(iteration=p['iteration'],rank=p['rank_upper_bound'],mass_error=p['mass_derivative_error'],FD_error=p['max_actual_FD_error'],FD_bound=p['max_propagated_FD_bound'],naive_duplicate=p['naive_full_addition_doublecounts_diagonal_max']) for p in x['points']]) for x in results],indent=2))
