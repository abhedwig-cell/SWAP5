"""Read-only two-array origin rollback and direct D2 suffix qualification."""
from pathlib import Path
import json,math,hashlib,re
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-inactive51';B=R.parent/'swap431-macro-b1-select50';W=Path('C:/Users/Veldh012/swap431-restore52-work/native')
def rows(p):return [list(map(float,l.split())) for l in p.read_text().splitlines()]
def f(p):return {l.split()[0].lower():list(map(float,l.split()[1:])) for l in p.read_text().splitlines()}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for root in [R,R/'initial_always_clear']:
 patch=(root/'IMPLEMENTATION.patch').read_text()
 for p in P.glob('*.f90'):
  s=(root/p.name).read_text()
  if '+++ RESTORE52/'+p.name+'\n' in patch:
   section=patch.split('+++ RESTORE52/'+p.name+'\n',1)[1].split('--- INACTIVE51/',1)[0]
   for h in re.split(r'@@[^\n]*\n',section)[1:]:
    ls=h.splitlines(True);old=''.join(x[1:] for x in ls if x[:1] in [' ','-']);new=''.join(x[1:] for x in ls if x[:1] in [' ','+']);assert s.count(new)==1;s=s.replace(new,old,1)
  assert s==p.read_text(),(root.name,p.name)
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

results=[];runs=[];initial=[]
for opt in ['O0','O2']:
 t=R/'data'/opt/'TRIAL_D2';d=R/'data'/opt/'DIRECT_D2';old=P/'data'/opt/'TRIAL_D2'
 ta=rows(t/'attempt_trace.txt');da=rows(d/'attempt_trace.txt');oa=rows(old/'attempt_trace.txt')
 assert len(ta)==4 and len(da)==3 and [x[:-1] for x in ta]==[x[:-1] for x in oa]
 assert [x[2:-1] for x in ta[1:]]==[x[2:-1] for x in da]
 assert all(x[9]==1 and x[7]==31 and x[6]==1 and x[25]==0 for x in ta[:3]) and ta[-1][7]==3 and ta[-1][25]==1
 assert all(ta[i][3]==ta[i-1][3]/3 for i in [1,2,3])
 for name in ['origin','context_origin','ledger_origin','prefix_budget']:
  assert (t/(name+'.txt')).read_bytes()==(old/(name+'.txt')).read_bytes()==(d/(name+'.txt')).read_bytes()
 for name in ['accepted_return','context_accepted_return','ledger_accepted_return','committed','context_committed','ledger_committed','step_budget']:
  assert (t/(name+'.txt')).read_bytes()==(d/(name+'.txt')).read_bytes()
  if name not in ['accepted_return','context_accepted_return']:assert (t/(name+'.txt')).read_bytes()==(old/(name+'.txt')).read_bytes()
 for name,changed in [('accepted_return',{'reference','sorptivity'}),('context_accepted_return',{'thtsrprefdmcp','sorpdmcp'})]:
  now=f(t/(name+'.txt'));before=f(old/(name+'.txt'));assert {k for k in now if now[k]!=before[k]}==changed

 for i in range(1,4):assert (t/('solver_'+str(i+1)+'.txt')).read_bytes()==(d/('solver_'+str(i)+'.txt')).read_bytes()
 pp=rows(t/'provider49_trace.txt');pd=rows(d/'provider49_trace.txt')
 assert [x[1:] for x in pp if x[0]>=2]==[x[1:] for x in pd] and pp==rows(old/'provider49_trace.txt')
 co=f(t/'context_origin.txt');oo=f(t/'origin.txt');rollbacks=[]
 for dd,nfail in [(t,3),(d,2)]:
  base=f(dd/'context_origin.txt');baseinv=f(dd/'origin.txt')
  for i in range(1,nfail+1):
   rb=f(dd/('context_rollback_'+str(i)+'.txt'));v=f(dd/('rollback_'+str(i)+'.txt'))
   for key in ['thtsrprefdmcp','sorpdmcp','timabscumdmcp','awlcorfac']:assert base[key]==rb[key],(opt,dd.name,i,key)
   expected={'vlmpdycp','subsidcp'}|({'dt'} if dd==d or i>1 else set())
   assert {k for k in base if base[k]!=rb[k]}==expected
   assert {k for k in baseinv if baseinv[k]!=v[k]}<= {'controls','macro_exchange','macro_rapid','matrix_exchange','boundary_rates','event'}
   cache=rows(dd/('cache_rollback_'+str(i)+'.txt'))[0];assert cache[:3]==[0,0,0]
   for name in ['ledger_begin_'+str(i),'ledger_returned_'+str(i),'ledger_rollback_'+str(i),'ledger_begin_'+str(i+1)]:assert (dd/(name+'.txt')).read_bytes()==(dd/'ledger_origin.txt').read_bytes()
   # Visible unchanged pre-head origin in the smaller retry after restoring inactive fields.
   nxt=f(dd/('context_begin_'+str(i+1)+'.txt'))
   assert all(base[k]==nxt[k] for k in ['thtsrprefdmcp','sorpdmcp','timabscumdmcp','awlcorfac'])
   if dd==t:rollbacks.append(dict(attempt=i,positive_CONTACT47_evaluations=sum(x[0]==i and x[8]>0 for x in pp),reference_entire_array_exact=True,initial_sorptivity_entire_array_exact=True,clock_entire_array_exact=True,AwlCorFac_exact=True,CONTACT47_cache_invalid_empty=True,ledger_unchanged=True,remaining_native_differences=sorted(expected)))
 assert [x['positive_CONTACT47_evaluations'] for x in rollbacks]==[119,68,52]
 # Observe overwrite-before-use and show only prior temporary initializations changed relative to INACTIVE51.
 rr=rows(t/'inactive51_trace.txt');ro=rows(old/'inactive51_trace.txt');assert len(rr)==len(ro)==614
 assert [[v for j,v in enumerate(x) if j not in [9,10]] for x in rr]==[[v for j,v in enumerate(x) if j not in [9,10]] for x in ro]
 assert any(x[9:11]!=y[9:11] for x,y in zip(rr,ro))
 assert not (t/'feedback48_trace.txt').exists() and not (d/'feedback48_trace.txt').exists()
 results.append(dict(optimization=opt,original_D2_prefix_origin_exact=True,true_active_unscaled_MAXIT_refusals=3,rollbacks=rollbacks,first_smaller_dt=ta[1][3],direct_smaller_solver_and_provider_suffix_exact=True,accepted_committed_inventory_context_ledger_budget_exact=True,final_dt=ta[-1][3],final_iterations=3,final_max_residual=ta[-1][18],final_time=f(t/'committed.txt')['controls'][0],TRIAL_inventory=inv(t,'begin_4',ta[-1]),DIRECT_inventory=inv(d,'begin_3',da[-1]),full_native_geometry_scratch_byte_restored=False))
 for mode in ['TRIAL','DIRECT']:
  q=json.loads((R/(opt+'_'+mode+'_D2_RUN.json')).read_text());assert q['returncode']==0 and not q['censored'] and q['seconds']<20
  assert 'TARGET_RETRY_HOST_COMMITTED' in (R/'data'/opt/(mode+'_D2')/'outcome.txt').read_text()
  cost=rows(R/'data'/opt/(mode+'_D2')/'cost_trace.txt')[-1];assert cost[-1]<16
  runs.append(dict(optimization=opt,mode=mode,seconds=q['seconds'],terminal_internal_elapsed_seconds=cost[-1]))
 ident=json.loads((R/(opt+'_IDENTITY.json')).read_text());assert all(sha(R/n)==hh for n,hh in ident['sources'].items()) and sha(W/opt/'native09.exe')==ident['exe_sha256']
 st=R/'initial_always_clear';sd=st/'data'/opt/'TRIAL_D2';si=json.loads((st/(opt+'_IDENTITY.json')).read_text());assert all(sha(st/n)==hh for n,hh in si['sources'].items()) and sha(W/opt/'native_initial52.exe')==si['exe_sha256']
 qr=json.loads((st/(opt+'_TRIAL_D2_RUN.json')).read_text());assert qr['returncode']==0 and not qr['censored'] and qr['seconds']<20
 if opt=='O0':
  assert 'INTERNAL16_ORIGINAL_PREFIX_LIMIT' in (sd/'outcome.txt').read_text() and not (sd/'context_origin.txt').exists()
  part=(sd/'prefix_budget.txt').read_text().splitlines();full=(t/'prefix_budget.txt').read_text().splitlines();assert part==full[:len(part)]
 else:
  for p in sd.glob('*.txt'):
   if p.name not in ['cost_trace.txt','attempt_trace.txt']:assert p.read_bytes()==(t/p.name).read_bytes(),p.name
 initial.append(dict(optimization=opt,seconds=qr['seconds'],D2_completed=opt=='O2',outcome=(sd/'outcome.txt').read_text().strip(),retained=True))
