"""Read-only original357 contact-repair, jump, convergence and water-inventory qualification."""
from pathlib import Path
import json,math,hashlib,csv
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-contract42';W=Path('C:/Users/Veldh012/swap431-repair43-work/native')
def rows(p):return [list(map(float,s.split())) for s in p.read_text().splitlines()]
def f(p):return {s.split()[0].lower():list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for name in ['jac37_update.f90','jac_update.f90','head_diag.f90','macropore_native.f90','probe_state.f90','calcgwl_probe.f90','native_state.f90','ledger_state.f90','integral_canopy.f90','swap_native.f90','swapoutput_native.f90','meteo_native.f90']:
 assert (R/name).read_bytes()==(P/name).read_bytes(),name
m=(R/'macrorate_node.f90').read_text();p=(P/'macrorate_node.f90').read_text()
assert m[:m.index('      subroutine ABSORPTION(')]==p[:p.index('      subroutine ABSORPTION(')]
assert m[m.index('      subroutine RAPIDDRAIN('):]==p[p.index('      subroutine RAPIDDRAIN('):]
assert (R/'guard41_observer.f90').read_text()==(P/'guard41_observer.f90').read_text().replace('\nif(iter_index==10) call contract42_probe()','')
result=[];pairrows=[];frozen=[]
for opt in ['O0','O2']:
 d=R/'data'/opt/'TRAJ';old=P/'data'/opt/'TRAJ';a=rows(d/'attempt_trace.txt');oa=rows(old/'attempt_trace.txt');b=rows(d/'step_budget.txt');iv=rows(d/'inventory_trace.txt');j=rows(d/'jac37_trace.txt');j24=rows(d/'jac24_trace.txt')
 assert len(a)==len(b)==len(iv)==357
 assert [x[:-1] for x in a[:356]]==[x[:-1] for x in oa[:356]]
 assert b[:356]==rows(old/'step_budget.txt') and iv[:356]==rows(old/'inventory_trace.txt')
 assert [x for x in j if x[0]<=356]==[x for x in rows(old/'jac37_trace.txt') if x[0]<=356]
 assert [x for x in j24 if x[0]<=356]==[x for x in rows(old/'jac24_trace.txt') if x[0]<=356]
 for name,after in [('origin','after_probe'),('context_origin','context_after_probe'),('ledger_origin','ledger_after_probe')]:
  assert (d/(name+'.txt')).read_bytes()==(old/(name+'.txt')).read_bytes()==(d/(after+'.txt')).read_bytes(),name
 for name in ['host43_before.bin','host43_cache_before.bin']:
  assert (d/name).read_bytes()==(d/name.replace('before','after')).read_bytes()
 for copied,source in [('frozen42_base.bin','probe42_base.bin'),('frozen42_cache.bin','probe42_cache_base.bin')]:
  assert (d/copied).read_bytes()==(old/source).read_bytes()==(d/source).read_bytes()
  frozen.append(dict(optimization=opt,file=copied,sha256=sha(d/copied),parent_source=source))
 pts=rows(d/'probe42_points.txt');op=rows(old/'probe42_points.txt');dom=rows(d/'probe42_domains.txt');rest=rows(d/'probe42_restore.txt');ct=rows(d/'contact43_trace.txt')
 assert len(pts)==9 and len(dom)==45 and len(rest)==10 and all(x[1:]==[20347880,3247712,1,1,1] for x in rest)
 assert pts[0][1:]==pts[-1][1:]
 for i,oi in [(0,0),(1,1),(3,3),(5,5),(8,7)]:assert pts[i][1:]==op[oi][1:],i
 assert pts[7][5]==-60 and pts[7][6]==47
 for name in ['probe42_base.bin','probe42_cache_base.bin']:
  assert (d/name).read_bytes()==(d/name.replace('base','restored')).read_bytes()
 for x in pts:
  assert x[3]<0 and x[15]==1 and all(z==0 for z in x[27:])
  assert x[25]>.0565 and x[24]>0 and abs(math.fsum(x[17:22])-math.fsum(x[22:27]))<1e-15
 for x in dom:assert x[9]==x[17]==1
 probe_ct=[x for x in ct if x[4]==1];normal_ct=[x for x in ct if x[4]==0]
 assert len(probe_ct)==18 and len(normal_ct)==24 and all(x[6] in [3,4] and x[7]==47 for x in ct)
 for x in probe_ct:
  point=pts[int(x[5])-1];domid=int(x[6]);dm=dom[(int(point[0])-1)*5+domid-1]
  wet_top=min(point[13]+.5*point[14],dm[25]);wet_len=max(0,wet_top-(point[13]-.5*point[14]))
  overlap=max(0,wet_top-max(point[13]-.5*point[14],point[5]));ratio=min(1,max(0,overlap/wet_len))
  expected=ratio if point[6]==47 else 1
  assert abs(x[11]-expected)<1e-14
  if domid==3:
   assert x[16]==1 and x[13]==0 and abs(x[17]-wet_len/point[14])<1e-14
   assert abs(x[15]/point[16]-point[24])<1e-15
  else:
   assert x[16]==0 and x[17]==1
   expected_rate=dm[31]*expected
   assert abs(point[25]-expected_rate)<1e-15 and abs(x[15]/point[16]-expected_rate)<1e-15
 assert all(x[11]<=1 and x[11]>0 for x in ct)
 for level,eps in enumerate([1e-4,1e-6,1e-8]):
  lo,hi=pts[1+2*level:3+2*level];gap=lo[25]-hi[25];oldgap=op[1+2*level][25]-op[2+2*level][25]
  assert lo[5]==-60-eps and hi[5]==-60+eps and 0<gap<5e-6*(eps/1e-4)
  assert abs(pts[7][25]-hi[25])<4e-6*(eps/1e-4) and abs(pts[7][25]-lo[25])<2e-6*(eps/1e-4)
  pairrows.append(dict(optimization=opt,GWL_offset_cm=eps,old_D4_rate_gap=oldgap,repaired_D4_rate_below=lo[25],repaired_D4_rate_above=hi[25],repaired_D4_gap=gap,repaired_D3_gap=lo[24]-hi[24],exact_boundary_D4_rate=pts[7][25]))
 last=a[-1];assert last[2:4]==oa[-1][2:4] and last[4:7]==[0,0,1] and last[7:17]==[5,0,0,0,0,0,0,0,0,0]
 assert last[20:26]==[7,5,7,5,5,1] and last[18]<1e-6 and abs(last[17])<1e-5
 assert len([x for x in j if x[0]==357])==5 and all(x[2]==-3 and x[16]==1 for x in j if x[0]==357)
 assert all(x[2]==0 for x in j24 if x[0]==357)
 assert 'TARGET_RETRY_HOST_COMMITTED' in (d/'outcome.txt').read_text() and not (d/'rollback.txt').exists()
 aa=f(d/'origin.txt');zz=f(d/'committed.txt');ca=f(d/'context_origin.txt');cz=f(d/'context_committed.txt');L0=f(d/'ledger_origin.txt');L1=f(d/'ledger_committed.txt');v=b[-1];dt=v[1]
 assert dt==last[3] and zz['controls'][0]==v[0]==35797.488000008023 and zz['controls'][1]==dt
 assert aa['fraction']==zz['fraction'] and aa['dz']==zz['dz']
 stock=math.fsum((y-x)*dz*fr for x,y,dz,fr in zip(aa['theta'],zz['theta'],aa['dz'],aa['fraction']))+math.fsum(y-x for x,y in zip(aa['macro_domain'],zz['macro_domain']))+zz['pond'][0]-aa['pond'][0]+cz['sicact'][0]-ca['sicact'][0]
 ext=dt*(v[2]+v[3]+v[4]-v[5]-v[6]-v[7]-v[8]+v[9]-v[10]+v[11]-v[12])-v[13];error=stock-ext;assert abs(error)<dt*1e-5 and abs(error-dt*last[17])<1e-15
 domains=[]
 for k in range(5):
  de=zz['macro_domain'][k]-aa['macro_domain'][k]-dt*(v[17+k]+v[22+k]-v[27+k]-(v[12] if k==0 else 0));assert abs(de)<1e-13;domains.append(de)
 for key,col in [('cgrai',2),('cgird',3),('crunon',4),('caintc',5),('cepd',6),('cevap',7),('cqrot',8),('cqbot',9),('cqdra',10),('cqssdi',11),('cqmpoutdrrap',12)]:assert abs(L1[key][0]-L0[key][0]-dt*v[col])<1e-12
 assert (d/'ledger_returned.txt').read_bytes()==(d/'ledger_origin.txt').read_bytes()
 assert all(abs(x[9])<x[3]*1e-5 and max(abs(y) for y in x[13:])<1e-13 for x in iv)
 run=json.loads((R/(opt+'_TRAJ_RUN.json')).read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20
 ident=json.loads((R/(opt+'_IDENTITY.json')).read_text());assert all(sha(R/name)==h for name,h in ident['sources'].items()) and sha(W/opt/'native09.exe')==ident['exe_sha256']
 result.append(dict(optimization=opt,seconds=run['seconds'],original_prefix_commits_and_attempts_exact=356,original_target_context_exact=True,probe_outer_host_and_cache_restore_byte_exact=True,probe_selected_scope_and_cache_and_flags_restores=10,actual_extra_frozen_provider_calls=9,old_D4_gap_at_1e_minus8=op[5][25]-op[6][25],repaired_D4_gap_at_1e_minus8=pts[5][25]-pts[6][25],exact_boundary_D4_rate=pts[7][25],target_used_dt=dt,target_iterations=5,target_vector_calls=7,target_extra_backtracks=0,target_fresh_certifications=1,target_max_residual=last[18],target_sum_residual=last[17],flux_factor=1,old_fixed_geometry_Jacobian_correction_inactive=True,new_contact_geometry_Jacobian_outerproduct_added=False,host_commit_t1900=v[0],next_dt=zz['controls'][1],target_independent_inventory_error_cm=error,target_inventory_limit_cm=dt*1e-5,target_domain_balance_errors_cm=domains,ledger_increments_verified=True,real_refusal_occurred=False,new_repair_active_refusal_rollback_direct_qualified=False))
for p in (R/'data/O0/TRAJ').glob('*.txt'):
 if p.name not in ['cost_trace.txt','attempt_trace.txt']:assert p.read_bytes()==(R/'data/O2/TRAJ'/p.name).read_bytes(),p.name
assert [x[:-1] for x in rows(R/'data/O0/TRAJ/attempt_trace.txt')]==[x[:-1] for x in rows(R/'data/O2/TRAJ/attempt_trace.txt')]
for p in (R/'data/O0/TRAJ').glob('*.bin'):assert p.read_bytes()==(R/'data/O2/TRAJ'/p.name).read_bytes(),p.name
with (R/'PAIRED_LIMITS.csv').open('w',newline='',encoding='utf-8') as fp:
 w=csv.DictWriter(fp,fieldnames=list(pairrows[0]));w.writeheader();w.writerows(pairrows)
(R/'FROZEN_INPUTS.json').write_text(json.dumps(frozen,indent=2)+'\n',encoding='utf-8')
q=dict(work_unit='SWAP431-MACRO-B1-REPAIR43',decision='PASS_MINIMAL_CONTACT_REPAIR_JUMP_AND_ORIGINAL357_CONVERGENCE_HOSTCOMMIT_O0_O2',source_checkpoint='4b0d9752f',model_routes=2,all_uncensored=True,hard_timeout_seconds=20,O0_O2_non_timing_byte_exact=True,physical_change='Only authorized unsaturated/water-wetted GWLcell contact repair; original mechanisms/max/stock/perched/SATFLOW rules preserved',solver_tolerance_MAXIT_dt_reduction_rule_changes=False,complete_corrected_trajectory_period_restart_general_admission=False,new_repair_real_refusal_rollback_direct_qualified=False,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',official_promotion=False,results=result)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8');print(json.dumps(q,indent=2))
