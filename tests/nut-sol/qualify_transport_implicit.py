"""Checked small real reactive process, default preservation and positive policy."""
import argparse,hashlib,importlib.util,json,os,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);a=ap.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 path=ROOT/'tests/support/augment_bartholomeus_backend_sources.py'
 spec=importlib.util.spec_from_file_location('dep',path);dep=importlib.util.module_from_spec(spec);spec.loader.exec_module(dep)
 sources,_=dep.strict_closure(ROOT,['tests/nut-sol/test_transport_implicit.f90'],[])
 report=dict(status='RUNNING',inputs={str(p.relative_to(ROOT)):sha(p)for p in [*sources,Path(__file__),path]},providers=len(sources)-1,events=[],cases={})
 def save():(out/'result.json').write_text(json.dumps(report,indent=2)+'\n')
 def run(cmd,cwd):
  start=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=120);n=len(report['events'])
  for stream in ['stdout','stderr']:(out/f'{n:04d}.{stream}').write_bytes(getattr(r,stream))
  report['events'].append(dict(command=list(map(str,cmd)),seconds=time.perf_counter()-start,returncode=r.returncode))
  if r.returncode:report['status']='FAILED'
  save();assert r.returncode==0,(r.stdout,r.stderr)
  return r.stdout
 for opt in ['O0','O2']:
  folder=out/opt;folder.mkdir();exe=folder/'implicit'
  run([os.environ.get('FC','gfortran'),'-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-fbacktrace',
   '-ffpe-trap=invalid,zero,overflow','-J'+str(folder),*sources,'-o',exe],folder)
  raw=run([exe],folder);assert b'TRANSPORT_IMPLICIT_POSITIVE_MASS_ORACLE_REFERENCE_REJECTION_PASS'in raw
  lines=[l.split()for l in raw.decode().splitlines()if l.strip().startswith('IMPLICIT ')]
  assert len(lines)==36
  assert sum(l.strip().startswith('SOURCES ')for l in raw.decode().splitlines())==6
  assert sum(l.strip().startswith('CONVERGENCE ')for l in raw.decode().splitlines())==3
  report['cases'][opt]=dict(executable_sha256=sha(exe),observations=lines)
 assert report['inputs']=={p:sha(ROOT/p)for p in report['inputs']}
 report['status']='TRANSPORT_IMPLICIT_POSITIVE_MASS_ORACLE_REFERENCE_REJECTION_O0_O2_PASS';save();print(report['status'])
if __name__=='__main__':main()
