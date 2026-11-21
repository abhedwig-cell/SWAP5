"""Seal actual canonical initial-profile admission while preserving neutral raw."""
import argparse,json,subprocess,zipfile
from pathlib import Path
from analytical_hydraulic_archives import SHA
HEAD='83ec37ac4aeba6901c6eea28d1b5d0f72633f2a8'
PARENT='56efdcbb78cbf4cdedd3b70bc44b76323f7112b4'
SYNTHETIC='fdcc40cdca1a1d4b9f885a283e59701e78caa6d8'
CANONICAL='a8aa149a22b67a7f5bbf7c2e4243002f89d7242c'
TREE='8749a93476d8dc52f0f1da19bf79336f8629a2c5'
STATUS='BOUNDED_ORIGINAL_INITIAL_PRESSURE_PROFILE_SOURCE_RAW_NATIVE_PASS'
NEGATIVES=(('SOURCE','22e97566220798af561574d6ebf64432da8f1156','app/hybrid_water/experimental_project.py','Unreviewed initial pressure profile source delta'),('RAW','a00bef09364e6f55d35df2a991620e201f540e82','integration/f-ci/nomacro-complete01/HYDRAULIC_INITIAL_PRESSURE_WINDOWS_RAW_V1.zip','AssertionError'),('INHERITED','9854cdf42124079a39e5fed304dd70cf93bc7d3f','integration/f-ci/nomacro-complete01/HYDRAULIC_VAPOR_BOUNDARY_ADMISSION_RAW_V1.zip','AssertionError'),('PUBLICATION','9c0f4e7ddb65b067e4a15a1a90a568272b13c8f9','tests/publication/run_pub_p2e09_reference_threshold_freeze.sh','AssertionError'))


