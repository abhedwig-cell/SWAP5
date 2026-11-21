"""Seal the actual 74-context candidate gates for final Frost coadmission."""
import argparse,json,subprocess,zipfile
from pathlib import Path
from analytical_hydraulic_archives import SHA
HEAD='2de490869d688fd2eff0721b7d466d67956fc654'
PARENT='904d3cdd1fb9132839bec689c22cdeecdba79676'
SYNTHETIC='5c6997477aac2cf59529256dd8f98af29da99e9a'
TREE='44a50cc3cf5e3493bf5b290cbd02a8dbf427a2fb'
STATUS='BOUNDED_ORIGINAL_INITIAL_PROFILE_CALENDAR_SOURCE_RAW_NATIVE_PASS'
NEGATIVES=(('SOURCE','aba8ee363d3eb904d63a3c1320e70089af9ef0c0','app/hybrid_water/initial_profile_calendar.py'),('RAW','2a56c42c021390937109477cbe8e8b22f0ebc0c8','integration/f-ci/nomacro-complete01/INITIAL_PROFILE_CALENDAR_WINDOWS_RAW_V1.zip'),('INHERITED','e1799a8cbb3d570033658c6ff612f77daa9b470b','integration/f-ci/nomacro-complete01/ANALYTICAL_CDE_CALENDAR_CANDIDATE_STAGE_RAW_V1.zip'),('PUBLICATION','8de4d590d33c12e28335b7dc64722d446f861d06','tests/publication/run_pub_p2e09_reference_threshold_freeze.sh'))


