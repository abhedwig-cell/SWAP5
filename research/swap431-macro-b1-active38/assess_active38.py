"""Read-only finite selection and active refusal/rollback/direct-retry qualification."""
from pathlib import Path
import json,math,hashlib,collections
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-correction37';B=R.parent/'swap431-macro-b1-period34';W=Path('C:/Users/Veldh012/swap431-active38-work')
def rows(p):return [list(map(float,s.split())) for s in p.read_text().splitlines()]
def f(p):return {s.split()[0].lower():list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
source_changed=[p.name for p in R.glob('*.f90') if p.read_bytes()!=(P/p.name).read_bytes()]
assert source_changed==['soilwater_native.f90'],source_changed
selection=[];results=[];runs=[]
for opt in ['O0','O2']:
 old=rows(B/'data'/opt/'TRAJ/attempt_trace.txt');oldbudget=(B/'data'/opt/'TRAJ/step_budget.txt').read_text().splitlines()
 for target in [296,297]:
  d=R/'data'/opt/('TRIAL_'+str(target));a=rows(d/'attempt_trace.txt');j=rows(d/'jac37_trace.txt')
  assert [v[:-1] for v in a[:target-1]]==[v[:-1] for v in old[:target-1]]
  assert (d/'step_budget.txt').read_text().splitlines()[:294]==oldbudget[:294]
  assert len(j)>0 and all(v[2]==1 and v[16]==1 and v[27]<1e-12 and abs(v[24])>1e-12 for v in j)
  assert (d/'cal37_before.bin').read_bytes()==(d/'cal37_after.bin').read_bytes()
  q=a[target-1];assert q[2:4]==old[target-1][2:4] and q[4:7]==[0,0,1]
  if target==296:
   assert len(a)==296 and q[7]==3 and q[9:17]==[0]*8 and q[25]==1
   assert len(j)==3 and all(v[0]==296 for v in j) and not (d/'rollback_1.txt').exists()
  else:
   assert len(a)==298 and q[7:17]==[31,4,1,0,0,1,1,0,0,0] and q[25]==0
   assert len([v for v in j if v[0]==297])==30
   assert a[-1][7:17]==[10,0,0,0,0,0,0,0,0,0] and a[-1][25]==1
  selection.append(dict(optimization=opt,attempt=target,real_refusal=bool(q[9]),active_corrected_iterations=sum(v[0]==target for v in j),max_residual=q[18],sum_residual=q[17]))
 t=R/'data'/opt/'TRIAL_297';d=R/'data'/opt/'DIRECT_297';ta=rows(t/'attempt_trace.txt');da=rows(d/'attempt_trace.txt');large,small=ta[-2:]
 assert len(da)==297 and [v[:-1] for v in da[:296]]==[v[:-1] for v in ta[:296]]
 assert small[2:-1]==da[-1][2:-1] and small[3]==large[3]/3 and small[6]==large[6]==1
 assert small[18]<1e-6 and abs(small[17])<1e-5
 for name in ['origin','context_origin','ledger_origin','accepted_return','context_accepted_return','ledger_accepted_return','committed','context_committed','ledger_committed','step_budget']:
  assert (t/(name+'.txt')).read_bytes()==(d/(name+'.txt')).read_bytes(),name
 assert (t/'solver_2.txt').read_bytes()==(d/'solver_1.txt').read_bytes()
 tj=[x[1:] for x in rows(t/'jac37_trace.txt') if x[0]==298];dj=[x[1:] for x in rows(d/'jac37_trace.txt')]
 assert tj==dj and len(tj)==10
 oo=f(t/'origin.txt');rb=f(t/'rollback_1.txt');sb=f(t/'begin_2.txt');db=f(d/'begin_1.txt')
 scratch={'macro_exchange','macro_rapid','matrix_exchange','boundary_rates','sorptivity'}
 assert {k for k in oo if oo[k]!=rb[k]}==scratch|{'controls'}
 assert oo['controls'][:7]==rb['controls'][:7] and rb['controls'][7]==1
 assert {k for k in sb if sb[k]!=db[k]}==scratch
 co=f(t/'context_origin.txt');cr=f(t/'context_rollback_1.txt');cb=f(t/'context_begin_2.txt');cd=f(d/'context_begin_1.txt')
 assert {k for k in co if co[k]!=cr[k]}=={'sorpdmcp','subsidcp'}
 assert {k for k in cb if cb[k]!=cd[k]}=={'sorpdmcp','subsidcp'}
 for name in ['ledger_begin_1','ledger_returned_1','ledger_rollback_1','ledger_begin_2']:
  assert (t/(name+'.txt')).read_bytes()==(t/'ledger_origin.txt').read_bytes()
 all_inv=[]
 for mode,dd,beg in [('TRIAL',t,'begin_2'),('DIRECT',d,'begin_1')]:
  a=f(dd/(beg+'.txt'));b=f(dd/'committed.txt');ca=f(dd/('context_'+beg+'.txt'));ce=f(dd/'context_committed.txt');v=rows(dd/'step_budget.txt')[-1];dt=v[1]
  assert dt==small[3] and b['controls'][0]==v[0] and abs(v[0]-a['controls'][0]-dt)<5e-12
  assert rows(dd/'attempt_trace.txt')[-1][25]==1
  stock=math.fsum((y-x)*dz*fr for x,y,dz,fr in zip(a['theta'],b['theta'],a['dz'],a['fraction']))+math.fsum(y-x for x,y in zip(a['macro_domain'],b['macro_domain']))+b['pond'][0]-a['pond'][0]+ce['sicact'][0]-ca['sicact'][0]
  ext=dt*(v[2]+v[3]+v[4]-v[5]-v[6]-v[7]-v[8]+v[9]-v[10]+v[11]-v[12])-v[13];err=stock-ext
  assert abs(err)<dt*1e-5 and abs(err-dt*small[17])<1e-15
  dom=[]
  for k in range(5):
   de=b['macro_domain'][k]-a['macro_domain'][k]-dt*(v[17+k]+v[22+k]-v[27+k]-(v[12] if k==0 else 0));assert abs(de)<1e-13;dom.append(de)
  L0=f(dd/('ledger_'+beg+'.txt'));L1=f(dd/'ledger_committed.txt')
  for key,col in [('cgrai',2),('cgird',3),('crunon',4),('caintc',5),('cepd',6),('cevap',7),('cqrot',8),('cqbot',9),('cqdra',10),('cqssdi',11),('cqmpoutdrrap',12)]:assert abs(L1[key][0]-L0[key][0]-dt*v[col])<1e-12
  iv=rows(dd/'inventory_trace.txt');assert all(abs(w[9])<w[3]*1e-5 and max(abs(k) for k in w[13:])<1e-13 for w in iv)
  all_inv.append(dict(mode=mode,inventory_error_cm=err,inventory_limit_cm=dt*1e-5,domain_errors_cm=dom,ledger_increments_verified=True))
 failedj=[x for x in rows(t/'jac37_trace.txt') if x[0]==297]
 results.append(dict(optimization=opt,original_prefix_attempts_exact=296,original_prefix_commits_exact=294,refused_attempt=297,large_dt_days=large[3],real_unscaled_refusal=True,MAXIT_30_iterations=True,active_correction_iterations=len(failedj),stock_rank_counts=dict(collections.Counter(int(x[3]) for x in failedj)),large_max_residual=large[18],large_sum_residual=large[17],rollback_physical_inventory_and_saved_state_restored=True,rollback_scratch_differences=sorted(scratch),rollback_native_dump_differences=['sorpdmcp','subsidcp'],immediate_full_snapshot_byte_identity=False,ledger_unchanged_until_commit=True,small_dt_days=small[3],small_iterations=int(small[7]),small_fresh_V1=True,small_max_residual=small[18],small_sum_residual=small[17],direct_and_postrollback_solver_context_ledger_commit_budget_byte_exact=True,direct_and_postrollback_corrected_Jacobians_exact=True,committed_t1900=f(t/'committed.txt')['controls'][0],inventory=all_inv,max_corrected_linear_residual=max(x[27] for x in rows(t/'jac37_trace.txt')),minimum_Woodbury_determinant=min(abs(x[24]) for x in rows(t/'jac37_trace.txt'))))
 for profile in ['TRIAL_296','TRIAL_297','DIRECT_297']:
  run=json.loads((R/(opt+'_'+profile+'_RUN.json')).read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20
  runs.append(dict(optimization=opt,profile=profile,seconds=run['seconds']))
 identity=json.loads((R/(opt+'_IDENTITY.json')).read_text());assert all(sha(R/name)==hv for name,hv in identity['sources'].items()) and sha(W/'native'/opt/'native09.exe')==identity['exe_sha256']
for profile in ['TRIAL_296','TRIAL_297','DIRECT_297']:
 d0=R/'data/O0'/profile;d2=R/'data/O2'/profile
 for p in d0.glob('*.txt'):
  if p.name in ['attempt_trace.txt','cost_trace.txt']:continue
  assert p.read_bytes()==(d2/p.name).read_bytes(),(profile,p.name)
 assert [x[:-1] for x in rows(d0/'attempt_trace.txt')]==[x[:-1] for x in rows(d2/'attempt_trace.txt')]
 for name in ['cal37_before.bin','cal37_after.bin','domains36_point.bin']:assert (d0/name).read_bytes()==(d2/name).read_bytes()
assert not (R/'data/O0/TRIAL_298').exists() and not (R/'data/O2/TRIAL_298').exists()
q=dict(work_unit='SWAP431-MACRO-B1-ACTIVE38',decision='PASS_ORIGINAL297_ACTIVE_TRUE_REFUSAL_ROLLBACK_DIRECT_SMALL_RETRY_O0_O2',source_checkpoint='6f5f7142d',model_routes=6,hard_seconds_per_route=20,all_uncensored=True,selection_stopped_at_first_paired_witness=True,independent_target298_route_not_launched=True,O0_O2_non_timing_byte_exact=True,physics_and_numerical_policy_unchanged=True,full_trial_state_byte_restoration_claim=False,full_trajectory_period_restart_general_admission=False,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',official_promotion=False,selection=selection,results=results,runs=runs)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8')
print(json.dumps(q,indent=2))