def main():
 p=argparse.ArgumentParser()
 for key in ('repository','evidence'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--verify-only',action='store_true');a=p.parse_args();root=a.repository;ev=a.evidence;proof=root/'integration/f-ci/nomacro-complete01';git=lambda *args:subprocess.check_output(['git',*args],cwd=root,text=True).strip();load=lambda name:json.loads((ev/name).read_text())
 archive=proof/'HYDRAULIC_INITIAL_PRESSURE_ADMISSION_RAW_V1.zip'
 if a.verify_only:
  record=json.loads(archive.with_suffix('.json').read_text());assert record['canonical']==CANONICAL and record['sha256']==SHA(archive.read_bytes())
  with zipfile.ZipFile(archive) as z:
   assert len(z.namelist())==len(set(z.namelist()))==len(record['members'])
   for name,item in record['members'].items():raw=z.read(name);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
  print('FIXED_ORIGINAL_INITIAL_PROFILE_ADMISSION_ARCHIVE_VERIFIED_WITHOUT_WRITES');return
 assert not archive.exists() and not archive.with_suffix('.json').exists();merge=load('INITIAL_PRESSURE_PROFILE_PR1785_ACTUAL_MERGE_API_V1.json');assert merge['merged'] and merge['sha']==CANONICAL
 for commit in (CANONICAL,SYNTHETIC):assert git('show','-s','--format=%P',commit).split()==[PARENT,HEAD]
 for commit in (HEAD,CANONICAL,SYNTHETIC):assert git('rev-parse',commit+'^{tree}')==TREE
 observations={};cases=[('INITIAL_PRESSURE_PROFILE_FINAL_CANDIDATE_PUBLIC_OWNER_V3',HEAD,None),('INITIAL_PRESSURE_PROFILE_ACTUAL_CANONICAL_PUBLIC_OWNER_V1',CANONICAL,None)]+[('INITIAL_PRESSURE_PROFILE_FINAL_'+role+'_NEGATIVE_PUBLIC_V4',head,error) for role,head,path,error in NEGATIVES]
 for label,head,error in cases:
  q=load(label+'.json');observations[label]=q;assert q['before']==q['after'] and q['before']['head']==head and not q['before']['status'] and len(q['before']['sparse'])==39 and q['model_executions']==q['compiler_executions']==0 and q['command'][-1]=='tests/hupsel51/verify_successor.py'
  out=(ev/(label+'.stdout.txt')).read_bytes();err=(ev/(label+'.stderr.txt')).read_bytes()
  if error:assert q['returncode']!=0 and error in err.decode()
  else:assert q['returncode']==0 and not err and q['before']['tree']==TREE and json.loads(out)['status']==STATUS
 for role,head,path,error in NEGATIVES:assert git('diff','--name-only',HEAD,head)==path and git('show','-s','--format=%P',head)==HEAD
 for name,head in [('INITIAL_PRESSURE_PROFILE_FINAL_PUBLICATION_SCOPE_POSITIVE_V3.json',HEAD),('INITIAL_PRESSURE_PROFILE_FINAL_PUBLICATION_SCOPE_CANONICAL_POSITIVE_V1.json',CANONICAL)]:
  q=load(name);assert q['head']==head and q['returncode']==0 and q['clean_including_ignored'] and q['model_executions']==q['compiler_executions']==0 and 'PUBLICATION_REPLAY_SELECTED=false' in q['stdout'] and not q['stderr']
 assert 'PUBLICATION_REPLAY_SELECTED=true' in (ev/'INITIAL_PRESSURE_PROFILE_FINAL_PUBLICATION_SCOPE_NEGATIVE_V4.txt').read_text()
 checks=load('INITIAL_PRESSURE_PROFILE_PR1785_ALL_TERMINAL_CHECKS_V1.json');assert checks['headRevision']==HEAD and not checks['hasMore'] and not checks['statuses'] and len(checks['checks'])==44 and all(c['head_sha']==HEAD and c['status']=='completed' and c['conclusion'] in ('success','skipped') for c in checks['checks']) and sum(c['conclusion']=='success' for c in checks['checks'])==29
 runs=load('INITIAL_PRESSURE_PROFILE_PR1785_ALL_TERMINAL_RUNS_V1.json');assert runs['total_count']==len(runs['workflow_runs'])==15 and all(v['head_sha']==HEAD and v['status']=='completed' and v['conclusion']=='success' for v in runs['workflow_runs'])
 pre=load('INITIAL_PRESSURE_PROFILE_PR1785_IMMEDIATE_PREMERGE_V1.json');assert pre['head']['sha']==HEAD and pre['base']['sha']==PARENT and pre['merge_commit_sha']==SYNTHETIC and pre['mergeable'] and not pre['draft']
 for name in ('INITIAL_PRESSURE_PROFILE_PR1785_READER136869949455_DEADLINE_HEAD_PASS_FULL_V1.txt','INITIAL_PRESSURE_PROFILE_PR1785_COLUMN136869949400_DEADLINE_HEAD_PASS_FULL_V1.txt'):assert STATUS in (ev/name).read_text()
 files={p.name:p for p in ev.iterdir() if p.is_file() and p.name.lower().startswith(('initial_pressure_profile','initial-pressure-profile'))}
 stems=('HYDRAULIC_INITIAL_PRESSURE_WINDOWS_RAW_V1','HYDRAULIC_INITIAL_PRESSURE_UBUNTU_O0_RAW_V1','HYDRAULIC_INITIAL_PRESSURE_UBUNTU_O2_RAW_V1','HYDRAULIC_INITIAL_PRESSURE_BOTTOM5_WINDOWS_RAW_V1');neutral=['HYDRAULIC_INITIAL_PRESSURE_QUALIFICATION.json',*[s+'.json' for s in stems]]
 for name in neutral:
  assert (proof/name).read_bytes().replace(b'\r\n',b'\n')==subprocess.check_output(['git','show',HEAD+':integration/f-ci/nomacro-complete01/'+name],cwd=root);files['neutral-'+name]=proof/name
 members={name:dict(bytes=p.stat().st_size,sha256=SHA(p.read_bytes())) for name,p in files.items()}
 with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
  for name,path in sorted(files.items()):z.write(path,name)
 with zipfile.ZipFile(archive) as z:
  assert len(z.namelist())==len(set(z.namelist()))==len(members)
  for name,item in members.items():raw=z.read(name);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
 digest=SHA(archive.read_bytes());record=dict(status='ACTUAL_CANONICAL_ORIGINAL_INITIAL_PRESSURE_PROFILE_ADMISSION_RAW_SEALED',canonical=CANONICAL,candidate=HEAD,ordered_parents=[PARENT,HEAD],full_tree=TREE,archive=archive.name,bytes=archive.stat().st_size,sha256=digest,members=members,sealer_source=git('rev-parse','HEAD'),neutral_scientific_archives_changed=False)
 archive.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n');qual=json.loads((proof/neutral[0]).read_text());receipt=dict(status='ACTUAL_CANONICAL_ORIGINAL_INITIAL_PRESSURE_PROFILE_ADMISSION_VERIFIED',PR=1785,previous_canonical=PARENT,qualified_head=HEAD,synthetic_merge=SYNTHETIC,actual_merge=CANONICAL,ordered_parents=[PARENT,HEAD],whole_qualified_tree=TREE,all_terminal_PR_checks=44,success=29,skipped=15,all15workflow_runs_success=True,actual_candidate_public_seconds=observations[cases[0][0]]['seconds'],actual_canonical_public_seconds=observations[cases[1][0]]['seconds'],actual_canonical_sparse_patterns=39,admission_archive_sha256=digest,canonical_admission=True,short35_contexts=14,exact_cold_windows=42,native_checkpoints=98,exact_private_CDE_stocks=56,frontend_controls=35,fresh_compilations_for_admission=0,fresh_model_periods_for_admission=0,neutral_qualification_and_raw_unchanged=True,scope=qual['scope'],earlier_failed_and_cancelled_controls_retained=True,unused_raw_V2_controller_probe_not_counted=True,canonical_push_all_workflows_success=False,canonical_push_preservation_jobs_failed=[136876797163,136876797414],canonical_push_preservation_runs_failed=[44914401059,44914401061],canonical_push_preservation_failure='Existing unresolved verify_dataqual12_current.py broad scientific_delta source succession assertion; before model execution, full logs retained, no waiver or successful replay claimed',whole_historical_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)
 (proof/'HYDRAULIC_INITIAL_PRESSURE_MERGE_RECEIPT_V1.json').write_text(json.dumps(receipt,indent=2)+'\n');print(record['status'],record['bytes'],digest,len(members))


if __name__=='__main__':main()
