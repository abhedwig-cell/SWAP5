"""Read-only delineation: exact saved history vs recomputed provisional initialization."""
from pathlib import Path
import json,math,hashlib,re,zipfile,collections
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-select50';W=Path('C:/Users/Veldh012/swap431-inactive51-work/native')
def rows(p):return [list(map(float,l.split())) for l in p.read_text().splitlines()]
def fields(p):return {l.split()[0].lower():list(map(float,l.split()[1:])) for l in p.read_text().splitlines()}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
# Bind inherited direct evidence to sealed parent, not an unversioned remembered PASS.
evidence=json.loads((P/'EVIDENCE.json').read_text());assert sha(P/evidence['file'])==evidence['sha256']
with zipfile.ZipFile(P/evidence['file']) as z:
 m={x['path']:x for x in json.loads(z.read('manifest.json'))};assert sha(P/'RESULT.json')==m['research/RESULT.json']['sha256']
parent=json.loads((P/'RESULT.json').read_text());assert parent['active_refusal_witness_found'] and parent['O0_O2_physical_solver_commit_ledger_budget_exact']
patch=(R/'OBSERVATION.patch').read_text()
for p in P.glob('*.f90'):
 s=(R/p.name).read_text()
 if '+++ INACTIVE51/'+p.name+'\n' in patch:
  section=patch.split('+++ INACTIVE51/'+p.name+'\n',1)[1].split('--- SELECT50/',1)[0]
  for h in re.split(r'@@[^\n]*\n',section)[1:]:
   ls=h.splitlines(True);old=''.join(x[1:] for x in ls if x[:1] in [' ','-']);new=''.join(x[1:] for x in ls if x[:1] in [' ','+']);assert s.count(new)==1;s=s.replace(new,old,1)
 assert s==p.read_text(),p.name
