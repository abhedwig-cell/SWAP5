"""Read-only fixed-period attempt: strict stop and original-policy partial evidence."""
from pathlib import Path
import json,math,hashlib,collections,difflib
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-trajectory33'
def rows(p):return [list(map(float,s.split())) for s in p.read_text().splitlines()]
def f(p):return {s.split()[0].lower():list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
result=[]
for opt in ['O0','O2']:
 for mode in ['TRAJ','TRAJ_POLICY']:
  policy=mode.endswith('POLICY');d=R/'data'/opt/mode;a=rows(d/'attempt_trace.txt');b=rows(d/'step_budget.txt');iv=rows(d/'inventory_trace.txt');j=rows(d/'jac24_trace.txt')
  run=json.loads((R/(opt+'_'+mode+'_RUN.json')).read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20
  outcome=(d/'outcome.txt').read_text();assert ('INTERNAL_BUDGET_BEFORE_PERIOD_END' if policy else 'SCALED_REQUEST_BEFORE_ACTIVE_REFUSAL') in outcome
  assert not (d/'period_final.txt').exists() and not (d/'event33.txt').exists() and 'Period' not in (d/'result.bal').read_text()
  assert len(iv)==len(b) and b[-1][0]<35798
  active=collections.Counter(int(v[0]) for v in j if v[2]==1);assert sum(active.values())==222 and len(active)==90 and max(active)==125
  failures=[v for v in a if v[8]==4];assert all(active[int(v[0])]==0 for v in failures)
  accepted=[v for v in a if v[8]==0];assert len(accepted)==len(b)
  for x,v,w in zip(accepted,b,iv):
   assert w[1]==x[0] and w[2]==v[0] and w[3]==v[1]==x[3] and w[11]==v[16]==x[6] and w[12]==active[int(x[0])]
   assert abs(v[0]-x[2]-x[3])<5e-12 and x[25]==1 and x[18]<=1e-6 and abs(x[17])<=1e-5
   assert x[9:11]==[0,0] and x[12:17]==[0]*5
   ext=v[1]*(v[2]+v[3]+v[4]-v[5]-v[6]-v[7]-v[8]+v[9]-v[10]+v[11]-v[12])-v[13]
   assert abs(ext-w[8])<1e-15 and abs(math.fsum(w[4:8])-ext-w[9])<1e-15
   assert abs(w[9])<v[1]*1e-5 and abs(w[9]-x[17]*v[1])<1e-15 and max(abs(z) for z in w[13:])<1e-13
  ini=f(d/'begin.txt');fin=f(d/'final.txt');ci=f(d/'context_begin.txt');cf=f(d/'context_final.txt');L=f(d/'ledger_begin.txt');F=f(d/'ledger_final.txt')
  assert ini['controls'][0]==35797 and L['sicini']==ci['sicact']==[.0025926018136122326]
  assert L['cgrai']==L['caintc']==[0.] and L['wasrdm1ini']==[ini['macro_domain'][0]]
  assert abs(L['wasrdm2ini'][0]-math.fsum(ini['macro_domain'][1:]))<1e-15
  assert (d/'ledger_begin.txt').read_bytes()==(R.parent/'swap431-macro-b1-next18/data'/opt/'RESUME/ledger_begin.txt').read_bytes()
  # STRICT ends on a FAILED, uncommitted head. Use saved accepted m1 fields, never trial theta/pond.
  th=fin['theta'] if policy else fin['thetm1'];pond=fin['pond'][0 if policy else 1]
  matrix=math.fsum((y-x)*dz*fr for x,y,dz,fr in zip(ini['theta'],th,ini['dz'],ini['fraction']))
  macro=math.fsum(y-x for x,y in zip(ini['macro_domain'],fin['macro_domain']))
  stock=matrix+macro+pond-ini['pond'][0]+cf['sicact'][0]-ci['sicact'][0]
  external=math.fsum(v[8] for v in iv);error=stock-external;duration=math.fsum(v[1] for v in b);envelope=duration*1e-5
  assert abs(error)<envelope and abs(error-math.fsum(v[9] for v in iv))<1e-12
  assert abs(b[-1][0]-35797-duration)<1e-8
  ledger_errors=[]
  for key,col in [('cgrai',2),('cgird',3),('crunon',4),('caintc',5),('cepd',6),('cevap',7),('cqrot',8),('cqbot',9),('cqdra',10),('cqssdi',11),('cqmpoutdrrap',12)]:
   z=F[key][0]-L[key][0]-math.fsum(v[1]*v[col] for v in b);assert abs(z)<1e-12;ledger_errors.append(z)
  assert abs(F['crunoff'][0]-L['crunoff'][0]-math.fsum(v[13] for v in b))<1e-12
  for suffix,ids in [('1',[0]),('2',[1,2,3,4])]:
   for part,col in [('intoplat',17),('intopvrt',22)]:
    key='cqmp'+part+'dm'+suffix
    assert abs(F[key][0]-L[key][0]-math.fsum(v[1]*math.fsum(v[col+idx] for idx in ids) for v in b))<1e-12
  orig=(P/'data'/opt/'TRAJ/step_budget.txt').read_text().splitlines();assert (d/'step_budget.txt').read_text().splitlines()[:63]==orig
  assert j[:269]==rows(P/'data'/opt/'TRAJ/jac24_trace.txt')
  assert (d/'own.end').read_bytes()==(P/'data'/opt/'TRAJ/own.end').read_bytes()
  if policy:
   sd=R/'data'/opt/'TRAJ';sa=rows(sd/'attempt_trace.txt');sj=rows(sd/'jac24_trace.txt')
   assert [v[:-1] for v in a[:299]]==[v[:-1] for v in sa] and j[:len(sj)]==sj
   assert (d/'step_budget.txt').read_text().splitlines()[:294]==(sd/'step_budget.txt').read_text().splitlines()
   assert (d/'inventory_trace.txt').read_text().splitlines()[:294]==(sd/'inventory_trace.txt').read_text().splitlines()
   reduced=[v for v in b if v[16]!=1];assert reduced and reduced[0][0]==35797.370924155744 and reduced[0][16]==.1
   assert 16<=run['seconds']<20
   n=4243 if opt=='O0' else 5613;nh=4876 if opt=='O0' else 6594
   assert len(b)==n and len(a)==nh
   end_source='actual committed final theta/pond and stocks'
  else:
   assert len(a)==299 and len(b)==294 and len(failures)==5 and all(v[16]==1 for v in b)
   assert a[-1][2]==b[-1][0]==35797.37078273439 and a[-1][3]==1e-5 and a[-1][7]==61 and a[-1][10]==1 and a[-1][5]==1
   end_source='saved accepted thetm1/pondm1 plus unchanged committed macro/canopy, not failed trial theta/pond'
  result.append(dict(optimization=opt,mode='ORIGINAL_POLICY' if policy else 'STRICT_UNSCALED',seconds=run['seconds'],normal_uncensored=True,commits=len(b),head_attempts=len(a),inactive_head_refusals=len(failures),active_head_refusals=0,rank1_active_iterations=222,rank1_active_heads=90,last_active_attempt=125,last_committed_t1900=b[-1][0],last_attempt_t1900=a[-1][2],recorded_duration_days=duration,reduced_flux_commits=sum(v[16]!=1 for v in b),minimum_committed_flux_factor=min(v[16] for v in b),canopy_begin_cm=L['sicini'][0],canopy_at_last_commit_cm=cf['sicact'][0],postreset_ledger_exact_to_original_NEXT18=True,max_step_inventory_error_cm=max(abs(v[9]) for v in iv),max_step_inventory_limit_fraction=max(abs(v[9])/(v[3]*1e-5) for v in iv),max_domain_inventory_error_cm=max(abs(z) for v in iv for z in v[13:]),partial_inventory_stock_source=end_source,partial_inventory_error_cm=error,partial_integrated_residual_envelope_cm=envelope,max_primitive_ledger_error_cm=max(abs(v) for v in ledger_errors),BAL_bytes=(d/'result.bal').stat().st_size,period_endpoint_reached=False,full_period_BAL_qualified=False))
# STRICT pair is identical aside from timing. POLICY pairs have different budget stops, compare common accepted trajectory.
for p in (R/'data/O0/TRAJ').glob('*.txt'):
 if p.name in ['cost_trace.txt','attempt_trace.txt']:continue
 assert p.read_bytes()==(R/'data/O2/TRAJ'/p.name).read_bytes(),p.name
for mode in ['TRAJ','TRAJ_POLICY']:
 a=rows(R/'data/O0'/mode/'attempt_trace.txt');b=rows(R/'data/O2'/mode/'attempt_trace.txt')
 assert [v[:-1] for v in a]==[v[:-1] for v in b[:len(a)]]
 for name in ['step_budget.txt','inventory_trace.txt','jac24_trace.txt']:
  aa=(R/'data/O0'/mode/name).read_text().splitlines();bb=(R/'data/O2'/mode/name).read_text().splitlines();assert aa==bb[:len(aa)]
 for name in ['begin.txt','ledger_begin.txt','context_begin.txt','initial.txt','ledger_initial.txt','context_initial.txt']:
  assert (R/'data/O0'/mode/name).read_bytes()==(R/'data/O2'/mode/name).read_bytes()
for opt in ['O0','O2']:
 for prefix,source in [('',R),('STRICT_',R/'strict_source')]:
  ident=json.loads((R/(prefix+opt+'_IDENTITY.json')).read_text());assert all(sha(source/n)==h for n,h in ident['sources'].items())
for p in P.glob('*.f90'):
 if p.name not in ['diag_state.f90','soilwater_native.f90']:assert p.read_bytes()==(R/p.name).read_bytes()
assert not list((R/'data').glob('*/DIRECT*')) and not list((R/'data').glob('*/TRIAL*')) and not (R/'EVENT_SELECTION.json').exists()
# Match separately preserved strict->policy observation patch, no numerical formulas changed.
patch=''.join(difflib.unified_diff((R/'strict_source/soilwater_native.f90').read_text().splitlines(True),(R/'soilwater_native.f90').read_text().splitlines(True),fromfile='PERIOD34/strict_observation',tofile='PERIOD34/original_policy_observation'))
assert patch==(R/'original_policy_observation.patch').read_text()
q=dict(work_unit='SWAP431-MACRO-B1-PERIOD34',decision='INCOMPLETE_BUDGET_LIMITED_NO_FULL_PERIOD_BAL_PASS',model_routes=4,hard_timeout_seconds=20,internal_observation_budget_seconds=16,all_processes_normal_uncensored=True,unscaled_full_period_qualified=False,full_period_BAL_qualified=False,postreset_nonzero_canopy_origin_qualified=True,active_refusal_rollback_direct_qualification=False,STRICT_O0_O2_non_timing_byte_exact=True,POLICY_O0_O2_common_commits_byte_exact=4243,POLICY_O0_O2_common_attempts_non_timing_byte_exact=4876,POLICY_final_states_expected_different_due_to_timed_stop=True,physics_candidate_dt_tolerance_MAXIT_reduction_rule_changes=False,scope_revision='Two strict stops preserved, two original-policy runs in SAME fixedperiod; no new numerical variant, no further horizon/campaign',B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',official_promotion=False,strict_binary_retention='Only exact source/build/runtime identity/output retained; original binary replaced by final policy build; see STRICT_SOURCE_IDENTITY.json',results=result)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q,indent=2))
# Exact targets for a possible separately scoped diagnosis; these are INACTIVE failures, not event witnesses.
a=rows(R/'data/O2/TRAJ/attempt_trace.txt');idx=[v for v in a if v[8]==4]
(R/'INACTIVE_FAILURE_INDEX.json').write_text(json.dumps(dict(own_candidate_trajectory=True,initial_native_t1900=35797,first_inactive_refusal=dict(attempt=int(idx[0][0]),prior_commits=int(idx[0][1])-1,time=idx[0][2],dt=idx[0][3],iterations=30,worst_node=int(idx[0][19]),rank1_active_iterations=0),first_flux_reduction_request=dict(attempt=299,time=a[-1][2],dt=a[-1][3],iterations=60,worst_node=int(a[-1][19]),rank1_active_iterations=0),not_an_active_refusal_witness=True,no_additional_diagnosis_model_run=True),indent=2)+'\n')
