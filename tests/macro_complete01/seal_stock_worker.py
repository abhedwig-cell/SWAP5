"""Retain all stock implementation stages and raw failures; no models."""
from pathlib import Path
import hashlib,zipfile,json,subprocess
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';res=json.loads((R/'RESOURCE_PATHS.json').read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();files={}
for p in R.iterdir():
 if p.is_file() and (p.name.startswith('STOCK_') or p.name.startswith('BLOCK03_')) and p.suffix!='.zip' and p.name!='BLOCK03_EVIDENCE.json':files['records/'+p.name]=p
for opt in ['O0','O2']:
 b=Path(res[opt]['path'])
 for d in b.iterdir():
  if d.is_dir() and (d.name.startswith('STOCK_') or d.name.startswith('worker-coupled-stock-')):
   for p in d.rglob('*'):
    if p.is_file() and p.suffix!='.s':files['build/'+opt+'/'+p.relative_to(b).as_posix()]=p
for p in (ROOT/'app/hybrid_water').iterdir():
 if p.name.startswith('macro_stock_') or p.name in ['coupled_macro_policy.py','macro_trial_origin.py']:files['source/'+p.name]=p
for p in (ROOT/'tests/macro_complete01').iterdir():
 if p.is_file() and ('stock' in p.name or p.name=='run_worker_window.py'):files['source/tests/'+p.name]=p
manifest={n:dict(sha256=sha(p),bytes=p.stat().st_size) for n,p in files.items()};zp=R/'BLOCK03_EVIDENCE.zip'
with zipfile.ZipFile(zp,'w',zipfile.ZIP_DEFLATED,compresslevel=3) as z:
 for n,p in files.items():z.write(p,n)
 z.writestr('MANIFEST.json',json.dumps(manifest,indent=2))
with zipfile.ZipFile(zp) as z:
 for n,m in manifest.items():assert hashlib.sha256(z.read(n)).hexdigest()==m['sha256']
q=dict(sha256=sha(zp),bytes=zp.stat().st_size,members=len(manifest),checkpoint=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),models_launched=0,original_provider_archive=json.loads((R/'BLOCK02_V1_EVIDENCE.json').read_text())['sha256'])
(R/'BLOCK03_EVIDENCE.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q))
