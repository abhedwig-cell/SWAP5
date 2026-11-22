"""Seal the actual final 156-context admission, never an intermediate candidate."""
import argparse,json,subprocess,zipfile
from pathlib import Path
from analytical_hydraulic_archives import SHA
HEAD='8ae1661391ed35125421290de3fb5d95ec8cd5b5'
PARENT='84e815a0ba9f59a2d56fe838a3b13361ad8670a2'
SYNTHETIC='cbe2f277e7e7bdad5723c9ee68e73d8edce8c18b'
TREE='b3c78d4bd0c5b583bd8046e339bbe3bb3eb45371'
STATUS='BOUNDED_ORIGINAL_INITIAL_PRESSURE_AGE_GROUNDWATER_SOURCE_RAW_NATIVE_PASS'


def main():
 p=argparse.ArgumentParser()
 for key in ('repository','evidence'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();root=a.repository;ev=a.evidence;proof=root/'integration/f-ci/nomacro-complete01';git=lambda *args:subprocess.check_output(['git',*args],cwd=root,text=True).strip();load=lambda name:json.loads((ev/name).read_text())
 assert all(len(value)==40 for value in (HEAD,SYNTHETIC,TREE)),'Actual final head/tree/synthetic must exist before sealing'
 merge=load('INITIAL_PROFILE_AGE_GROUNDWATER_PR1788_ACTUAL_MERGE_API_V1.json');assert merge['merged'];canonical=merge['sha']
 name='INITIAL_PROFILE_AGE_GROUNDWATER_ADMISSION_RAW_V1';archive=proof/(name+'.zip');assert not archive.exists() and not archive.with_suffix('.json').exists()
 for commit in (canonical,SYNTHETIC):assert git('show','-s','--format=%P',commit).split()==[PARENT,HEAD]
 for commit in (HEAD,canonical,SYNTHETIC):assert git('rev-parse',commit+'^{tree}')==TREE
 controls=load('INITIAL_PROFILE_AGE_GROUNDWATER_FINAL_NEGATIVES_OBSERVE_V1.json');assert controls['status']=='FOUR_ACTUAL_COMMITTED_PUSHED_CLEAN44_PUBLIC_NEGATIVES_REFUSED' and controls['candidate']==HEAD and len(controls['controls'])==4 and controls['never_merge'] is True
 expected={'SOURCE':'app/hybrid_water/initial_profile_groundwater.py','RAW':'integration/f-ci/nomacro-complete01/INITIAL_PROFILE_GROUNDWATER_WINDOWS_RAW_V1.zip.part001','INHERITED':'integration/f-ci/nomacro-complete01/INITIAL_PROFILE_FROST_ADMISSION_RAW_V1.zip','PUBLICATION':'tests/publication/run_pub_p2e09_reference_threshold_freeze.sh'}
 assert {item['role']:item['path'] for item in controls['controls']}==expected
 cases=[('INITIAL_PROFILE_AGE_GROUNDWATER_FINAL_CANDIDATE_PUBLIC_OWNER_V2',HEAD,False),('INITIAL_PROFILE_AGE_GROUNDWATER_ACTUAL_CANONICAL_PUBLIC_OWNER_V1',canonical,False)]+[('INITIAL_PROFILE_AGE_GROUNDWATER_FINAL_'+item['role']+'_NEGATIVE_PUBLIC_V1',item['head'],True) for item in controls['controls']];observations={}
 for label,head,negative in cases:
  q=load(label+'.json');observations[label]=q;assert q['status']=='ACTUAL_PUBLIC_COMMAND_RETURNED' and q['before']==q['after'] and q['before']['head']==head and not q['before']['status'] and len(q['before']['sparse'])==44 and q['model_executions']==q['compiler_executions']==0 and q['command'][-1]=='tests/hupsel51/verify_successor.py'
  out=(ev/(label+'.stdout.txt')).read_bytes();err=(ev/(label+'.stderr.txt')).read_bytes()
  if negative:assert isinstance(q['returncode'],int) and q['returncode']!=0 and b'AssertionError' in err
  else:
   result=json.loads(out);assert q['returncode']==0 and not err and q['before']['tree']==TREE and result['status']==STATUS and result['coadmission']['contexts']==156 and result['coadmission']['standalone_AGE110_admission_claimed'] is False
 for item in controls['controls']:
  assert git('show','-s','--format=%P',item['head'])==HEAD and git('diff','--name-only',HEAD,item['head'])==item['path'] and item['actual_refusal'] is True
  assert git('ls-remote','origin','refs/heads/'+item['branch']).split()[0]==item['head']
 for label,head in [('INITIAL_PROFILE_AGE_GROUNDWATER_FINAL_PUBLICATION_SCOPE_POSITIVE_V1.json',HEAD),('INITIAL_PROFILE_AGE_GROUNDWATER_FINAL_PUBLICATION_SCOPE_CANONICAL_POSITIVE_V1.json',canonical)]:
  q=load(label);assert q['before']==q['after'] and q['before']['head']==head and not q['before']['status'] and q['returncode']==0 and not q['stderr'] and 'PUBLICATION_REPLAY_SELECTED=false' in q['stdout'] and q['compiler_executions']==q['model_executions']==0
 assert 'PUBLICATION_REPLAY_SELECTED=true' in (ev/'INITIAL_PROFILE_AGE_GROUNDWATER_FINAL_PUBLICATION_SCOPE_NEGATIVE_V1.txt').read_text()
 checks=load('INITIAL_PROFILE_AGE_GROUNDWATER_PR1788_ALL_TERMINAL_CHECKS_V1.json');assert checks['headRevision']==HEAD and not checks['hasMore'] and not checks['statuses'] and len(checks['checks'])==44 and all(c['head_sha']==HEAD and c['status']=='completed' and c['conclusion'] in ('success','skipped') for c in checks['checks']) and sum(c['conclusion']=='success' for c in checks['checks'])==29
 runs=load('INITIAL_PROFILE_AGE_GROUNDWATER_PR1788_ALL_TERMINAL_RUNS_V1.json');assert runs['total_count']==len(runs['workflow_runs'])==15 and all(v['head_sha']==HEAD and v['status']=='completed' and v['conclusion']=='success' for v in runs['workflow_runs'])
 pre=load('INITIAL_PROFILE_AGE_GROUNDWATER_PR1788_IMMEDIATE_PREMERGE_V1.json');assert pre['head']['sha']==HEAD and pre['base']['sha']==PARENT and pre['merge_commit_sha']==SYNTHETIC and pre['mergeable'] and not pre['draft']
 logs=load('INITIAL_PROFILE_AGE_GROUNDWATER_PR1788_FULL_PASS_LOGS_V1.json');assert logs['head']==HEAD and {item['check_name'] for item in logs['logs']}=={'original-reader','column'} and len(logs['logs'])==2
 for item in logs['logs']:
  assert any(check['id']==item['job_id'] and check['name']==item['check_name'] and check['conclusion']=='success' for check in checks['checks'])
  raw=(ev/item['file']).read_bytes();assert len(raw)==item['bytes'] and SHA(raw)==item['sha256'] and STATUS in raw.decode('utf8') and HEAD in raw.decode('utf8')
 files={path.name:path for path in ev.iterdir() if path.is_file() and path.name.lower().startswith(('initial_profile_age_groundwater','initial-profile-age-groundwater'))}
 failed_artifact=ev/'GITHUB_ARTIFACT_14732030831_ORIGINAL_V1.zip';assert failed_artifact.is_file();files[failed_artifact.name]=failed_artifact
 neutral=['INITIAL_PROFILE_AGE_GROUNDWATER_QUALIFICATION.json','INITIAL_PROFILE_AGE_GROUNDWATER_COADMISSION_CONTRACT_V1.json','INITIAL_PROFILE_AGE_QUALIFICATION.json','INITIAL_PROFILE_GROUNDWATER_CONTRACT_V1.json','INITIAL_PROFILE_FROST_ADMISSION_RAW_V1.json','INITIAL_PROFILE_FROST_MERGE_RECEIPT_V1.json']+[n+'.json' for n in tuple('INITIAL_PROFILE_'+family+'_'+suffix+'_RAW_V1' for family in ('AGE','GROUNDWATER') for suffix in ('WINDOWS','UBUNTU_O0','UBUNTU_O2'))]
 for filename in neutral:assert (proof/filename).read_bytes().replace(b'\r\n',b'\n')==subprocess.check_output(['git','show',HEAD+':integration/f-ci/nomacro-complete01/'+filename],cwd=root);files['neutral-'+filename]=proof/filename
 members={key:dict(bytes=path.stat().st_size,sha256=SHA(path.read_bytes())) for key,path in files.items()}
 with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
  for key,path in sorted(files.items()):z.write(path,key)
 with zipfile.ZipFile(archive) as z:
  assert len(z.namelist())==len(set(z.namelist()))==len(members)
  for key,item in members.items():raw=z.read(key);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
 digest=SHA(archive.read_bytes());size=archive.stat().st_size;assert size<90*1024*1024
 record=dict(status='ACTUAL_CANONICAL_156CONTEXT_PRESSURE_AGE_GROUNDWATER_ADMISSION_RAW_SEALED',canonical=canonical,candidate=HEAD,ordered_parents=[PARENT,HEAD],full_tree=TREE,archive=archive.name,bytes=size,sha256=digest,parts=[dict(file=archive.name,bytes=size,sha256=digest)],members=members,sealer_source=git('rev-parse','HEAD'),neutral_scientific_archives_changed=False,canonical_admission=True,standalone_AGE110_admission_claimed=False)
 archive.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n')
 receipt=dict(status='ACTUAL_CANONICAL_156CONTEXT_PRESSURE_AGE_GROUNDWATER_ADMISSION_VERIFIED',PR=1788,previous_canonical=PARENT,qualified_head=HEAD,synthetic_merge=SYNTHETIC,actual_merge=canonical,ordered_parents=[PARENT,HEAD],whole_qualified_tree=TREE,all_terminal_PR_checks=44,success=29,skipped=15,all15workflow_runs_success=True,actual_candidate_public_seconds=observations[cases[0][0]]['seconds'],actual_canonical_public_seconds=observations[cases[1][0]]['seconds'],actual_canonical_sparse_patterns=44,admission_archive_sha256=digest,canonical_admission=True,standalone_AGE110_admission_claimed=False,contexts=156,short35_contexts=154,year367_contexts=2,exact_cold_windows=472,native_calendar_samples=1098,compiled_postimages=103,fresh_compilations_in_local_read_only_admission_observers=0,fresh_model_periods_in_local_read_only_admission_observers=0,CI_runtime_tests_preserved_and_executed_separately=True,neutral_qualification_and_raw_unchanged=True,canonical_push_CI_not_replaced_by_PR_gates=True,whole_historical_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)
 (proof/'INITIAL_PROFILE_AGE_GROUNDWATER_MERGE_RECEIPT_V1.json').write_text(json.dumps(receipt,indent=2)+'\n');print(record['status'],size,digest,len(members))


if __name__=='__main__':main()
