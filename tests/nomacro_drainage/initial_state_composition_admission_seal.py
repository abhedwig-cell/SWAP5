"""Seal actual canonical initial-state composition admission while preserving neutral raw."""
import argparse,json,subprocess,zipfile
from pathlib import Path
from analytical_hydraulic_archives import SHA
HEAD='5c0cba9fbbd93ffb482199016f392e53e371e095'
PARENT='a8aa149a22b67a7f5bbf7c2e4243002f89d7242c'
SYNTHETIC='c24f72f547b12a0a2f2c4edfb59a10b79e647442'
CANONICAL='904d3cdd1fb9132839bec689c22cdeecdba79676'
TREE='47eb063eaca3ed78287cbe71e68898f4f74d9e50'
STATUS='BOUNDED_ORIGINAL_INITIAL_STATE_COMPOSITION_SOURCE_RAW_NATIVE_PASS'
NEGATIVES=(('SOURCE','b70f682375abd2321cb053f3fd71520289014bd1','app/hybrid_water/ordinary_pond_source_guard.py','Unreviewed original initial-state composition source delta'),('RAW','db7c8fb66bdfea2bf14f294b9f3e69fadf13c784','integration/f-ci/nomacro-complete01/INITIAL_STATE_COMPOSITION_WINDOWS_RAW_V1.zip','AssertionError'),('INHERITED','6393e4bc7a2c1986b53a8f71df23da59752d87fb','integration/f-ci/nomacro-complete01/HYDRAULIC_INITIAL_PRESSURE_ADMISSION_RAW_V1.zip','AssertionError'),('PUBLICATION','6f3c038405f7d4523ee4f36bc766f66243dc4266','tests/publication/run_pub_p2e09_reference_threshold_freeze.sh','AssertionError'))


