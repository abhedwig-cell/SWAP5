"""Seal actual vapor boundary admission without changing neutral science."""
import argparse,hashlib,json,subprocess,zipfile
from pathlib import Path

HEAD='56df667d37c6e4070d6e552e493ddc0e28880a28'
PARENT='1e639e0febd12922e48ed7e239f29f7fabb95909'
SYNTHETIC='c8f081d45abcb7f42eedc297d57485719d60971b'
TREE='d986b747dfd44d41c148b99f6300f7bc03137445'
STATUS='BOUNDED_ORIGINAL_VAPOR_DRAINAGE_BOTTOM_NATIVE5_SOURCE_RAW_NATIVE_PASS'
NEGATIVES=(
 ('SOURCE','bc7424977b7d5f9c46364f4ab50a3b33a4676e8d','app/hybrid_water/vapor_boundary_composition.py','Unreviewed vapor boundary source delta'),
 ('RAW','68965f21e0868ce425c2214115c7b05ce673c7af','integration/f-ci/nomacro-complete01/HYDRAULIC_VAPOR_BOUNDARY_WINDOWS_RAW_V1.zip','AssertionError'),
 ('INHERITED','3ad83427639d396b5e4f96a1d64b7891aaf1bbe6','integration/f-ci/nomacro-complete01/HYDRAULIC_ANALYTICAL_CALENDAR_ADMISSION_RAW_V1.zip','AssertionError'),
 ('PUBLICATION','8a7e31bc4361ce56596969278e9d5a70fcb254cb','tests/publication/run_pub_p2e09_reference_threshold_freeze.sh','AssertionError'))
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


