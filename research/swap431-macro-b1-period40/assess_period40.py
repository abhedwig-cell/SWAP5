"""Read-only qualification of the fixed full-period attempt and bounded partial evidence."""
from pathlib import Path
import json,math,hashlib,collections,difflib
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-trajectory39';W=Path('C:/Users/Veldh012/swap431-period40-work/native')
def rows(p):return [list(map(float,s.split())) for s in p.read_text().splitlines()]
def f(p):return {s.split()[0].lower():list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def body(p):return '\n'.join(s for s in p.read_text().splitlines() if not s.startswith('* Generated at:'))
source=(P/'soilwater_native.f90').read_text();strict=(R/'strict_source/soilwater_native.f90').read_text()
expected=source.replace('SCALED_REQUEST_BEFORE_SHORT_TARGET','SCALED_REQUEST_BEFORE_PERIOD_END').replace(" if(t1900>=35797.372d0) call finish33('BOUNDED_CORRECTED_TRAJECTORY')\n",'').replace(" if(budget_count>=512) call finish33('COMMIT_CAP_BEFORE_SHORT_TARGET')\n",'').replace('INTERNAL_BUDGET_BEFORE_SHORT_TARGET','INTERNAL_BUDGET_BEFORE_PERIOD_END')
assert strict==expected
for p in P.glob('*.f90'):
 if p.name!='soilwater_native.f90':assert p.read_bytes()==(R/p.name).read_bytes()==(R/'strict_source'/p.name).read_bytes()
patch=''.join(difflib.unified_diff(strict.splitlines(True),(R/'soilwater_native.f90').read_text().splitlines(True),fromfile='PERIOD40/strict_source/soilwater_native.f90',tofile='PERIOD40/soilwater_native.f90'))
assert patch==(R/'ORIGINAL_POLICY_OBSERVATION.patch').read_text()
results=[]
for opt in ['O0','O2']:
 for mode in ['TRAJ','TRAJ_POLICY']:
  policy=mode.endswith('POLICY');d=R/'data'/opt/mode;a=rows(d/'attempt_trace.txt');b=rows(d/'step_budget.txt');iv=rows(d/'inventory_trace.txt');j=rows(d/'jac37_trace.txt');j24=rows(d/'jac24_trace.txt');active=[v for v in j if v[2]==1];accepted=[x for x in a if x[8]==0];failures=[x for x in a if x[8]!=0]
  run=json.loads((R/(opt+'_'+mode+'_RUN.json')).read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20
  assert ('INTERNAL_BUDGET_BEFORE_PERIOD_END' if policy else 'SCALED_REQUEST_BEFORE_PERIOD_END') in (d/'outcome.txt').read_text()
  assert not (d/'period_final.txt').exists() and 'Period' not in (d/'result.bal').read_text() and (d/'result.bal').stat().st_size==195
  assert len(b)==len(iv)==len(accepted) and b[-1][0]<35798
  assert len(active)==252 and sum(x[2] for x in j24)==222 and max(x[0] for x in active)==324
  assert len(active)+len(j24)==len(j) and all(x[16]==1 for x in j if x[2]!=-1) and all(x[16]==0 for x in j if x[2]==-1)
  assert all(x[27]<1e-12 and abs(x[24])>1e-12 for x in active)
  counts=collections.Counter(int(x[0]) for x in active);legacy=collections.Counter(int(x[0]) for x in j24 if x[2]==1)
  assert all(counts[int(x[0])]==legacy[int(x[0])]==0 for x in failures)
  assert all(x[9:11]==[0,0] and x[12:17]==[0]*5 and x[25]==1 and x[18]<=1e-6 and abs(x[17])<=1e-5 for x in accepted)
  for n,(x,v,w) in enumerate(zip(accepted,b,iv),1):
   assert x[1]==n and w[:2]==[n,x[0]] and w[2]==v[0] and w[3]==v[1]==x[3]
   assert abs(v[0]-x[2]-v[1])<5e-12 and x[6]==v[16]==w[11]
   assert w[12]==counts[int(x[0])]+legacy[int(x[0])]
   ext=v[1]*(v[2]+v[3]+v[4]-v[5]-v[6]-v[7]-v[8]+v[9]-v[10]+v[11]-v[12])-v[13]
   assert abs(w[8]-ext)<1e-18 and abs(math.fsum(w[4:8])-ext-w[9])<=8*math.ulp(max(abs(y) for y in w[4:9]))
   assert abs(w[9])<v[1]*1e-5 and abs(w[9]-w[10])<1e-15 and abs(w[10]-v[1]*x[17])<1e-18
   assert max(abs(y) for y in w[13:])<1e-13
  # Preserve entire qualified short trajectory, not merely its starting checkpoint.
  pd=P/'data'/opt/'TRAJ';pa=rows(pd/'attempt_trace.txt');pb=rows(pd/'step_budget.txt')
  assert [x[:-1] for x in a[:287]]==[x[:-1] for x in pa] and b[:287]==pb
  for name in ['initial','context_initial','ledger_initial','begin','context_begin','ledger_begin']:
   assert (d/(name+'.txt')).read_bytes()==(pd/(name+'.txt')).read_bytes()
  ini=f(d/'initial.txt');fin=f(d/'final.txt');ci=f(d/'context_initial.txt');cf=f(d/'context_final.txt');assert ini['controls'][0]==35797 and fin['controls'][0]==b[-1][0]
  assert ini['fraction']==fin['fraction'] and ini['dz']==fin['dz']
  if not policy:assert fin['theta']==fin['thetm1'] and fin['h']==fin['hm1'] # Physical rollback before finaldump.
  stock=math.fsum((y-x)*dz*fr for x,y,dz,fr in zip(ini['theta'],fin['theta'],ini['dz'],ini['fraction']))+math.fsum(y-x for x,y in zip(ini['macro_domain'],fin['macro_domain']))+fin['pond'][0]-ini['pond'][0]+cf['sicact'][0]-ci['sicact'][0]
  ext=math.fsum(x[8] for x in iv);err=stock-ext;lim=math.fsum(x[3]*1e-5 for x in iv)
  assert abs(err)<lim and abs(err-math.fsum(x[9] for x in iv))<1e-14 and abs(err-math.fsum(x[10] for x in iv))<1e-14
  L0=f(d/'ledger_begin.txt');L1=f(d/'ledger_final.txt');Linitial=f(d/'ledger_initial.txt');assert L0['sicini']==ci['sicact'] and L0['sicini'][0]>0 and L0['cgrai']==L0['caintc']==[0.]
  inc={}
  for key,col in [('cgrai',2),('cgird',3),('crunon',4),('caintc',5),('cepd',6),('cevap',7),('cqrot',8),('cqbot',9),('cqdra',10),('cqssdi',11),('cqmpoutdrrap',12)]:
   inc[key]=L1[key][0]-L0[key][0]-math.fsum(v[1]*v[col] for v in b);assert abs(inc[key])<1e-12
  domains=[]
  for k in range(5):
   de=fin['macro_domain'][k]-ini['macro_domain'][k]-math.fsum(v[1]*(v[17+k]+v[22+k]-v[27+k]-(v[12] if k==0 else 0)) for v in b);assert abs(de)<1e-13;domains.append(de)
  assert sha(d/'own.end')=='21bd728c9983d6a0d4e82d6b2fd12729dc02284277a5dab5d296d8edc1dcbf16'
  identity=json.loads((R/(('' if policy else 'STRICT_')+opt+'_IDENTITY.json')).read_text());src=R if policy else R/'strict_source';exe=W/opt/'native09.exe' if policy else W/'STRICT'/opt/'native09.exe'
  assert all(sha(src/name)==hv for name,hv in identity['sources'].items()) and sha(exe)==identity['exe_sha256']
  if policy:assert rows(d/'cost_trace.txt')[-1][-1]>=16
  else:assert len(a)==366 and len(b)==360 and a[-1][5]==1 and a[-1][10]==1 and min(v[16] for v in b)==1
  results.append(dict(optimization=opt,profile=mode,seconds=run['seconds'],stop_reason='INTERNAL16' if policy else 'FIRST_SCALED_REQUEST',commits=len(b),attempts=len(a),refusals=len(failures),end_committed_t1900=b[-1][0],last_used_dt=b[-1][1],minimum_committed_flux_factor=min(v[16] for v in b),flux_reduced_commits=sum(v[16]!=1 for v in b),new_corrected_iterations=252,old_rank1_active_iterations=222,last_new_active_attempt=324,all_refusals_new_and_old_correction_inactive=True,all_accepted_fresh_V1=True,maximum_accepted_residual=max(x[18] for x in accepted),maximum_absolute_accepted_sum_residual=max(abs(x[17]) for x in accepted),max_step_inventory_limit_fraction=max(abs(x[9])/(x[3]*1e-5) for x in iv),segment_inventory_error_cm=err,segment_inherited_residual_envelope_cm=lim,segment_domain_errors_cm=domains,postreset_ledger_increment_errors_cm=inc,BAL_bytes=195,natural_endpoint_and_BAL_body_present=False))
for opt in ['O0','O2']:
 a=rows(R/'data'/opt/'TRAJ/attempt_trace.txt');b=rows(R/'data'/opt/'TRAJ_POLICY/attempt_trace.txt');assert [x[:-1] for x in a]==[x[:-1] for x in b[:len(a)]]
 for name in ['step_budget','inventory_trace','jac24_trace','jac37_trace']:
  x=(R/'data'/opt/'TRAJ'/(name+'.txt')).read_text().splitlines();y=(R/'data'/opt/'TRAJ_POLICY'/(name+'.txt')).read_text().splitlines();assert x==y[:len(x)]
 # Both strictrefusal snapshots and their partial endpoint are preserved. Policy continuesafter same366thhead.
for p in (R/'data/O0/TRAJ').glob('*.txt'):
 if p.name not in ['attempt_trace.txt','cost_trace.txt']:assert p.read_bytes()==(R/'data/O2/TRAJ'/p.name).read_bytes(),p.name
common={}
for mode in ['TRAJ','TRAJ_POLICY']:
 a=rows(R/'data/O0'/mode/'attempt_trace.txt');b=rows(R/'data/O2'/mode/'attempt_trace.txt');assert [x[:-1] for x in a]==[x[:-1] for x in b[:len(a)]]
 for name in ['step_budget','inventory_trace','jac24_trace','jac37_trace']:
  x=(R/'data/O0'/mode/(name+'.txt')).read_text().splitlines();y=(R/'data/O2'/mode/(name+'.txt')).read_text().splitlines();assert x==y[:len(x)]
 common[mode]=dict(commits=len(rows(R/'data/O0'/mode/'step_budget.txt')),attempts=len(a))
 for name in ['result.bal','result.blc','result.bma','result_output.csv']:assert body(R/'data/O0'/mode/name)==body(R/'data/O2'/mode/name),name
strict_a=rows(R/'data/O2/TRAJ/attempt_trace.txt');first=next(x for x in strict_a if x[8]!=0)
selection=dict(first_inactive_refusal_attempt=int(first[0]),time=first[2],dt=first[3],worst_node=int(first[19]),max_residual=first[18],first_scaled_request_attempt=366,time_scaled_request=strict_a[-1][2],new_correction_active=False,diagnosis_or_new_model_run_performed=False)
q=dict(work_unit='SWAP431-MACRO-B1-PERIOD40',decision='INCOMPLETE_BUDGET_LIMITED_NO_FULL_PERIOD_BAL_PASS',model_routes=4,hard_timeout_seconds=20,internal_observation_seconds=16,all_processes_normal_uncensored=True,full_original_period_balance_qualified=False,unscaled_full_period_qualified=False,full_period_BAL_qualified=False,physics_input_tolerance_MAXIT_dt_reduction_rules_unchanged=True,complete_trajectory39_prefix_preserved=True,strict_O0_O2_non_timing_byte_exact=True,policy_O0_O2_common_prefix_exact=common['TRAJ_POLICY'],timed_policy_endpoints_expected_different=True,strict_binary_source_runtime_closures_preserved=True,scope_revision='Samefixedperiod two strict plus two original-policy routes only; no further horizon/context/variant',new_restart_or_general_admission=False,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',official_promotion=False,next_original_context=selection,results=results)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8');(R/'NEXT_CONTEXT_INDEX.json').write_text(json.dumps(selection,indent=2)+'\n',encoding='utf-8');print(json.dumps(q,indent=2))