for profile in ['TRIAL_D2','DIRECT_D2']:
 d0=R/'data/O0'/profile;d2=R/'data/O2'/profile
 for p in d0.glob('*.txt'):
  if p.name not in ['cost_trace.txt','attempt_trace.txt']:assert p.read_bytes()==(d2/p.name).read_bytes(),(profile,p.name)
 assert [x[:-1] for x in rows(d0/'attempt_trace.txt')]==[x[:-1] for x in rows(d2/'attempt_trace.txt')]
 assert sha(d0/'own.end')==sha(d2/'own.end')=='21bd728c9983d6a0d4e82d6b2fd12729dc02284277a5dab5d296d8edc1dcbf16'
q=dict(work_unit='SWAP431-MACRO-B1-RESTORE52',decision='PASS_INACTIVE51_EXACT_TWO_ARRAY_HISTORY_ROLLBACK_AND_DIRECT_SMALLER_RETRY_SAME_ORIGINAL_D2_O0_O2',baseline='7bc7ac98a86cfd3b87c0ae7641dd9b70dcb78049',source_checkpoint='bc2912fb9',initial_source_checkpoint='33ba1d067',model_routes_total=6,final_postimage_routes=4,initial_budget_limited_route_retained=True,external_hard_seconds=20,internal16_policy_unchanged=True,clock_physical_flux_laws_solver_limits_dt_reduction_budget_rules_unchanged=True,new_native_persistent_fields=False,O0_O2_non_timing_byte_exact=True,CONTACT47_empty_clear_optimization_equivalent_in_observed_D2=True,no_broad_campaign=True,full_native_geometry_rollback_or_new_restart_admission=False,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',official_promotion=False,results=results,final_runs=runs,initial_runs=initial)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8');print(json.dumps(q,indent=2))
