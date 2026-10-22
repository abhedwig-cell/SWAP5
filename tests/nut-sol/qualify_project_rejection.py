"""Replay the real rejected day from its retained committed checkpoint, O0/O2."""
import argparse,hashlib,json,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser()
 for opt in ['O0','O2']:ap.add_argument('--bundle-'+opt,type=Path,required=True)
 ap.add_argument('--checkpoint-dir',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);a=ap.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);source=a.checkpoint_dir.resolve()
 report=dict(status='RUNNING',inputs={'tests/nut-sol/qualify_project_rejection.py':sha(Path(__file__))},cases={},events=[],checkpoint_sha256=sha(source/'diagnostic-rejected.bin'))
 for opt in ['O0','O2']:
  bundle=json.loads((getattr(a,'bundle_'+opt)/'bundle.json').read_text());exe=Path(bundle['exe'])
  build=json.loads((exe.parent/'build-complete.json').read_text());assert sha(exe)==build['executable_sha256']
  assert all(sha(ROOT/p)==h for p,h in build['input_sha256'].items())
  case=out/opt;case.mkdir()
  for src,dst in [('input.nml','input.nml'),('input.swp','input.swp'),('diagnostic-rejected.bin','before.bin')]:
   (case/dst).write_bytes((source/src).read_bytes())
  cmd=[str(exe),'input.nml','before.bin','229','input.swp'];t=time.perf_counter()
  r=subprocess.run(cmd,cwd=case,input=b'',capture_output=True,timeout=120)
  for stream in ['stdout','stderr']:(case/stream).write_bytes(getattr(r,stream))
  report['events'].append(dict(command=cmd,returncode=r.returncode,seconds=time.perf_counter()-t))
  assert r.returncode!=0 and b'rejected window/process/completed:'in r.stdout and b'joint interval rejected'in r.stdout
  line=next(l for l in r.stdout.decode().splitlines()if 'rejected window/process/completed:'in l)
  fields=list(map(int,line.split(':')[1].split()));assert fields==[229,3,2221],fields
  assert (case/'diagnostic-rejected.bin').read_bytes()==(case/'before.bin').read_bytes()
  assert not (case/'restart.bin').exists()and not (case/'endpoint.csv').exists()
  report['cases'][opt]=dict(build=build,unchanged_owner_sha256=sha(case/'before.bin'),process_status=3,completed_substeps=2221)
 report['status']='PROJECT_REAL_COARSE_REJECTION_ATOMIC_O0_O2_PASS'
 (out/'result.json').write_text(json.dumps(report,indent=2)+'\n');print(report['status'])
if __name__=='__main__':main()
