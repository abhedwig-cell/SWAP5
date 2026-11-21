"""Seal actual default-grammar admission without changing neutral science."""
import argparse,hashlib,json,subprocess,zipfile
from pathlib import Path

HEAD='8e27dd9eb0f633050d2d82d00d28992435c313cb'
PARENT='0c3d905102672354e7f8df4212e8075d7c133e31'
SYNTHETIC='46302713558c06490463439362e9fe848213481b'
TREE='e16f8e47e677b40e4ce5b1ef6001b33f2f0498c7'
STATUS='BOUNDED_ORIGINAL_DEFAULT_MODEL_INTEGER_GRAMMAR_SOURCE_RAW_NATIVE_PASS'
NEGATIVES=(
 ('SOURCE','6795745f2073fcb449721a2e3a894084a66ad8f3','app/hybrid_water/implicit_conductivity.py','Unreviewed default model grammar source delta'),
 ('RAW','f7d92079c164e2371b09471b470e34b2320b7701','integration/f-ci/nomacro-complete01/HYDRAULIC_DEFAULT_MODEL_GRAMMAR_WINDOWS_RAW_V1.zip','AssertionError'),
 ('INHERITED','fe1679d932741a268c50b0e81bff0c396a992c96','integration/f-ci/nomacro-complete01/HYDRAULIC_SIGNED_SELECTORS_ADMISSION_RAW_V1.zip','AssertionError'),
 ('PUBLICATION','1c3541aa3dc7262ebdc4071c64af8b9009c2ae4a','tests/publication/run_pub_p2e09_reference_threshold_freeze.sh','AssertionError'))
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


