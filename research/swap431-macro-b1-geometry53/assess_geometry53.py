"""Read-only exact geometry contract and actual first-provider branch audit."""
from pathlib import Path
import json,math,hashlib,re,collections
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-restore52';W=Path('C:/Users/Veldh012/swap431-geometry53-work/native')
def rows(p):return [list(map(float,l.split())) for l in p.read_text().splitlines()]
def f(p):return {l.split()[0].lower():list(map(float,l.split()[1:])) for l in p.read_text().splitlines()}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
patch=(R/'OBSERVATION.patch').read_text()
for p in P.glob('*.f90'):
 s=(R/p.name).read_text()
 if '+++ GEOMETRY53/'+p.name+'\n' in patch:
  section=patch.split('+++ GEOMETRY53/'+p.name+'\n',1)[1].split('--- RESTORE52/',1)[0]
  for h in re.split(r'@@[^\n]*\n',section)[1:]:
   ls=h.splitlines(True);old=''.join(x[1:] for x in ls if x[:1] in [' ','-']);new=''.join(x[1:] for x in ls if x[:1] in [' ','+']);assert s.count(new)==1;s=s.replace(new,old,1)
 assert s==p.read_text(),p.name
results=[];runs=[]
for opt in ['O0','O2']:
 root=R/'data'/opt;t=root/'TRIAL_D2';d=root/'DIRECT_D2'
 for mode,dd,heads in [('TRIAL',t,4),('DIRECT',d,3)]:
  parent=P/'data'/opt/(mode+'_D2');a=rows(dd/'attempt_trace.txt');g=rows(dd/'geometry53_trace.txt')
  assert len(a)==heads and len(g)==heads*50 and all(len(x)==20 and x[1:4]==[0,1,1] for x in g)
  for p in parent.glob('*.txt'):
   if p.name not in ['cost_trace.txt','attempt_trace.txt']:assert p.read_bytes()==(dd/p.name).read_bytes(),(opt,mode,p.name)
  assert [x[:-1] for x in a]==[x[:-1] for x in rows(parent/'attempt_trace.txt')]
  for i in range(1,heads+1):
   gg=[x for x in g if x[0]==i];base=f(dd/('context_begin_'+str(i)+'.txt'))
   assert [x[4] for x in gg]==list(range(1,51))
   for j,x in enumerate(gg):
    assert x[16]==base['vlmpdycp'][j] and x[17]==base['subsidcp'][j] and x[13]==x[16]
    assert x[12]==(x[16] if j==0 else gg[j-1][18]) and x[14]==base['vlmpdycp'][j+1]
    eligible=x[6]!=0 and x[7]<x[9]-1e-4
    expected=(1 if x[7]>x[8]-1e-8 and (x[13]>0 or x[12]+x[14]>0) else 2) if eligible else -1
    assert x[15]==expected and x[18]==0
  q=json.loads((R/(opt+'_'+mode+'_D2_RUN.json')).read_text());assert q['returncode']==0 and not q['censored'] and q['seconds']<20
  assert 'TARGET_RETRY_HOST_COMMITTED' in (dd/'outcome.txt').read_text()
  cost=rows(dd/'cost_trace.txt')[-1];assert cost[-1]<16
  runs.append(dict(optimization=opt,mode=mode,seconds=q['seconds'],terminal_internal_elapsed_seconds=cost[-1]))
 co=f(t/'context_origin.txt');viol=[]
 for i in [1,2,3]:
  rb=f(t/('context_rollback_'+str(i)+'.txt'))
  for key in ['thtsrprefdmcp','sorpdmcp','timabscumdmcp','awlcorfac']:assert co[key]==rb[key]
  v={}
  for key,n in [('vlmpdycp',48),('subsidcp',44)]:
   dd=[(j+1,x,y) for j,(x,y) in enumerate(zip(co[key],rb[key])) if x!=y];assert len(dd)==n
   v[key]=dict(changed_nodes=len(dd),nodes=[x[0] for x in dd],max_absolute_difference=max(abs(y-x) for j,x,y in dd))
  assert {k for k in co if co[k]!=rb[k]}==({'vlmpdycp','subsidcp'} if i==1 else {'vlmpdycp','subsidcp','dt'})
  assert rows(t/('cache_rollback_'+str(i)+'.txt'))[0][:3]==[0,0,0]
  assert (t/('ledger_rollback_'+str(i)+'.txt')).read_bytes()==(t/'ledger_origin.txt').read_bytes()
  viol.append(dict(rollback=i,fields=v))
 gt=rows(t/'geometry53_trace.txt');gd=rows(d/'geometry53_trace.txt');comparison=[]
 for i in [2,3,4]:
  aa=[x for x in gt if x[0]==i];bb=[x for x in gd if x[0]==i-1]
  assert all(x[1:12]==y[1:12] for x,y in zip(aa,bb)) # Same theta/origin theta and physical parameters.
  changes=[int(x[4]) for x,y in zip(aa,bb) if x[15]!=y[15]]
  assert len(changes)==(43 if i==2 else 0)
  subdiff=max(abs(x[19]-y[19]) for x,y in zip(aa,bb));assert subdiff>5e-4 if i==2 else subdiff==0
  comparison.append(dict(TRIAL_attempt=i,DIRECT_attempt=i-1,same_theta_thetaM1_and_parameters=True,branch_differences=len(changes),changed_nodes=changes,max_post_Aloop_dynamic_volume_difference=max(abs(x[18]-y[18]) for x,y in zip(aa,bb)),max_post_Aloop_subsidence_difference_cm=subdiff))
 # Existing physical operator outputs and full accepted continuation remain equal despite transient A-loop difference.
 ta=rows(t/'attempt_trace.txt');da=rows(d/'attempt_trace.txt');assert [x[2:-1] for x in ta[1:]]==[x[2:-1] for x in da]
 for i in [1,2,3]:assert (t/('solver_'+str(i+1)+'.txt')).read_bytes()==(d/('solver_'+str(i)+'.txt')).read_bytes()
 for n in ['origin','context_origin','ledger_origin','prefix_budget','accepted_return','context_accepted_return','ledger_accepted_return','committed','context_committed','ledger_committed','step_budget']:assert (t/(n+'.txt')).read_bytes()==(d/(n+'.txt')).read_bytes()
 ident=json.loads((R/(opt+'_IDENTITY.json')).read_text());assert all(sha(R/n)==hh for n,hh in ident['sources'].items()) and sha(W/opt/'native09.exe')==ident['exe_sha256']
 results.append(dict(optimization=opt,current_exact_geometry_origin_rollback_pass=False,rollback_differences=viol,actual_first_provider_history_branch_reconstructed=True,inplace_previous_cell_update_verified=True,TRIAL_geometry_rows=200,DIRECT_geometry_rows=150,retry_direct_first_provider_geometry_comparison=comparison,old_solver_state_ledger_inventory_outputs_parent_exact=True,RESTORE52_sorption_and_clock_restoration_retained=True,all_observed_first_Aloop_dynamic_volumes_zero=True,remaining_dynamic_geometry_rollback_contract_open=True))
