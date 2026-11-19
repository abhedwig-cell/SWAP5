"""Full-vector analytic potential audit in the selected fixed-support envelope; no model calls."""
from pathlib import Path
import json,csv,hashlib,math,sys
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-factor60';CONTROL=R.parent/'swap431-macro-b1-node59'
def rows(p):return [[float(v) for v in s.split()] for s in p.read_text().splitlines() if s.strip()]
def sha(p):
 with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def save(n,q):(R/n).write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8')
def points(p):
 a=rows(p);assert len(a)==26*11;return [a[i:i+11] for i in range(0,len(a),11)]
out=[];gradient=[];results=[]
for opt in ['O0','O2']:
 d=R/'data'/opt/'RESTART_D2';old=CONTROL/'data'/opt/'RESTART_D2';run=json.loads((R/(opt+'_RESTART_D2_RUN.json')).read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20
 names=[p.name for p in old.glob('*.txt') if p.name not in ['attempt_trace.txt','cost_trace.txt','inactive51_trace.txt']]
 for n in names:assert (d/n).read_bytes()==(old/n).read_bytes(),n
 assert [a[:-1] for a in rows(d/'attempt_trace.txt')]==[a[:-1] for a in rows(old/'attempt_trace.txt')]
 original=(old/'inactive51_trace.txt').read_text().splitlines();actual=(d/'inactive51_trace.txt').read_text().splitlines();ix=0;extra=[]
 for s in actual:
  if ix<len(original) and s==original[ix]:ix+=1
  else:extra.append(s)
 assert ix==len(original) and all([int(s.split()[0]),int(s.split()[1])] in [[2,53],[2,54]] for s in extra)
 pp=[]
 for it in [53,54]:
  a=points(d/f'potential61_i{it}_points.txt');b=a[0];c=b[0][4:28];m=b[7];N=112
  assert a[0][0][1:]==a[-1][0][1:]
  assert all(a[0][i]==a[-1][i] for i in range(1,11) if i!=8)
  assert all(x==y for k,(x,y) in enumerate(zip(a[0][8],a[-1][8])) if k!=3) # sample46 diagnostic sequence is not serialized or consumed by physics
  receipt=rows(d/f'potential61_i{it}_restore.txt');assert len(receipt)==25 and all(x[3:]==[1,1,1] for x in receipt)
  for before,after in [('base','restored'),('cache','cache_restored')]:assert sha(d/f'potential61_i{it}_{before}.bin')==sha(d/f'potential61_i{it}_{after}.bin')
  assert m[12]==1 and m[14]==50 and m[10]==0 and m[15]==1 and c[19]==50
  volume=(c[3]<c[0]);assert volume==(it==54)
  assert [i+1 for i,x in enumerate(b[1]) if x>0]==list(range(51,58))
  assert [i+1 for i,x in enumerate(b[2]) if x>0]==([50] if it==54 else [])
  Hm=b[0][27];z=b[10];dz=b[4];h=b[6];C=m[0];theta=m[1];thetaS=m[2];thetaR=m[3];smax=m[4];power=m[5];T=m[10];dt=c[20]
  ref=thetaS if T<1e-8 else m[11];deficit=ref-theta;assert deficit>1e-8 and thetaS-theta>1e-8
  A=4*m[6]*m[7]*dz[49]/m[8]*m[9];S=smax*(deficit/(thetaS-thetaR))**power
  raw=A*S*(math.sqrt(T+dt)-math.sqrt(T));cap=1e3*dt*dz[49];assert raw<cap
  raw_prime=-power*C/deficit*raw
  wet_top=min(z[49]+.5*dz[49],Hm);span=wet_top-(z[49]-.5*dz[49]);overlap=max(0,wet_top-c[18]);assert 0<=overlap<span
  B=raw/span;Bprime=raw_prime/span
  assert abs(m[15]*B*overlap-b[2][49])<1e-25
  if it==54:
   sample=b[8];assert sample[23]==1 and sample[5]==0 and abs(sample[20]-raw)<1e-20
   assert abs(sample[21]-b[2][49])<1e-25 and sample[22]==sample[21] # winner: sorptivity, Darcy alternative0 here
  den=h[50]-h[49];g50=(z[49]-z[50])*h[50]/den**2;g51=-(z[49]-z[50])*h[49]/den**2
  moisture=m[15]*Bprime*overlap if overlap>0 else 0.
  contact50=-m[15]*B*g50 if overlap>0 else 0.;contact51=-m[15]*B*g51 if overlap>0 else 0.
  G=[[0.]*N for _ in range(N)]
  for i in range(50,57):
   assert h[i]>0 and Hm-z[i]-h[i]>1e-8
   assert abs(b[1][i]-dt*m[15]*b[9][i]*(Hm-z[i]-h[i]))<1e-20
   G[i][i]=-dt*m[15]*b[9][i]
  G[49][49]=moisture+contact50;G[49][50]=contact51
  for i in range(N):
   for j in range(N):
    if G[i][j]!=0:gradient.append([opt,it,i+1,j+1,G[i][j],G[i][j]/dt])
  columns=[];maxerr=0;maxrateerr=0;maxsumerr=0;moisture_checks=[]
  for node in range(49,58):
   for eps in ([1e-7,5e-8] if node in [50,51,52] else [1e-7]):
    lo=next(x for x in a if x[0][1]==node and x[0][2]==-eps);hi=next(x for x in a if x[0][1]==node and x[0][2]==eps)
    for x in [lo,hi]:
     assert x[0][27]==Hm and x[3]==b[3] and x[9]==b[9]
     assert (x[0][7]<x[0][4])==volume
     assert (x[0][22]<Hm)==(overlap>0)
     assert [i+1 for i,p in enumerate(x[1]) if p>0]==list(range(51,58))
     assert all(x[7][i]==m[i] for i in [2,3,4,5,6,7,8,9,10,12,13,14,15])
    fd=[((s+u)-(t+v))/(2*eps) for s,u,t,v in zip(hi[1],hi[2],lo[1],lo[2])]
    pred=[G[i][node-1] for i in range(N)];error=max(abs(x-y) for x,y in zip(fd,pred));assert error<2e-14
    dofd=(hi[0][9]-lo[0][9])/(2*eps);dosum=sum(pred);assert abs(dofd-dosum)<2e-14
    if node==49:assert all(x==0 for x in fd)
    maxerr=max(maxerr,error);maxrateerr=max(maxrateerr,error/dt);maxsumerr=max(maxsumerr,abs(dofd-dosum))
    if it==54 and node==50:
     rawfd=(hi[8][20]-lo[8][20])/(2*eps*span);Cfd=(hi[7][1]-lo[7][1])/(2*eps)
     Btheta=-(raw/span)*power/deficit;Btheta_fd=(hi[8][20]-lo[8][20])/(span*(hi[7][1]-lo[7][1]))
     assert abs((Btheta_fd-Btheta)/Btheta)<1e-8
     c_roundbound=2*sys.float_info.epsilon*max(abs(theta),1)/(2*eps)
     assert abs(Cfd-C)<=c_roundbound
     moisture_checks.append(dict(epsilon=eps,Bprime_analytic=Bprime,Bprime_head_FD=rawfd,C_analytic=C,C_head_FD=Cfd,C_roundoff_bound=c_roundbound,dB_dtheta_analytic=Btheta,dB_dtheta_FD=Btheta_fd,dB_dtheta_relative_error=abs((Btheta_fd-Btheta)/Btheta)))
    columns.append(dict(node=node,epsilon=eps,max_fullvector_error_amount_per_head=error,O_derivative_analytic=dosum,O_derivative_provider_FD=dofd,unsat50_derivative_analytic=pred[49],unsat50_derivative_provider_FD=fd[49]))
    out.append([opt,it,node,eps,error,error/dt,dosum,dofd,pred[49],fd[49]])
  pp.append(dict(iteration=it,branch='V' if volume else 'W',contact='partial' if overlap>0 else 'closed',sat_support=list(range(51,58)),unsat_support=[50] if overlap>0 else [],tested_heads=list(range(49,58)),provider_perturbations=24,restore_checks=25,raw_sorptivity=raw,peak_cap=cap,winning_component='sorptivity' if overlap>0 else 'contact closed',Time=T,moisture_capacity=C,deficit=deficit,wet_span=span,overlap=overlap,B=B,Bprime=Bprime,unsat50_local_moisture_term=moisture,unsat50_GWL_term_head50=contact50,unsat50_GWL_term_head51=contact51,fullvector_max_error_amount_per_head=maxerr,fullvector_max_error_rate_per_head=maxrateerr,O_derivative_max_error=maxsumerr,moisture_checks=moisture_checks,columns=columns))
 results.append(dict(optimization=opt,seconds=run['seconds'],returncode=0,censored=False,parent_physical_text_files_exact=len(names),parent_inactive_history_is_exact_subsequence=True,additional_inactive_observer_rows=len(extra),trajectory_and_solver_unchanged=True,points=pp))
x=R/'data/O0/RESTART_D2';y=R/'data/O2/RESTART_D2'
for f in x.glob('*.txt'):
 if f.name not in ['attempt_trace.txt','cost_trace.txt']:assert f.read_bytes()==(y/f.name).read_bytes(),f.name
for f in P.glob('*.f90'):
 if f.name=='factor60_probe.f90':continue
 s=(R/f.name).read_text()
 if f.name=='head_diag.f90':s=s.replace('call potential61_probe()','call factor60_probe()')
 assert s==f.read_text(),f.name
for name,cols,data in [('GRADIENT_AUDIT.csv',['opt','iteration','head_column','epsilon_cm','max_vector_error_amount_per_head','max_vector_error_rate_per_head','dO_analytic','dO_FD','dU50_analytic','dU50_FD'],out),('SPARSE_POTENTIAL_GRADIENT.csv',['opt','iteration','row','column','amount_gradient','rate_gradient'],gradient)]:
 with (R/name).open('w',newline='',encoding='utf-8') as f:w=csv.writer(f);w.writerow(cols);w.writerows(data)
q=dict(work_unit='SWAP431-MACRO-B1-POTENTIAL61',decision='CONDITIONAL_FULL_D3_POTENTIAL_GRADIENT_QUALIFIED_ACTIVE_SUPPORT_O0_O2',model_routes=2,hard_seconds_per_route=20,real_provider_perturbations_per_route=48,analytic_gradient_shape=[112,112],active_columns_tested=list(range(50,58)),outside_control_head=49,all112_independent_columns_not_probed=True,qualification_envelope='current fixed material/geometry/macrolevel/history/active-support at original D2 providers53/54',local_moisture_and_GWL_contact_included=True,source_solver_physics_clock_budget_unchanged=True,no_Jacobian_update_installed=True,O0_O2_probe_outputs_exact=True,convergence_or_accepted_follow_not_qualified=True,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',results=results)
save('RESULT.json',q);save('STATUS.json',dict(q,stage='CONDITIONAL_POTENTIAL_GRADIENT_CONTRACT_QUALIFIED',recovery='POTENTIAL_CONTRACT.md; REPORT.md; RESULT.json; SPARSE_POTENTIAL_GRADIENT.csv; CODEX_FOLLOWUP.md; EVIDENCE.json',no_broad_campaign=True,official_promotion=False))
print(json.dumps([dict(opt=x['optimization'],seconds=x['seconds'],points=[dict(iteration=p['iteration'],vector_error=p['fullvector_max_error_amount_per_head'],restore_checks=p['restore_checks']) for p in x['points']]) for x in results],indent=2))
