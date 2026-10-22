"""Small real production driver for the centered-transport spatial positivity gap."""
import argparse,hashlib,importlib.util,json,os,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);a=ap.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 path=ROOT/'tests/support/augment_bartholomeus_backend_sources.py'
 spec=importlib.util.spec_from_file_location('dep',path);dep=importlib.util.module_from_spec(spec);spec.loader.exec_module(dep)
 sources,_=dep.strict_closure(ROOT,['tests/nut-sol/test_transport_spatial_positivity.f90'],[])
 events=[];fc=os.environ.get('FC','gfortran')
 report=dict(status='RUNNING',inputs={str(p.relative_to(ROOT)):sha(p)for p in [*sources,Path(__file__),path]},providers=len(sources)-1,events=events,cases={})
 def save():(out/'result.json').write_text(json.dumps(report,indent=2)+'\n')
 def run(cmd,cwd):
  cmd=list(map(str,cmd));t=time.perf_counter();r=subprocess.run(cmd,cwd=cwd,capture_output=True);i=len(events)
  for stream in ['stdout','stderr']:(out/f'{i:04d}.{stream}').write_bytes(getattr(r,stream))
  events.append(dict(command=cmd,seconds=time.perf_counter()-t,returncode=r.returncode));save();assert r.returncode==0,(r.stdout,r.stderr)
  return r.stdout
 for opt in ['O0','O2']:
  case=out/opt;case.mkdir();exe=case/'spatial'
  run([fc,'-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(case),*sources,'-o',exe],case)
  result=run([exe],case);assert b'TRANSPORT_SPATIAL_NEGATIVE_NOT_FIXED_BY_SMALL_DT_RESOLVED_MASS_PASS'in result
  lines=[l.split()for l in result.decode().splitlines()if 'SPATIAL 'in l]
  assert len(lines)==8 and all(int(l[3])==(3 if int(l[1])==1 else 0)for l in lines)
  report['cases'][opt]=dict(executable_sha256=sha(exe),observations=lines)
 report['status']='TRANSPORT_SPATIAL_COARSE_NEGATIVE_RESOLVED_MASS_O0_O2_PASS';save();print(json.dumps(dict(status=report['status'],providers=report['providers'])))
if __name__=='__main__':main()
