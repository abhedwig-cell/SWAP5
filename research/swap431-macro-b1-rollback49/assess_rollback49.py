"""Read-only bounded genuine refusal / empty-cache rollback / active acceptance audit."""
from pathlib import Path
import json,math,hashlib,re
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-feedback48';B=R.parent/'swap431-macro-b1-period34';W=Path('C:/Users/Veldh012/swap431-rollback49-work/native')
def rows(p):return [list(map(float,l.split())) for l in p.read_text().splitlines()]
def f(p):return {l.split()[0].lower():list(map(float,l.split()[1:])) for l in p.read_text().splitlines()}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
# Both tested source variants differ from FEEDBACK48 only by the recorded driver/observation patch.
for root in [R,R/'version297']:
 patch=(root/'HARNESS_OBSERVATION.patch').read_text()
 for p in P.glob('*.f90'):
  s=(root/p.name).read_text()
  if '+++ ROLLBACK49/'+p.name+'\n' in patch:
   section=patch.split('+++ ROLLBACK49/'+p.name+'\n',1)[1].split('--- FEEDBACK48/',1)[0]
   for h in re.split(r'@@[^\n]*\n',section)[1:]:
    ls=h.splitlines(True);old=''.join(x[1:] for x in ls if x[:1] in [' ','-']);new=''.join(x[1:] for x in ls if x[:1] in [' ','+'])
    assert s.count(new)==1;s=s.replace(new,old,1)
  assert s==p.read_text(),(root.name,p.name)
 assert (root/'macropore_native.f90').read_bytes()==(P/'macropore_native.f90').read_bytes()
results=[];runs=[]
def inventory(d,beg,head):
 a=f(d/(beg+'.txt'));b=f(d/'committed.txt');ca=f(d/('context_'+beg+'.txt'));ce=f(d/'context_committed.txt');v=rows(d/'step_budget.txt')[-1];dt=v[1]
 stock=math.fsum((y-x)*dz*fr for x,y,dz,fr in zip(a['theta'],b['theta'],a['dz'],a['fraction']))+math.fsum(y-x for x,y in zip(a['macro_domain'],b['macro_domain']))+b['pond'][0]-a['pond'][0]+ce['sicact'][0]-ca['sicact'][0]
 ext=dt*(v[2]+v[3]+v[4]-v[5]-v[6]-v[7]-v[8]+v[9]-v[10]+v[11]-v[12])-v[13];err=stock-ext
 assert abs(err)<dt*1e-5 and abs(err-dt*head[17])<1e-15
 assert head[25]==1 and head[18]<1e-6 and abs(head[17])<1e-5 and head[6]==1
 for k in range(5):
  de=b['macro_domain'][k]-a['macro_domain'][k]-dt*(v[17+k]+v[22+k]-v[27+k]-(v[12] if k==0 else 0));assert abs(de)<1e-13
 L0=f(d/('ledger_'+beg+'.txt'));L1=f(d/'ledger_committed.txt')
 for key,col in [('cgrai',2),('cgird',3),('crunon',4),('caintc',5),('cepd',6),('cevap',7),('cqrot',8),('cqbot',9),('cqdra',10),('cqssdi',11),('cqmpoutdrrap',12)]:assert abs(L1[key][0]-L0[key][0]-dt*v[col])<1e-12
 for w in rows(d/'inventory_trace.txt'):assert abs(w[9])<w[3]*1e-5 and max(abs(k) for k in w[13:])<1e-13
 return dict(inventory_error_cm=err,inventory_limit_cm=dt*1e-5,fresh_V1=True,ledger_increments_verified=True)
