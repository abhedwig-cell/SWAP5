"""Read-only exact GEOMETRY53 origin restoration and direct retry qualification."""
from pathlib import Path
import json,math,hashlib,re,collections
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-geometry53';W=Path('C:/Users/Veldh012/swap431-georestore54-work/native')
def rows(p):return [list(map(float,l.split())) for l in p.read_text().splitlines()]
def f(p):return {l.split()[0].lower():list(map(float,l.split()[1:])) for l in p.read_text().splitlines()}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
patch=(R/'IMPLEMENTATION.patch').read_text()
for p in P.glob('*.f90'):
 s=(R/p.name).read_text()
 if '+++ GEORESTORE54/'+p.name+'\n' in patch:
  section=patch.split('+++ GEORESTORE54/'+p.name+'\n',1)[1].split('--- GEOMETRY53/',1)[0]
  for h in re.split(r'@@[^\n]*\n',section)[1:]:
   ls=h.splitlines(True);old=''.join(x[1:] for x in ls if x[:1] in [' ','-']);new=''.join(x[1:] for x in ls if x[:1] in [' ','+']);assert s.count(new)==1;s=s.replace(new,old,1)
 assert s==p.read_text(),p.name
 assert p.name=='macropore_native.f90' or p.read_bytes()==(R/p.name).read_bytes()
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
 root=R/'data'/opt;t=root/'TRIAL_D2';d=root/'DIRECT_D2';old=P/'data'/opt/'TRIAL_D2'
 ta=rows(t/'attempt_trace.txt');da=rows(d/'attempt_trace.txt');oa=rows(old/'attempt_trace.txt')
 assert len(ta)==4 and len(da)==3 and [x[:-1] for x in ta]==[x[:-1] for x in oa]
 assert [x[2:-1] for x in ta[1:]]==[x[2:-1] for x in da]
 assert all(x[7]==31 and x[9]==1 and x[6]==1 and x[25]==0 for x in ta[:3]) and ta[-1][7]==3 and ta[-1][25]==1
 assert all(ta[i][3]==ta[i-1][3]/3 for i in [1,2,3])
 for name in ['origin','context_origin','ledger_origin','prefix_budget']:
  assert (t/(name+'.txt')).read_bytes()==(old/(name+'.txt')).read_bytes()==(d/(name+'.txt')).read_bytes()
 for name in ['accepted_return','context_accepted_return','ledger_accepted_return','committed','context_committed','ledger_committed','step_budget']:
  assert (t/(name+'.txt')).read_bytes()==(d/(name+'.txt')).read_bytes()
  assert (t/(name+'.txt')).read_bytes()==(old/(name+'.txt')).read_bytes()
 for i in range(1,4):assert (t/('solver_'+str(i+1)+'.txt')).read_bytes()==(d/('solver_'+str(i)+'.txt')).read_bytes()
 pp=rows(t/'provider49_trace.txt');pd=rows(d/'provider49_trace.txt');assert pp==rows(old/'provider49_trace.txt')
 assert [x[1:] for x in pp if x[0]>=2]==[x[1:] for x in pd]
 rollback=[]
 for mode,dd,nfail in [('TRIAL',t,3),('DIRECT',d,2)]:
  base=f(dd/'context_origin.txt');water=f(dd/'origin.txt')
  for i in range(1,nfail+1):
   rb=f(dd/('context_rollback_'+str(i)+'.txt'));iv=f(dd/('rollback_'+str(i)+'.txt'))
   for k in ['vlmpdycp','subsidcp','thtsrprefdmcp','sorpdmcp','timabscumdmcp','awlcorfac']:assert base[k]==rb[k],(opt,mode,i,k)
   different={k for k in base if base[k]!=rb[k]};expected={'dt'} if mode=='DIRECT' or i>1 else set();assert different==expected
   if not expected:assert (dd/'context_origin.txt').read_bytes()==(dd/('context_rollback_'+str(i)+'.txt')).read_bytes()
   assert {k for k in water if water[k]!=iv[k]}<={'controls','macro_exchange','macro_rapid','matrix_exchange','boundary_rates','event'}
   assert rows(dd/('cache_rollback_'+str(i)+'.txt'))[0][:3]==[0,0,0]
   for name in ['ledger_begin_'+str(i),'ledger_returned_'+str(i),'ledger_rollback_'+str(i),'ledger_begin_'+str(i+1)]:assert (dd/(name+'.txt')).read_bytes()==(dd/'ledger_origin.txt').read_bytes()
   nxt=f(dd/('context_begin_'+str(i+1)+'.txt'));assert all(base[k]==nxt[k] for k in ['vlmpdycp','subsidcp','thtsrprefdmcp','sorpdmcp','timabscumdmcp','awlcorfac'])
   if mode=='TRIAL':rollback.append(dict(attempt=i,positive_CONTACT47_evaluations=sum(x[0]==i and x[8]>0 for x in pp),entire_dynamic_volume_and_subsidence_exact_origin=True,entire_sorption_and_clock_arrays_exact_origin=True,native_context_dump_differences=sorted(different),CONTACT47_cache_invalid_empty=True,ledger_unchanged=True))
 assert [x['positive_CONTACT47_evaluations'] for x in rollback]==[119,68,52]
 gt=rows(t/'geometry53_trace.txt');gd=rows(d/'geometry53_trace.txt');assert len(gt)==200 and len(gd)==150
 assert [x[1:] for x in gt if x[0]>=2]==[x[1:] for x in gd]
 for dd,gg,heads in [(t,gt,4),(d,gd,3)]:
  base=f(dd/'context_origin.txt')
  for i in range(1,heads+1):
   frame=[x for x in gg if x[0]==i];begin=f(dd/('context_begin_'+str(i)+'.txt'));assert len(frame)==50 and sum(x[15]==1 for x in frame)==43
   for j,x in enumerate(frame):
    assert x[1:4]==[0,1,1] and x[16]==begin['vlmpdycp'][j]==base['vlmpdycp'][j] and x[17]==begin['subsidcp'][j]==base['subsidcp'][j]
    assert x[13]==x[16] and x[12]==(x[16] if j==0 else frame[j-1][18]) and x[14]==base['vlmpdycp'][j+1]
    eligible=x[6]!=0 and x[7]<x[9]-1e-4;branch=(1 if x[7]>x[8]-1e-8 and (x[13]>0 or x[12]+x[14]>0) else 2) if eligible else -1
    assert x[15]==branch
 # Old 43-node first-smaller discrepancy has disappeared, without clamping tiny origin values.
 first=[x for x in gt if x[0]==2 and x[4]==1][0];assert first[13]==1.7347234759768071e-18 and first[15]==1
 assert not (t/'feedback48_trace.txt').exists() and not (d/'feedback48_trace.txt').exists()
 results.append(dict(optimization=opt,original_D2_prefix_origin_exact=True,true_active_unscaled_MAXIT30_refusals=3,rollback=rollback,first_smaller_dt=ta[1][3],all_smaller_first_provider_geometry_frames_exact_DIRECT=True,remaining_first_smaller_branch_discrepancies=0,first_node_positive_origin_retained=first[13],all_smaller_solver_provider_suffix_exact=True,accepted_committed_context_ledger_budget_exact=True,final_dt=ta[-1][3],final_iterations=3,final_max_residual=ta[-1][18],final_time=f(t/'committed.txt')['controls'][0],TRIAL_inventory=inv(t,'begin_4',ta[-1]),DIRECT_inventory=inv(d,'begin_3',da[-1]),general_full_native_restart_or_all_work_arrays_not_qualified=True))
 for mode in ['TRIAL','DIRECT']:
  q=json.loads((R/(opt+'_'+mode+'_D2_RUN.json')).read_text());assert q['returncode']==0 and not q['censored'] and q['seconds']<20
  dd=root/(mode+'_D2');assert 'TARGET_RETRY_HOST_COMMITTED' in (dd/'outcome.txt').read_text();cost=rows(dd/'cost_trace.txt')[-1];assert cost[-1]<16
  runs.append(dict(optimization=opt,mode=mode,seconds=q['seconds'],terminal_internal_elapsed_seconds=cost[-1]))
 ident=json.loads((R/(opt+'_IDENTITY.json')).read_text());assert all(sha(R/n)==hh for n,hh in ident['sources'].items()) and sha(W/opt/'native09.exe')==ident['exe_sha256']
