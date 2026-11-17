"""Read-only qualification of one short, continuous corrected candidate trajectory."""
from pathlib import Path
import json,math,hashlib,collections
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-active38';W=Path('C:/Users/Veldh012/swap431-trajectory39-work')
def rows(p):return [list(map(float,s.split())) for s in p.read_text().splitlines()]
def f(p):return {s.split()[0].lower():list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
contract=json.loads((R/'CONTRACT.json').read_text());results=[]
assert [p.name for p in R.glob('*.f90') if p.read_bytes()!=(P/p.name).read_bytes()]==['soilwater_native.f90']
s=(R/'soilwater_native.f90').read_text();driver=s[s.index('logical function retry07_driver'):s.index('subroutine retry07_checkpoint')]
assert 'apply37=.true.' in driver and driver.index('apply37=.true.')<driver.index('call headcalc')
assert 'target_attempt' not in driver and 'jac37_calibrate' not in driver and 'TimeControl' not in driver
for opt in ['O0','O2']:
 d=R/'data'/opt/'TRAJ';old=P/'data'/opt/'TRIAL_297';a=rows(d/'attempt_trace.txt');b=rows(d/'step_budget.txt');iv=rows(d/'inventory_trace.txt');j=rows(d/'jac37_trace.txt');j24=rows(d/'jac24_trace.txt');act=[v for v in j if v[2]==1]
 run=json.loads((R/(opt+'_TRAJ_RUN.json')).read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20
 assert 'BOUNDED_CORRECTED_TRAJECTORY' in (d/'outcome.txt').read_text()
 assert len(a)==len(b)==len(iv)==287 and len(j)==1929 and len(j24)==1817 and len(act)==112
 assert len(set(v[0] for v in act))==28 and min(v[0] for v in act)==259
 assert all(v[16]==1 for v in j) and all(v[27]<1e-12 and abs(v[24])>1e-12 for v in act)
 assert sum(v[2] for v in j24)==222 and len(j24)+len(act)==len(j)
 assert all(x[0]==x[1]==i and x[4:7]==[0,0,1] and x[8:17]==[0]*9 and x[25]==1 and x[18]<=1e-6 and abs(x[17])<=1e-5 for i,x in enumerate(a,1))
 counts=collections.Counter(int(v[0]) for v in act);legacy=collections.Counter(int(v[0]) for v in j24 if v[2]==1);calls=collections.Counter(int(v[0]) for v in j)
 for n,(x,v,w) in enumerate(zip(a,b,iv),1):
  assert x[0]==x[1]==n and w[:2]==[n,n] and x[3]==v[1]==w[3] and calls[n]==x[21]
  assert w[2]==v[0] and abs(v[0]-x[2]-v[1])<5e-12 and v[16]==w[11]==1
  assert w[12]==counts[n]+legacy[n]
  external=v[1]*(v[2]+v[3]+v[4]-v[5]-v[6]-v[7]-v[8]+v[9]-v[10]+v[11]-v[12])-v[13]
  assert abs(w[8]-external)<1e-18 and abs(math.fsum(w[4:8])-external-w[9])<1e-18
  assert abs(w[9])<v[1]*1e-5 and abs(w[9]-w[10])<1e-15 and abs(w[10]-v[1]*x[17])<1e-18
  assert max(abs(y) for y in w[13:])<1e-13
 ini=f(d/'initial.txt');fin=f(d/'final.txt');ci=f(d/'context_initial.txt');cf=f(d/'context_final.txt');beg=f(d/'begin.txt');cb=f(d/'context_begin.txt')
 assert ini['controls'][0]==35797 and fin['controls'][0]==b[-1][0]==35797.372198904130
 assert b[-2][0]<35797.372<=b[-1][0] and b[-1][0]>contract['reference_original297_t1900']
 assert all(ini[k]==beg[k] for k in ['theta','macro_domain','pond','fraction','dz']) and ci['sicact']==cb['sicact']
 assert ini['fraction']==fin['fraction'] and ini['dz']==fin['dz']
 interval=math.fsum(v[1] for v in b);assert abs(interval-(b[-1][0]-35797))<2e-9
 matrix=math.fsum((y-x)*dz*fr for x,y,dz,fr in zip(ini['theta'],fin['theta'],ini['dz'],ini['fraction']))
 macro=math.fsum(y-x for x,y in zip(ini['macro_domain'],fin['macro_domain']))
 stock=matrix+macro+fin['pond'][0]-ini['pond'][0]+cf['sicact'][0]-ci['sicact'][0]
 external=math.fsum(v[1]*(v[2]+v[3]+v[4]-v[5]-v[6]-v[7]-v[8]+v[9]-v[10]+v[11]-v[12])-v[13] for v in b)
 error=stock-external;tol=math.fsum(v[1]*1e-5 for v in b)
 assert abs(error)<tol and abs(error-math.fsum(v[9] for v in iv))<1e-14 and abs(error-math.fsum(v[10] for v in iv))<1e-14
 dom=[]
 for k in range(5):
  de=fin['macro_domain'][k]-ini['macro_domain'][k]-math.fsum(v[1]*(v[17+k]+v[22+k]-v[27+k]-(v[12] if k==0 else 0)) for v in b);assert abs(de)<1e-13;dom.append(de)
 # The original day-start reset lies between initial and begin. Use the actual post-reset ledger baseline.
 L0=f(d/'ledger_begin.txt');L1=f(d/'ledger_final.txt');increments={}
 for key,col in [('cgrai',2),('cgird',3),('crunon',4),('caintc',5),('cepd',6),('cevap',7),('cqrot',8),('cqbot',9),('cqdra',10),('cqssdi',11),('cqmpoutdrrap',12)]:
  delta=L1[key][0]-L0[key][0];integ=math.fsum(v[1]*v[col] for v in b);assert abs(delta-integ)<1e-12;increments[key]=delta-integ
 oa=rows(old/'attempt_trace.txt');ob=rows(old/'step_budget.txt')
 assert [v[:-1] for v in a[:258]]==[v[:-1] for v in oa[:258]] and b[:258]==ob[:258]
 assert a[258][:-1]!=oa[258][:-1] and b[258]!=ob[258]
 assert [v for v in j24 if v[0]<=258]==[v for v in rows(old/'jac24_trace.txt') if v[0]<=258]
 for name in ['initial','context_initial','ledger_initial','begin','context_begin','ledger_begin']:
  assert (d/(name+'.txt')).read_bytes()==(old/(name+'.txt')).read_bytes(),name
 assert not list(d.glob('*refus*')) and not list(d.glob('*rollback*')) and not (d/'cal37_terms.txt').exists() and not (d/'domains36_point.bin').exists()
 assert sha(d/'own.end')==contract['native_sha256']
 identity=json.loads((R/(opt+'_IDENTITY.json')).read_text());assert all(sha(R/name)==hv for name,hv in identity['sources'].items()) and sha(W/'native'/opt/'native09.exe')==identity['exe_sha256']
 results.append(dict(optimization=opt,seconds=run['seconds'],commits=287,head_attempts=287,refusals=0,scaled_commits=0,native_source_sha256=sha(d/'own.end'),first_new_correction_attempt=259,first_new_correction_begin_t1900=a[258][2],first_new_correction_iteration=2,unchanged_old_prefix_attempts_and_commits=258,new_corrected_iterations=112,new_corrected_heads=28,old_rank1_active_iterations=222,combined_active_iterations=334,stock_ranks=dict(collections.Counter(int(v[3]) for v in act)),ineligible_guards=dict(collections.Counter(int(v[2]) for v in j if v[2]!=1)),all_provider_stamps_valid=True,total_Newton_iterations=int(sum(v[21] for v in a)),iteration_range=[int(min(v[7] for v in a)),int(max(v[7] for v in a))],extra_line_search_trials=int(sum(v[24]-v[21] for v in a)),maximum_end_residual=max(v[18] for v in a),maximum_absolute_sum_residual=max(abs(v[17]) for v in a),end_t1900=b[-1][0],last_used_dt=b[-1][1],next_dt=fin['controls'][1],sum_used_dt_days=interval,original297_time_crossed=True,max_step_inventory_error_cm=max(abs(v[9]) for v in iv),max_step_inventory_limit_fraction=max(abs(v[9])/(v[3]*1e-5) for v in iv),max_step_domain_error_cm=max(abs(y) for v in iv for y in v[13:]),segment_stock_change_cm=stock,segment_external_cm=external,segment_inventory_error_cm=error,segment_integrated_residual_envelope_cm=tol,segment_domain_errors_cm=dom,post_day_reset_ledger_primitive_increment_errors_cm=increments,max_new_correction_linear_residual=max(v[27] for v in act),min_Woodbury_determinant=min(abs(v[24]) for v in act)))
for p in (R/'data/O0/TRAJ').glob('*.txt'):
 if p.name in ['cost_trace.txt','attempt_trace.txt']:continue
 assert p.read_bytes()==(R/'data/O2/TRAJ'/p.name).read_bytes(),p.name
assert [v[:-1] for v in rows(R/'data/O0/TRAJ/attempt_trace.txt')]==[v[:-1] for v in rows(R/'data/O2/TRAJ/attempt_trace.txt')]
q=dict(work_unit='SWAP431-MACRO-B1-TRAJECTORY39',decision='PASS_SHORT_OWN_CORRECTED_TRAJECTORY_BEYOND_ORIGINAL297_O0_O2',source_checkpoint='80fca3ece',model_routes=2,all_uncensored=True,hard_timeout_seconds=20,O0_O2_non_timing_byte_exact=True,continuous_correction_enabled_from_first_head=True,actual_new_correction_starts_at_attempt259=True,original_native_checkpoint_used=True,physics_input_tolerances_MAXIT_dt_reduction_rules_unchanged=True,no_forced_dt_to_observation_threshold=True,full_period_balance_new_restart_or_general_admission=False,active_refusal_evidence_inherited_from_active38_not_reexercised=True,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',official_promotion=False,results=results)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8');print(json.dumps(q,indent=2))