for mode in ['TRIAL','DIRECT']:
 d0=R/'data/O0'/(mode+'_D2');d2=R/'data/O2'/(mode+'_D2')
 for p in d0.glob('*.txt'):
  if p.name not in ['cost_trace.txt','attempt_trace.txt']:assert p.read_bytes()==(d2/p.name).read_bytes(),(mode,p.name)
 assert [x[:-1] for x in rows(d0/'attempt_trace.txt')]==[x[:-1] for x in rows(d2/'attempt_trace.txt')]
q=dict(work_unit='SWAP431-MACRO-B1-GEOMETRY53',decision='GEOMETRY_ROLLBACK_CONTRACT_DELINEATED_HISTORY_READ_BEFORE_WRITE_CONFIRMED_CURRENT_EXACT_RESTORE_FAILS_O0_O2',baseline='7eb323c228533b77d0ef8ba55d6589726b8adf58',source_checkpoint='799f5c1a1',model_routes=4,hard_seconds_per_route=20,internal16_policy_unchanged=True,no_physics_geometry_rollback_clock_solver_budget_changes=True,geometry_repair_implemented=False,minimal_future_origin_snapshots=['VlMpDyCp(1:NumNod)','SubsidCp(1:NumNod)'],new_native_format_required=False,O0_O2_non_timing_byte_exact=True,no_general_reconstructibility_or_harmless_roundoff_claim=True,no_broad_campaign=True,full_native_restart_or_period_admission=False,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',official_promotion=False,results=results,runs=runs)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8');print(json.dumps(q,indent=2))
