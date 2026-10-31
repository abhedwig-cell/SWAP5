"""Replay the exact failed executable and checkpoint with existing read-only diagnostics."""
import argparse,hashlib,json,os,subprocess,tarfile,time
from pathlib import Path
from checkpoint_layout import layout
ROOT=Path(__file__).resolve().parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--capsule',type=Path,required=True);p.add_argument('--manifest',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 cap=a.capsule;m=json.loads(a.manifest.read_text());assert sha(cap.read_bytes())==m['archive_sha256']
 with tarfile.open(cap)as t:
  get=lambda name:t.extractfile(name).read()
  data={v.name:t.extractfile(v).read()for v in t if v.isfile()};inventory=json.loads(data.pop('MANIFEST.json'));assert inventory=={name:sha(raw)for name,raw in data.items()}
  binary=data['build-O2/swap5_grass_startup'];build=json.loads(data['build-O2/BUILD.json']);assert sha(binary)==build['executable_sha256']
  for name in ['input.swp','grass.crp','input.met','swap.bbc','swap.dra','application.binding']:(out/name).write_bytes(data['adaptive-O2/'+name])
  binding=json.loads((out/'application.binding').read_text());assert binding['executable_sha256']==sha(binary)
  origin=data['adaptive-O2/checkpoint.bin'];assert layout(origin)['clock']==1191;(out/'origin.bin').write_bytes(origin)
  exe=out/'swap5_grass_startup';exe.write_bytes(binary);exe.chmod(0o755)
  env=dict(os.environ,SWAP5_DIAG_GROUNDWATER='1',OMP_NUM_THREADS='1');cmd=[str(exe),'1192','retain-step','100000',str(out/'origin.bin'),'thermal-control'];start=time.monotonic()
  with(out/'stdout').open('wb')as so,(out/'stderr').open('wb')as se:
   try:r=subprocess.run(cmd,cwd=out,env=env,stdout=so,stderr=se,timeout=300);code=r.returncode;censored=False
   except subprocess.TimeoutExpired:code=None;censored=True
  report=dict(status='MEASURED_DIAGNOSTIC_NOT_QUALIFICATION',command=cmd,seconds=time.monotonic()-start,returncode=code,censored=censored,executable_sha256=sha(binary),origin_sha256=sha(origin),checkpoint_unchanged=(out/'origin.bin').read_bytes()==origin,complete_day=layout((out/'checkpoint.bin').read_bytes())['clock']if(out/'checkpoint.bin').exists()else None)
  (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n');print(json.dumps(report,indent=2));print('STDOUT_TAIL');print('\n'.join((out/'stdout').read_text(errors='replace').splitlines()[-35:]));print('STDERR_TAIL');print('\n'.join((out/'stderr').read_text(errors='replace').splitlines()[-35:]))
if __name__=='__main__':main()
