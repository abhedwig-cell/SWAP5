"""Read-only domain decomposition and bounded analytic correction contract."""
from pathlib import Path
import json,math,hashlib,collections,difflib
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-inactive35';W=Path('C:/Users/Veldh012/swap431-domains36-work')
def rows(p):return [list(map(float,s.split())) for s in p.read_text().splitlines()]
def f(p):return {s.split()[0].lower():list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
results=[]
zone=json.loads((R/'NATIVE_ZONE_CONTEXT.json').read_text())
for opt in ['O0','O2']:
 d=R/'data'/opt/'TRIAL_PROBE';old=P/'data'/opt/'TRIAL_PROBE';run=json.loads((R/(opt+'_TRIAL_PROBE_RUN.json')).read_text())
 assert run['returncode']==0 and not run['censored'] and run['seconds']<20
 for x in old.glob('*.txt'):
  if x.name not in ['attempt_trace.txt','cost_trace.txt']:assert x.read_bytes()==(d/x.name).read_bytes(),x.name
 assert [v[:-1] for v in rows(old/'attempt_trace.txt')]==[v[:-1] for v in rows(d/'attempt_trace.txt')]
 assert (d/'probe35_base.bin').read_bytes()==(old/'probe35_base.bin').read_bytes()==(d/'probe35_restored.bin').read_bytes()
 restore=rows(d/'probe35_restore.txt');assert len(restore)==19 and all(v[1:]==[20347880,1,1] for v in restore)
 zc=next(v for v in zone['contexts'] if v['optimization']==opt);assert zc['perched_top_compartment']==zc['perched_bottom_compartment']==51 and zc['perched_GWL_cm']==-66.56028506140325
 c=f(d/'probe35_context.txt');h=c['h'];z=c['z'];dz=c['dz'];n=len(h);assert n==112
 base=rows(d/'probe36_base.txt');pts=rows(d/'probe36_domains.txt');oldpts=rows(d/'probe35_points.txt')
 assert len(base)==5 and all(len(v)==585 for v in base) and len(pts)==90 and all(len(v)==588 for v in pts)
 for dm,v in enumerate(base,1):assert v[0]==dm and v[1:]==pts[dm-1][4:]
 for v in pts:
  meta=v[4:28];q=v[28:28+n];pi=v[28+n:28+2*n];po=v[28+2*n:28+3*n];uns=v[28+3*n:28+4*n];rapid=v[28+4*n:]
  assert all(abs(qi-(meta[15]*(o+u)-meta[7]*ii)/meta[20])<1e-13 for qi,o,u,ii in zip(q,po,uns,pi))
  assert abs(meta[4]-meta[8]-meta[9]-math.fsum(pi))<1e-15
  assert abs(meta[5]-math.fsum(po)-math.fsum(uns)-math.fsum(rapid))<1e-15
 for point in oldpts:
  group=[v for v in pts if v[0]==point[0]]
  assert [v[3] for v in group]==[1,2,3,4,5]
  assert all(abs(math.fsum(v[28+i] for v in group)-point[18+n+i])<1e-14 for i in range(n))
 # Same active set at every point, with separate unconstrained main domain and unsaturated domains.
 for dom in range(1,6):
  pp=[v for v in pts if v[3]==dom]
  assert all(v[11]==1 and v[25]==0 and v[26]==1 and v[23]==51 for v in pp) # FrIn,TopExcess,IcTopMP,nativecell
  if dom in [2,3]:
   assert all(v[5]<v[4] and 0<v[19]<1 and v[14:16]==[0,0] and v[17:19]==[0,0] for v in pp)
   assert all(v[8]==v[12]==base[dom-1][5] for v in pp) # constant top only I
  else:assert all(v[19]==1 for v in pp)
 b1=base[0];m1=b1[1:25];pi1=b1[25+n:25+2*n]
 depth=m1[18]-z[50]+.5*dz[50];C=pi1[50]/m1[20]/depth;HM1=max(0,m1[23]-z[50]);assert HM1==0
 internal=m1[10]/m1[20]/(h[50]-HM1)
 op=rows(d/'operator_nodes.txt');v51=next(v for v in op if v[0]==293 and v[2]==91 and v[6]==51)
 assert abs(v51[39]*m1[20]-m1[10])<1e-20 and abs((v51[34]+v51[39])*m1[20]-pi1[50])<1e-20
 D=h[50]-h[49];g50=(z[49]-z[50])*h[50]/D**2;g51=-(z[49]-z[50])*h[49]/D**2
 UV=[];domain_summary=[]
 for dom in [1,2,3,4,5]:
  v=base[dom-1];m=v[1:25]
  domain_summary.append(dict(domain=dom,W=m[0],L=m[1],U=m[2],I=m[4],O=m[5],FrIn=m[7],FrOut=m[15],rho=m[17],outgoing_unsaturated=m[13],rapid_potential=m[14],incoming_internal=m[10],active_minimum_limiter=dom in [2,3],active_maximum_limiter=False))
  if dom not in [2,3]:continue
  pot=v[25+2*n:25+3*n];U=[-v/m[20] for v in pot];V=[]
  for k in range(n):
   dO=-pot[k]/(max(0,m[23]-z[k])-h[k]) if pot[k]>0 else 0
   dg=g50 if k==49 else(g51 if k==50 else 0)
   V.append((-m[17]*dg-m[15]*dO)/m[5])
  UV.append((U,V))
 fd_report=[];maxerr=0;max_without_internal=0
 for node in [50,51,52,57]:
  for eps in [1e-5,5e-6]:
   dq=[]
   for dom in range(1,6):
    lo=next(v for v in pts if v[1]==node and v[2]==-eps and v[3]==dom);hi=next(v for v in pts if v[1]==node and v[2]==eps and v[3]==dom)
    dq.append([(x-y)/(2*eps) for x,y in zip(hi[28:28+n],lo[28:28+n])])
   measured=[-math.fsum(v[i] for v in dq) for i in range(n)]
   predicted=[math.fsum(U[i]*V[node-1] for U,V in UV) for i in range(n)]
   predicted[node-1]+=-c['existing_local_macro_derivative'][node-1]
   predicted[50]+=C*(g50 if node==50 else(g51 if node==51 else 0))
   if node==51:max_without_internal=max(max_without_internal,abs(predicted[50]-measured[50]));predicted[50]+=internal
   err=max(abs(a-b) for a,b in zip(predicted,measured));maxerr=max(maxerr,err);assert err<3e-8
   fd_report.append(dict(node=node,epsilon=eps,full_four_component_shadow_max_error=err,residual_J52_by_domain=[-v[51] for v in dq],residual_J51_by_domain=[-v[50] for v in dq],residual_J53_by_domain=[-v[52] for v in dq],residual_J57_by_domain=[-v[56] for v in dq]))
 r=lambda i,j:math.fsum(U[i-1]*V[j-1] for U,V in UV)
 minor=r(52,50)*r(57,57)-r(52,57)*r(57,50);assert abs(minor)>1e-6
 u2,v2=UV[0];u3,v3=UV[1];ucos=math.fsum(a*b for a,b in zip(u2,u3))/(math.sqrt(math.fsum(a*a for a in u2))*math.sqrt(math.fsum(a*a for a in u3)))
 ref=next(v for v in fd_report if v['node']==50 and v['epsilon']==5e-6)['residual_J52_by_domain']
 assert ref[0]==ref[3]==ref[4]==0 and abs(ref[1]-.1053661976281942)<1e-10 and abs(ref[2]-.3409272299746343)<1e-12
 ident=json.loads((R/(opt+'_IDENTITY.json')).read_text());assert all(sha(R/name)==hv for name,hv in ident['sources'].items()) and sha(W/'native'/opt/'native09.exe')==ident['exe_sha256']
 results.append(dict(optimization=opt,seconds=run['seconds'],all_original_INACTIVE35_numerical_exports_byte_exact=True,snapshot_sha256=sha(d/'probe35_base.bin'),selected_snapshot_restore_checks=19,all_18_real_provider_points_same_active_set=True,native_head_interpolation=[50,51],native_saturated_compartment=51,perched_top_and_bottom=[51,51],perched_GWL_equals_main=True,domains=domain_summary,additional_banded_J51_50=C*g50,additional_banded_J51_51_geometry=C*g51,additional_banded_J51_51_internal_incoming=internal,additional_banded_J51_51_total=C*g51+internal,geometry_coefficient_per_GWL=C,two_rank1_stock_update_minor=minor,potential_U_cosine=ucos,max_error_if_internal_diagonal_omitted=max_without_internal,max_complete_shadow_error=maxerr,probed_columns=[50,51,52,57],output_rows=112,all_112_input_columns_qualified=False,FD=fd_report))
for x in (R/'data/O0/TRIAL_PROBE').glob('*.txt'):
 if x.name not in ['cost_trace.txt','attempt_trace.txt']:assert x.read_bytes()==(R/'data/O2/TRIAL_PROBE'/x.name).read_bytes(),x.name
assert [v[:-1] for v in rows(R/'data/O0/TRIAL_PROBE/attempt_trace.txt')]==[v[:-1] for v in rows(R/'data/O2/TRIAL_PROBE/attempt_trace.txt')]
for p in P.glob('*.f90'):
 if p.name not in ['macrorate_node.f90','probe_state.f90']:assert p.read_bytes()==(R/p.name).read_bytes()
patch=''
for p in P.glob('*.f90'):
 if p.read_bytes()!=(R/p.name).read_bytes():patch+=''.join(difflib.unified_diff(p.read_text().splitlines(True),(R/p.name).read_text().splitlines(True),fromfile='INACTIVE35/'+p.name,tofile='DOMAINS36/'+p.name))
assert patch==(R/'observation_only.patch').read_text()
q=dict(work_unit='SWAP431-MACRO-B1-DOMAINS36',decision='MINIMAL_POINT_QUALIFIED_CONTRACT_TWO_STOCK_RANK_ONE_TERMS_PLUS_BANDED_DOMAIN1_GEOMETRY_AND_INTERNAL_INFLOW_DIAGONAL',model_routes=2,hard_timeout_seconds=20,all_uncensored=True,O0_O2_non_timing_byte_exact=True,physical_and_numerical_candidate_changes=False,operator_response_domain_decomposition='PASS_FIXED_POINT',analytic_four_column_shadow='PASS_112_ROWS_TWO_EPS_BOTH_OPTS',correction_implemented_or_trajectory_qualified=False,full_112_by112_Jacobian_qualified=False,active_refusal_full_period_restart_or_general_admission=False,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',official_promotion=False,results=results)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q,indent=2))
