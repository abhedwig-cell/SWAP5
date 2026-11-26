"""Seal field-v2 native proof; retain initial v1 archive by hash, no model runs."""
from pathlib import Path
import json,hashlib,zipfile,subprocess
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';res=json.loads((R/'RESOURCE_PATHS.json').read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
files={}
for p in R.iterdir():
 if p.is_file() and (p.name.startswith('FIELD_V2_') or p.name.startswith('BLOCK02_FIELD')):files['records/'+p.name]=p
for opt in ['O0','O2']:
 b=Path(res[opt]['path'])
 for name in ['worker-coupled-field-v2','FIELD_V2_COLD1','FIELD_V2_COLD2','FIELD_V2_OWN1TO2','FIELD_V2_OWN2TO3']:
  for p in (b/name).rglob('*'):
   if p.is_file() and p.suffix!='.s':files['build/'+opt+'/'+p.relative_to(b).as_posix()]=p
for name in ['app/hybrid_water/coupled_macro_policy.py','app/hybrid_water/macro_trial_origin.py','tests/macro_complete01/build_field_worker.py','tests/macro_complete01/assess_field_worker.py','tests/macro_complete01/run_worker_window.py']:files['source/'+name]=ROOT/name
manifest={n:dict(sha256=sha(p),bytes=p.stat().st_size) for n,p in files.items()};zpath=R/'BLOCK02_FIELD_V2_EVIDENCE.zip'
with zipfile.ZipFile(zpath,'w',zipfile.ZIP_DEFLATED,compresslevel=3) as z:
 for n,p in files.items():z.write(p,n)
 z.writestr('MANIFEST.json',json.dumps(manifest,indent=2))
with zipfile.ZipFile(zpath) as z:
 for n,m in manifest.items():assert hashlib.sha256(z.read(n)).hexdigest()==m['sha256']
q=dict(sha256=sha(zpath),bytes=zpath.stat().st_size,members=len(manifest),checkpoint=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),original_provider_archive=json.loads((R/'BLOCK02_V1_EVIDENCE.json').read_text())['sha256'],models_launched=0)
(R/'BLOCK02_FIELD_V2_EVIDENCE.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q))