def main():
 p=argparse.ArgumentParser()
 for key in ('repository','evidence'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();root=a.repository;ev=a.evidence;proof=root/'integration/f-ci/nomacro-complete01';git=lambda *args:subprocess.check_output(['git',*args],cwd=root,text=True).strip();load=lambda name:json.loads((ev/name).read_text())
 name='INITIAL_PROFILE_CALENDAR_CANDIDATE_STAGE_RAW_V1';archive=proof/(name+'.zip');assert not archive.exists() and not archive.with_suffix('.json').exists()
 assert git('show','-s','--format=%P',SYNTHETIC).split()==[PARENT,HEAD] and git('merge-base','--is-ancestor',HEAD,'HEAD')==''
 for commit in (HEAD,SYNTHETIC):assert git('rev-parse',commit+'^{tree}')==TREE
 cases=[('INITIAL_PROFILE_CALENDAR_FINAL_CANDIDATE_PUBLIC_OWNER_V3',HEAD,False)]+[('INITIAL_PROFILE_CALENDAR_FINAL_'+role+'_NEGATIVE_PUBLIC_V3',head,True) for role,head,path in NEGATIVES]
 for label,head,negative in cases:
  q=load(label+'.json');assert q['before']==q['after'] and q['before']['head']==head and not q['before']['status'] and len(q['before']['sparse'])==42 and q['model_executions']==q['compiler_executions']==0 and q['command'][-1]=='tests/hupsel51/verify_successor.py'
  out=(ev/(label+'.stdout.txt')).read_bytes();err=(ev/(label+'.stderr.txt')).read_bytes()
  if negative:assert q['returncode']!=0 and b'AssertionError' in err
  else:
   result=json.loads(out);assert q['returncode']==0 and not err and q['before']['tree']==TREE and result['status']==STATUS and result['coadmission']['contexts']==74
 for role,head,path in NEGATIVES:
  assert git('show','-s','--format=%P',head)==HEAD and git('diff','--name-only',HEAD,head)==path
  branch='codex/nomacro-initial-profile-calendar-'+role.lower()+'-negative03';assert git('ls-remote','origin','refs/heads/'+branch).split()[0]==head
 pub=load('INITIAL_PROFILE_CALENDAR_FINAL_PUBLICATION_SCOPE_POSITIVE_V3.json');assert pub['before']==pub['after'] and pub['before']['head']==HEAD and not pub['before']['status'] and pub['returncode']==0 and not pub['stderr'] and 'PUBLICATION_REPLAY_SELECTED=false' in pub['stdout'] and pub['compiler_executions']==pub['model_executions']==0
 assert 'PUBLICATION_REPLAY_SELECTED=true' in (ev/'INITIAL_PROFILE_CALENDAR_FINAL_PUBLICATION_SCOPE_NEGATIVE_V3.txt').read_text()
 checks=load('INITIAL_PROFILE_CALENDAR_PR1787_ALL_TERMINAL_CHECKS_V1.json');assert checks['headRevision']==HEAD and not checks['hasMore'] and not checks['statuses'] and len(checks['checks'])==44 and all(c['head_sha']==HEAD and c['status']=='completed' and c['conclusion'] in ('success','skipped') for c in checks['checks']) and sum(c['conclusion']=='success' for c in checks['checks'])==29
 runs=load('INITIAL_PROFILE_CALENDAR_PR1787_ALL_TERMINAL_RUNS_V1.json');assert runs['total_count']==len(runs['workflow_runs'])==15 and all(v['head_sha']==HEAD and v['status']=='completed' and v['conclusion']=='success' for v in runs['workflow_runs'])
 api=load('INITIAL_PROFILE_CALENDAR_PR1787_FINAL_CANDIDATE_STAGE_API_V1.json');assert api['head']['sha']==HEAD and api['base']['sha']==PARENT and api['merge_commit_sha']==SYNTHETIC and api['mergeable'] and not api['draft'] and api['state']=='open'
 for filename in ('INITIAL_PROFILE_CALENDAR_PR1787_READER136961908168_HEAD_PASS_FULL_V1.txt','INITIAL_PROFILE_CALENDAR_PR1787_COLUMN136962320159_HEAD_PASS_FULL_V1.txt'):assert STATUS in (ev/filename).read_text()
 files={path.name:path for path in ev.iterdir() if path.is_file() and path.name.lower().startswith(('initial_profile_calendar','initial-profile-calendar'))}
 neutral=['INITIAL_PROFILE_CALENDAR_QUALIFICATION.json','INITIAL_PROFILE_CALENDAR_COADMISSION_CONTRACT_V1.json','INITIAL_PROFILE_CALENDAR_CI_DEADLINE_CONTRACT_V1.json','ANALYTICAL_CDE_CALENDAR_CANDIDATE_STAGE_RAW_V1.json']+[n+'.json' for n in ('INITIAL_PROFILE_CALENDAR_WINDOWS_RAW_V1','INITIAL_PROFILE_CALENDAR_UBUNTU_O0_RAW_V1','INITIAL_PROFILE_CALENDAR_UBUNTU_O2_RAW_V1','INITIAL_PROFILE_CALENDAR_IMPLICIT_UBUNTU_O0_RAW_V1','INITIAL_PROFILE_CALENDAR_IMPLICIT_UBUNTU_O2_RAW_V1')]
 for filename in neutral:assert (proof/filename).read_bytes().replace(b'\r\n',b'\n')==subprocess.check_output(['git','show',HEAD+':integration/f-ci/nomacro-complete01/'+filename],cwd=root);files['neutral-'+filename]=proof/filename
 members={key:dict(bytes=path.stat().st_size,sha256=SHA(path.read_bytes())) for key,path in files.items()}
 with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
  for key,path in sorted(files.items()):z.write(path,key)
 with zipfile.ZipFile(archive) as z:
  assert len(z.namelist())==len(set(z.namelist()))==len(members)
  for key,item in members.items():raw=z.read(key);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
 digest=SHA(archive.read_bytes());size=archive.stat().st_size;assert size<90*1024*1024
 record=dict(status='ACTUAL_74CONTEXT_INITIAL_CALENDAR_CANDIDATE_GATES_SEALED_FOR_FINAL_FROST_COADMISSION_NOT_CANONICAL',candidate=HEAD,previous_canonical=PARENT,synthetic=SYNTHETIC,full_tree=TREE,archive=archive.name,bytes=size,sha256=digest,parts=[dict(file=archive.name,bytes=size,sha256=digest)],members=members,sealer_source=git('rev-parse','HEAD'),neutral_scientific_archives_changed=False,canonical_admission=False,standalone_merge_claimed=False,final_integrated_head_gates_required=True,contexts=74,exact_cold_windows=226,native_calendar_samples=524,compiled_postimages=21)
 archive.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n');print(record['status'],size,digest,len(members))


if __name__=='__main__':main()
