"""Retain all stock implementation stages and raw failures; no models."""
from pathlib import Path
import hashlib,zipfile,json,subprocess
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';res=json.loads((R/'RESOURCE_PATHS.json').read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();files={}
for p in R.iterdir():
 if p.is_file() and (p.name.startswith(('JACOBIAN15','JACOBIAN16','LOCALDARCY_V16','REJECTION17','BLOCK15_','BLOCK16_','BLOCK17_'))) and p.suffix!='.zip' and p.name!='BLOCK17_EVIDENCE.json':files['records/'+p.name]=p
for opt in ['O0','O2']:
 b=Path(res[opt]['path'])
 for d in b.iterdir():
  if d.is_dir() and (d.name.startswith(('JACOBIAN15','JACOBIAN16','LOCALDARCY_V16','REJECTION17','worker-live-jacobian-v15','worker-live-jacobian-v16','worker-coupled-local-darcy-v16','worker-rejection-v17'))):
   for p in d.rglob('*'):
    if p.is_file() and p.suffix!='.s':files['build/'+opt+'/'+p.relative_to(b).as_posix()]=p
for p in (ROOT/'app/hybrid_water').iterdir():
 if p.is_file() and (p.name.startswith('macro_') or p.name=='coupled_macro_policy.py'):files['source/'+p.name]=p
for p in (ROOT/'tests/macro_complete01').iterdir():
 if p.is_file():files['source/tests/'+p.name]=p
manifest={n:dict(sha256=sha(p),bytes=p.stat().st_size) for n,p in files.items()};zp=R/'BLOCK17_EVIDENCE.zip'
with zipfile.ZipFile(zp,'w',zipfile.ZIP_DEFLATED,compresslevel=3) as z:
 for n,p in files.items():z.write(p,n)
 z.writestr('MANIFEST.json',json.dumps(manifest,indent=2))
with zipfile.ZipFile(zp) as z:
 for n,m in manifest.items():assert hashlib.sha256(z.read(n)).hexdigest()==m['sha256']
q=dict(sha256=sha(zp),bytes=zp.stat().st_size,members=len(manifest),checkpoint=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),models_launched=0,original_provider_archive=json.loads((R/'BLOCK02_V1_EVIDENCE.json').read_text())['sha256'])
(R/'BLOCK17_EVIDENCE.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q))
