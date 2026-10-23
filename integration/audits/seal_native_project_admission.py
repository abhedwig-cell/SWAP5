"""Seal fresh incumbent preservation, keeping already valid current physics separate."""
import argparse,base64,io,json,subprocess,tarfile
from pathlib import Path
from native_project_admission import ROOT,BASE,sha,validate
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--proof',type=Path,required=True);ap.add_argument('--nut-proof',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);a=ap.parse_args()
 proof=a.proof.resolve();files={};inputs={}
 entries=[(p,str(p.relative_to(proof)))for p in proof.rglob('*')]
 nut=a.nut_proof.resolve();entries += [(p,'nut-current/'+str(p.relative_to(nut)))for p in nut.rglob('*')]
 for p,name in sorted(entries,key=lambda pair:pair[1]):
  if not p.is_file()or p.is_symlink()or p.suffix in ['.o','.mod','.smod','.a','.so','.tmp','.pyc']:continue
  raw=p.read_bytes()
  if raw.startswith(b'\x7fELF'):continue
  files[name]=raw
  if p.suffix!='.json':continue
  try:r=json.loads(raw)
  except(ValueError,UnicodeError):continue
  # Record actual source arguments and current top-level input receipts. Nested
  # immutable comparator receipts remain historical, never relabelled current.
  if isinstance(r,dict):
   for field in ['input_sha256','inputs']:
    for q,h in r.get(field,{}).items()if isinstance(r.get(field),dict)else []:
     if isinstance(h,str)and len(h)==64 and(ROOT/q).is_file():
      assert sha((ROOT/q).read_bytes())==h,(name,q,'current input changed');inputs[q]=h
   def commands(value):
    if isinstance(value,dict):
     if isinstance(value.get('command'),list):
      for arg in value['command']:
       if not isinstance(arg,str):continue
       q=Path(arg)
       if q.is_absolute()and q.is_relative_to(ROOT)and q.is_file():inputs[str(q.relative_to(ROOT))]=sha(q.read_bytes())
     for v in value.values():commands(v)
    elif isinstance(value,list):
     for v in value:commands(v)
   commands(r)
 for opt in ['O0','O2']:
  b=json.loads(files['weather-'+opt+'/BUILD.json'])
  for p,h in b['sources'].items():
   if p=='tests/fsi/fsi04_real_headcalc_stubs.f90':inputs[p]=sha((ROOT/p).read_bytes())
   elif p=='src/runtime/mod_fmr_serialized_multiswap_runtime.f90':inputs[p]=b['observer_original_sha256']
   elif p=='src/runtime/mod_fmr_production_application_bootstrap.f90':inputs[p]=b['surface_observer_original_sha256']
   else:inputs[p]=h
 for p in ['integration/audits/native_project_admission.py','integration/audits/validate_native_nut_composition.py','integration/audits/seal_native_project_admission.py',
           'integration/audits/run_native_project_preservation.py','tests/fci/run_fci93_non_m1_fixed_k_qualification.sh',
           'tests/support/augment_bartholomeus_backend_sources.py']:
  inputs[p]=sha((ROOT/p).read_bytes())
 for p,h in inputs.items():assert sha((ROOT/p).read_bytes())==h,(p,'late source drift');files['source/'+p]=(ROOT/p).read_bytes()
 for pattern in ['sol-admission-*.log','sol-admission-*.stderr']:
  for p in proof.parent.glob(pattern):files['operational-history/'+p.name]=p.read_bytes()
 phase_paths=subprocess.check_output(['git','diff','--name-only','27b630f9','HEAD','--','integration/audits'],cwd=ROOT,text=True).splitlines()
 phase_paths=[p for p in phase_paths if p.endswith('.py')]
 for rev in subprocess.check_output(['git','rev-list','27b630f9..HEAD'],cwd=ROOT,text=True).splitlines():
  for p in phase_paths:
   cp=subprocess.run(['git','show',rev+':'+p],cwd=ROOT,capture_output=True)
   if cp.returncode==0:files['source-versions/'+sha(cp.stdout)]=cp.stdout
 report=dict(baseline=BASE,canonically_admitted=False,current_inputs=inputs,
  source_checkpoint=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
  inherited_current='Existing day65 source/raw capsule; identical current physical inputs verified separately',
  operational_history='Initial direct registration check fails closed; CSV comparison excludes only measured core_cpu_s; first control build attempt retained after wrong builder view, then corrected and all controls executed successfully',
  full_historical_migration=False)
 files['execution-recipes/warm-weather.py']=subprocess.check_output(['git','show','53010691:benchmarks/performance/run_perf01_warm_weather.py'],cwd=ROOT)
 report['reviewed_execution_recipe_successor']='Canonical only adds optional --profile forwarding, default original; old actual execution recipe retained and exact additive source delta validated. No sensitive profile is credited to this preservation run.'
 files['ASSESSMENT.json']=(json.dumps(report,indent=2)+'\n').encode()
 result=validate(files)
 files['MANIFEST.json']=(json.dumps({p:sha(v)for p,v in sorted(files.items())},indent=2)+'\n').encode()
 buffer=io.BytesIO()
 with tarfile.open(fileobj=buffer,mode='w:xz')as t:
  for p,raw in sorted(files.items()):
   m=tarfile.TarInfo(p);m.size=len(raw);m.mode=0o644;m.mtime=0;t.addfile(m,io.BytesIO(raw))
 raw=buffer.getvalue();a.output.write_bytes(base64.encodebytes(raw))
 print(json.dumps(dict(path=str(a.output),decoded_sha256=sha(raw),decoded_bytes=len(raw),members=len(files),verification=result)))
if __name__=='__main__':main()