def main():
 p=argparse.ArgumentParser()
 for key in ('repository','evidence'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--verify-only',action='store_true');a=p.parse_args();root=a.repository;ev=a.evidence;proof=root/'integration/f-ci/nomacro-complete01';git=lambda *args:subprocess.check_output(['git',*args],cwd=root,text=True).strip();load=lambda name:json.loads((ev/name).read_text())
 archive=proof/'INITIAL_STATE_COMPOSITION_ADMISSION_RAW_V1.zip'
 if a.verify_only:
  record=json.loads(archive.with_suffix('.json').read_text());assert record['canonical']==CANONICAL and record['sha256']==SHA(archive.read_bytes())
  with zipfile.ZipFile(archive) as z:
   assert len(z.namelist())==len(set(z.namelist()))==len(record['members'])
   for name,item in record['members'].items():raw=z.read(name);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
  print('FIXED_ORIGINAL_INITIAL_STATE_COMPOSITION_ADMISSION_ARCHIVE_VERIFIED_WITHOUT_WRITES');return
 assert not archive.exists() and not archive.with_suffix('.json').exists();merge=load('INITIAL_STATE_COMPOSITION_PR1786_ACTUAL_MERGE_API_V1.json');assert merge['merged'] and merge['sha']==CANONICAL
 for commit in (CANONICAL,SYNTHETIC):assert git('show','-s','--format=%P',commit).split()==[PARENT,HEAD]
 for commit in (HEAD,CANONICAL,SYNTHETIC):assert git('rev-parse',commit+'^{tree}')==TREE
 observations={};cases=[('INITIAL_STATE_COMPOSITION_FINAL_CANDIDATE_PUBLIC_OWNER_V1',HEAD,None),('INITIAL_STATE_COMPOSITION_ACTUAL_CANONICAL_PUBLIC_OWNER_V1',CANONICAL,None)]+[('INITIAL_STATE_COMPOSITION_FINAL_'+role+'_NEGATIVE_PUBLIC_V1',head,error) for role,head,path,error in NEGATIVES]
 for label,head,error in cases:
  q=load(label+'.json');observations[label]=q;assert q['before']==q['after'] and q['before']['head']==head and not q['before']['status'] and len(q['before']['sparse'])==40 and q['model_executions']==q['compiler_executions']==0 and q['command'][-1]=='tests/hupsel51/verify_successor.py'
  out=(ev/(label+'.stdout.txt')).read_bytes();err=(ev/(label+'.stderr.txt')).read_bytes()
  if error:assert q['returncode']!=0 and error in err.decode()
  else:assert q['returncode']==0 and not err and q['before']['tree']==TREE and json.loads(out)['status']==STATUS
 for role,head,path,error in NEGATIVES:assert git('diff','--name-only',HEAD,head)==path and git('show','-s','--format=%P',head)==HEAD
 for name,head in [('INITIAL_STATE_COMPOSITION_FINAL_PUBLICATION_SCOPE_POSITIVE_V1.json',HEAD),('INITIAL_STATE_COMPOSITION_FINAL_PUBLICATION_SCOPE_CANONICAL_POSITIVE_V1.json',CANONICAL)]:
  q=load(name);assert q['head']==head and q['returncode']==0 and q['clean_including_ignored'] and q['model_executions']==q['compiler_executions']==0 and 'PUBLICATION_REPLAY_SELECTED=false' in q['stdout'] and not q['stderr']
 assert 'PUBLICATION_REPLAY_SELECTED=true' in (ev/'INITIAL_STATE_COMPOSITION_FINAL_PUBLICATION_SCOPE_NEGATIVE_V1.txt').read_text()
 checks=load('INITIAL_STATE_COMPOSITION_PR1786_ALL_TERMINAL_CHECKS_V1.json');assert checks['headRevision']==HEAD and not checks['hasMore'] and not checks['statuses'] and len(checks['checks'])==44 and all(c['head_sha']==HEAD and c['status']=='completed' and c['conclusion'] in ('success','skipped') for c in checks['checks']) and sum(c['conclusion']=='success' for c in checks['checks'])==29
 runs=load('INITIAL_STATE_COMPOSITION_PR1786_ALL_TERMINAL_RUNS_V1.json');assert runs['total_count']==len(runs['workflow_runs'])==15 and all(v['head_sha']==HEAD and v['status']=='completed' and v['conclusion']=='success' for v in runs['workflow_runs'])
 pre=load('INITIAL_STATE_COMPOSITION_PR1786_IMMEDIATE_PREMERGE_V1.json');assert pre['head']['sha']==HEAD and pre['base']['sha']==PARENT and pre['merge_commit_sha']==SYNTHETIC and pre['mergeable'] and not pre['draft']
 for name in ('INITIAL_STATE_COMPOSITION_PR1786_READER136883596873_HEAD_PASS_FULL_V1.txt','INITIAL_STATE_COMPOSITION_PR1786_COLUMN136883596445_HEAD_PASS_FULL_V1.txt'):assert STATUS in (ev/name).read_text()
 files={p.name:p for p in ev.iterdir() if p.is_file() and p.name.lower().startswith(('initial_state_composition','initial-state-composition'))}
 stems=('INITIAL_STATE_COMPOSITION_WINDOWS_RAW_V1','INITIAL_STATE_COMPOSITION_UBUNTU_O0_RAW_V1','INITIAL_STATE_COMPOSITION_UBUNTU_O2_RAW_V1');neutral=['INITIAL_STATE_COMPOSITION_QUALIFICATION.json',*[s+'.json' for s in stems]]
 for name in neutral:
  assert (proof/name).read_bytes().replace(b'\r\n',b'\n')==subprocess.check_output(['git','show',HEAD+':integration/f-ci/nomacro-complete01/'+name],cwd=root);files['neutral-'+name]=proof/name
 members={name:dict(bytes=p.stat().st_size,sha256=SHA(p.read_bytes())) for name,p in files.items()}
 with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
  for name,path in sorted(files.items()):z.write(path,name)
 with zipfile.ZipFile(archive) as z:
  assert len(z.namelist())==len(set(z.namelist()))==len(members)
  for name,item in members.items():raw=z.read(name);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
 digest=SHA(archive.read_bytes());record=dict(status='ACTUAL_CANONICAL_ORIGINAL_INITIAL_STATE_COMPOSITION_ADMISSION_RAW_SEALED',canonical=CANONICAL,candidate=HEAD,ordered_parents=[PARENT,HEAD],full_tree=TREE,archive=archive.name,bytes=archive.stat().st_size,sha256=digest,members=members,sealer_source=git('rev-parse','HEAD'),neutral_scientific_archives_changed=False)
 archive.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n');qual=json.loads((proof/neutral[0]).read_text());receipt=dict(status='ACTUAL_CANONICAL_ORIGINAL_INITIAL_STATE_COMPOSITION_ADMISSION_VERIFIED',PR=1786,previous_canonical=PARENT,qualified_head=HEAD,synthetic_merge=SYNTHETIC,actual_merge=CANONICAL,ordered_parents=[PARENT,HEAD],whole_qualified_tree=TREE,all_terminal_PR_checks=44,success=29,skipped=15,all15workflow_runs_success=True,actual_candidate_public_seconds=observations[cases[0][0]]['seconds'],actual_canonical_public_seconds=observations[cases[1][0]]['seconds'],actual_canonical_sparse_patterns=40,admission_archive_sha256=digest,canonical_admission=True,short35_contexts=30,exact_cold_windows=90,native_checkpoints=210,exact_private_CDE_stocks=126,frontend_controls=56,fresh_compilations_for_admission=0,fresh_model_periods_for_admission=0,neutral_qualification_and_raw_unchanged=True,scope=qual['scope'],earlier_failed_and_cancelled_controls_retained=True,canonical_push_all_workflows_success=False,canonical_push_preservation_jobs_failed=[136892901248,136892901578],canonical_push_preservation_runs_failed=[44919721650,44919721728],canonical_push_preservation_failure='Existing unresolved verify_dataqual12_current.py broad scientific_delta source succession assertion; before model execution, full logs retained, no waiver or successful replay claimed',whole_historical_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)
 (proof/'INITIAL_STATE_COMPOSITION_MERGE_RECEIPT_V1.json').write_text(json.dumps(receipt,indent=2)+'\n');print(record['status'],record['bytes'],digest,len(members))


if __name__=='__main__':main()
