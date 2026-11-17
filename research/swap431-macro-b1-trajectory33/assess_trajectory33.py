"""Read-only qualification of one continuous own-candidate bounded trajectory."""
from pathlib import Path
import json,math,hashlib,collections,difflib
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-outside32'
def rows(p):return [list(map(float,s.split())) for s in p.read_text().splitlines()]
def fields(p):return {s.split()[0].lower():list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
result=[]
for opt in ['O0','O2']:
 d=R/'data'/opt/'TRAJ';a=rows(d/'attempt_trace.txt');j=rows(d/'jac24_trace.txt');b=rows(d/'step_budget.txt');iv=rows(d/'inventory_trace.txt')
 run=json.loads((R/(opt+'_TRAJ_RUN.json')).read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20
 assert 'BOUNDED_CANDIDATE_TRAJECTORY' in (d/'outcome.txt').read_text()
 assert len(a)==len(b)==len(iv)==63 and len(j)==269
 active=collections.Counter(int(v[0]) for v in j if v[2]==1);assert len(active)==28 and sum(active.values())==81 and min(active)==36
 assert all(x[8]==0 and x[4:7]==[0,0,1] and x[9:17]==[0]*8 and x[25]==1 and x[18]<=1e-6 and abs(x[17])<=1e-5 for x in a)
 assert all(v[1]==.002 and v[16]==1 for v in b)
 for n,(x,v,w) in enumerate(zip(a,b,iv),1):
  assert x[0]==x[1]==n and w[:2]==[n,n] and x[3]==v[1]==w[3]
  assert w[2]==v[0] and abs(v[0]-x[2]-v[1])<5e-12
  assert w[11]==1 and w[12]==active[n]
  external=v[1]*(v[2]+v[3]+v[4]-v[5]-v[6]-v[7]-v[8]+v[9]-v[10]+v[11]-v[12])-v[13]
  assert abs(w[8]-external)<1e-18
  assert abs(math.fsum(w[4:8])-external-w[9])<1e-18
  assert abs(w[9])<v[1]*1e-5 and abs(w[9]-w[10])<1e-15 and abs(w[10]-v[1]*x[17])<1e-18
  assert max(abs(z) for z in w[13:])<1e-13
 ini=fields(d/'initial.txt');fin=fields(d/'final.txt');ci=fields(d/'context_initial.txt');cf=fields(d/'context_final.txt')
 assert ini['controls'][0]==35797 and fin['controls'][0]==b[-1][0]==35797.126000000026
 assert b[-2][0]<35797.125<=b[-1][0] and math.fsum(v[1] for v in b)==.126
 matrix=math.fsum((y-x)*dz*fr for x,y,dz,fr in zip(ini['theta'],fin['theta'],ini['dz'],ini['fraction']))
 macro=math.fsum(y-x for x,y in zip(ini['macro_domain'],fin['macro_domain']))
 stock=matrix+macro+fin['pond'][0]-ini['pond'][0]+cf['sicact'][0]-ci['sicact'][0]
 external=math.fsum(v[8] for v in iv);error=stock-external;tolerance=math.fsum(v[1]*1e-5 for v in b)
 assert abs(error)<tolerance and abs(error-math.fsum(v[9] for v in iv))<1e-14
 assert abs(stock-math.fsum(math.fsum(v[4:8]) for v in iv))<1e-14
 old=(R.parent/'swap431-macro-b1-next18/data'/opt/'RESUME/step_budget.txt').read_text().splitlines()
 assert (d/'step_budget.txt').read_text().splitlines()[:35]==old[:35]
 iso=R.parent/'swap431-macro-b1-remaining31/data'/opt/'TRIAL_G1'
 assert [v[1:] for v in j if v[0]==36]==[v[1:] for v in rows(iso/'jac24_trace.txt')]
 assert (d/'step_budget.txt').read_text().splitlines()[35]==(iso/'step_budget.txt').read_text().splitlines()[0]
 assert all(v[16]<1e-14 for v in j)
 ident=json.loads((R/(opt+'_IDENTITY.json')).read_text());assert all(sha(R/n)==h for n,h in ident['sources'].items())
 assert (d/'own.end').read_bytes()==(R.parent/'swap431-macro-b1-next18/data'/opt/'PREFIX/midnight.end').read_bytes()
 assert not list(d.glob('event33.txt')) and not list(d.glob('rollback*.txt'))
 result.append(dict(optimization=opt,seconds=run['seconds'],commits=63,head_attempts=63,head_refusals=0,rank1_active_iterations=81,rank1_active_heads=28,first_active_attempt=36,first_active_begin_t1900=a[35][2],newton_iterations=269,newton_iteration_range=[min(v[7] for v in a),max(v[7] for v in a)],extra_line_search_trials=sum(v[24]-v[21] for v in a),max_end_residual=max(v[18] for v in a),max_absolute_sum_residual=max(abs(v[17]) for v in a),original_prefix_budget_rows_exact=35,first_active_commit_and_jacobian_exact_to_isolated_G1=True,end_t1900=b[-1][0],accepted_used_dt_days=.002,interval_days=.126,flux_reduced_commits=0,max_step_inventory_error_cm=max(abs(v[9]) for v in iv),max_step_inventory_limit_fraction=max(abs(v[9])/(v[3]*1e-5) for v in iv),max_domain_error_cm=max(abs(e) for v in iv for e in v[13:]),segment_stock_change_cm=stock,segment_external_cm=external,segment_inventory_error_cm=error,segment_integrated_residual_envelope_cm=tolerance,max_rank1_linear_residual=max(v[16] for v in j),min_active_rank1_denominator=min(abs(v[14]) for v in j if v[2]==1),native_source_sha256=sha(d/'own.end'),genuine_active_refusal=False,active_rollback_direct_qualification=False))
for p in (R/'data/O0/TRAJ').glob('*.txt'):
 if p.name in ['cost_trace.txt','attempt_trace.txt']:continue
 assert p.read_bytes()==(R/'data/O2/TRAJ'/p.name).read_bytes(),p.name
assert [v[:-1] for v in rows(R/'data/O0/TRAJ/attempt_trace.txt')]==[v[:-1] for v in rows(R/'data/O2/TRAJ/attempt_trace.txt')]
# Explicitly prove only diagnostics changed around the frozen arithmetic.
s=(P/'head_diag.f90').read_text().replace('use DIAG19,only:nvec,njac,nrate,nderiv,nback,nfresh,outcome,target,attempts,iter_index,node_u,op_u','use DIAG19,only:nvec,njac,nrate,nderiv,nback,nfresh,outcome,target,attempts,iter_index,node_u,op_u,detail33').replace('if(.not.target) return','if(.not.detail33) return').replace('if(target) active=.true.','if(detail33) active=.true.')
assert s==(R/'head_diag.f90').read_text()
s=(P/'jac_update.f90').read_text().replace('use DIAG19,only:attempts,iter_index','use DIAG19,only:attempts,iter_index,active_in_attempt,active_total').replace('if(meta(1)==1d0) then\n call tridag','if(meta(1)==1d0) then\n active_in_attempt=active_in_attempt+1;active_total=active_total+1\n call tridag').replace('flush(trace_u)','if(mod(iter_index,16)==0) flush(trace_u)')
assert s==(R/'jac_update.f90').read_text()
s=(P/'macrorate_node.f90').read_text().replace('point_delta\n','point_delta,detail33\n',1).replace('integer,intent(in)::stage\n      real(8)::outfac','integer,intent(in)::stage\n      real(8)::outfac\n      if(.not.detail33) return').replace('use DIAG19,only:target,attempts,iter_index,nvec,raw_u','use DIAG19,only:target,attempts,iter_index,nvec,raw_u,detail33').replace('if(target.and.ic==52) then','if(detail33.and.ic==52) then')
assert s==(R/'macrorate_node.f90').read_text()
old=(P/'soilwater_native.f90').read_text();new=(R/'soilwater_native.f90').read_text()
assert old[old.index('   contains'):old.index('subroutine prefix14_start()')]==new[new.index('   contains'):new.index('subroutine prefix14_start()')]
assert old[old.index('subroutine day11_boundary()'):]==new[new.index('subroutine day11_boundary()'):]
changed={'diag_state.f90','head_diag.f90','jac_update.f90','macrorate_node.f90','soilwater_native.f90'}
for p in P.glob('*.f90'):
 if p.name not in changed:assert p.read_bytes()==(R/p.name).read_bytes()
patch=''
for p in P.glob('*.f90'):
 if p.read_bytes()!=(R/p.name).read_bytes():patch+=''.join(difflib.unified_diff(p.read_text().splitlines(True),(R/p.name).read_text().splitlines(True),fromfile='OUTSIDE32/'+p.name,tofile='TRAJECTORY33/'+p.name))
assert patch==(R/'diagnostic_driver.patch').read_text()
assert not (R/'EVENT_SELECTION.json').exists() and not list((R/'data').glob('*/DIRECT*')) and not list((R/'data').glob('*/TRIAL*'))
# Existing original route: compare observation threshold, not identical trajectory/endstate/speed.
ob=rows(R.parent/'swap431-macro-b1-next18/data/O2/RESUME/step_budget.txt');oa=rows(R.parent/'swap431-macro-b1-diag19/data/O2/RESUME/attempt_trace.txt')
k=next(n for n,v in enumerate(ob,1) if v[0]>=35797.125);sub=[v for v in oa if v[1]<=k]
assert k==383 and len(sub)==816 and sum(v[8]==4 for v in sub)==433
comparison=dict(stop_threshold_t1900=35797.125,original_first_crossing_t1900=ob[k-1][0],original_commits=k,original_head_attempts=len(sub),original_head_refusals=sum(v[8]==4 for v in sub),original_reduced_flux_commits=sum(v[16]!=1 for v in ob[:k]),same_endpoint_or_physical_trajectory=False,performance_speedup_claim=False)
q=dict(work_unit='SWAP431-MACRO-B1-TRAJECTORY33',decision='PASS_BOUNDED_OWN_CANDIDATE_TRAJECTORY_WITH_ACTIVE_REFUSAL_EXCLUSION',model_routes=2,all_uncensored=True,hard_timeout_seconds=20,stop_reason='first committed t1900>=35797.125; original dt not shortened',O0_O2_non_timing_byte_exact=True,numerical_arithmetic_guards_and_budget_rules_unchanged=True,continuous_candidate_from_original_native_boundary=True,original_V1_prefix_trajectory=False,active_refusal_rollback_direct_qualification=False,conditional_replay_implementation='Persisted but not exercised or qualified because no refusal occurred',full_period_balance_or_native_restart_or_general_solver_admission=False,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',official_promotion=False,results=result,existing_original_threshold_comparison=comparison)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q,indent=2))
