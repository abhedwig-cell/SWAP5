"""Rebuild the exact admitted PR1605 provider graph without admitting writers.

The producer and immutable source view have separate, explicit identities.
No old admission guard or production file is changed by this experiment.
"""
import argparse,hashlib,json,os,shutil,subprocess,sys,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
SOURCE='79cceedb8c35cf0fd79761ecd011b270245a67f1'
def git(root,*args):return subprocess.check_output(['git',*args],cwd=root,text=True).strip()
def sha(raw):return hashlib.sha256(raw).hexdigest()
def execute(view,out,opt,compiler,producer):
 sys.path.insert(0,str(view/'tests/dataqual15_hupsel'))
 import joint_logical as native
 import joint_production as authority
 pin=git(ROOT,'rev-parse',SOURCE)
 def guard():
  assert git(view,'rev-parse','HEAD')==pin
  for area in ('src','app','reference'):
   assert not git(view,'diff','HEAD','--',area)
   assert not git(view,'ls-files','--others','--exclude-standard','--',area)
  return {area:git(view,'rev-parse','HEAD:'+area)for area in('src','app','reference')}
 trees=guard();assert not out.exists();out.parent.mkdir(parents=True,exist_ok=True)
 # prepare() owns fixture construction; its caller supplies the exact current
 # source guard instead of claiming the old frozen source guard passed.
 native.prior.guard=guard
 native.prior.DRIVERS=dict(native.prior.DRIVERS,age='tests/nut-sol/test_age_joint.f90')
 fixture,ordered,drivers=native.prepare(out);assert len(ordered)==335
 build=out/'baseline';executables,events=native.build(build,Path(compiler),opt,fixture,ordered,drivers)
 measured=native.measure(build,executables,events,'candidate')
 snapshots=out/'source-snapshots';snapshots.mkdir();rows=[]
 for source in dict.fromkeys([*ordered,*drivers.values()]):
  relative=source.relative_to(view).as_posix()if source.is_relative_to(view)else'fixture/'+source.name
  raw=source.read_bytes();name=str(len(rows))+'.f90';(snapshots/name).write_bytes(raw)
  if source.is_relative_to(view):assert raw.replace(b'\r\n',b'\n')==subprocess.check_output(['git','show',pin+':'+relative],cwd=view)
  rows.append(dict(source=str(source),path=relative,snapshot='source-snapshots/'+name,sha256=sha(raw),repository=source.is_relative_to(view)))
 # Exact old native payloads are a preservation oracle, never evidence that
 # changed peer physics has acquired whole-project scientific qualification.
 import joint_limiter_writer as previous
 _,old=previous.reference_runtime.reference('WINDOWS'if os.name=='nt'else'POSIX',opt)
 for name in native.NAMES:
  expected={k.removeprefix('candidate/'):v for k,v in old.items()if k.startswith('candidate/'+name+'/')}
  actual={name+'/'+p.name:p.read_bytes()for p in(build/name).iterdir()if p.is_file()}
  assert expected==actual,'exact independent prior native payload '+name
 result=dict(status='EXACT_PR1605_COLD335_NATIVE_PASS_NOT_ADMITTED',source_head=pin,producer_head=producer,producer_sha256=sha(Path(__file__).read_bytes().replace(b'\r\n',b'\n')),production_trees=trees,optimization=opt,platform='WINDOWS'if os.name=='nt'else'POSIX',provider_count=335,provider_objects_reused=0,sources=rows,native=measured,production_admission=False,whole_scientific_admission=False)
 assert trees==guard();(out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
 print(result['status'],opt,flush=True)
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--compiler',default=shutil.which('gfortran'));p.add_argument('--view',type=Path);p.add_argument('--producer');a=p.parse_args();os.environ['OMP_NUM_THREADS']='1'
 if a.view:return execute(a.view.resolve(),a.output.resolve(),a.optimization,str(Path(a.compiler).resolve()),a.producer)
 head=git(ROOT,'rev-parse','HEAD');assert subprocess.check_output(['git','show',head+':'+Path(__file__).relative_to(ROOT).as_posix()],cwd=ROOT)==Path(__file__).read_bytes().replace(b'\r\n',b'\n'),'persist producer before execution'
 pin=git(ROOT,'rev-parse',SOURCE);parent=Path(tempfile.mkdtemp(prefix='s5jwp-phase-view-'));view=parent/'source'
 try:
  subprocess.run(['git','-c','core.autocrlf=false','worktree','add','--detach',str(view),pin],cwd=ROOT,check=True,capture_output=True)
  subprocess.run([sys.executable,'-B',str(Path(__file__).resolve()),'--view',str(view),'--producer',head,'--output',str(a.output.resolve()),'--optimization',a.optimization,'--compiler',a.compiler],cwd=ROOT,check=True)
 finally:
  if view.exists():subprocess.run(['git','worktree','remove','--force',str(view)],cwd=ROOT,check=True,capture_output=True)
  parent.rmdir()
if __name__=='__main__':main()
