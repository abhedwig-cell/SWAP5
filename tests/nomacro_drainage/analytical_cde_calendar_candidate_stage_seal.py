"""Preserve actual candidate gates for joint admission; never claim a merge."""
import argparse,json,subprocess,zipfile
from pathlib import Path
from analytical_hydraulic_archives import SHA
HEAD='cb7ce3774ce263d05bd7ec79a66c3cbf4009b383'
PARENT='904d3cdd1fb9132839bec689c22cdeecdba79676'
SYNTHETIC='a8de996bebeae030da206a786d7feafee8462b82'
TREE='9b5dec72d184b4973995653dc38c19949fcfae47'
STATUS='BOUNDED_ORIGINAL_ANALYTICAL_VAPOR_CDE_CALENDAR_SOURCE_RAW_NATIVE_PASS'
NEGATIVES=(('SOURCE','759a85a757536f99947b1742a7841cdd3f45f2c1','app/hybrid_water/analytical_cde_calendar.py'),('RAW','862c99b1fb9dd2d60a213ea23d94544d34b7bd6c','integration/f-ci/nomacro-complete01/ANALYTICAL_CDE_CALENDAR_WINDOWS_RAW_V1.zip.part001'),('INHERITED','7b1f7019d1b49398cebbf956601a10db8a5a097e','integration/f-ci/nomacro-complete01/INITIAL_STATE_COMPOSITION_ADMISSION_RAW_V1.zip'),('PUBLICATION','1833082d59a7f79b2d48192b3858df43a815e319','tests/publication/run_pub_p2e09_reference_threshold_freeze.sh'))


def main():
 p=argparse.ArgumentParser()
 for key in ('repository','evidence'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();root=a.repository;ev=a.evidence;proof=root/'integration/f-ci/nomacro-complete01'
 git=lambda *args:subprocess.check_output(['git',*args],cwd=root,text=True).strip();load=lambda name:json.loads((ev/name).read_text())
 name='ANALYTICAL_CDE_CALENDAR_CANDIDATE_STAGE_RAW_V1';archive=proof/(name+'.zip');assert not archive.exists() and not archive.with_suffix('.json').exists()
 assert git('show','-s','--format=%P',SYNTHETIC).split()==[PARENT,HEAD]
 assert git('rev-parse',HEAD+'^{tree}')==git('rev-parse',SYNTHETIC+'^{tree}')==TREE
 cases=[('ANALYTICAL_CDE_CALENDAR_FINAL_CANDIDATE_PUBLIC_OWNER_V5',HEAD,False)]+[('ANALYTICAL_CDE_CALENDAR_FINAL_'+role+'_NEGATIVE_PUBLIC_V4',head,True) for role,head,path in NEGATIVES]
 for label,head,negative in cases:
  q=load(label+'.json');assert q['before']==q['after'] and q['before']['head']==head and not q['before']['status'] and len(q['before']['sparse'])==41 and q['model_executions']==q['compiler_executions']==0 and q['command'][-1]=='tests/hupsel51/verify_successor.py'
  out=(ev/(label+'.stdout.txt')).read_bytes();err=(ev/(label+'.stderr.txt')).read_bytes()
  if negative:assert q['returncode']!=0 and b'AssertionError' in err
  else:assert q['returncode']==0 and not err and q['before']['tree']==TREE and json.loads(out)['status']==STATUS
 for role,head,path in NEGATIVES:
  assert git('diff','--name-only',HEAD,head)==path and git('show','-s','--format=%P',head)==HEAD
  branch='codex/nomacro-analytical-cde-calendar-'+role.lower()+'-negative04';assert git('ls-remote','origin','refs/heads/'+branch).split()[0]==head
 pub=load('ANALYTICAL_CDE_CALENDAR_FINAL_PUBLICATION_SCOPE_POSITIVE_V5.json');assert pub['before']==pub['after'] and pub['before']['head']==HEAD and not pub['before']['status'] and pub['returncode']==0 and 'PUBLICATION_REPLAY_SELECTED=false' in pub['stdout'] and not pub['stderr'] and pub['model_executions']==pub['compiler_executions']==0
 assert 'PUBLICATION_REPLAY_SELECTED=true' in (ev/'ANALYTICAL_CDE_CALENDAR_FINAL_PUBLICATION_SCOPE_NEGATIVE_V4.txt').read_text()
 checks=load('ANALYTICAL_CDE_CALENDAR_PR1787_ALL_TERMINAL_CHECKS_V1.json');assert checks['headRevision']==HEAD and not checks['hasMore'] and not checks['statuses'] and len(checks['checks'])==44 and all(c['head_sha']==HEAD and c['status']=='completed' and c['conclusion'] in ('success','skipped') for c in checks['checks']) and sum(c['conclusion']=='success' for c in checks['checks'])==29
 runs=load('ANALYTICAL_CDE_CALENDAR_PR1787_ALL_TERMINAL_RUNS_V1.json');assert runs['total_count']==len(runs['workflow_runs'])==15 and all(v['head_sha']==HEAD and v['status']=='completed' and v['conclusion']=='success' for v in runs['workflow_runs'])
 for filename in ('ANALYTICAL_CDE_CALENDAR_PR1787_ORIGINAL_READER136936372686_HEAD_PASS_FULL_V1.txt','ANALYTICAL_CDE_CALENDAR_PR1787_COLUMN136936372804_HEAD_PASS_FULL_V1.txt'):assert STATUS in (ev/filename).read_text()
 files={p.name:p for p in ev.iterdir() if p.is_file() and p.name.lower().startswith(('analytical_cde_calendar','analytical-cde-calendar'))}
 stems=('ANALYTICAL_CDE_CALENDAR_WINDOWS_RAW_V1','ANALYTICAL_CDE_CALENDAR_UBUNTU_O0_RAW_V1','ANALYTICAL_CDE_CALENDAR_UBUNTU_O2_RAW_V1','ANALYTICAL_CDE_CALENDAR_POSTIMAGE_RAW_V1')
 for filename in ['ANALYTICAL_CDE_CALENDAR_QUALIFICATION.json',*[stem+'.json' for stem in stems]]:
  assert (proof/filename).read_bytes().replace(b'\r\n',b'\n')==subprocess.check_output(['git','show',HEAD+':integration/f-ci/nomacro-complete01/'+filename],cwd=root);files['neutral-'+filename]=proof/filename
 members={key:dict(bytes=path.stat().st_size,sha256=SHA(path.read_bytes())) for key,path in files.items()}
 with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
  for key,path in sorted(files.items()):z.write(path,key)
 with zipfile.ZipFile(archive) as z:
  assert len(z.namelist())==len(set(z.namelist()))==len(members)
  for key,item in members.items():
   raw=z.read(key);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
 digest=SHA(archive.read_bytes());size=archive.stat().st_size;assert size<90*1024*1024
 record=dict(status='ACTUAL_ANALYTICAL_CDE_CALENDAR_CANDIDATE_GATES_SEALED_FOR_JOINT_ADMISSION_NOT_CANONICAL',candidate=HEAD,previous_canonical=PARENT,synthetic=SYNTHETIC,full_tree=TREE,archive=archive.name,bytes=size,sha256=digest,parts=[dict(file=archive.name,bytes=size,sha256=digest)],members=members,sealer_source=git('rev-parse','HEAD'),neutral_scientific_archives_changed=False,canonical_admission=False,standalone_merge_claimed=False,final_integrated_head_gates_required=True)
 archive.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n');print(record['status'],size,digest,len(members))


if __name__=='__main__':main()
