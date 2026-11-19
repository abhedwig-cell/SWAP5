"""Read-only finite active CONTACT47 refusal and continuation qualification."""
from pathlib import Path
import json,math,hashlib,re
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-rollback49';B=R.parent/'swap431-macro-b1-select28';W=Path('C:/Users/Veldh012/swap431-select50-work/native')
def rows(p):return [list(map(float,l.split())) for l in p.read_text().splitlines()]
def f(p):return {l.split()[0].lower():list(map(float,l.split()[1:])) for l in p.read_text().splitlines()}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
patch=(R/'HARNESS.patch').read_text()
for p in P.glob('*.f90'):
 s=(R/p.name).read_text()
 if '+++ SELECT50/'+p.name+'\n' in patch:
  section=patch.split('+++ SELECT50/'+p.name+'\n',1)[1].split('--- ROLLBACK49/',1)[0]
  for h in re.split(r'@@[^\n]*\n',section)[1:]:
   ls=h.splitlines(True);old=''.join(x[1:] for x in ls if x[:1] in [' ','-']);new=''.join(x[1:] for x in ls if x[:1] in [' ','+']);assert s.count(new)==1;s=s.replace(new,old,1)
 assert s==p.read_text(),p.name
 assert p.name=='soilwater_native.f90' or p.read_bytes()==(R/p.name).read_bytes()
def inv(d,beg,head):
 a=f(d/(beg+'.txt'));b=f(d/'committed.txt');ca=f(d/('context_'+beg+'.txt'));ce=f(d/'context_committed.txt');v=rows(d/'step_budget.txt')[-1];dt=v[1]
 stock=math.fsum((y-x)*dz*fr for x,y,dz,fr in zip(a['theta'],b['theta'],a['dz'],a['fraction']))+math.fsum(y-x for x,y in zip(a['macro_domain'],b['macro_domain']))+b['pond'][0]-a['pond'][0]+ce['sicact'][0]-ca['sicact'][0]
 ext=dt*(v[2]+v[3]+v[4]-v[5]-v[6]-v[7]-v[8]+v[9]-v[10]+v[11]-v[12])-v[13];err=stock-ext
 assert abs(err)<dt*1e-5 and abs(err-dt*head[17])<1e-15
 assert head[25]==1 and head[18]<1e-6 and abs(head[17])<1e-5 and head[6]==1
 for k in range(5):assert abs(b['macro_domain'][k]-a['macro_domain'][k]-dt*(v[17+k]+v[22+k]-v[27+k]-(v[12] if k==0 else 0)))<1e-13
 L0=f(d/('ledger_'+beg+'.txt'));L1=f(d/'ledger_committed.txt');errors={}
 for key,col in [('cgrai',2),('cgird',3),('crunon',4),('caintc',5),('cepd',6),('cevap',7),('cqrot',8),('cqbot',9),('cqdra',10),('cqssdi',11),('cqmpoutdrrap',12)]:
  errors[key]=L1[key][0]-L0[key][0]-dt*v[col];assert abs(errors[key])<1e-12
 return dict(inventory_error_cm=err,inventory_limit_cm=dt*1e-5,ledger_increment_errors_cm=errors,fresh_V1=True)