def main():
 p=argparse.ArgumentParser(description=__doc__)
 for key in ('repository','evidence'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--verify-only',action='store_true');a=p.parse_args();root=a.repository;ev=a.evidence;proof=root/'integration/f-ci/nomacro-complete01'
 git=lambda *args:subprocess.check_output(['git',*args],cwd=root,text=True).strip()
 load=lambda name:json.loads((ev/name).read_text(encoding='utf8'))
 merge=load('DEFAULT_MODEL_GRAMMAR_PR1781_ACTUAL_MERGE_API_V1.json');canonical=merge['sha'];assert merge['merged'] is True
 for commit in (canonical,SYNTHETIC):assert git('show','-s','--format=%P',commit).split()==[PARENT,HEAD]
 assert all(git('rev-parse',commit+'^{tree}')==TREE for commit in (HEAD,canonical,SYNTHETIC))
 files={};observations={}
 cases=[('DEFAULT_MODEL_GRAMMAR_FINAL_CANDIDATE_PUBLIC_OWNER_V2',HEAD,None),('DEFAULT_MODEL_GRAMMAR_ACTUAL_CANONICAL_PUBLIC_OWNER_V1',canonical,None)]
 cases += [('DEFAULT_MODEL_GRAMMAR_FINAL_'+role+'_NEGATIVE_PUBLIC_V1',head,error) for role,head,path,error in NEGATIVES]
 for label,head,error in cases:
  q=load(label+'.json');observations[label]=q
  assert q['before']==q['after'] and q['before']['head']==head and not q['before']['status'] and len(q['before']['sparse'])==37
  assert q['compiler_executions']==q['model_executions']==0 and q['command'][-1]=='tests/hupsel51/verify_successor.py'
  out=(ev/(label+'.stdout.txt')).read_bytes();err=(ev/(label+'.stderr.txt')).read_bytes()
  if error:assert q['returncode']!=0 and error in err.decode()
  else:assert q['returncode']==0 and not err and q['before']['tree']==TREE and json.loads(out)['status']==STATUS
  for suffix in ('.json','.stdout.txt','.stderr.txt'):files[label+suffix]=ev/(label+suffix)
 for role,head,path,error in NEGATIVES:assert git('diff','--name-only',HEAD,head)==path
 for role,head in (('POSITIVE',HEAD),('CANONICAL_POSITIVE',canonical)):
  name='DEFAULT_MODEL_GRAMMAR_FINAL_PUBLICATION_SCOPE_'+role+'_V1.json';q=load(name)
  assert q['head']==head and q['clean_including_ignored'] and q['model_executions']==q['compiler_executions']==0
  assert 'PUBLICATION_REPLAY_SELECTED=false' in q['stdout'] and not q['stderr'];files[name]=ev/name
 name='DEFAULT_MODEL_GRAMMAR_FINAL_PUBLICATION_SCOPE_NEGATIVE_V1.txt';assert 'PUBLICATION_REPLAY_SELECTED=true' in (ev/name).read_text();files[name]=ev/name
 checks=load('DEFAULT_MODEL_GRAMMAR_PR1781_ALL_TERMINAL_CHECKS_V1.json')
 assert checks['headRevision']==HEAD and not checks['hasMore'] and not checks['statuses'] and len(checks['checks'])==44
 assert all(c['head_sha']==HEAD and c['status']=='completed' and c['conclusion'] in ('success','skipped') for c in checks['checks'])
 assert sum(c['conclusion']=='success' for c in checks['checks'])==29
 runs=load('DEFAULT_MODEL_GRAMMAR_PR1781_ALL_TERMINAL_RUNS_V1.json');assert runs['total_count']==len(runs['workflow_runs'])==15
 assert all(r['head_sha']==HEAD and r['status']=='completed' and r['conclusion']=='success' for r in runs['workflow_runs'])
 pre=load('DEFAULT_MODEL_GRAMMAR_PR1781_IMMEDIATE_PREMERGE_V1.json')
 assert pre['head']['sha']==HEAD and pre['base']['sha']==PARENT and pre['merge_commit_sha']==SYNTHETIC and pre['mergeable'] and not pre['draft']
 logs=list(ev.glob('DEFAULT_MODEL_GRAMMAR_PR1781_FINAL_JOB*_FULL.txt'));assert len(logs)==3
 for path in logs:assert STATUS in path.read_text(encoding='utf8')
 neutral=['integration/f-ci/nomacro-complete01/'+name for name in ('HYDRAULIC_DEFAULT_MODEL_GRAMMAR_QUALIFICATION.json','HYDRAULIC_DEFAULT_MODEL_GRAMMAR_WINDOWS_RAW_V1.json','HYDRAULIC_DEFAULT_MODEL_GRAMMAR_WINDOWS_RAW_V1.zip')]
 assert not git('diff',HEAD,'--',*neutral),'Neutral default grammar science changed'
 qual=json.loads((root/neutral[0]).read_text());assert not qual['canonical_admission'] and (qual['actual_short35_contexts'],qual['actual_exact_cold_windows'],qual['actual_frontend_controls'])==(6,12,90)
 initial=load('DEFAULT_MODEL_GRAMMAR_FINAL_CANDIDATE_PUBLIC_OWNER_V1.json')
 assert initial['before']==initial['after'] and initial['before']['head']==HEAD and not initial['before']['status'] and initial['returncode']!=0
 assert 'Permission denied' in (ev/'DEFAULT_MODEL_GRAMMAR_FINAL_CANDIDATE_PUBLIC_OWNER_V1.stderr.txt').read_text()
 for pattern in ('DEFAULT_MODEL_GRAMMAR_PR1781_*','DEFAULT_MODEL_GRAMMAR_FINAL_*','DEFAULT_MODEL_GRAMMAR_ACTUAL_CANONICAL*'):
  for path in ev.glob(pattern):assert path.is_file();files[path.name]=path
 for name in ('DEFAULT_MODEL_GRAMMAR_PUBLIC_OBSERVE_V1.py','DEFAULT_MODEL_GRAMMAR_NEGATIVE_OBSERVER_INITIAL_EXPECTED_MESSAGE_STATE_V1.json','default_model_grammar_actual_negatives_v1.py','default_publication_observe_v1.py'):files[name]=ev/name
 members={name:dict(bytes=path.stat().st_size,sha256=SHA(path.read_bytes())) for name,path in files.items()}
 archive=proof/'HYDRAULIC_DEFAULT_MODEL_GRAMMAR_ADMISSION_RAW_V1.zip'
 if a.verify_only:
  record=json.loads(archive.with_suffix('.json').read_text());assert record['members']==members and record['sha256']==SHA(archive.read_bytes())
 else:
  assert not archive.exists() and not archive.with_suffix('.json').exists()
  with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
   for name,path in sorted(files.items()):z.write(path,name)
 with zipfile.ZipFile(archive) as z:
  assert len(z.namelist())==len(set(z.namelist()))==len(members)
  for name,item in members.items():raw=z.read(name);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
 if a.verify_only:print('ACTUAL_DEFAULT_GRAMMAR_CANONICAL_ADMISSION_REVERIFIED_WITHOUT_WRITES');return
 digest=SHA(archive.read_bytes());record=dict(status='ACTUAL_CANONICAL_DEFAULT_GRAMMAR_ADMISSION_RAW_SEALED',canonical=canonical,candidate=HEAD,ordered_parents=[PARENT,HEAD],full_tree=TREE,archive=archive.name,bytes=archive.stat().st_size,sha256=digest,members=members,sealer_source=git('rev-parse','HEAD'),neutral_scientific_archives_changed=False)
 archive.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n')
 receipt=dict(status='ACTUAL_CANONICAL_BOUNDED_DEFAULT_MODEL_INTEGER_GRAMMAR_ADMISSION_VERIFIED',PR=1781,previous_canonical=PARENT,qualified_head=HEAD,synthetic_merge=SYNTHETIC,actual_merge=canonical,ordered_parents=[PARENT,HEAD],whole_qualified_tree=TREE,all_terminal_PR_checks=44,success=29,skipped=15,all15workflow_runs_success=True,actual_candidate_public_seconds=observations[cases[0][0]]['seconds'],actual_canonical_public_seconds=observations[cases[1][0]]['seconds'],actual_canonical_sparse_patterns=37,admission_archive_sha256=digest,canonical_admission=True,short35_contexts=6,exact_cold_windows=12,frontend_controls=90,fresh_full_periods=0,original_failed_observers_retained=True,neutral_qualification_and_raw_unchanged=True,scope=qual['scope'],whole_historical_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False,canonical_older_source_succession_failures_not_waived=True)
 (proof/'HYDRAULIC_DEFAULT_MODEL_GRAMMAR_MERGE_RECEIPT_V1.json').write_text(json.dumps(receipt,indent=2)+'\n');print(record['status'],record['bytes'],digest,len(members))


if __name__=='__main__':main()
