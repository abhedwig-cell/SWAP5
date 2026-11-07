"""Actual unchanged age/surface and mineral POSIX consumer preservation."""
import argparse,io,json,zipfile,subprocess
from pathlib import Path
import joint_writer_production as g
STEM='integration/dataqual15_hupsel/JOINT_WRITER_PRODUCTION_POSIX_CONSUMERS_20261106'
RUNNERS={'age':'tests/nut-sol/run_age.py','pond':'tests/nut-sol/run_pond_joint.py','mineral':'tests/nut-mineral/run_mineral.py'}

def audit(files,r):
 if subprocess.run(['git','cat-file','-e',r['head']+'^{commit}'],cwd=g.ROOT,capture_output=True).returncode:subprocess.run(['git','fetch','--no-tags','origin',r['head']],cwd=g.ROOT,check=True,capture_output=True)
 assert r['status']=='ORIGINAL_POSIX_AGE_SURFACE_AND_MINERAL_CONSUMERS_PASS'and r['production_trees']=={a:g.blob(r['head'],a)for a in('src','app','reference')}==g.guard_source()
 for name,runner in RUNNERS.items():
  assert g.raw(r['head'],runner)==g.runner_postimage(runner)
  result=json.loads(files[name+'/result.json']);assert result['baseline']==r['head']
  if name=='mineral':assert result['source_tree']==r['production_trees']['src']
  expected='SCOPED_LOCAL_QUALIFICATION_PASS_NOT_ADMITTED'if name=='mineral'else'PHYSICAL_PASS_NOT_ADMITTED'
  assert result['status']==expected and set(result['runs'])=={'O0','O2'}
  for path,digest in result['input_sha256'].items():assert g.sha(g.raw(r['head'],path))==digest,'actual consumer input '+path
  events=json.loads(files[name+'/events.json']);assert events and all(e['returncode']==0 for e in events)
  compiles=[e for e in events if e['category']=='publication_compile'];assert len(compiles)==2
  for opt in('O0','O2'):
   assert len([e for e in compiles if '-'+opt in e['command']and'-std=c11'in e['command']and any(p.replace('\\','/').endswith('/app/support/restart_publish.c')for p in e['command'])])==1
   base=name+'/'+opt+'/'
   assert files[base+'expected.bin']==files[base+'fresh.bin']
   if name=='age':assert files[base+'surface_expected.bin']==files[base+'surface_fresh.bin']
  assert files[name+'/O0/expected.bin']==files[name+'/O2/expected.bin']
  for event in events:
   so=event.get('stdout',event.get('stdout_file'));se=event.get('stderr',event.get('stderr_file'))
   assert name+'/'+so in files and name+'/'+se in files
 return dict(original_runners=3,optimizations=2,surface_triplet_preserved=True,pond_rollback_consumer_preserved=True,original_assertions_unchanged=True,whole_scientific_admission=False)

def capture(out):
 g.guard_source();files={}
 for name in RUNNERS:
  for path in(out/name).rglob('*'):
   if path.is_file()and(path.suffix in('.json','.stdout','.stderr','.f90','.inc')or'.bin'in path.name):files[name+'/'+path.relative_to(out/name).as_posix()]=path.read_bytes()
 r=dict(status='ORIGINAL_POSIX_AGE_SURFACE_AND_MINERAL_CONSUMERS_PASS',head=g.git('rev-parse','HEAD'),production_trees=g.guard_source(),whole_scientific_admission=False)
 measurement=audit(files,r);buffer=io.BytesIO()
 with zipfile.ZipFile(buffer,'w',zipfile.ZIP_DEFLATED)as z:
  for path,raw in files.items():z.writestr(path,raw)
 raw=buffer.getvalue();(g.ROOT/(STEM+'.zip')).write_bytes(raw)
 r.update(archive=Path(STEM).name+'.zip',sha256=g.sha(raw),members={p:g.sha(b)for p,b in files.items()},measurement=measurement)
 (g.ROOT/(STEM+'.json')).write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(measurement))

def verify():
 r=json.loads((g.ROOT/(STEM+'.json')).read_text());raw=(g.ROOT/(STEM+'.zip')).read_bytes();assert g.sha(raw)==r['sha256']
 with zipfile.ZipFile(io.BytesIO(raw))as z:files={p:z.read(p)for p in z.namelist()}
 assert {p:g.sha(b)for p,b in files.items()}==r['members']and audit(files,r)==r['measurement']
 return r['measurement']

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--capture',type=Path);a=p.parse_args()
 if a.capture:capture(a.capture.resolve())
 else:print(json.dumps(verify()))