results=[];runs=[]
for opt in ['O0','O2']:
 root=R/'data'/opt;t=root/'TRIAL_D2';d=root/'DIRECT_D2';d1=root/'TRIAL_D1'
 for label in ['D1','D2']:
  dd=root/('TRIAL_'+label);old=B/'data'/opt/('TRIAL_'+label)
  for name in ['origin','context_origin','ledger_origin','prefix_budget']:assert (dd/(name+'.txt')).read_bytes()==(old/(name+'.txt')).read_bytes(),(label,name)
 ta=rows(t/'attempt_trace.txt');da=rows(d/'attempt_trace.txt');a1=rows(d1/'attempt_trace.txt')
 assert len(ta)==4 and len(da)==3 and len(a1)==1
 assert all(x[7]==31 and x[9]==1 and x[10]==0 and x[6]==1 and x[25]==0 for x in ta[:3])
 assert [x[2:-1] for x in ta[1:]]==[x[2:-1] for x in da]
 assert ta[1][3]==ta[0][3]/3 and ta[2][3]==ta[1][3]/3 and ta[3][3]==ta[2][3]/3
 assert ta[3][7]==3 and da[2][7]==3 and a1[0][7]==12
 for name in ['origin','context_origin','ledger_origin','prefix_budget','accepted_return','context_accepted_return','ledger_accepted_return','committed','context_committed','ledger_committed','step_budget']:
  assert (t/(name+'.txt')).read_bytes()==(d/(name+'.txt')).read_bytes(),name
 for i in range(1,4):assert (t/('solver_'+str(i+1)+'.txt')).read_bytes()==(d/('solver_'+str(i)+'.txt')).read_bytes()
 pp=rows(t/'provider49_trace.txt');pd=rows(d/'provider49_trace.txt')
 assert [x[1:] for x in pp if x[0]>=2]==[x[1:] for x in pd]
 oo=f(t/'origin.txt');co=f(t/'context_origin.txt');rollback=[]
 for i in range(1,4):
  x=rows(t/('cache_returned_returned_'+str(i)+'.txt'))[0];y=rows(t/('cache_rollback_'+str(i)+'.txt'))[0]
  assert y[:3]==[0,0,0]
  active=[v for v in pp if v[0]==i and v[8]>0];assert len(active)>0
  rb=f(t/('rollback_'+str(i)+'.txt'));cr=f(t/('context_rollback_'+str(i)+'.txt'))
  scratch={'controls','macro_exchange','macro_rapid','matrix_exchange','boundary_rates','event','reference','sorptivity'}
  assert {k for k in oo if oo[k]!=rb[k]}==(scratch if i==1 else scratch-{'event'})
  assert oo['controls'][0]==rb['controls'][0] and oo['controls'][2:7]==rb['controls'][2:7] and rb['controls'][1]==ta[i-1][3] and rb['controls'][7]==1
  assert {k for k in co if co[k]!=cr[k]}==({'thtsrprefdmcp','sorpdmcp','vlmpdycp','subsidcp'} if i==1 else {'thtsrprefdmcp','sorpdmcp','vlmpdycp','subsidcp','dt'})
  assert co['timabscumdmcp']==cr['timabscumdmcp']
  changes=[]
  for key in ['thtsrprefdmcp','sorpdmcp']:
   for k,(a,b) in enumerate(zip(co[key],cr[key])):
    if a!=b:
     assert co['timabscumdmcp'][k]==cr['timabscumdmcp'][k]==0
     changes.append(dict(field=key,domain=k%5+1,node=k//5+1,before=a,after=b,tau=0))
  assert {(v['domain'],v['node']) for v in changes}=={(4,49),(3,50)}
  for name in ['ledger_begin_'+str(i),'ledger_returned_'+str(i),'ledger_rollback_'+str(i),'ledger_begin_'+str(i+1)]:assert (t/(name+'.txt')).read_bytes()==(t/'ledger_origin.txt').read_bytes()
  rollback.append(dict(attempt=i,positive_CONTACT47_evaluations=len(active),provider_evaluations=sum(v[0]==i for v in pp),returned_cache_increment=x[2],cache_invalid_and_cleared_after_rollback=True,water_core_and_active_event_history_restored=True,inactive_history_initializations_not_byte_restored=changes))
 assert rollback[0]['returned_cache_increment']>0
 assert not (t/'feedback48_trace.txt').exists() and not (d/'feedback48_trace.txt').exists() # No rejected reference increment committed; final small does not activate CONTACT47.
 pr1=rows(d1/'provider49_trace.txt');rr1=rows(d1/'feedback48_trace.txt');assert len(pr1)==42 and all(x[8]>0 for x in pr1) and len(rr1)==1
 results.append(dict(optimization=opt,D1=dict(accepted_iterations=12,positive_CONTACT47_evaluations=42,reference_increment=rr1[0][7],max_residual=a1[0][18],inventory=inv(d1,'begin_1',a1[0])),D2=dict(original_attempt=3066,original_time=ta[0][2],large_dt_days=ta[0][3],large_max_residual=ta[0][18],large_sum_residual=ta[0][17],real_active_MAXIT30_refusals=3,rollback=rollback,first_smaller_dt_days=ta[1][3],direct_first_smaller_also_refuses=True,entire_smaller_solver_and_provider_suffix_exact=True,final_dt_days=ta[-1][3],final_iterations=3,final_max_residual=ta[-1][18],final_CONTACT47_increment_inactive=True,committed_t1900=f(t/'committed.txt')['controls'][0],TRIAL_inventory=inv(t,'begin_4',ta[-1]),DIRECT_inventory=inv(d,'begin_3',da[-1]),full_native_immediate_byte_rollback=False)))
 for profile in ['TRIAL_D1','TRIAL_D2','DIRECT_D2']:
  q=json.loads((R/(opt+'_'+profile+'_RUN.json')).read_text());assert q['returncode']==0 and not q['censored'] and q['seconds']<20 and 'TARGET_RETRY_HOST_COMMITTED' in (root/profile/'outcome.txt').read_text()
  runs.append(dict(optimization=opt,profile=profile,seconds=q['seconds']))
 ident=json.loads((R/(opt+'_IDENTITY.json')).read_text());assert all(sha(R/n)==hh for n,hh in ident['sources'].items()) and sha(W/opt/'native09.exe')==ident['exe_sha256']
exceptions=[]
for profile in ['TRIAL_D1','TRIAL_D2','DIRECT_D2']:
 d0=R/'data/O0'/profile;d2=R/'data/O2'/profile
 for p in d0.glob('*.txt'):
  if p.name in ['cost_trace.txt','attempt_trace.txt']:continue
  if p.read_bytes()!=(d2/p.name).read_bytes():
   assert profile=='TRIAL_D1' and p.name=='contact43_trace.txt'
   aa=rows(p);bb=rows(d2/p.name)
   for x,y in zip(aa,bb):
    assert x[:14]==y[:14] and x[15:]==y[15:] and x[13]==y[13]==0 and x[16]==y[16]==1
    assert x[14]==0 and math.isfinite(y[14]) and abs(y[14])<2.2250738585072014e-308
   exceptions.append(dict(profile=profile,file=p.name,field_zero_based=14,name='inactive SorpFac',rows=len(aa)))
 assert [x[:-1] for x in rows(d0/'attempt_trace.txt')]==[x[:-1] for x in rows(d2/'attempt_trace.txt')]
 assert sha(d0/'own.end')==sha(d2/'own.end')=='21bd728c9983d6a0d4e82d6b2fd12729dc02284277a5dab5d296d8edc1dcbf16'
assert not (R/'data/O0/DIRECT_D1').exists()
q=dict(work_unit='SWAP431-MACRO-B1-SELECT50',decision='PASS_ACTIVE_CONTACT47_REFUSAL_CACHE_DISCARD_AND_DIRECT_RETRY_SUFFIX_EQUIVALENCE_WITH_INACTIVE_HISTORY_ROLLBACK_LIMIT',baseline='da27aad15a69ea40bf898e392e92d14c3b5969f6',source_checkpoint='c8cacc16a',model_routes=6,hard_seconds_per_route=20,internal_seconds=16,FEEDBACK48_physics_reference_clock_solver_policy_unchanged=True,active_refusal_witness_found=True,O0_O2_physical_solver_commit_ledger_budget_exact=True,O0_O2_all_nontiming_diagnostics_byte_exact=False,diagnostic_exceptions=exceptions,rejected_CONTACT47_increment_not_committed=True,full_native_or_inactive_history_byte_rollback_qualified=False,selection_stopped_at_first_paired_witness=True,full_period_restart_general_admission=False,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',official_promotion=False,results=results,runs=runs)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8');print(json.dumps(q,indent=2))
