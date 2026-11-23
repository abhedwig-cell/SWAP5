"""Seal actual canonical216 only after real clean45 public/PUB and final controls."""
import argparse,hashlib,json,subprocess,zipfile
from pathlib import Path
HEAD='67d2636672921505ecb47f1c9f4c6ea27a451889'
PARENT='79ff3ab235f8b07535bf5273dcda32f4bef15f7d'
TREE='8c2cd14e561b0f2d25fbe597d76c565af61a0589'
STATUS='BOUNDED_ORIGINAL_EXPLICIT9_WATER_CDE_AGE_CALENDAR_DRAINAGE_SOURCE_RAW_NATIVE_PASS'
SHA=lambda raw:hashlib.sha256(raw).hexdigest()

def main():
 p=argparse.ArgumentParser()
 for key in ('repository','evidence'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();root=a.repository;ev=a.evidence;proof=root/'integration/f-ci/nomacro-complete01';git=lambda *args:subprocess.check_output(['git',*args],cwd=root,text=True).strip();load=lambda name:json.loads((ev/name).read_text());files={}
 def keep(name):
  path=ev/name;assert path.is_file() and not path.is_symlink();files[name]=path;return path
 pre=load('EXPLICIT_BOTTOM9_PR1789_IMMEDIATE_PREMERGE_V1.json');keep('EXPLICIT_BOTTOM9_PR1789_IMMEDIATE_PREMERGE_V1.json');assert pre['head']['sha']==HEAD and pre['base']['sha']==PARENT and pre['mergeable'] and not pre['draft'];synthetic=pre['merge_commit_sha'];assert len(synthetic)==40
 merge=load('EXPLICIT_BOTTOM9_PR1789_ACTUAL_MERGE_API_V1.json');keep('EXPLICIT_BOTTOM9_PR1789_ACTUAL_MERGE_API_V1.json');assert merge['merged'];canonical=merge['sha'];assert len(canonical)==40
 for commit in (canonical,synthetic):assert git('show','-s','--format=%P',commit).split()==[PARENT,HEAD]
 for commit in (HEAD,canonical,synthetic):assert git('rev-parse',commit+'^{tree}')==TREE
 controls=load('EXPLICIT_BOTTOM9_FINAL_NEGATIVES_OBSERVE_V4.json');keep('EXPLICIT_BOTTOM9_FINAL_NEGATIVES_OBSERVE_V4.json');assert controls['status']=='FOUR_ACTUAL_COMMITTED_PUSHED_CLEAN45_PUBLIC_NEGATIVES_REFUSED' and controls['candidate']==HEAD and controls['never_merge'] and len(controls['controls'])==4
 expected={'SOURCE':'app/hybrid_water/prescribed_head_flux_boundary.py','RAW':'integration/f-ci/nomacro-complete01/EXPLICIT_BOTTOM9_CDE_UBUNTU_DRAIN_O0_RAW_V1.zip','INHERITED':'integration/f-ci/nomacro-complete01/INITIAL_PROFILE_FROST_ADMISSION_RAW_V1.zip','PUBLICATION':'tests/publication/run_pub_p2e09_reference_threshold_freeze.sh'}
 assert {item['role']:item['path'] for item in controls['controls']}==expected
 cases=[('EXPLICIT_BOTTOM9_CANDIDATE_PUBLIC_OWNER_V3',HEAD,False),('EXPLICIT_BOTTOM9_ACTUAL_CANONICAL_PUBLIC_OWNER_V1',canonical,False)]+[('EXPLICIT_BOTTOM9_FINAL_'+item['role']+'_NEGATIVE_PUBLIC_V4',item['head'],True) for item in controls['controls']];observations={}
 for label,head,negative in cases:
  q=load(label+'.json');observations[label]=q
  for suffix in ('.json','.stdout.txt','.stderr.txt'):keep(label+suffix)
  assert q['status']=='ACTUAL_PUBLIC_COMMAND_RETURNED' and q['before']==q['after'] and q['before']['head']==head and not q['before']['status'] and len(q['before']['sparse'])==45 and q['model_executions']==q['compiler_executions']==0 and q['command'][-1]=='tests/hupsel51/verify_successor.py'
  out=(ev/(label+'.stdout.txt')).read_bytes();err=(ev/(label+'.stderr.txt')).read_bytes()
  if negative:assert isinstance(q['returncode'],int) and q['returncode']!=0 and b'AssertionError' in err
  else:
   result=json.loads(out);assert q['returncode']==0 and not err and q['before']['tree']==TREE and result['status']==STATUS
   assert result['coadmission']['contexts']==216 and result['coadmission']['short35_contexts']==214 and result['coadmission']['year367_contexts']==2 and result['coadmission']['native_calendar_samples']==1518 and result['coadmission']['exact_cold_windows']==652 and result['coadmission']['compiled_postimages']==159 and result['coadmission']['standalone_AGE110_admission_claimed'] is False
   assert result['functional_completion']=='PARTIAL' and result['whole_scientific_equivalence']=='NOT_QUALIFIED' and result['RC3_changed'] is False
 for item in controls['controls']:
  assert git('show','-s','--format=%P',item['head'])==HEAD and git('diff','--name-only',HEAD,item['head'])==item['path'] and item['actual_refusal']
  assert git('ls-remote','origin','refs/heads/'+item['branch']).split()[0]==item['head']
  for tail in ('.stdout.txt','.stderr.txt'):keep('EXPLICIT_BOTTOM9_FINAL_'+item['role']+'_NEGATIVE_PUSH_V4'+tail)
 for label,head in [('EXPLICIT_BOTTOM9_FINAL_PUBLICATION_SCOPE_POSITIVE_V2.json',HEAD),('EXPLICIT_BOTTOM9_FINAL_PUBLICATION_SCOPE_CANONICAL_POSITIVE_V1.json',canonical)]:
  q=load(label);keep(label);assert q['before']==q['after'] and q['before']['head']==head and not q['before']['status'] and len(q['before']['sparse'])==45 and q['returncode']==0 and not q['stderr'] and 'PUBLICATION_REPLAY_SELECTED=false' in q['stdout'] and q['compiler_executions']==q['model_executions']==0
 pubnegative='EXPLICIT_BOTTOM9_FINAL_PUBLICATION_SCOPE_NEGATIVE_V4.stdout.txt';assert 'PUBLICATION_REPLAY_SELECTED=true' in keep(pubnegative).read_text();assert not keep('EXPLICIT_BOTTOM9_FINAL_PUBLICATION_SCOPE_NEGATIVE_V4.stderr.txt').read_bytes()
 checks=load('EXPLICIT_BOTTOM9_FINAL67_ALL_TERMINAL_CHECKS_V1.json');keep('EXPLICIT_BOTTOM9_FINAL67_ALL_TERMINAL_CHECKS_V1.json');assert checks['total_count']==len(checks['check_runs'])==45 and len({c['id'] for c in checks['check_runs']})==45 and all(c['head_sha']==HEAD and c['status']=='completed' and c['conclusion'] in ('success','skipped') for c in checks['check_runs']) and sum(c['conclusion']=='success' for c in checks['check_runs'])==30
 runs=load('EXPLICIT_BOTTOM9_FINAL67_ALL_TERMINAL_RUNS_API_V1.json');keep('EXPLICIT_BOTTOM9_FINAL67_ALL_TERMINAL_RUNS_API_V1.json');assert runs['total_count']==len(runs['workflow_runs'])==16 and all(r['head_sha']==HEAD and r['status']=='completed' and r['conclusion']=='success' for r in runs['workflow_runs'])
 legacy=load('EXPLICIT_BOTTOM9_FINAL67_COMMIT_STATUSES_V1.json');keep('EXPLICIT_BOTTOM9_FINAL67_COMMIT_STATUSES_V1.json');assert legacy['total_count']==len(legacy['statuses']) and all(v['state']=='success' for v in legacy['statuses'])
 logs=load('EXPLICIT_BOTTOM9_FINAL67_TERMINAL_CI_RECEIPT_V1.json');keep('EXPLICIT_BOTTOM9_FINAL67_TERMINAL_CI_RECEIPT_V1.json');assert logs['candidate']==HEAD and len(logs['logs'])==2
 for item in logs['logs']:
  path=keep(item['file']);raw=path.read_bytes();assert len(raw)==item['bytes'] and SHA(raw)==item['sha256'] and HEAD in raw.decode() and STATUS in raw.decode() and item['coadmission']['contexts']==216
 # Keep every actual failed/setup observer and controller, without relabelling
 # their outcomes. Scientific model raw remains once in its existing archives.
 for path in ev.iterdir():
  if not path.is_file():continue
  name=path.name;upper=name.upper()
  if ('ANALYTICAL' not in upper and (upper.startswith('EXPLICIT_BOTTOM9_FINAL') or upper.startswith('EXPLICIT_BOTTOM9_CANDIDATE') or upper.startswith('EXPLICIT_BOTTOM9_GW_SCIENCE') or name.startswith('explicit-bottom9-final-real-negatives-') or name.startswith('explicit-bottom9-final67-original-job-log-'))):files.setdefault(name,path)
 for name in ('EXPLICIT_BOTTOM9_COADMISSION_CONTRACT_V1.json','EXPLICIT_BOTTOM9_QUALIFICATION_V1.json','INITIAL_PROFILE_AGE_GROUNDWATER_ADMISSION_RAW_V1.json','INITIAL_PROFILE_AGE_GROUNDWATER_MERGE_RECEIPT_V1.json'):
  raw=(proof/name).read_bytes();assert raw.replace(b'\r\n',b'\n')==subprocess.check_output(['git','show',HEAD+':integration/f-ci/nomacro-complete01/'+name],cwd=root);files['neutral-'+name]=proof/name
 files['actual-sealer.py']=Path(__file__)
 name='EXPLICIT_BOTTOM9_ADMISSION_RAW_V1';archive=proof/(name+'.zip');assert not archive.exists() and not archive.with_suffix('.json').exists();members={key:dict(bytes=value.stat().st_size,sha256=SHA(value.read_bytes())) for key,value in files.items()}
 with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
  for key,path in sorted(files.items()):z.write(path,key)
 with zipfile.ZipFile(archive) as z:
  assert len(z.namelist())==len(set(z.namelist()))==len(members)
  for key,item in members.items():raw=z.read(key);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
 digest=SHA(archive.read_bytes());size=archive.stat().st_size;assert size<90*1024*1024
 record=dict(status='ACTUAL_CANONICAL_216CONTEXT_EXPLICIT9_ADMISSION_RAW_SEALED',canonical=canonical,candidate=HEAD,ordered_parents=[PARENT,HEAD],full_tree=TREE,archive=archive.name,bytes=size,sha256=digest,parts=[dict(file=archive.name,bytes=size,sha256=digest)],members=members,sealer_source=git('rev-parse','HEAD'),neutral_scientific_archives_changed=False,canonical_admission=True,standalone_AGE110_admission_claimed=False);archive.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n')
 receipt=dict(status='ACTUAL_CANONICAL_216CONTEXT_EXPLICIT9_WATER_CDE_AGE_CALENDAR_DRAINAGE_ADMISSION_VERIFIED',PR=1789,previous_canonical=PARENT,qualified_head=HEAD,synthetic_merge=synthetic,actual_merge=canonical,ordered_parents=[PARENT,HEAD],whole_qualified_tree=TREE,all_terminal_PR_checks=45,success=30,skipped=15,all16workflow_runs_success=True,actual_candidate_public_seconds=observations[cases[0][0]]['seconds'],actual_canonical_public_seconds=observations[cases[1][0]]['seconds'],actual_canonical_sparse_patterns=45,admission_archive_sha256=digest,canonical_admission=True,contexts=216,short35_contexts=214,year367_contexts=2,exact_cold_windows=652,native_calendar_samples=1518,compiled_postimages=159,fresh_compilations_in_local_read_only_observers=0,fresh_model_periods_in_local_read_only_observers=0,canonical_push_CI_not_replaced_by_PR_gates=True,whole_historical_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)
 (proof/'EXPLICIT_BOTTOM9_MERGE_RECEIPT_V1.json').write_text(json.dumps(receipt,indent=2)+'\n');print(record['status'],size,digest,len(members))

if __name__=='__main__':main()