def main():
 p=argparse.ArgumentParser(description=__doc__)
 for key in ('repository','evidence'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--verify-only',action='store_true');a=p.parse_args();root=a.repository;ev=a.evidence;proof=root/'integration/f-ci/nomacro-complete01'
 git=lambda *args:subprocess.check_output(['git',*args],cwd=root,text=True).strip()
 load=lambda name:json.loads((ev/name).read_text(encoding='utf8'))
 merge=load('VAPOR_BOUNDARY_PR1784_ACTUAL_MERGE_API_V1.json');canonical=merge['sha'];assert merge['merged'] is True
 for commit in (canonical,SYNTHETIC):assert git('show','-s','--format=%P',commit).split()==[PARENT,HEAD]
 assert all(git('rev-parse',commit+'^{tree}')==TREE for commit in (HEAD,canonical,SYNTHETIC))
 files={};observations={}
 cases=[('VAPOR_BOUNDARY_FINAL_CANDIDATE_PUBLIC_OWNER_V1',HEAD,None),('VAPOR_BOUNDARY_ACTUAL_CANONICAL_PUBLIC_OWNER_V1',canonical,None)]
 cases += [('VAPOR_BOUNDARY_FINAL_'+role+'_NEGATIVE_PUBLIC_V1',head,error) for role,head,path,error in NEGATIVES]
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
  name='VAPOR_BOUNDARY_FINAL_PUBLICATION_SCOPE_'+role+'_V1.json';q=load(name)
  assert q['head']==head and q['clean_including_ignored'] and q['model_executions']==q['compiler_executions']==0
  assert 'PUBLICATION_REPLAY_SELECTED=false' in q['stdout'] and not q['stderr'];files[name]=ev/name
 name='VAPOR_BOUNDARY_FINAL_PUBLICATION_SCOPE_NEGATIVE_V1.txt';assert 'PUBLICATION_REPLAY_SELECTED=true' in (ev/name).read_text();files[name]=ev/name
 checks=load('VAPOR_BOUNDARY_PR1784_ALL_TERMINAL_CHECKS_V1.json')
 assert checks['headRevision']==HEAD and not checks['hasMore'] and not checks['statuses'] and len(checks['checks'])==42
 assert all(c['head_sha']==HEAD and c['status']=='completed' and c['conclusion'] in ('success','skipped') for c in checks['checks'])
 assert sum(c['conclusion']=='success' for c in checks['checks'])==27
 runs=load('VAPOR_BOUNDARY_PR1784_ALL_TERMINAL_RUNS_V1.json');assert runs['total_count']==len(runs['workflow_runs'])==13
 assert all(r['head_sha']==HEAD and r['status']=='completed' and r['conclusion']=='success' for r in runs['workflow_runs'])
 pre=load('VAPOR_BOUNDARY_PR1784_IMMEDIATE_PREMERGE_V1.json')
 assert pre['head']['sha']==HEAD and pre['base']['sha']==PARENT and pre['merge_commit_sha']==SYNTHETIC and pre['mergeable'] and not pre['draft']
 logs=[ev/'VAPOR_BOUNDARY_PR1784_FINAL_JOB136841339980_FULL.txt'];assert len(logs)==1
 for path in logs:assert STATUS in path.read_text(encoding='utf8')
 names=['HYDRAULIC_VAPOR_BOUNDARY_QUALIFICATION.json']
 for stem in ('HYDRAULIC_VAPOR_BOUNDARY_WINDOWS_RAW_V1','HYDRAULIC_VAPOR_BOUNDARY_UBUNTU_O0_RAW_V1','HYDRAULIC_VAPOR_BOUNDARY_UBUNTU_O2_RAW_V1','HYDRAULIC_VAPOR_BOUNDARY_GUARD_WINDOWS_RAW_V1','HYDRAULIC_VAPOR_BOUNDARY_GUARD_UBUNTU_O0_RAW_V1','HYDRAULIC_VAPOR_BOUNDARY_GUARD_UBUNTU_O2_RAW_V1'):
  names.extend(stem+suffix for suffix in ('.json','.zip'))
 neutral=['integration/f-ci/nomacro-complete01/'+name for name in names]
 assert not git('diff',HEAD,'--',*neutral),'Neutral native5 science changed'
 qual=json.loads((root/neutral[0]).read_text());assert not qual['canonical_admission'] and qual['native_domain_version']==5
 for pattern in ('VAPOR_BOUNDARY_PR1784_*','VAPOR_BOUNDARY_FINAL_*','VAPOR_BOUNDARY_ACTUAL_CANONICAL*'):
  for path in ev.glob(pattern):assert path.is_file();files[path.name]=path
 for pattern in ('VAPOR_BOUNDARY_FINAL_*','VAPOR_BOUNDARY_PR1784_*','vapor_boundary_actual_negatives_v1.py','vapor_boundary*publication_observe_v1.py','VAPOR_BOUNDARY_PUBLIC_OBSERVE_V1.py','VAPOR_BOUNDARY_*PUBLICATION_OBSERVE_V*.py'):
  for path in ev.glob(pattern):assert path.is_file();files[path.name]=path

 members={name:dict(bytes=path.stat().st_size,sha256=SHA(path.read_bytes())) for name,path in files.items()}
 archive=proof/'HYDRAULIC_VAPOR_BOUNDARY_ADMISSION_RAW_V1.zip'
 if a.verify_only:
  record=json.loads(archive.with_suffix('.json').read_text());assert record['members']==members and record['sha256']==SHA(archive.read_bytes())
 else:
  assert not archive.exists() and not archive.with_suffix('.json').exists()
  with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
   for name,path in sorted(files.items()):z.write(path,name)
 with zipfile.ZipFile(archive) as z:
  assert len(z.namelist())==len(set(z.namelist()))==len(members)
  for name,item in members.items():raw=z.read(name);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
 if a.verify_only:print('ACTUAL_VAPOR_BOUNDARY_CANONICAL_ADMISSION_REVERIFIED_WITHOUT_WRITES');return
 digest=SHA(archive.read_bytes());record=dict(status='ACTUAL_CANONICAL_VAPOR_BOUNDARY_ADMISSION_RAW_SEALED',canonical=canonical,candidate=HEAD,ordered_parents=[PARENT,HEAD],full_tree=TREE,archive=archive.name,bytes=archive.stat().st_size,sha256=digest,members=members,sealer_source=git('rev-parse','HEAD'),neutral_scientific_archives_changed=False)
 archive.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n')
 receipt=dict(status='ACTUAL_CANONICAL_BOUNDED_ORIGINAL_VAPOR_DRAINAGE_BOTTOM_NATIVE5_ADMISSION_VERIFIED',PR=1784,previous_canonical=PARENT,qualified_head=HEAD,synthetic_merge=SYNTHETIC,actual_merge=canonical,ordered_parents=[PARENT,HEAD],whole_qualified_tree=TREE,all_terminal_PR_checks=42,success=27,skipped=15,all13workflow_runs_success=True,actual_candidate_public_seconds=observations[cases[0][0]]['seconds'],actual_canonical_public_seconds=observations[cases[1][0]]['seconds'],actual_canonical_sparse_patterns=38,admission_archive_sha256=digest,canonical_admission=True,year367_contexts=4,short35_contexts=26,exact_cold_windows=98,native_checkpoints=222,exact_private_CDE_stocks=160,native_refusals=588,external_transaction_contexts=12,frontend_controls=55,fresh_full_periods_for_admission=0,original_targeted_build_probe_retained_in_neutral_raw=True,neutral_qualification_and_raw_unchanged=True,scope=qual['scope'],whole_historical_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False,canonical_older_source_succession_failures_not_waived=True)
 (proof/'HYDRAULIC_VAPOR_BOUNDARY_MERGE_RECEIPT_V1.json').write_text(json.dumps(receipt,indent=2)+'\n');print(record['status'],record['bytes'],digest,len(members))


if __name__=='__main__':main()