for mode in ['TRIAL','DIRECT']:
 d0=R/'data/O0'/(mode+'_D2');d2=R/'data/O2'/(mode+'_D2')
 for p in d0.glob('*.txt'):
  if p.name not in ['cost_trace.txt','attempt_trace.txt']:assert p.read_bytes()==(d2/p.name).read_bytes(),(mode,p.name)
 assert [x[:-1] for x in rows(d0/'attempt_trace.txt')]==[x[:-1] for x in rows(d2/'attempt_trace.txt')]
 assert sha(d0/'own.end')==sha(d2/'own.end')=='21bd728c9983d6a0d4e82d6b2fd12729dc02284277a5dab5d296d8edc1dcbf16'
q=dict(work_unit='SWAP431-MACRO-B1-GEORESTORE54',decision='PASS_GEOMETRY53_EXACT_ORIGIN_GEOMETRY_ROLLBACK_AND_DIRECT_SMALLER_RETRY_D2_O0_O2',baseline='7c4e746cb53b65213f4ab1586009c7ce6973bae3',source_checkpoint='1a44f9e97',model_routes=4,hard_seconds_per_route=20,internal16_policy_unchanged=True,clock_physical_geometry_laws_solver_guards_limits_dt_reduction_budget_rules_unchanged=True,new_native_persistent_fields=False,exact_native_context_dump_restored_except_expected_retry_dt_in_this_D2=True,O0_O2_non_timing_byte_exact=True,geometry_first_smaller_branch_discrepancy_resolved=True,no_broad_campaign=True,general_full_native_restart_period_or_all_work_arrays_admitted=False,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',official_promotion=False,results=results,runs=runs)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8');print(json.dumps(q,indent=2))