for opt in ['O0','O2']:
 t=R/'data'/opt/'TRIAL_297';d=R/'data'/opt/'DIRECT_297';e=R/'data'/opt/'TRIAL_36'
 ta=rows(t/'attempt_trace.txt');da=rows(d/'attempt_trace.txt');ea=rows(e/'attempt_trace.txt');original=rows(B/'data'/opt/'TRAJ/attempt_trace.txt')
 assert len(ta)==298 and len(da)==297 and len(ea)==36
 assert [x[:-1] for x in ta[:296]]==[x[:-1] for x in da[:296]]==[x[:-1] for x in original[:296]]
 assert [x[:-1] for x in ea[:35]]==[x[:-1] for x in original[:35]]
 assert (t/'step_budget.txt').read_text().splitlines()[:294]==(B/'data'/opt/'TRAJ/step_budget.txt').read_text().splitlines()[:294]
 large,small=ta[-2:];assert large[7:17]==[31,4,1,0,0,1,1,0,0,0] and large[25]==0 and large[6]==1
 assert small[2:-1]==da[-1][2:-1] and small[3]==large[3]/3 and small[7]==10
 assert (t/'solver_2.txt').read_bytes()==(d/'solver_1.txt').read_bytes()
 for n in ['origin','context_origin','ledger_origin','accepted_return','context_accepted_return','ledger_accepted_return','committed','context_committed','ledger_committed','step_budget']:
  assert (t/(n+'.txt')).read_bytes()==(d/(n+'.txt')).read_bytes(),n
 tj=[x[1:] for x in rows(t/'jac37_trace.txt') if x[0]==298];dj=[x[1:] for x in rows(d/'jac37_trace.txt')];assert tj==dj and len(tj)==10
 scratch={'macro_exchange','macro_rapid','matrix_exchange','boundary_rates','sorptivity'}
 oo=f(t/'origin.txt');rb=f(t/'rollback_1.txt');sb=f(t/'begin_2.txt');db=f(d/'begin_1.txt')
 assert {k for k in oo if oo[k]!=rb[k]}==scratch|{'controls'} and oo['controls'][:7]==rb['controls'][:7] and rb['controls'][7]==1
 assert {k for k in sb if sb[k]!=db[k]}==scratch
 for aa,bb in [('context_origin','context_rollback_1'),('context_begin_2','DIRECT:context_begin_1')]:
  aa=f(t/(aa+'.txt'));bb=f(d/(bb.split(':')[1]+'.txt')) if ':' in bb else f(t/(bb+'.txt'))
  assert {k for k in aa if aa[k]!=bb[k]}=={'sorpdmcp','subsidcp'}
 for n in ['ledger_begin_1','ledger_returned_1','ledger_rollback_1','ledger_begin_2']:assert (t/(n+'.txt')).read_bytes()==(t/'ledger_origin.txt').read_bytes()
 cache=rows(t/'cache_rollback_1.txt')[0];assert cache[:3]==[0,0,0]
 pr=rows(t/'provider49_trace.txt');failed=[x for x in pr if x[0]==297];assert len(failed)>0 and all(x[7:9]==[0,0] for x in pr)
 assert set(int(x[1]) for x in failed)==set(range(31))
 assert not (t/'feedback48_trace.txt').exists() and not (d/'feedback48_trace.txt').exists()
 # Second and last context is the immutable original36, not a fed-back parent origin.
 for n in ['origin','context_origin','ledger_origin']:
  assert (e/(n+'.txt')).read_bytes()==(R.parent/'swap431-macro-b1-remaining31/data'/opt/'TRIAL_G1'/(n+'.txt')).read_bytes(),n
 pp=rows(e/'provider49_trace.txt');assert len(pp)==6 and all(x[7]==1 and x[8]>0 for x in pp)
 assert ea[-1][7]==2 and ea[-1][9:17]==[0]*8 and ea[-1][25]==1 and not (e/'rollback_1.txt').exists()
 rr=rows(e/'feedback48_trace.txt');assert len(rr)==1 and rr[0][3:5]==[3,50]
 x=rr[0];v=rows(e/'reference46_trace.txt')[0]
 delta=v[17]*v[18]*(4/v[20])*v[21]*v[22]*v[10]*(math.sqrt(v[8]+v[2])-math.sqrt(v[8]))
 assert math.isclose(delta,x[7],rel_tol=1e-14) and x[8]==x[6]+x[7]>x[6]
 for n in ['ledger_begin_1','ledger_returned_1']:assert (e/(n+'.txt')).read_bytes()==(e/'ledger_origin.txt').read_bytes()
 results.append(dict(optimization=opt,original297=dict(true_unscaled_MAXIT30_refusal=True,CONTACT47_nonzero_scratch_evaluations=0,large_dt_days=large[3],large_max_residual=large[18],large_sum_residual=large[17],rollback_physical_core_and_ledger_restored=True,cache_invalid_after_rollback=True,immediate_full_native_byte_identity=False,inherited_native_scratch_differences=['sorpdmcp','subsidcp'],small_dt_days=small[3],small_iterations=10,small_max_residual=small[18],postrollback_direct_solver_context_commit_ledger_budget_exact=True,TRIAL_inventory=inventory(t,'begin_2',small),DIRECT_inventory=inventory(d,'begin_1',da[-1])),original36=dict(original_origin_inventory_context_ledger_byte_exact=True,accepted_iterations=2,true_refusal=False,positive_scratch_evaluations=6,committed_reference_increment=x[7],reference_after=x[8],max_residual=ea[-1][18],inventory=inventory(e,'begin_1',ea[-1]))))
 for profile in ['TRIAL_297','DIRECT_297','TRIAL_36']:
  q=json.loads((R/(opt+'_'+profile+'_RUN.json')).read_text());assert q['returncode']==0 and not q['censored'] and q['seconds']<20
  runs.append(dict(optimization=opt,profile=profile,seconds=q['seconds']))
 for src,exe in [(R/'version297','native297.exe'),(R,'native09.exe')]:
  ident=json.loads((src/(opt+'_IDENTITY.json')).read_text());assert all(sha(src/n)==hh for n,hh in ident['sources'].items()) and sha(W/opt/exe)==ident['exe_sha256']