results=[]
for opt in ['O0','O2']:
 d=R/'data'/opt/'TRIAL_D2';old=P/'data'/opt/'TRIAL_D2';a=rows(d/'attempt_trace.txt');receipt=rows(d/'inactive51_trace.txt')
 for p in old.glob('*.txt'):
  if p.name not in ['attempt_trace.txt','cost_trace.txt']:assert p.read_bytes()==(d/p.name).read_bytes(),p.name
 assert [x[:-1] for x in a]==[x[:-1] for x in rows(old/'attempt_trace.txt')]
 assert len(a)==4 and all(x[7]==31 and x[9]==1 and x[6]==1 for x in a[:3]) and a[-1][7]==3 and a[-1][25]==1
 assert len(receipt)==614 and all(len(x)==19 and x[8]==0 and x[11]==x[14] and x[12]==x[13] for x in receipt)
 counts=collections.Counter((int(x[0]),int(x[4]),int(x[5])) for x in receipt)
 assert dict(counts)=={(1,3,50):119,(1,4,49):123,(2,3,50):68,(2,4,49):136,(3,3,50):54,(3,4,49):106,(4,4,49):8}
 for x in receipt:
  assert x[6:8]==a[int(x[0])-1][2:4]
  expected=x[17]*(max(0.,x[14]-x[15])/(x[14]-x[16]))**x[18]
  assert expected==x[12] and x[9] in [0,.444]
 assert sum(x[10]!=x[12] for x in receipt)==470
 assert all(x[11] in [0,.444] for x in receipt)
 origin=fields(d/'context_origin.txt');violations=[]
 for i in [1,2,3]:
  rollback=fields(d/('context_rollback_'+str(i)+'.txt'))
  assert origin['timabscumdmcp']==rollback['timabscumdmcp'] and origin['awlcorfac']==rollback['awlcorfac']
  cache=rows(d/('cache_rollback_'+str(i)+'.txt'))[0];assert cache[:3]==[0,0,0]
  for name in ['thtsrprefdmcp','sorpdmcp']:
   for j,(before,after) in enumerate(zip(origin[name],rollback[name])):
    if before!=after:
     assert origin['timabscumdmcp'][j]==rollback['timabscumdmcp'][j]==0
     violations.append(dict(rollback=i,field=name,domain=j%5+1,node=j//5+1,before=before,after=after,tau=0))
  assert (d/('ledger_rollback_'+str(i)+'.txt')).read_bytes()==(d/'ledger_origin.txt').read_bytes()
 assert len(violations)==12 and {(x['domain'],x['node']) for x in violations}=={(3,50),(4,49)}
 assert all(x['after']==.444 for x in violations if x['field']=='thtsrprefdmcp')
 assert not (d/'feedback48_trace.txt').exists()
 # The unchanged new TRIAL reproduces the sealed parent TRIAL, so its direct suffix proof is inherited.
 for n in ['accepted_return','context_accepted_return','ledger_accepted_return','committed','context_committed','ledger_committed','step_budget']:
  assert (d/(n+'.txt')).read_bytes()==(P/'data'/opt/'DIRECT_D2'/(n+'.txt')).read_bytes()
 for i in range(1,4):assert (d/('solver_'+str(i+1)+'.txt')).read_bytes()==(P/'data'/opt/'DIRECT_D2'/('solver_'+str(i)+'.txt')).read_bytes()
 run=json.loads((R/(opt+'_TRIAL_D2_RUN.json')).read_text());assert run['returncode']==0 and not run['censored'] and run['seconds']<20
 assert 'TARGET_RETRY_HOST_COMMITTED' in (d/'outcome.txt').read_text()
 ident=json.loads((R/(opt+'_IDENTITY.json')).read_text());assert all(sha(R/n)==hh for n,hh in ident['sources'].items()) and sha(W/opt/'native09.exe')==ident['exe_sha256']
 cost=rows(d/'cost_trace.txt')[-1]
 results.append(dict(optimization=opt,seconds=run['seconds'],complete_same_D2_chain=True,parent_all_nontiming_outputs_exact=True,event_start_receipts=614,receipt_counts=[dict(attempt=k[0],domain=k[1],node=k[2],count=v) for k,v in sorted(counts.items())],all_logged_tau_exactly_zero=True,all_references_overwritten_with_theta_s_before_sorption=True,all_initial_sorptivities_recomputed_exactly_before_use=True,old_sorptivity_value_changed_in_receipts=470,strict_inactive_history_rollback_contract_current_pass=False,history_contract_violations=violations,clock_AwlCorFac_and_active_history_unchanged=True,CONTACT47_cache_cleared_after_each_rollback=True,sealed_parent_direct_suffix_equivalence_inherited=True,internal_terminal_commit_elapsed_seconds=cost[-1],internal16_exceeded_at_terminal_commit=cost[-1]>=16))
for p in (R/'data/O0/TRIAL_D2').glob('*.txt'):
 if p.name not in ['attempt_trace.txt','cost_trace.txt']:assert p.read_bytes()==(R/'data/O2/TRIAL_D2'/p.name).read_bytes(),p.name
assert [x[:-1] for x in rows(R/'data/O0/TRIAL_D2/attempt_trace.txt')]==[x[:-1] for x in rows(R/'data/O2/TRIAL_D2/attempt_trace.txt')]
q=dict(work_unit='SWAP431-MACRO-B1-INACTIVE51',decision='ROLLBACK_CONTRACT_DELINEATED_EXACT_ORIGIN_REFERENCE_AND_INITIAL_SORPTIVITY_RESTORE_REQUIRED_CURRENT_IMPLEMENTATION_FAILS_STRICT_CONTRACT',baseline='f90b871d31a41f624d92abe1fb236c7395ed5015',source_checkpoint='3ec00a631',model_routes=2,external_hard_seconds=20,internal16_stop_policy_source_unchanged=True,internal16_is_not_strict_walltime_at_terminal_accepted_commit=True,physics_reference_clock_rollback_not_modified=True,O0_O2_non_timing_outputs_byte_exact=True,minimal_future_saved_arrays=['ThtSrpRefDmCp','SorpDmCp'],new_native_fields_required=False,rollback_repair_implemented=False,no_extra_provider_probe_or_context=True,full_native_restart_or_general_admission=False,B1_status='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',official_promotion=False,results=results)
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8');print(json.dumps(q,indent=2))
