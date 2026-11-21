"""Seal actual signed-selector admission, retaining the real earlier refusal."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

HEAD='7862c1b3866a0ea2e3652a3b3d153c45714cea66'
PARENT='277c6135ff4250a04ee3e3330530dc0895e0fc7d'
SYNTHETIC='0753f37d1e3bb3bf1385688016fb1747029c433a'
CANONICAL='0c3d905102672354e7f8df4212e8075d7c133e31'
TREE='3b2e0f9c73a0aa5317479a78f3e3f6a9b45bdaff'
STATUS='BOUNDED_ORIGINAL_SIGNED_HYDRAULIC_CONFIGURATION_SOURCE_RAW_NATIVE_PASS'
NEGATIVES=(
 ('SOURCE','d54964dec5a3811125653e51e3a18cc73f91261b','app/hybrid_water/model7_capacity.py','Unreviewed signed hydraulic source delta'),
 ('RAW','5bab44fc1fbb5b8bb4e2cafbb1266105299541e0','integration/f-ci/nomacro-complete01/HYDRAULIC_SIGNED_SELECTORS_WINDOWS_RAW_V1.zip','AssertionError'),
 ('INHERITED','163802d82151c036f5efbb656571f14692a30259','integration/f-ci/nomacro-complete01/HYDRAULIC_VAPOR_ADMISSION_RAW_V1.zip','AssertionError'),
 ('PUBLICATION','eef3c0eeecf081c0134d4b86383a686c77a7b9fc','tests/publication/run_pub_p2e09_reference_threshold_freeze.sh','Earlier observer modified outside exact delegation'))
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


def main():
 p=argparse.ArgumentParser(description=__doc__)
 for key in ('repository','evidence'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--verify-only',action='store_true');a=p.parse_args();root=a.repository;ev=a.evidence;proof=root/'integration/f-ci/nomacro-complete01'
 git=lambda *args:subprocess.check_output(['git',*args],cwd=root,text=True).strip()
 load=lambda name:json.loads((ev/name).read_text(encoding='utf8'))
 for commit in (CANONICAL,SYNTHETIC):assert git('show','-s','--format=%P',commit).split()==[PARENT,HEAD]
 assert all(git('rev-parse',commit+'^{tree}')==TREE for commit in (HEAD,CANONICAL,SYNTHETIC))
 files={};observations={}
 cases=[('SIGNED_SELECTORS_FINAL_CANDIDATE_PUBLIC_OWNER_V2',HEAD,None),('SIGNED_SELECTORS_ACTUAL_CANONICAL_PUBLIC_OWNER_V2',CANONICAL,None)]
 cases += [('SIGNED_SELECTORS_FINAL_'+role+'_NEGATIVE_PUBLIC_V2',head,error) for role,head,path,error in NEGATIVES]
 for label,head,error in cases:
  q=load(label+'.json');observations[label]=q
  assert q['before']==q['after'] and q['before']['head']==head and not q['before']['status'] and len(q['before']['sparse'])==36
  assert q['compiler_executions']==q['model_executions']==0 and q['command'][-1]=='tests/hupsel51/verify_successor.py'
  out=(ev/(label+'.stdout.txt')).read_bytes();err=(ev/(label+'.stderr.txt')).read_bytes()
  if error:assert q['returncode']!=0 and error in err.decode()
  else:assert q['returncode']==0 and not err and q['before']['tree']==TREE and json.loads(out)['status']==STATUS
  for suffix in ('.json','.stdout.txt','.stderr.txt'):files[label+suffix]=ev/(label+suffix)
 for role,head,path,error in NEGATIVES:assert git('diff','--name-only',HEAD,head)==path
 for role,head in (('POSITIVE',HEAD),('CANONICAL_POSITIVE',CANONICAL)):
  name='SIGNED_SELECTORS_FINAL_PUBLICATION_SCOPE_'+role+'_V2.json';q=load(name)
  assert q['head']==head and q['clean_including_ignored'] and q['model_executions']==q['compiler_executions']==0
  assert 'PUBLICATION_REPLAY_SELECTED=false' in q['stdout'] and not q['stderr'];files[name]=ev/name
 name='SIGNED_SELECTORS_FINAL_PUBLICATION_SCOPE_NEGATIVE_V2.txt';assert 'PUBLICATION_REPLAY_SELECTED=true' in (ev/name).read_text();files[name]=ev/name
 checks=load('SIGNED_SELECTORS_PR1780_ALL_TERMINAL_CHECKS_V2.json')
 assert checks['headRevision']==HEAD and not checks['hasMore'] and not checks['statuses'] and len(checks['checks'])==44
 assert all(c['head_sha']==HEAD and c['status']=='completed' and c['conclusion'] in ('success','skipped') for c in checks['checks'])
 assert sum(c['conclusion']=='success' for c in checks['checks'])==29
 runs=load('SIGNED_SELECTORS_PR1780_ALL_TERMINAL_RUNS_V2.json');assert runs['total_count']==len(runs['workflow_runs'])==15
 assert all(r['head_sha']==HEAD and r['status']=='completed' and r['conclusion']=='success' for r in runs['workflow_runs'])
 pre=load('SIGNED_SELECTORS_PR1780_IMMEDIATE_PREMERGE_V2.json');merge=load('SIGNED_SELECTORS_PR1780_ACTUAL_MERGE_API_V2.json')
 assert pre['head']['sha']==HEAD and pre['base']['sha']==PARENT and pre['merge_commit_sha']==SYNTHETIC and pre['mergeable'] and not pre['draft']
 assert merge['merged'] is True and merge['sha']==CANONICAL
 for job in (136761071023,136759764820,136764453244):assert STATUS in (ev/f'SIGNED_SELECTORS_PR1780_FINAL_JOB{job}_FULL.txt').read_text(encoding='utf8')
 neutral=['integration/f-ci/nomacro-complete01/'+name for name in ('HYDRAULIC_SIGNED_SELECTORS_QUALIFICATION.json','HYDRAULIC_SIGNED_SELECTORS_WINDOWS_RAW_V1.json','HYDRAULIC_SIGNED_SELECTORS_WINDOWS_RAW_V1.zip')]
 assert not git('diff',HEAD,'--',*neutral),'Neutral signed science changed'
 qual=json.loads((root/neutral[0]).read_text());assert not qual['canonical_admission'] and (qual['actual_short35_contexts'],qual['actual_exact_cold_windows'],qual['actual_parser_controls'])==(4,12,38)
 initial=load('SIGNED_SELECTORS_FINAL_CANDIDATE_PUBLIC_OWNER_V1.json')
 assert initial['before']==initial['after'] and initial['before']['head']=='b77e027e7b53801a67808c44b6a03ef9c71dba5c' and not initial['before']['status'] and initial['returncode']!=0
 assert "['app/hybrid_water/cde_native_receipt.py', 'app/hybrid_water/model7_capacity.py']" in (ev/'SIGNED_SELECTORS_FINAL_CANDIDATE_PUBLIC_OWNER_V1.stderr.txt').read_text()
 for path in ev.glob('SIGNED_SELECTORS_PR1780_*'):assert path.is_file();files[path.name]=path
 for path in ev.glob('SIGNED_SELECTORS_FINAL_*'):assert path.is_file();files[path.name]=path
 for name in ('SIGNED_SELECTORS_PUBLIC_OBSERVE_V1.py','SIGNED_SELECTORS_ACTUAL_CANONICAL_POSTIMAGE_V2.json','SIGNED_SELECTORS_INITIAL_UBUNTU_SOURCE_BRIDGE_V1.json','signed_selectors_actual_negatives_v1.py','signed_selectors_actual_negatives_v2.py'):files[name]=ev/name
 members={name:dict(bytes=path.stat().st_size,sha256=SHA(path.read_bytes())) for name,path in files.items()}
 archive=proof/'HYDRAULIC_SIGNED_SELECTORS_ADMISSION_RAW_V1.zip'
 if a.verify_only:
  record=json.loads(archive.with_suffix('.json').read_text());assert record['members']==members and record['sha256']==SHA(archive.read_bytes())
 else:
  assert not archive.exists() and not archive.with_suffix('.json').exists()
  with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
   for name,path in sorted(files.items()):z.write(path,name)
 with zipfile.ZipFile(archive) as z:
  assert len(z.namelist())==len(set(z.namelist()))==len(members)
  for name,item in members.items():raw=z.read(name);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
 if a.verify_only:print('ACTUAL_SIGNED_SELECTOR_CANONICAL_ADMISSION_REVERIFIED_WITHOUT_WRITES');return
 digest=SHA(archive.read_bytes());record=dict(status='ACTUAL_CANONICAL_SIGNED_SELECTOR_ADMISSION_RAW_SEALED',canonical=CANONICAL,candidate=HEAD,ordered_parents=[PARENT,HEAD],full_tree=TREE,archive=archive.name,bytes=archive.stat().st_size,sha256=digest,members=members,sealer_source=git('rev-parse','HEAD'),neutral_scientific_archives_changed=False)
 archive.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n')
 receipt=dict(status='ACTUAL_CANONICAL_BOUNDED_SIGNED_HYDRAULIC_CONFIGURATION_ADMISSION_VERIFIED',PR=1780,previous_canonical=PARENT,qualified_head=HEAD,synthetic_merge=SYNTHETIC,actual_merge=CANONICAL,ordered_parents=[PARENT,HEAD],whole_qualified_tree=TREE,all_terminal_PR_checks=44,success=29,skipped=15,all15workflow_runs_success=True,actual_candidate_public_seconds=observations[cases[0][0]]['seconds'],actual_canonical_public_seconds=observations[cases[1][0]]['seconds'],actual_canonical_sparse_patterns=36,admission_archive_sha256=digest,canonical_admission=True,short35_contexts=4,exact_cold_windows=12,parser_controls=38,fresh_full_periods=0,original_failed_candidate_and_controls_retained=True,neutral_qualification_and_raw_unchanged=True,scope=qual['scope'],whole_historical_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False,canonical_older_source_succession_failures_not_waived=True)
 (proof/'HYDRAULIC_SIGNED_SELECTORS_MERGE_RECEIPT_V1.json').write_text(json.dumps(receipt,indent=2)+'\n');print(record['status'],record['bytes'],digest,len(members))


if __name__=='__main__':main()
