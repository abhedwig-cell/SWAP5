"""Seal actual vapor admission only after fresh actual-canonical observations."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

HEAD='88091c3c6a5cc7ee2ae36402ccd521f5f29e2106'
PARENT='5b8373d0809c25e24415f4d5dc01784a92ff481e'
SYNTHETIC='a9c8beb458b7446c1ef82c68ca51a5aa9f9728cd'
TREE='b484956c0aab430fbe8f4b98e643be0dec7ac9b8'
STATUS='BOUNDED_ORIGINAL_PER_LAYER_VAPOR_KELVIN_LOOKUP_SOURCE_RAW_NATIVE_PASS'
NEGATIVES=(
 ('SOURCE','33e7fee7be87fead7b11d812b51097be9e38242b','app/hybrid_water/experimental_project.py','Unreviewed actual vapor source delta'),
 ('RAW','82ca7a844964a37bd0049cd382436655433f573c','integration/f-ci/nomacro-complete01/HYDRAULIC_VAPOR_UBUNTU_CONTINUATION_O2_RAW_V1.zip','AssertionError'),
 ('INHERITED','9568702b1a936ffb6a901ae31e213f3427da41ea','integration/f-ci/nomacro-complete01/HYDRAULIC_ANALYTICAL_ADMISSION_RAW_V1.zip','AssertionError'),
 ('PUBLICATION','43166a92274976371a1af676a0c84a196207da54','tests/publication/run_pub_p2e09_reference_threshold_freeze.sh','Earlier observer modified outside exact delegation'))
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


def main():
 p=argparse.ArgumentParser(description=__doc__)
 for key in ('repository','evidence'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--canonical',required=True);p.add_argument('--verify-only',action='store_true');a=p.parse_args()
 root=a.repository;ev=a.evidence;proof=root/'integration/f-ci/nomacro-complete01'
 git=lambda *args:subprocess.check_output(['git',*args],cwd=root,text=True).strip()
 load=lambda name:json.loads((ev/name).read_text(encoding='utf8'))
 canonical=a.canonical;assert len(canonical)==40
 for commit in (canonical,SYNTHETIC):assert git('show','-s','--format=%P',commit).split()==[PARENT,HEAD]
 assert all(git('rev-parse',commit+'^{tree}')==TREE for commit in (HEAD,canonical,SYNTHETIC))
 files={};observations={}
 cases=[('VAPOR_FINAL_CANDIDATE_PUBLIC_OWNER_V1',HEAD,None),('VAPOR_ACTUAL_CANONICAL_PUBLIC_OWNER_V1',canonical,None)]
 cases += [('VAPOR_FINAL_'+role+'_NEGATIVE_PUBLIC_V1',head,error) for role,head,path,error in NEGATIVES]
 for label,head,error in cases:
  q=load(label+'.json');observations[label]=q
  assert q['before']==q['after'] and q['before']['head']==head and not q['before']['status'] and len(q['before']['sparse'])==35
  assert q['compiler_executions']==q['model_executions']==0 and q['command'][-1]=='tests/hupsel51/verify_successor.py'
  out=(ev/(label+'.stdout.txt')).read_bytes();err=(ev/(label+'.stderr.txt')).read_bytes()
  if error:assert q['returncode']!=0 and error in err.decode()
  else:assert q['returncode']==0 and not err and q['before']['tree']==TREE and json.loads(out)['status']==STATUS
  for suffix in ('.json','.stdout.txt','.stderr.txt'):files[label+suffix]=ev/(label+suffix)
 for role,head,path,error in NEGATIVES:assert git('diff','--name-only',HEAD,head)==path
 for role,head in (('POSITIVE',HEAD),('CANONICAL_POSITIVE',canonical)):
  name='VAPOR_FINAL_PUBLICATION_SCOPE_'+role+'_V1.json';q=load(name)
  assert q['head']==head and q['clean_including_ignored'] and q['model_executions']==q['compiler_executions']==0
  assert 'PUBLICATION_REPLAY_SELECTED=false' in q['stdout'] and not q['stderr'];files[name]=ev/name
 name='VAPOR_FINAL_PUBLICATION_SCOPE_NEGATIVE_V1.txt'
 assert 'PUBLICATION_REPLAY_SELECTED=true' in (ev/name).read_text();files[name]=ev/name
 checks=load('VAPOR_PR1779_ALL_TERMINAL_CHECKS_V1.json')
 assert checks['headRevision']==HEAD and not checks['hasMore'] and not checks['statuses'] and checks['checks']
 assert all(c['head_sha']==HEAD and c['status']=='completed' and c['conclusion'] in ('success','skipped') for c in checks['checks'])
 runs=load('VAPOR_PR1779_ALL_TERMINAL_RUNS_V1.json')['workflow_runs']
 assert runs and all(r['head_sha']==HEAD and r['status']=='completed' and r['conclusion']=='success' for r in runs)
 pre=load('VAPOR_PR1779_IMMEDIATE_PREMERGE_V1.json');merge=load('VAPOR_PR1779_ACTUAL_MERGE_API_V1.json')
 assert pre['head']['sha']==HEAD and pre['base']['sha']==PARENT and pre['merge_commit_sha']==SYNTHETIC and pre['mergeable'] and not pre['draft']
 assert merge['merged'] is True and merge['sha']==canonical
 for job in (136743781599,136743781552):assert STATUS in (ev/f'VAPOR_PR1779_FINAL_JOB{job}_FULL.txt').read_text(encoding='utf8')
 qualpath='integration/f-ci/nomacro-complete01/HYDRAULIC_VAPOR_QUALIFICATION.json';q=json.loads((root/qualpath).read_text());neutral=[qualpath]
 assert q['vapor_family_admitted'] is False and q['actual_full1096_contexts']==64 and q['actual_exact_cold_windows']==448
 for item in q['archives'].values():
  record=proof/item['record'];r=json.loads(record.read_text());neutral.append(record.relative_to(root).as_posix())
  neutral.extend((proof/name).relative_to(root).as_posix() for name in ([v['file'] for v in r['parts']] if r.get('parts') else [r['archive']]))
 assert not git('diff',HEAD,'--',*neutral),'Neutral vapor science or raw archives changed'
 for path in ev.glob('VAPOR_PR1779_*'):assert path.is_file();files[path.name]=path
 for name in ('VAPOR_PUBLIC_OBSERVE_V1.py','VAPOR_FINAL_NEGATIVES_OBSERVE_V1.json','VAPOR_ACTUAL_CANONICAL_POSTIMAGE_V1.json'):files[name]=ev/name
 members={name:dict(bytes=path.stat().st_size,sha256=SHA(path.read_bytes())) for name,path in files.items()}
 archive=proof/'HYDRAULIC_VAPOR_ADMISSION_RAW_V1.zip'
 if a.verify_only:
  record=json.loads(archive.with_suffix('.json').read_text());assert record['members']==members and record['sha256']==SHA(archive.read_bytes())
 else:
  assert not archive.exists() and not archive.with_suffix('.json').exists()
  with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
   for name,path in sorted(files.items()):z.write(path,name)
 with zipfile.ZipFile(archive) as z:
  assert len(z.namelist())==len(set(z.namelist()))==len(members)
  for name,item in members.items():raw=z.read(name);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
 if a.verify_only:print('ACTUAL_VAPOR_CANONICAL_ADMISSION_REVERIFIED_WITHOUT_WRITES');return
 digest=SHA(archive.read_bytes());counts={value:sum(c['conclusion']==value for c in checks['checks']) for value in ('success','skipped')}
 record=dict(status='ACTUAL_CANONICAL_VAPOR_ADMISSION_RAW_SEALED',canonical=canonical,candidate=HEAD,ordered_parents=[PARENT,HEAD],full_tree=TREE,archive=archive.name,bytes=archive.stat().st_size,sha256=digest,members=members,sealer_source=git('rev-parse','HEAD'),neutral_scientific_archives_changed=False)
 archive.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n')
 receipt=dict(status='ACTUAL_CANONICAL_BOUNDED_VAPOR_ADMISSION_VERIFIED',PR=1779,previous_canonical=PARENT,qualified_head=HEAD,synthetic_merge=SYNTHETIC,actual_merge=canonical,ordered_parents=[PARENT,HEAD],whole_qualified_tree=TREE,all_terminal_PR_checks=len(checks['checks']),check_conclusions=counts,all_terminal_workflow_runs=len(runs),all_workflow_runs_success=True,actual_candidate_public_seconds=observations[cases[0][0]]['seconds'],actual_canonical_public_seconds=observations[cases[1][0]]['seconds'],actual_canonical_sparse_patterns=35,admission_archive_sha256=digest,vapor_family_admitted=True,neutral_qualification_and_all_eight_raw_roles_unchanged=True,full1096_contexts=64,exact_cold_windows=448,compiled_native_refusals=1002,active_transaction_contexts=12,scope=q['scope'],whole_historical_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)
 (proof/'HYDRAULIC_VAPOR_MERGE_RECEIPT_V1.json').write_text(json.dumps(receipt,indent=2)+'\n');print(record['status'],record['bytes'],digest,len(members))


if __name__=='__main__':main()
