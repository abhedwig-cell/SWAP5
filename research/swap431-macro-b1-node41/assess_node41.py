"""Read-only replay identity, node47 progress/operator decomposition, and eligibility diagnosis."""
from pathlib import Path
import json,math,hashlib,collections,csv
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-period40';W=Path('C:/Users/Veldh012/swap431-node41-work/native')
def rows(p):return [list(map(float,s.split())) for s in p.read_text().splitlines()]
def f(p):return {s.split()[0].lower():list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
# Reconstruct exact observer-only source changes, never accepting a numerical formula change.
s=(P/'head_diag.f90').read_text();i=s.index('subroutine node20_log(stage)');e=s.index('subroutine node35_log(stage)',i);part=s[i:e].replace('52','47').replace('51:53','46:48').replace('kmean(53)','kmean(48)').replace('grad(53)','grad(48)');assert (s[:i]+part+s[e:]).replace('do ic=50,57','do ic=44,57')==(R/'head_diag.f90').read_text()
s=(P/'jac37_update.f90').read_text().replace('use DIAG19,only:attempts,iter_index,active_in_attempt,active_total','use DIAG19,only:attempts,iter_index,active_in_attempt,active_total,detail33',1).replace('call jac37_terms(n,uu,vv,bl,bd,meta,handled)','call jac37_terms(n,uu,vv,bl,bd,meta,handled)\nif(detail33) call guard41_observe(meta)',1);assert s==(R/'jac37_update.f90').read_text()
for p in P.glob('*.f90'):
 if p.name not in ['head_diag.f90','jac37_update.f90','soilwater_native.f90']:assert p.read_bytes()==(R/p.name).read_bytes()
assert 'call MACRORATE(' not in (R/'guard41_observer.f90').read_text()
result=[]
for opt in ['O0','O2']:
 d=R/'data'/opt/'TRAJ';old=P/'data'/opt/'TRAJ';a=rows(d/'attempt_trace.txt');oa=rows(old/'attempt_trace.txt');b=rows(d/'step_budget.txt');iv=rows(d/'inventory_trace.txt');j=rows(d/'jac37_trace.txt');j24=rows(d/'jac24_trace.txt');g=rows(d/'guard41_trace.txt');heads=rows(d/'guard41_heads.txt');domains=rows(d/'guard41_domains.txt');ni=rows(d/'node_iterations.txt');op=rows(d/'operator_nodes.txt');lim=rows(d/'domain3_limit.txt')
 run=json.loads((R/(opt+'_TRAJ_RUN.json')).read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20
 assert 'ORIGINAL357_REAL_UNSCALED_REFUSAL' in (d/'outcome.txt').read_text()
 assert len(a)==357 and len(b)==len(iv)==356 and [x[:-1] for x in a]==[x[:-1] for x in oa[:357]]
 assert b==rows(old/'step_budget.txt')[:356] and iv==rows(old/'inventory_trace.txt')[:356]
 assert j==[x for x in rows(old/'jac37_trace.txt') if x[0]<=357] and j24==[x for x in rows(old/'jac24_trace.txt') if x[0]<=357]
 last=a[-1];assert last[2:4]==[35797.487000006880,.001000001146167051] and last[4:7]==[0,0,1] and last[7:17]==[31,4,1,0,0,1,1,0,0,0] and last[19]==47 and last[25]==0
 assert last[20:26]==[105,30,105,30,104,0] and last[18]==.02571625908888784
 assert all(x[2]==-3 and x[16]==1 for x in j if x[0]==357) and all(x[2]==0 for x in j24 if x[0]==357)
 assert len(g)==len(heads)==30 and len(domains)==150 and all(x[2:4]==[-3,1] and x[24]==1 for x in g)
 assert all(x[20:22]==[0,0] and x[23]==0 and x[18]==47 and x[14]==x[19] for x in g)
 assert collections.Counter(tuple(x[10:13]) for x in g)=={(48.,48.,48.):17,(47.,47.,-1.):13}
 ini=f(d/'origin.txt');rb=f(d/'rollback.txt');dz=ini['dz'];z=[-math.fsum(dz[:k+1])+.5*dz[k] for k in range(112)];assert -math.fsum(dz[:47])==-60
 for x,hh in zip(g,heads):
  h=hh[2:];assert len(h)==112 and h[46]<0<h[47] and h[49]==x[15] and h[50]==x[16]
  gg=z[47]+h[47]/(h[47]-h[46])*(z[46]-z[47]);assert abs(gg-x[14])<1e-13
 assert all(x[10]==x[18]==1 for x in domains) # Every Jacobian-state inflow/outflow factor, all five domains.
 d2=[x for x in domains if x[2]==2];assert all(x[12]>0 and x[7]>x[11] for x in d2) # Lateral inflow alone already violates the selected top-only contract.
 ends=[x for x in ni if x[2]==4];trials=[x for x in ni if x[2]==3];start=next(x for x in ni if x[2]==0);assert len(ends)==30 and len(trials)==104
 assert all(x[19:21]==[1,1] and x[15]==abs(x[13]) for x in ends)
 assert sum(x[13]*y[13]<0 for x,y in zip(ends,ends[1:]))==19
 assert sum(x[16]>p[16] for p,x in zip([start]+ends[:-1],ends))==9
 assert max(x[3] for x in trials)==4 and sum(x[3]==5 for x in ends)==9
 limits={(x[1],x[2]):x for x in lim if x[4]==1 and x[5]==3};ops=[x for x in op if x[6]==47];assert len(limits)==len(ops)==105 and len(op)==14*105
 assert all(abs(x[10]-math.fsum(x[11:18]))<1e-12 and abs(x[17]+math.fsum(x[19:24]))<1e-12 for x in op)
 branch={}
 for cp,count in [(47,56),(48,49)]:
  vals=[x for x in ops if limits[(x[1],x[2])][10]==cp];assert len(vals)==count
  assert all((limits[(x[1],x[2])][9]>=-60) if cp==47 else (limits[(x[1],x[2])][9]<-60) for x in vals)
  assert all(all(y==0 for y in x[29:44]) for x in vals) # No SAT outflow or any incoming at node47.
  assert all(x[19]==x[20]==x[23]==0 and x[21]==x[26] and x[22]==x[27] for x in vals)
  if cp==47:assert all(x[17]==0 for x in vals)
  else:assert all(-x[17]>.0566 and x[27]>.0565 for x in vals)
  branch[str(cp)]=dict(evaluations=count,unsaturated_macro_out_rate_range=[min(-x[17] for x in vals),max(-x[17] for x in vals)],domain3_rate_range=[min(x[26] for x in vals),max(x[26] for x in vals)],domain4_rate_range=[min(x[27] for x in vals),max(x[27] for x in vals)])
 progress=[]
 for e in ends:
  tr=[x for x in trials if x[1]==e[1]];oo=[x for x in ops if x[1]==e[1]][-1];ll=limits[(oo[1],oo[2])]
  progress.append(dict(iteration=int(e[1]),actual_line_trials=len(tr),last_tested_factor=tr[-1][7],post_loop_itry=int(e[3]),post_loop_factor=e[7],line_search_exhausted=bool(e[3]>4),h47=e[9],F47=e[13],Fmax=e[15],sum_residual=e[14],objective=e[16],GWL=ll[9],native_sat_cell=int(ll[10]),matrix_storage=oo[11],upper_vertical=oo[15],lower_vertical=oo[16],minus_macro_exchange=oo[17],domain3_UNSAT_out=oo[26],domain4_UNSAT_out=oo[27],node47_balance_failure=int(e[20]),node47_head_failure=int(e[21])))
 with (R/(opt+'_ITERATION_PROGRESS.csv')).open('w',newline='',encoding='utf-8') as fp:
  w=csv.DictWriter(fp,fieldnames=list(progress[0]));w.writeheader();w.writerows(progress)
 assert (d/'ledger_origin.txt').read_bytes()==(d/'ledger_returned.txt').read_bytes()==(d/'ledger_rollback.txt').read_bytes()==(d/'ledger_final.txt').read_bytes()
 for key in ['h','hm1','theta','thetm1','pond','macro_total','macro_sat','macro_domain','macro_compartment','macro_volume','macro_bottom','clock','wet_wall','wet_wall_old']:assert ini[key]==rb[key],key
 assert all(abs(x[9])<x[3]*1e-5 for x in iv)
 identity=json.loads((R/(opt+'_IDENTITY.json')).read_text());assert all(sha(R/name)==hv for name,hv in identity['sources'].items()) and sha(W/opt/'native09.exe')==identity['exe_sha256']
 assert sha(d/'own.end')=='21bd728c9983d6a0d4e82d6b2fd12729dc02284277a5dab5d296d8edc1dcbf16'
 oo=ops[-1]
 result.append(dict(optimization=opt,seconds=run['seconds'],original_prefix_commits_exact=356,original_attempts_including_selected_exact=357,selected_iterations=30,vector_and_provider_calls=105,line_search_trials=104,extra_line_search_trials=74,line_search_exhaustions=9,node47_residual_sign_changes=19,initial_Fmax=start[15],minimum_iteration_end_Fmax=min(x[15] for x in ends),final_Fmax=last[18],final_sum_residual=last[17],final_node=47,final_fresh_certifications=0,no_provisional_convergence=True,guard_reason=-3,provider_stamps_all_valid=True,actual_head_interpolation=[47,48],native_zone_states={'48_48_48':17,'47_47_minus1':13},fixed_zone_condition_passes=0,fixed_head_condition_passes=0,fixed_interpolation_condition_passes=0,PeGWL_absent_sentinel999_iterations=sum(x[13]==999 for x in g),h50_range=[min(x[15] for x in g),max(x[15] for x in g)],h51_range=[min(x[16] for x in g),max(x[16] for x in g)],all_Jacobian_domain_in_out_factors_one=True,domain2_lateral_inflow_nonzero_all_Jacobians=True,domain2_other_positive_flow_Jacobians={key:sum(x[col]>0 for x in d2) for key,col in [('internal_in',13),('matrix_in',14),('UNSAT_out',16)]},cell47_bottom_cm=-60,provider_branch=branch,final_node47_operator=dict(storage=oo[11],sink=oo[12],minus_source=oo[13],root=oo[14],upper=oo[15],lower=oo[16],minus_macro=oo[17],residual=oo[10],domain3_unsat_out=oo[26],domain4_unsat_out=oo[27]),max_operator_decomposition_error=max(abs(x[10]-math.fsum(x[11:18])) for x in op),physical_saved_water_inventory_restored=True,ledger_unchanged_no_target_commit=True,immediate_full_native_snapshot_identity=False))
for p in (R/'data/O0/TRAJ').glob('*.txt'):
 if p.name in ['cost_trace.txt','attempt_trace.txt']:continue
 assert p.read_bytes()==(R/'data/O2/TRAJ'/p.name).read_bytes(),p.name
assert [x[:-1] for x in rows(R/'data/O0/TRAJ/attempt_trace.txt')]==[x[:-1] for x in rows(R/'data/O2/TRAJ/attempt_trace.txt')]
assert (R/'O0_ITERATION_PROGRESS.csv').read_bytes()==(R/'O2_ITERATION_PROGRESS.csv').read_bytes()
q=dict(work_unit='SWAP431-MACRO-B1-NODE41',decision='PASS_DIAGNOSIS_ORIGINAL357_NODE47_PROGRESS_AND_GUARD_O0_O2',source_checkpoint='28e70e7ee',model_routes=2,all_uncensored=True,hard_timeout_seconds=20,O0_O2_non_timing_byte_exact=True,no_extra_provider_evaluations_or_FD_probes=True,physics_numerical_terms_guards_tolerance_MAXIT_dt_reduction_rules_unchanged=True,finding='Iterationchatter across originalABSORPTION discretecell exclusion at GWL=-60. Newcorrection fixedgeometryoutofscope; allJacstockfactors1; notstalecache. Observedbranchjump localized; not yetproof ofphysicalcontractdefect or authorizedguardextension.',full_period_BAL_new_restart_general_admission=False,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',official_promotion=False,results=result)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8');print(json.dumps(q,indent=2))
