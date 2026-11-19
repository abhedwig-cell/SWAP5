"""Bounded derivative-chain audit, no model calls."""
from pathlib import Path
import json,csv,hashlib,math
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-node59'
def rows(p):return [[float(v) for v in s.split()] for s in p.read_text().splitlines() if s.strip()]
def sha(p):
 with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def save(n,v):(R/n).write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')
def fs(c):return ((c[0]-c[1])+c[4])/c[5]
def records(p):
 a=rows(p);assert len(a)==14*7;return [a[i:i+7] for i in range(0,len(a),7)]
allrows=[];results=[]
for opt in ['O0','O2']:
 d=R/'data'/opt/'RESTART_D2';old=P/'data'/opt/'RESTART_D2';run=json.loads((R/(opt+'_RESTART_D2_RUN.json')).read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20
 names=[p.name for p in old.glob('*.txt') if p.name not in ['attempt_trace.txt','cost_trace.txt','inactive51_trace.txt']]
 for n in names:assert (d/n).read_bytes()==(old/n).read_bytes(),n
 assert [x[:-1] for x in rows(d/'attempt_trace.txt')]==[x[:-1] for x in rows(old/'attempt_trace.txt')]
 a=(old/'inactive51_trace.txt').read_text().splitlines();b=(d/'inactive51_trace.txt').read_text().splitlines();ix=0;extra=[]
 for s in b:
  if ix<len(a) and s==a[ix]:ix+=1
  else:extra.append(s)
 assert ix==len(a) and len(extra)==36 and all([int(s.split()[0]),int(s.split()[1])] in [[2,53],[2,54]] for s in extra)
 points=[]
 for it in [53,54]:
  rr=records(d/f'factor60_i{it}_points.txt');base=rr[0];h0=base[0];c=h0[4:28];assert len(h0)==36 and len(base[1])==112
  assert rr[0][0][1:]==rr[-1][0][1:] and rr[0][1:]==rr[-1][1:]
  receipt=rows(d/f'factor60_i{it}_restore.txt');assert len(receipt)==13 and all(x[3:]==[1,1,1] for x in receipt)
  for stem in ['', 'cache_']:
   n=f'factor60_i{it}_'+('cache' if stem else 'base')+'.bin';m=f'factor60_i{it}_'+('cache_restored' if stem else 'restored')+'.bin';assert sha(d/n)==sha(d/m)
  volume_branch=c[3]<c[0];assert volume_branch==(it==54)
  assert c[7]==1 and c[21]==0 and 0<c[15]<1 and c[19]==50
  assert all(x[0][4]==c[0] and x[0][8]==c[4] and x[0][27]==h0[27] for x in rr)
  assert all((x[0][7]<x[0][4])==volume_branch for x in rr)
  # VOLUNDR integration weights at fixed cell/bottom, followed by actual geometry derivative.
  weights=[0.]*112;zh=h0[33];ic=int(h0[34])
  while zh<c[18] and ic>0:ic-=1;zh+=base[4][ic];weights[ic]=1
  weights[ic]-=(zh-c[18])/base[4][ic]
  assert ic+1==50 and abs(sum(w*v for w,v in zip(weights,base[3]))-c[3])<1e-14 and c[3]<c[2]
  h50,h51=h0[28:30];z50,z51=h0[31:33];den=h51-h50
  dg={50:(z50-z51)*h51/den**2,51:-(z50-z51)*h50/den**2,52:0.}
  cols=[]
  for eps in [1e-7,5e-8]:
   for node in [50,51,52]:
    minus=next(x for x in rr if x[0][1]==node and x[0][2]==-eps);plus=next(x for x in rr if x[0][1]==node and x[0][2]==eps)
    cm=minus[0][4:28];cp=plus[0][4:28];fd=lambda k:(cp[k]-cm[k])/(2*eps)
    assert all(0<x[0][19]<1 and x[0][23]==50 for x in [minus,plus])
    dvol=[(x-y)/(2*eps) for x,y in zip(plus[3],minus[3])];geom=sum(w*v for w,v in zip(weights,dvol));assert max(map(abs,dvol))==0
    dV=c[17]*dg[node]+geom;dL=dV if volume_branch else 0.
    dO=sum((x-y)/(2*eps) for x,y in zip(plus[1],minus[1]))+sum((x-y)/(2*eps) for x,y in zip(plus[2],minus[2]));assert abs(dO-fd(5))<1e-15
    dU=sum((x-y)/(2*eps) for x,y in zip(plus[2],minus[2]))
    predicted=(-dL-c[15]*dO)/c[5];chain=(-fd(1)-c[15]*dO)/c[5]
    stable_fd=(fs(cp)-fs(cm))/(2*eps);raw_fd=fd(15)
    roundbound=(abs(cp[15]-fs(cp))+abs(cm[15]-fs(cm)))/(2*eps)
    geom_bound=abs(dL-fd(1))/c[5]
    assert abs(stable_fd-chain)<2e-8
    assert abs(raw_fd-predicted)<=roundbound+geom_bound+2e-8
    assert abs(fd(18)-dg[node])<2e-7 and abs(fd(3)-dV)<1e-9
    P52=base[1][51]/c[20];dP52=(plus[1][51]-minus[1][51])/(2*eps*c[20])
    dqraw=(plus[5][51]-minus[5][51])/(2*eps);dqchain=c[15]*dP52+P52*chain
    qround=(abs(plus[1][51]/c[20]*(cp[15]-fs(cp)))+abs(minus[1][51]/c[20]*(cm[15]-fs(cm))))/(2*eps)
    assert abs(dqraw-dqchain)<=qround+2e-8
    U50=base[2][49]/c[20];dU50=(plus[2][49]-minus[2][49])/(2*eps*c[20])
    dq50raw=(plus[5][49]-minus[5][49])/(2*eps);dq50chain=c[15]*dU50+U50*chain
    assert abs(dq50raw-dq50chain)<2e-8
    # Amount and rate units are explicit: O in cm, P52 in cm/day.
    cols.append(dict(node=node,epsilon_cm=eps,df_provider_FD=raw_fd,df_contract_chain=predicted,df_chain_with_provider_dL=chain,df_stable_equivalent_FD=stable_fd,raw_roundoff_bound=roundbound,analytic_geometry_propagated_bound=geom_bound,dG_analytic=dg[node],dG_FD=fd(18),dV_chain=dV,dV_FD=fd(3),geometry_profile_derivative_max=0,dO_total=dO,dO_unsat=dU,dq52_provider_FD=dqraw,dq52_chain=dqchain,q_roundoff_bound=qround,missing_J52_node=-P52*predicted,dq50_provider_FD=dq50raw,dq50_chain=dq50chain,q50_potential_derivative_term=c[15]*dU50,q50_factor_derivative_term=U50*chain))
    allrows.append([opt,it,'V' if volume_branch else 'W',node,eps,raw_fd,predicted,chain,stable_fd,roundbound,geom_bound,dg[node],fd(18),dV,fd(3),dO,dU,dqraw,dqchain,-P52*predicted])
  points.append(dict(iteration=it,branch='V' if volume_branch else 'W',W=c[0],V=c[3],W_minus_V=c[0]-c[3],O=c[5],I=c[4],factor=c[15],GWL=c[18],rho=c[17],restore_checks=13,physical_snapshot_bytes=int(receipt[0][1]),cache_snapshot_bytes=int(receipt[0][2]),probe_evaluations=12,columns=cols))
 results.append(dict(optimization=opt,seconds=run['seconds'],returncode=0,censored=False,unchanged_parent_text_files=len(names),parent_inactive_history_is_exact_subsequence=True,additional_inactive_observer_rows=len(extra),original_solver_provider_history_unchanged=True,probe_points=points))
x=R/'data/O0/RESTART_D2';y=R/'data/O2/RESTART_D2'
for p in x.glob('*.txt'):
 if p.name not in ['attempt_trace.txt','cost_trace.txt']:assert p.read_bytes()==(y/p.name).read_bytes(),p.name
# Only an observational hook and the standalone probe routine are added.
for p in P.glob('*.f90'):
 s=(R/p.name).read_text()
 if p.name=='head_diag.f90':s=s.replace('\n      if(detail33.and.attempts==2.and.(iter_index==53.or.iter_index==54)) call factor60_probe()','')
 assert s==p.read_text(),p.name
with (R/'DERIVATIVE_AUDIT.csv').open('w',newline='',encoding='utf-8') as f:
 w=csv.writer(f);w.writerow(['opt','iteration','branch','node','epsilon_cm','df_raw_FD','df_analytic_G_with_provider_dO','df_provider_chain','df_stable_equivalent_FD','raw_factor_roundoff_bound','geometry_chain_error_bound','dG_analytic','dG_FD','dV_chain','dV_FD','dO_total_amount','dO_unsat_amount','dq52_raw_FD','dq52_chain','missing_J52_node']);w.writerows(allrows)
q=dict(work_unit='SWAP431-MACRO-B1-FACTOR60',decision='TWO_BRANCH_D3_FACTOR_CHAIN_QUALIFIED_SELECTED_COLUMNS_O0_O2',model_routes=2,hard_seconds_per_route=20,physics_solver_policy_unchanged=True,O0_O2_probe_outputs_exact=True,real_provider_perturbations_per_route=24,full_state_cache_and_IEEE_restored_each_probe=True,selected_heads=[50,51,52],selected_iterations=[53,54],factor_chain_tested=True,all112_analytic_columns_not_qualified=True,analytic_unsat_constitutive_gradient_not_implemented=True,raw_FD_roundoff_explicitly_bounded=True,no_solver_Jacobian_update=True,convergence_or_accepted_follow_not_qualified=True,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',results=results)
save('RESULT.json',q);save('STATUS.json',dict(q,stage='BOUNDED_TWO_BRANCH_DERIVATIVE_CONTRACT_QUALIFIED',recovery='DERIVATIVE_CONTRACT.md; REPORT.md; RESULT.json; DERIVATIVE_AUDIT.csv; CODEX_FOLLOWUP.md; EVIDENCE.json',no_broad_campaign=True,official_promotion=False))
print(json.dumps([dict(optimization=x['optimization'],seconds=x['seconds'],branches=[p['branch'] for p in x['probe_points']],restore_checks=sum(p['restore_checks'] for p in x['probe_points'])) for x in results],indent=2))
