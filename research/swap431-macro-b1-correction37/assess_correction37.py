"""Read-only qualification of guarded DOMAINS36 implementation on the same large293."""
from pathlib import Path
import json,math,hashlib,difflib
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-domains36';W=Path('C:/Users/Veldh012/swap431-correction37-work')
def rows(p):return [list(map(float,s.split())) for s in p.read_text().splitlines()]
def f(p):return {s.split()[0].lower():list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
results=[];ref=json.loads((P/'RESULT.json').read_text())['results'][0]
for opt in ['O0','O2']:
 d=R/'data'/opt/'TRIAL';old=P/'data'/opt/'TRIAL_PROBE';a=rows(d/'attempt_trace.txt');oa=rows(old/'attempt_trace.txt');b=rows(d/'step_budget.txt');iv=rows(d/'inventory_trace.txt');j=rows(d/'jac37_trace.txt')
 assert len(a)==len(b)==293 and len(iv)==293
 assert [v[:-1] for v in a[:292]]==[v[:-1] for v in oa[:292]]
 assert (d/'step_budget.txt').read_text().splitlines()[:292]==(old/'step_budget.txt').read_text().splitlines()[:292]
 for name in ['origin','context_origin','ledger_origin','begin_1','context_begin_1','ledger_begin_1']:
  assert (d/(name+'.txt')).read_bytes()==(old/(name+'.txt')).read_bytes(),name
 x=a[-1];assert x[0]==293 and x[2]==35797.370324351359 and x[3]==.0006875745394909628
 assert x[4:7]==[0,0,1] and x[7:17]==[4,0,0,0,0,0,0,0,0,0] and x[25]==1 and x[18]<1e-6 and abs(x[17])<1e-5
 assert len(j)==4 and all(v[0]==293 and v[2]==1 and v[16]==1 for v in j)
 assert [v[3] for v in j]==[2,1,2,2] and [v[1] for v in j]==[1,2,3,4]
 assert j[0][9]==1 and j[0][6:8]==[0,0] # First-state tie on domain3: explicit stock-cap derivative0.
 assert all(v[27]<1e-12 and abs(v[24])>1e-12 for v in j)
 oldrank=rows(old/'jac24_trace.txt');nowrank=rows(d/'jac24_trace.txt')
 assert nowrank==[v for v in oldrank if v[0]<=292] and sum(v[2] for v in nowrank)==222
 assert (d/'cal37_before.bin').read_bytes()==(d/'cal37_after.bin').read_bytes()
 assert (d/'domains36_point.bin').read_bytes()==(old/'probe35_base.bin').read_bytes()
 cal=f(d/'cal37_terms.txt');ctx=f(old/'probe35_context.txt');base=rows(old/'probe36_base.txt');n=112;h=ctx['h'];z=ctx['z']
 assert cal['meta'][0:2]==[1,2] and cal['meta'][4:8]==[1,1,0,0] and cal['meta'][14]==1
 assert abs(cal['band'][0]-ref['additional_banded_J51_50'])<1e-14 and abs(cal['band'][1]-ref['additional_banded_J51_51_total'])<1e-14
 D=h[50]-h[49];g0=(z[49]-z[50])*h[50]/D**2;g1=-(z[49]-z[50])*h[49]/D**2
 maxu=maxv=0
 for dom in [2,3]:
  bb=base[dom-1];m=bb[1:25];pot=bb[25+2*n:25+3*n]
  for k in range(n):
   uu=-pot[k]/m[20]
   dd=-pot[k]/(max(0,m[23]-z[k])-h[k]) if pot[k]>0 else 0
   gg=g0 if k==49 else(g1 if k==50 else 0)
   vv=(-m[17]*gg-m[15]*dd)/m[5]
   maxu=max(maxu,abs(uu-cal['u'+str(dom)][k]));maxv=max(maxv,abs(vv-cal['v'+str(dom)][k]))
 assert maxu<1e-13 and maxv<1e-11
 begin=f(d/'begin_1.txt');end=f(d/'committed.txt');ci=f(d/'context_begin_1.txt');ce=f(d/'context_committed.txt');L0=f(d/'ledger_begin_1.txt');L1=f(d/'ledger_committed.txt');v=b[-1];dt=v[1]
 assert dt==x[3] and v[16]==1 and end['controls'][0]==v[0]==35797.371011925898
 assert abs(v[0]-begin['controls'][0]-dt)<5e-12 and end['controls'][1]==2*dt
 stock=math.fsum((y-z0)*dz*fr for z0,y,dz,fr in zip(begin['theta'],end['theta'],begin['dz'],begin['fraction']))+math.fsum(y-z0 for z0,y in zip(begin['macro_domain'],end['macro_domain']))+end['pond'][0]-begin['pond'][0]+ce['sicact'][0]-ci['sicact'][0]
 external=dt*(v[2]+v[3]+v[4]-v[5]-v[6]-v[7]-v[8]+v[9]-v[10]+v[11]-v[12])-v[13];err=stock-external
 assert abs(err)<dt*1e-5 and abs(err-dt*x[17])<1e-15
 domains=[]
 for k in range(5):
  de=end['macro_domain'][k]-begin['macro_domain'][k]-dt*(v[17+k]+v[22+k]-v[27+k]-(v[12] if k==0 else 0));assert abs(de)<1e-13;domains.append(de)
 for key,col in [('cgrai',2),('cgird',3),('crunon',4),('caintc',5),('cepd',6),('cevap',7),('cqrot',8),('cqbot',9),('cqdra',10),('cqssdi',11),('cqmpoutdrrap',12)]:
  assert abs(L1[key][0]-L0[key][0]-dt*v[col])<1e-12
 assert (d/'ledger_returned_1.txt').read_bytes()==(d/'ledger_begin_1.txt').read_bytes()
 assert all(abs(w[9])<w[3]*1e-5 and max(abs(z0) for z0 in w[13:])<1e-13 for w in iv)
 assert not list(d.glob('rollback*.txt')) and not (d/'begin_2.txt').exists() and not (d/'event33.txt').exists()
 run=json.loads((R/(opt+'_TRIAL_RUN.json')).read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20
 identity=json.loads((R/(opt+'_IDENTITY.json')).read_text());assert all(sha(R/name)==hv for name,hv in identity['sources'].items()) and sha(W/'native'/opt/'native09.exe')==identity['exe_sha256']
 results.append(dict(optimization=opt,seconds=run['seconds'],original_candidate_prefix_commits_byte_exact=292,old_prefix_rank1_active_iterations_preserved=222,unchanged_original_target_origin_byte_exact=True,large_step_converged=True,large_used_dt_days=dt,Newton_iterations=4,extra_line_search_trials=x[24]-x[21],fresh_V1_certifications=x[25],maximum_residual=x[18],sum_residual=x[17],flux_factor=1,corrected_Jacobian_iterations=4,stock_update_ranks=[int(v[3]) for v in j],domain3_tie_stockcap_derivative_zero_encountered=True,minimum_Woodbury_determinant=min(abs(v[24]) for v in j),max_linear_residual=max(v[27] for v in j),frozen_point_calibration_selected_snapshot_byte_exact=True,frozen_point_max_U_error=maxu,frozen_point_max_V_error=maxv,frozen_point_band_matches_DOMAINS36=True,host_committed_t1900=v[0],inventory_error_cm=err,inventory_limit_cm=dt*1e-5,domain_inventory_errors_cm=domains,ledger_target_primitive_increments_verified=True,real_refusal_occurred=False,active_refusal_rollback_direct_qualification=False))
for p in (R/'data/O0/TRIAL').glob('*.txt'):
 if p.name in ['attempt_trace.txt','cost_trace.txt']:continue
 assert p.read_bytes()==(R/'data/O2/TRIAL'/p.name).read_bytes(),p.name
assert [v[:-1] for v in rows(R/'data/O0/TRIAL/attempt_trace.txt')]==[v[:-1] for v in rows(R/'data/O2/TRIAL/attempt_trace.txt')]
for name in ['cal37_before.bin','cal37_after.bin','domains36_point.bin']:
 assert (R/'data/O0/TRIAL'/name).read_bytes()==(R/'data/O2/TRIAL'/name).read_bytes()
changed={'diag_state.f90','soilwater_native.f90','macrorate_node.f90','jac_update.f90'}
for p in P.glob('*.f90'):
 if p.name not in changed:assert p.read_bytes()==(R/p.name).read_bytes(),p.name
# Old analytical rank1 routine and original physical provider code remain unchanged except explicit numerical workspace writes.
old=(P/'macrorate_node.f90').read_text().split('entry jac24_terms',1)[1];new=(R/'macrorate_node.f90').read_text().split('entry jac24_terms',1)[1];assert old==new
live=(R/'jac37_update.f90').read_text().split('subroutine jac37_calibrate()',1)[0]
assert 'obs36' not in live and 'domains36_point' not in live and 'snapshot(' not in live
assert not list((R/'data').glob('*/DIRECT*'))
q=dict(work_unit='SWAP431-MACRO-B1-CORRECTION37',decision='PASS_SAME_LARGE293_GUARDED_ANALYTIC_CORRECTION_O0_O2_HOSTCOMMIT_INVENTORY',model_routes=2,hard_timeout_seconds=20,all_uncensored=True,O0_O2_non_timing_byte_exact=True,scope='New correction onlyselected293/retries; exact existingcontinuouscandidateprefix unchanged. Same original large dt accepted, not old smaller retry comparison.',physical_provider_forcing_tolerances_MAXIT_dt_reduction_rule_changes=False,numerical_change='Current provider scratch +two band51 entries +two stock outerproducts; original TRIDAG and2x2Woodbury; no denseJac/FDsolver',selected_branch_tie_choice='Vunder=W uses stockcap derivative0; observed firstJacdomain3, actuallargehead accepted. Not general nondifferentiableFDqualification.',active_refusal_rollback_direct_qualification=False,full_candidate_trajectory_period_restart_general_admission=False,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',official_promotion=False,results=results)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q,indent=2))
