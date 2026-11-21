"""Seal actual analytical calendar admission without changing neutral science."""
import argparse,hashlib,json,subprocess,zipfile
from pathlib import Path

HEAD='70bae8871ec71b3c0969a6628cae596354f9c2e8'
PARENT='a7c6936bd4c392712f5479a0a997bdc908b4ff97'
SYNTHETIC='baea51eaebb8b0f5f8669485e7f437a3dc34cf66'
TREE='35ae8f5ff0a63634f16a9bcf2bb066acfa4f9e54'
STATUS='BOUNDED_ORIGINAL_ANALYTICAL_WATER_OUTPUT_CALENDAR_SOURCE_RAW_NATIVE_PASS'
NEGATIVES=(
 ('SOURCE','f1d769c20a95f4b3fdd27989b33c520f6705245d','app/hybrid_water/model7_terminal_water.py','Unreviewed analytical calendar source delta'),
 ('RAW','d63deb3e0543a5501c8370d804a6bccb5978147e','integration/f-ci/nomacro-complete01/HYDRAULIC_ANALYTICAL_CALENDAR_WINDOWS_RAW_V1.zip','AssertionError'),
 ('INHERITED','76cb5e73d7f682def0c9b1c9933ca43b120b9e00','integration/f-ci/nomacro-complete01/HYDRAULIC_SNOW_VAPOR_ADMISSION_RAW_V1.zip','AssertionError'),
 ('PUBLICATION','fa4f0fa6b05fe3a763bfebbeeaf1d673569d68be','tests/publication/run_pub_p2e09_reference_threshold_freeze.sh','AssertionError'))
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