for profile in ['TRIAL_297','DIRECT_297','TRIAL_36']:
 d0=R/'data/O0'/profile;d2=R/'data/O2'/profile
 for p in d0.glob('*.txt'):
  if profile=='TRIAL_36' and p.name=='contact43_trace.txt':
   aa=rows(p);bb=rows(d2/p.name);assert len(aa)==len(bb)==6
   for x,y in zip(aa,bb):
    assert x[:14]==y[:14] and x[15:]==y[15:] and x[13]==y[13]==0 and x[16]==y[16]==1 and x[12]>0
    assert x[14]==0 and math.isfinite(y[14]) and abs(y[14])<2.2250738585072014e-308
  elif p.name not in ['cost_trace.txt','attempt_trace.txt']:assert p.read_bytes()==(d2/p.name).read_bytes(),(profile,p.name)
 assert [x[:-1] for x in rows(d0/'attempt_trace.txt')]==[x[:-1] for x in rows(d2/'attempt_trace.txt')]
 assert sha(d0/'own.end')==sha(d2/'own.end')=='21bd728c9983d6a0d4e82d6b2fd12729dc02284277a5dab5d296d8edc1dcbf16'
assert not (R/'data/O0/DIRECT_36').exists() and not (R/'data/O2/DIRECT_36').exists()
q=dict(work_unit='SWAP431-MACRO-B1-ROLLBACK49',decision='PARTIAL_REAL_REFUSAL_EMPTY_CONTACT47_CACHE_ROLLBACK_DIRECT_PASS_ACTIVE_REFUSAL_NOT_FOUND',baseline='4a507f0f830f5d4a09941e1ac4e5f201ad6c1821',source_checkpoints={'original297':'9b171a366','original36':'a611d31eb'},model_routes=6,hard_seconds_per_route=20,O0_O2_physical_state_solver_commit_ledger_budget_exact=True,O0_O2_all_non_timing_byte_exact=False,diagnostic_exception="TRIAL36 contact43_trace zero-based field14 SorpFac: six rows have inactive Darcy factor0 in O0 and finite subnormal in O2, rawDarcy0 and chosenSorp1; all other fields exact; inherited uninitialized unused diagnostic, unchanged source",FEEDBACK48_reference_physics_unchanged=True,genuine_active_CONTACT47_refusal_rollback_direct_qualified=False,no_forced_refusal_or_broad_campaign=True,selection_stopped_after_two_original_contexts=True,full_period_restart_or_general_admission=False,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',official_promotion=False,results=results,runs=runs)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8');print(json.dumps(q,indent=2))
