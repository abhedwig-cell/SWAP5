"""Read-only diagnosis, inactive rollback/direct retry, and restored provider sensitivity."""
from pathlib import Path
import json,math,hashlib,collections,difflib
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-period34';W=Path('C:/Users/Veldh012/swap431-inactive35-work')
def rows(p):return [list(map(float,s.split())) for s in p.read_text().splitlines()]
def f(p):return {s.split()[0].lower():list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
results=[];sensitivity=[]
for opt in ['O0','O2']:
 t=R/'data'/opt/'TRIAL';d=R/'data'/opt/'DIRECT';p=R/'data'/opt/'TRIAL_PROBE'
 ta=rows(t/'attempt_trace.txt');da=rows(d/'attempt_trace.txt');old=rows(P/'data'/opt/'TRAJ/attempt_trace.txt')
 assert len(ta)==294 and len(da)==293 and [v[:-1] for v in ta]==[v[:-1] for v in old[:294]]
 assert [v[:-1] for v in da[:292]]==[v[:-1] for v in ta[:292]] and ta[-1][2:-1]==da[-1][2:-1]
 large,small=ta[-2:];assert large[0]==293 and large[7:11]==[31,4,1,0] and large[25]==0
 assert small[0]==294 and small[7:11]==[27,0,0,0] and small[25]==1 and small[3]==large[3]/3 and small[6]==large[6]==1
 assert large[18]==2.6450268135885802e-5 and abs(large[17])<1e-5 and large[13]==1 and large[14:17]==[0,0,0]
 for n in ['origin','context_origin','ledger_origin','accepted_return','context_accepted_return','ledger_accepted_return','committed','context_committed','ledger_committed','step_budget']:
  assert (t/(n+'.txt')).read_bytes()==(d/(n+'.txt')).read_bytes(),n
 assert (t/'solver_2.txt').read_bytes()==(d/'solver_1.txt').read_bytes()
 assert (t/'step_budget.txt').read_text().splitlines()==(P/'data'/opt/'TRAJ/step_budget.txt').read_text().splitlines()[:293]
 oo=f(t/'origin.txt');rb=f(t/'rollback_1.txt');sb=f(t/'begin_2.txt');db=f(d/'begin_1.txt')
 scratch={'macro_exchange','macro_rapid','matrix_exchange','boundary_rates','reference','sorptivity'}
 assert {k for k in oo if oo[k]!=rb[k]}==scratch|{'controls'}
 assert oo['controls'][:7]==rb['controls'][:7] and rb['controls'][7]==1
 assert {k for k in sb if sb[k]!=db[k]}==scratch
 for n in ['ledger_begin_1','ledger_returned_1','ledger_rollback_1','ledger_begin_2']:
  assert (t/(n+'.txt')).read_bytes()==(t/'ledger_origin.txt').read_bytes()
 for mode,dd,beg in [('TRIAL',t,'begin_2'),('DIRECT',d,'begin_1')]:
  a=f(dd/(beg+'.txt'));b=f(dd/'committed.txt');ca=f(dd/('context_'+beg+'.txt'));cb=f(dd/'context_committed.txt');v=rows(dd/'step_budget.txt')[-1];dt=v[1]
  stock=math.fsum((y-x)*dz*fr for x,y,dz,fr in zip(a['theta'],b['theta'],a['dz'],a['fraction']))+math.fsum(y-x for x,y in zip(a['macro_domain'],b['macro_domain']))+b['pond'][0]-a['pond'][0]+cb['sicact'][0]-ca['sicact'][0]
  ext=dt*(v[2]+v[3]+v[4]-v[5]-v[6]-v[7]-v[8]+v[9]-v[10]+v[11]-v[12])-v[13]
  assert abs(stock-ext)<dt*1e-5 and abs(stock-ext-small[17]*dt)<1e-15
  error=stock-ext
 lim=rows(t/'domain3_limit.txt');guard_report={}
 for att,count in [(293,30),(294,27)]:
  ll=[v for v in lim if v[0]==att and v[4]==2 and v[5]==3];assert len(ll)==count
  assert all(v[17]>0 and v[17]==v[24] and v[25:28]==[0,0,0] and v[20]==1 and v[37]==0 and v[10]==51 for v in ll)
  counts=collections.Counter('L_equals_W' if v[13]==v[12] else ('partial' if 0<v[23]<1 else 'unlimited') for v in ll)
  guard_report[str(att)]=dict(counts)
  assert all(v[2]==0 for v in rows(t/'jac24_trace.txt') if v[0]==att)
 assert guard_report=={'293':{'L_equals_W':3,'unlimited':2,'partial':25},'294':{'L_equals_W':2,'unlimited':6,'partial':19}}
 op=rows(t/'operator_nodes.txt');assert len(op)==8*(93+78)
 for v in op:
  assert abs(v[10]-math.fsum(v[11:18]))<1e-12
  assert abs(v[17]+math.fsum(v[19:24]))<1e-12
 last52=[v for v in op if v[0]==293 and v[6]==52][-1]
 assert last52[11]==0 and last52[13:15]==[0,0]
 # Probe must not alter any baseline numerical trace, solver, context, ledger or commit.
 for x in t.glob('*.txt'):
  if x.name in ['cost_trace.txt','attempt_trace.txt']:continue
  assert x.read_bytes()==(p/x.name).read_bytes(),x.name
 assert [v[:-1] for v in rows(p/'attempt_trace.txt')]==[v[:-1] for v in ta]
 restores=rows(p/'probe35_restore.txt');assert len(restores)==19 and all(v[1:]==[20347880,1,1] for v in restores)
 assert (p/'probe35_base.bin').read_bytes()==(p/'probe35_restored.bin').read_bytes()
 c=f(p/'probe35_context.txt');points=rows(p/'probe35_points.txt');n=len(c['h']);assert n==112 and len(points)==18 and all(len(v)==354 for v in points)
 base=points[0];assert base[3:]==points[-1][3:] and base[18+n:18+2*n]==c['q_total_before'] and base[18:18+n]==c['q_domain3_before']
 I,O,E,L,stock,gwl,sat,fr,ex,uns,rho,dt=base[3:15];fac=1-E/O;pot=base[18+2*n:];h=c['h'];z=c['z'];jg=max(k for k,v in enumerate(h) if v<0)
 assert jg==49 and sat==51 and I>0 and L<stock and 0<fac<1
 gcalc=z[jg+1]+h[jg+1]/(h[jg+1]-h[jg])*(z[jg]-z[jg+1]);assert gcalc==gwl
 assert all(v[3]==I and v[9:13]==[51,1,0,0] and v[6]<v[7] and 0<1-v[5]/v[4]<1 for v in points)
 zmacro=next(v[11] for v in lim if v[0]==293 and v[1]==30 and v[4]==2 and v[5]==3)
 fditems=[];max_shadow=0
 for node in [50,51,52,57]:
  k=node-1;dO=-pot[k]/(max(0,zmacro-z[k])-h[k]) if pot[k]>0 else 0
  dG=(z[jg]-z[jg+1])*h[jg+1]/(h[jg+1]-h[jg])**2 if k==jg else (-(z[jg]-z[jg+1])*h[jg]/(h[jg+1]-h[jg])**2 if k==jg+1 else 0)
  df=(-rho*dG-fac*dO)/O
  for eps in [1e-5,5e-6]:
   minus=next(v for v in points if v[1]==node and v[2]==-eps);plus=next(v for v in points if v[1]==node and v[2]==eps)
   der=[(x-y)/(2*eps) for x,y in zip(plus,minus)]
   assert der[3]==0 and abs(der[8]-dG)<2e-9 and abs(der[6]-rho*dG)<1e-10 and abs(der[4]-dO)<1e-12
   err=max(abs(pot[ii]/dt*df+(fac*dO/dt if ii==k else 0)-der[18+ii]) for ii in range(n));assert err<2e-8;max_shadow=max(max_shadow,err)
   coeff={}
   for row in [52,53,57]:
    dom=-der[18+row-1];total=-der[18+n+row-1]
    coeff[str(row)]=dict(residual_J_domain3=dom,residual_J_total_macro=total,residual_J_other_domains=total-dom,existing_off_tridiagonal_J=0 if abs(row-node)>1 else None)
   fditems.append(dict(node=node,epsilon=eps,dI=der[3],dGWL=der[8],dminimum_stock=der[6],doutpotential_total=der[4],domain3_stock_chain_shadow_max_error=err,coefficients_by_row=coeff))
 # Exact absent nonlocal coupling in current Jacobian, larger than numerical noise.
 example=next(v for v in fditems if v['node']==50 and v['epsilon']==5e-6)['coefficients_by_row']['52']
 assert example['residual_J_total_macro']>.44 and example['residual_J_domain3']>.34 and example['residual_J_other_domains']>.10
 sensitivity.append(dict(optimization=opt,point='attempt293 iteration30 afterJacobian beforeTRIDAG',head_interpolation_nodes=[50,51],native_saturated_volume_compartment=51,base_incoming_top_only_cm=I,base_outpotential_cm=O,base_minimum_stock_cm=L,base_stock_cm=stock,base_outflow_factor=fac,base_GWL_cm=gwl,volume_density_cm_per_cm=rho,all_18_points_branch_stable=True,selected_snapshot_bytes=20347880,byte_exact_restore_checks=19,recognized_IEEE_flags_restored_each_time=True,probe_baseline_continuation_byte_exact=True,snapshot_sha256=sha(p/'probe35_base.bin'),domain3_stock_chain_shadow_max_error=max_shadow,other_domain_nonlocal_response_demonstrated=True,FD=fditems))
 for prefix,source,native in [('BASE_',R/'baseline_source',W/'baseline_native'),('',R,W/'native')]:
  ident=json.loads((R/(prefix+opt+'_IDENTITY.json')).read_text());assert all(sha(source/nm)==hv for nm,hv in ident['sources'].items());assert sha(native/opt/'native09.exe')==ident['exe_sha256']
 runs={mode:json.loads((R/(opt+'_'+mode+'_RUN.json')).read_text()) for mode in ['TRIAL','DIRECT','TRIAL_PROBE']}
 assert all(v['returncode']==0 and not v['censored'] and v['seconds']<20 for v in runs.values())
 results.append(dict(optimization=opt,seconds={k:v['seconds'] for k,v in runs.items()},original_candidate_prefix_and_target_attempts_exact=True,large_dt=large[3],large_actual_iterations=30,large_final_max_residual=large[18],large_final_sum_residual=large[17],large_extra_line_search_trials=large[24]-large[21],retry_dt=small[3],retry_iterations=27,retry_final_max_residual=small[18],retry_final_sum_residual=small[17],retry_extra_line_search_trials=small[24]-small[21],rank1_active_iterations_in_both_target_heads=0,guard_counts=guard_report,rollback_physical_inventory_core_exact=True,rollback_ledger_unchanged=True,immediate_rollback_scratch_differences=sorted(scratch),retry_direct_full_accepted_solver_context_ledger_commit_exact=True,retry_inventory_error_cm=error,retry_inventory_limit_cm=small[3]*1e-5,last_large_node52_operator=last52))
for mode in ['TRIAL','DIRECT','TRIAL_PROBE']:
 for x in (R/'data/O0'/mode).glob('*.txt'):
  if x.name in ['cost_trace.txt','attempt_trace.txt']:continue
  assert x.read_bytes()==(R/'data/O2'/mode/x.name).read_bytes(),(mode,x.name)
 assert [v[:-1] for v in rows(R/'data/O0'/mode/'attempt_trace.txt')]==[v[:-1] for v in rows(R/'data/O2'/mode/'attempt_trace.txt')]
# Numerical candidate unchanged; only baseline diagnostics and targeted probe differ.
for p in P.glob('*.f90'):
 if p.name not in ['diag_state.f90','head_diag.f90','soilwater_native.f90']:assert p.read_bytes()==(R/'baseline_source'/p.name).read_bytes()
assert (R/'jac_update.f90').read_bytes()==(P/'jac_update.f90').read_bytes()
assert (R/'macrorate_node.f90').read_text().split('entry diagnose35_get')[0].replace('      real(8)::pot35(macp),info35(12)\n','')==(P/'macrorate_node.f90').read_text().split('entry jac24_terms')[0]
# RHS after the observational ENTRY rejoins the original unchanged analytic terms.
new=(R/'macrorate_node.f90').read_text().split('entry jac24_terms',1)[1];old=(P/'macrorate_node.f90').read_text().split('entry jac24_terms',1)[1]
new=new.replace('raw_u,detail33,probe_busy','raw_u,detail33').replace('if(detail33.and.ic==52.and..not.probe_busy) then','if(detail33.and.ic==52) then');assert new==old
q=dict(work_unit='SWAP431-MACRO-B1-INACTIVE35',decision='MISSING_NONLOCAL_JACOBIAN_TERMS_PROVEN_IN_INACTIVE_TOP_INFLOW_GWL_COMPARTMENT51_CONTEXT',model_routes=6,hard_timeout_seconds=20,all_uncensored=True,O0_O2_non_timing_byte_exact=True,numerical_candidate_physics_guards_MAXIT_tolerances_dt_reduction_unchanged=True,selected_inactive_refusal_rollback_direct_retry='PASS_THIS_CONTEXT',active_refusal_rollback_direct_qualification=False,FD_provider_transaction_restoration_and_continuation='PASS',domain3_constant_top_inflow_stock_chain='ANALYTIC_SHADOW_MATCHES_FD_NOT_IMPLEMENTED_AS_SOLVER',other_domain_nonlocal_terms='DEMONSTRATED_IN_TOTAL_MINUS_DOMAIN3_NOT_YET_DECOMPOSED',minimal_guard_relaxation_alone='INSUFFICIENTLY_JUSTIFIED_FOR_TOTAL_OPERATOR',physical_flux_defect_proven=False,numerical_correction_implemented=False,full_period_restart_or_general_solver_admission=False,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',official_promotion=False,results=results)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
(R/'SENSITIVITY.json').write_text(json.dumps(dict(points=sensitivity),indent=2)+'\n')
print(json.dumps(q,indent=2));print('SENSITIVITY analytical max',max(v['domain3_stock_chain_shadow_max_error'] for v in sensitivity))
