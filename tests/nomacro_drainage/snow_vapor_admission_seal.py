"""Seal actual Snow vapor admission without changing neutral science."""
import argparse,hashlib,json,subprocess,zipfile
from pathlib import Path

HEAD='bd9426711347a1bd7694d39e5c65345db0e25406'
PARENT='49a0641cb836d044c14c7146761ccff480c2f262'
SYNTHETIC='9f4304da48b5ef807b1975f54d7e86c5b688d409'
TREE='ac441dfec13868e091058d0a512fab612f2ccdaf'
STATUS='BOUNDED_ORIGINAL_SNOW_ACTIVE_VAPOR_SOURCE_RAW_NATIVE_PASS'
NEGATIVES=(
 ('SOURCE','d40721b191f8c2a9c02742cfbf90dc5beaa1f0fd','app/hybrid_water/snow_vapor_composition.py','Unreviewed Snow vapor source delta'),
 ('RAW','08d44ebd158710b04aa8c3dae06ba27abe63ad57','integration/f-ci/nomacro-complete01/HYDRAULIC_SNOW_VAPOR_WINDOWS_RAW_V1.zip','AssertionError'),
 ('INHERITED','dd8108850981021c012024221492ee00ed59f5b8','integration/f-ci/nomacro-complete01/HYDRAULIC_DEFAULT_MODEL_GRAMMAR_ADMISSION_RAW_V1.zip','AssertionError'),
 ('PUBLICATION','1620b238f6bc146d280b83ff254e111c03595b1a','tests/publication/run_pub_p2e09_reference_threshold_freeze.sh','AssertionError'))
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


