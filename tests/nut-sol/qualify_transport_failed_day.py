"""Test-only reinitialization from the actual rejected day228 committed state.

Read the Reference binary under its original policy, then initialize the explicit
new numerical policy with exactly the same validated physical owners. This is
not a public restart conversion and never changes the native restart adapter.
"""
import argparse,hashlib,json,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(raw):return hashlib.sha256(raw).hexdigest()
def main():
 ap=argparse.ArgumentParser()
 for opt in ['O0','O2']:ap.add_argument('--bundle-'+opt,type=Path,required=True)
 ap.add_argument('--checkpoint-dir',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);a=ap.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 source=(ROOT/'app/solute_project/main.f90').read_text()
 old="  call require(first<=stop_after,'no requested windows remain')"
 assert source.count(old)==1
 source=source.replace(old,"""  call solute%snapshot(clock,theta,mobile,companion,revision)
  chemistry%transport_scheme=1
  call reconstruct_matrix_solute_trusted(chemistry,9001_int64,revision,clock,theta,mobile%concentration_mg_cm3, &
    mobile%mass_mg_cm2,companion%sorbed_matrix_mass,solute,code,surface_mass=companion%pond_mass)
  call require(code==MATRIX_OK,'test-only physical state reinitialization')
"""+old)
 report=dict(status='RUNNING',inputs={p:sha((ROOT/p).read_bytes())for p in ['app/solute_project/main.f90','tests/nut-sol/qualify_transport_failed_day.py']},events=[],cases={})
 def save():(out/'result.json').write_text(json.dumps(report,indent=2)+'\n')
 def run(cmd,cwd):
  start=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,input=b'',timeout=120);n=len(report['events'])
  for stream in ['stdout','stderr']:(out/f'{n:04d}.{stream}').write_bytes(getattr(r,stream))
  report['events'].append(dict(command=list(map(str,cmd)),seconds=time.perf_counter()-start,returncode=r.returncode))
  if r.returncode:report['status']='FAILED'
  save();assert r.returncode==0,(r.stdout,r.stderr)
 for opt in ['O0','O2']:
  bundle=json.loads((getattr(a,'bundle_'+opt)/'bundle.json').read_text());folder=out/opt;folder.mkdir()
  build=json.loads((Path(bundle['exe']).parent/'build-complete.json').read_text())
  assert all(sha((ROOT/p).read_bytes())==h for p,h in build['input_sha256'].items())
  identities=build['reused_artifact_sha256'];assert all(sha(Path(p).read_bytes())==h for p,h in identities.items())
  objects=[p for p in identities if p.endswith('.o')];archive=[p for p in identities if p.endswith('.a')];assert len(objects)==193 and len(archive)==1
  (folder/'driver.f90').write_text(source);exe=folder/'failed_day'
  flags=[f for f in build['flags']if not f.startswith('-J')]+['-J'+str(folder)]
  run(build['compiler_command']+flags+[folder/'driver.f90',*objects,*archive,'-o',exe],folder)
  for src,dst in [('input.nml','input.nml'),('input.swp','input.swp'),('diagnostic-rejected.bin','before.bin')]:
   (folder/dst).write_bytes((a.checkpoint_dir/src).read_bytes())
  before=(folder/'before.bin').read_bytes();run([exe,'input.nml','before.bin','229','input.swp'],folder)
  assert (folder/'before.bin').read_bytes()==before
  assert (folder/'restart.bin').is_file()and(folder/'endpoint.csv').is_file()
  import csv
  budget=[{k:float(v)for k,v in r.items()}for r in csv.DictReader((folder/'budget.csv').open())]
  assert len(budget)==1
  for substance,unit in [('water','cm'),('solute','mg_cm2')]:
   d=budget[0];assert abs(d[f'{substance}_end_{unit}']-d[f'{substance}_start_{unit}']-d[f'{substance}_in_{unit}']+d[f'{substance}_out_{unit}'])<1e-10
  report['cases'][opt]=dict(budget=budget,driver_sha256=sha(source.encode()),executable_sha256=sha(exe.read_bytes()),
   before_sha256=sha(before),restart_sha256=sha((folder/'restart.bin').read_bytes()),build=build)
  assert all(sha(Path(p).read_bytes())==h for p,h in identities.items())
 report['status']='ACTUAL_FAILED_DAY229_IMPLICIT_POSITIVE_MASS_O0_O2_PASS';save();print(report['status'])
if __name__=='__main__':main()