def main():
 p=argparse.ArgumentParser(description=__doc__)
 for key in ('repository','evidence'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--verify-only',action='store_true');a=p.parse_args();root=a.repository;ev=a.evidence;proof=root/'integration/f-ci/nomacro-complete01'
 git=lambda *args:subprocess.check_output(['git',*args],cwd=root,text=True).strip()
 load=lambda name:json.loads((ev/name).read_text(encoding='utf8'))
 merge=load('ANALYTICAL_CALENDAR_PR1783_ACTUAL_MERGE_API_V1.json');canonical=merge['sha'];assert merge['merged'] is True
 for commit in (canonical,SYNTHETIC):assert git('show','-s','--format=%P',commit).split()==[PARENT,HEAD]
 assert all(git('rev-parse',commit+'^{tree}')==TREE for commit in (HEAD,canonical,SYNTHETIC))
 files={};observations={}
 cases=[('ANALYTICAL_CALENDAR_FINAL_CANDIDATE_PUBLIC_OWNER_V1',HEAD,None),('ANALYTICAL_CALENDAR_ACTUAL_CANONICAL_PUBLIC_OWNER_V1',canonical,None)]
 cases += [('ANALYTICAL_CALENDAR_FINAL_'+role+'_NEGATIVE_PUBLIC_V1',head,error) for role,head,path,error in NEGATIVES]
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
  name='ANALYTICAL_CALENDAR_FINAL_PUBLICATION_SCOPE_'+role+'_V1.json';q=load(name)
  assert q['head']==head and q['clean_including_ignored'] and q['model_executions']==q['compiler_executions']==0
  assert 'PUBLICATION_REPLAY_SELECTED=false' in q['stdout'] and not q['stderr'];files[name]=ev/name
 name='ANALYTICAL_CALENDAR_FINAL_PUBLICATION_SCOPE_NEGATIVE_V1.txt';assert 'PUBLICATION_REPLAY_SELECTED=true' in (ev/name).read_text();files[name]=ev/name
 checks=load('ANALYTICAL_CALENDAR_PR1783_ALL_TERMINAL_CHECKS_V1.json')
 assert checks['headRevision']==HEAD and not checks['hasMore'] and not checks['statuses'] and len(checks['checks'])==42
 assert all(c['head_sha']==HEAD and c['status']=='completed' and c['conclusion'] in ('success','skipped') for c in checks['checks'])
 assert sum(c['conclusion']=='success' for c in checks['checks'])==27
 runs=load('ANALYTICAL_CALENDAR_PR1783_ALL_TERMINAL_RUNS_V1.json');assert runs['total_count']==len(runs['workflow_runs'])==13
 assert all(r['head_sha']==HEAD and r['status']=='completed' and r['conclusion']=='success' for r in runs['workflow_runs'])
 pre=load('ANALYTICAL_CALENDAR_PR1783_IMMEDIATE_PREMERGE_V1.json')
 assert pre['head']['sha']==HEAD and pre['base']['sha']==PARENT and pre['merge_commit_sha']==SYNTHETIC and pre['mergeable'] and not pre['draft']
 logs=[ev/'ANALYTICAL_CALENDAR_PR1783_FINAL_JOB136815658985_FULL.txt'];assert len(logs)==1
 for path in logs:assert STATUS in path.read_text(encoding='utf8')
 neutral=['integration/f-ci/nomacro-complete01/'+name for name in ('HYDRAULIC_ANALYTICAL_CALENDAR_QUALIFICATION.json','HYDRAULIC_ANALYTICAL_CALENDAR_WINDOWS_RAW_V1.json','HYDRAULIC_ANALYTICAL_CALENDAR_WINDOWS_RAW_V1.zip')]
 assert not git('diff',HEAD,'--',*neutral),'Neutral analytical calendar science changed'
 qual=json.loads((root/neutral[0]).read_text());assert not qual['canonical_admission']
 for opt in ('O0','O2'):
  paths=['integration/f-ci/nomacro-complete01/HYDRAULIC_ANALYTICAL_CALENDAR_UBUNTU_'+opt+'_RAW_V1'+suffix for suffix in ('.json','.zip')]
  assert not git('diff',HEAD,'--',*paths),'Neutral Ubuntu science changed'
 for pattern in ('ANALYTICAL_CALENDAR_PR1783_*','ANALYTICAL_CALENDAR_FINAL_*','ANALYTICAL_CALENDAR_ACTUAL_CANONICAL*'):
  for path in ev.glob(pattern):assert path.is_file();files[path.name]=path
 for pattern in ('ANALYTICAL_CALENDAR_FINAL_*','ANALYTICAL_CALENDAR_PR1783_*','analytical_calendar_actual_negatives_v1.py','analytical_calendar*publication_observe_v1.py','ANALYTICAL_CALENDAR_PUBLIC_OBSERVE_V1.py'):
  for path in ev.glob(pattern):assert path.is_file();files[path.name]=path

 members={name:dict(bytes=path.stat().st_size,sha256=SHA(path.read_bytes())) for name,path in files.items()}
 archive=proof/'HYDRAULIC_ANALYTICAL_CALENDAR_ADMISSION_RAW_V1.zip'
 if a.verify_only:
  record=json.loads(archive.with_suffix('.json').read_text());assert record['members']==members and record['sha256']==SHA(archive.read_bytes())
 else:
  assert not archive.exists() and not archive.with_suffix('.json').exists()
  with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
   for name,path in sorted(files.items()):z.write(path,name)
 with zipfile.ZipFile(archive) as z:
  assert len(z.namelist())==len(set(z.namelist()))==len(members)
  for name,item in members.items():raw=z.read(name);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
 if a.verify_only:print('ACTUAL_ANALYTICAL_CALENDAR_CANONICAL_ADMISSION_REVERIFIED_WITHOUT_WRITES');return
 digest=SHA(archive.read_bytes());record=dict(status='ACTUAL_CANONICAL_ANALYTICAL_CALENDAR_ADMISSION_RAW_SEALED',canonical=canonical,candidate=HEAD,ordered_parents=[PARENT,HEAD],full_tree=TREE,archive=archive.name,bytes=archive.stat().st_size,sha256=digest,members=members,sealer_source=git('rev-parse','HEAD'),neutral_scientific_archives_changed=False)
 archive.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n')
 receipt=dict(status='ACTUAL_CANONICAL_BOUNDED_ORIGINAL_ANALYTICAL_WATER_OUTPUT_CALENDAR_ADMISSION_VERIFIED',PR=1783,previous_canonical=PARENT,qualified_head=HEAD,synthetic_merge=SYNTHETIC,actual_merge=canonical,ordered_parents=[PARENT,HEAD],whole_qualified_tree=TREE,all_terminal_PR_checks=42,success=27,skipped=15,all13workflow_runs_success=True,actual_candidate_public_seconds=observations[cases[0][0]]['seconds'],actual_canonical_public_seconds=observations[cases[1][0]]['seconds'],actual_canonical_sparse_patterns=38,admission_archive_sha256=digest,canonical_admission=True,year367_contexts=5,short35_contexts=13,density2day_contexts=2,exact_cold_windows=65,native_refusals=192,external_transaction_contexts=8,frontend_controls=15,fresh_full_periods_for_admission=0,original_targeted_build_probe_retained_in_neutral_raw=True,neutral_qualification_and_raw_unchanged=True,scope=qual['scope'],whole_historical_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False,canonical_older_source_succession_failures_not_waived=True)
 (proof/'HYDRAULIC_ANALYTICAL_CALENDAR_MERGE_RECEIPT_V1.json').write_text(json.dumps(receipt,indent=2)+'\n');print(record['status'],record['bytes'],digest,len(members))


if __name__=='__main__':main()