def main():
 p=argparse.ArgumentParser(description=__doc__)
 for key in ('repository','evidence'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--verify-only',action='store_true');a=p.parse_args();root=a.repository;ev=a.evidence;proof=root/'integration/f-ci/nomacro-complete01'
 git=lambda *args:subprocess.check_output(['git',*args],cwd=root,text=True).strip()
 load=lambda name:json.loads((ev/name).read_text(encoding='utf8'))
 merge=load('SNOW_VAPOR_PR1782_ACTUAL_MERGE_API_V2.json');canonical=merge['sha'];assert merge['merged'] is True
 for commit in (canonical,SYNTHETIC):assert git('show','-s','--format=%P',commit).split()==[PARENT,HEAD]
 assert all(git('rev-parse',commit+'^{tree}')==TREE for commit in (HEAD,canonical,SYNTHETIC))
 files={};observations={}
 cases=[('SNOW_VAPOR_FINAL_CANDIDATE_PUBLIC_OWNER_V2',HEAD,None),('SNOW_VAPOR_ACTUAL_CANONICAL_PUBLIC_OWNER_V2',canonical,None)]
 cases += [('SNOW_VAPOR_FINAL_'+role+'_NEGATIVE_PUBLIC_V2',head,error) for role,head,path,error in NEGATIVES]
 for label,head,error in cases:
  q=load(label+'.json');observations[label]=q
  assert q['before']==q['after'] and q['before']['head']==head and not q['before']['status'] and len(q['before']['sparse'])==38
  assert q['compiler_executions']==q['model_executions']==0 and q['command'][-1]=='tests/hupsel51/verify_successor.py'
  out=(ev/(label+'.stdout.txt')).read_bytes();err=(ev/(label+'.stderr.txt')).read_bytes()
  if error:assert q['returncode']!=0 and error in err.decode()
  else:assert q['returncode']==0 and not err and q['before']['tree']==TREE and json.loads(out)['status']==STATUS
  for suffix in ('.json','.stdout.txt','.stderr.txt'):files[label+suffix]=ev/(label+suffix)
 for role,head,path,error in NEGATIVES:assert git('diff','--name-only',HEAD,head)==path
 for role,head in (('POSITIVE',HEAD),('CANONICAL_POSITIVE',canonical)):
  name='SNOW_VAPOR_FINAL_PUBLICATION_SCOPE_'+role+'_V2.json';q=load(name)
  assert q['head']==head and q['clean_including_ignored'] and q['model_executions']==q['compiler_executions']==0
  assert 'PUBLICATION_REPLAY_SELECTED=false' in q['stdout'] and not q['stderr'];files[name]=ev/name
 name='SNOW_VAPOR_FINAL_PUBLICATION_SCOPE_NEGATIVE_V2.txt';assert 'PUBLICATION_REPLAY_SELECTED=true' in (ev/name).read_text();files[name]=ev/name
 checks=load('SNOW_VAPOR_PR1782_ALL_TERMINAL_CHECKS_V2.json')
 assert checks['headRevision']==HEAD and not checks['hasMore'] and not checks['statuses'] and len(checks['checks'])==45
 assert all(c['head_sha']==HEAD and c['status']=='completed' and c['conclusion'] in ('success','skipped') for c in checks['checks'])
 assert sum(c['conclusion']=='success' for c in checks['checks'])==30
 runs=load('SNOW_VAPOR_PR1782_ALL_TERMINAL_RUNS_V2.json');assert runs['total_count']==len(runs['workflow_runs'])==16
 assert all(r['head_sha']==HEAD and r['status']=='completed' and r['conclusion']=='success' for r in runs['workflow_runs'])
 pre=load('SNOW_VAPOR_PR1782_IMMEDIATE_PREMERGE_V2.json')
 assert pre['head']['sha']==HEAD and pre['base']['sha']==PARENT and pre['merge_commit_sha']==SYNTHETIC and pre['mergeable'] and not pre['draft']
 logs=[ev/('SNOW_VAPOR_PR1782_FINAL_JOB'+str(job)+'_FULL.txt') for job in (136794905714,136794905886,136798403959)];assert len(logs)==3
 for path in logs:assert STATUS in path.read_text(encoding='utf8')
 neutral=['integration/f-ci/nomacro-complete01/'+name for name in ('HYDRAULIC_SNOW_VAPOR_QUALIFICATION.json','HYDRAULIC_SNOW_VAPOR_WINDOWS_RAW_V1.json','HYDRAULIC_SNOW_VAPOR_WINDOWS_RAW_V1.zip')]
 assert not git('diff',HEAD,'--',*neutral),'Neutral Snow vapor science changed'
 qual=json.loads((root/neutral[0]).read_text());assert not qual['canonical_admission']
 for opt in ('O0','O2'):
  paths=['integration/f-ci/nomacro-complete01/HYDRAULIC_SNOW_VAPOR_UBUNTU_'+opt+'_RAW_V1'+suffix for suffix in ('.json','.zip')]
  assert not git('diff',HEAD,'--',*paths),'Neutral Ubuntu science changed'
 initial=load('SNOW_VAPOR_FINAL_CANDIDATE_PUBLIC_OWNER_V1.json')
 assert initial['before']==initial['after'] and initial['before']['head']=='208c25624268589b5f26cbc10f2113aca4276ae6' and not initial['before']['status'] and initial['returncode']!=0
 assert 'AssertionError' in (ev/'SNOW_VAPOR_FINAL_CANDIDATE_PUBLIC_OWNER_V1.stderr.txt').read_text()
 bridge=load('SNOW_VAPOR_INITIAL_UBUNTU_SOURCE_BRIDGE_V1.json')
 assert bridge['actual_head']==HEAD and bridge['model_executions']==bridge['compiler_executions']==0
 assert bridge['all_old_ledger_native_and_exact_stock_assertions_literal'] and not bridge['producer_or_checkout_identity_substituted']
 assert set(bridge['observations'])=={'O0','O2'} and bridge['status'].startswith('BOTH_LITERAL_INITIAL_UBUNTU_NATIVE3')
 old=load('SNOW_VAPOR_PR1782_PRIOR_208_ALL_TERMINAL_RUNS_V1.json')
 old=json.loads(old['structuredContent']['content']);assert old['total_count']==len(old['workflow_runs'])==16
 assert all(r['head_sha']=='208c25624268589b5f26cbc10f2113aca4276ae6' and r['status']=='completed' for r in old['workflow_runs'])
 assert sum(r['conclusion']=='failure' for r in old['workflow_runs'])==3
 for job in (136790712985,136790713060,136792868073):
  text=(ev/('SNOW_VAPOR_PR1782_PRIOR_208_JOB'+str(job)+'_FULL.txt')).read_text(encoding='utf8')
  assert 'AssertionError' in text and 'read_initial' in text
 cancelled=ev/'SNOW_VAPOR_PR1782_CANCELLED_HUPSEL_ORIGINAL_ARTIFACT_V1.zip'
 assert cancelled.stat().st_size==6341279 and SHA(cancelled.read_bytes())=='4f1866c27f80530613a2cbe69547a0b9334babe83b4b4cdbf54c2904c1d75439'
 assert 'The operation was canceled' in (ev/'SNOW_VAPOR_PR1782_CANCELLED_HUPSEL_JOB136794906184_FULL.txt').read_text()
 assert any(c['id']==136799625300 and c['conclusion']=='success' for c in checks['checks'])
 for pattern in ('SNOW_VAPOR_PR1782_*','SNOW_VAPOR_FINAL_*','SNOW_VAPOR_ACTUAL_CANONICAL*'):
  for path in ev.glob(pattern):assert path.is_file();files[path.name]=path
 for pattern in ('SNOW_VAPOR_INITIAL_UBUNTU_SOURCE_BRIDGE_V1.*','SNOW_VAPOR_FINAL_*','SNOW_VAPOR_PR1782_*','snow_vapor_actual_negatives_v*.py','snow_vapor*publication_observe_v2.py','SNOW_VAPOR_PUBLIC_OBSERVE_V1.py'):
  for path in ev.glob(pattern):assert path.is_file();files[path.name]=path

 members={name:dict(bytes=path.stat().st_size,sha256=SHA(path.read_bytes())) for name,path in files.items()}
 archive=proof/'HYDRAULIC_SNOW_VAPOR_ADMISSION_RAW_V1.zip'
 if a.verify_only:
  record=json.loads(archive.with_suffix('.json').read_text());assert record['members']==members and record['sha256']==SHA(archive.read_bytes())
 else:
  assert not archive.exists() and not archive.with_suffix('.json').exists()
  with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
   for name,path in sorted(files.items()):z.write(path,name)
 with zipfile.ZipFile(archive) as z:
  assert len(z.namelist())==len(set(z.namelist()))==len(members)
  for name,item in members.items():raw=z.read(name);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
 if a.verify_only:print('ACTUAL_SNOW_VAPOR_CANONICAL_ADMISSION_REVERIFIED_WITHOUT_WRITES');return
 digest=SHA(archive.read_bytes());record=dict(status='ACTUAL_CANONICAL_SNOW_VAPOR_ADMISSION_RAW_SEALED',canonical=canonical,candidate=HEAD,ordered_parents=[PARENT,HEAD],full_tree=TREE,archive=archive.name,bytes=archive.stat().st_size,sha256=digest,members=members,sealer_source=git('rev-parse','HEAD'),neutral_scientific_archives_changed=False)
 archive.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n')
 receipt=dict(status='ACTUAL_CANONICAL_BOUNDED_ORIGINAL_SNOW_ACTIVE_VAPOR_ADMISSION_VERIFIED',PR=1782,previous_canonical=PARENT,qualified_head=HEAD,synthetic_merge=SYNTHETIC,actual_merge=canonical,ordered_parents=[PARENT,HEAD],whole_qualified_tree=TREE,all_terminal_PR_checks=45,success=30,skipped=15,all16workflow_runs_success=True,actual_candidate_public_seconds=observations[cases[0][0]]['seconds'],actual_canonical_public_seconds=observations[cases[1][0]]['seconds'],actual_canonical_sparse_patterns=38,admission_archive_sha256=digest,canonical_admission=True,full1096_contexts=4,short35_contexts=16,exact_cold_windows=76,native_refusals=528,frontend_controls=72,fresh_full_periods_for_admission=0,original_failed_observers_retained=True,neutral_qualification_and_raw_unchanged=True,scope=qual['scope'],whole_historical_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False,canonical_older_source_succession_failures_not_waived=True)
 (proof/'HYDRAULIC_SNOW_VAPOR_MERGE_RECEIPT_V1.json').write_text(json.dumps(receipt,indent=2)+'\n');print(record['status'],record['bytes'],digest,len(members))


if __name__=='__main__':main()
