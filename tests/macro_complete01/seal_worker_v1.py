"""Preserve strict worker v1 proof before the next source policy; launches no models."""
from pathlib import Path
import json,hashlib,zipfile,subprocess
ROOT=Path(__file__).resolve().parents[2]; R=ROOT/'integration/macro-complete01'
res=json.loads((R/'RESOURCE_PATHS.json').read_text()); sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
q={'decision':'STRICT_V1_OWN_ORIGIN_VALID_NEXT_DAY_UNREDUCED_REFUSAL','models_launched':0,'results':[]}
for opt in ['O0','O2']:
 b=Path(res[opt]['path']);p=b/'WORKER_OWN1TO2'; r=json.loads((p/'RESULT.json').read_text());e=(p/'original/donor.stderr').read_text()
 assert r['status']=='FAILED' and r['initial_state_exact'] and not r['rows'] and 'FRESH_UNREDUCED_SCALE_REQUEST' in e
 cp=b/'WORKER_COLD1/accepted-column-1-day-1.zip'; cold=json.loads((R/'BLOCK02_COLD1_RESULT.json').read_text())['results'][['O0','O2'].index(opt)]
 assert sha(cp)==cold['checkpoint_sha256']
 q['results'].append(dict(opt=opt,seconds=r['elapsed_seconds'],scale_refusal=e,origin_unchanged=True))
(R/'BLOCK02_STAGE1_RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
files={}
for p in R.iterdir():
 if p.is_file() and (p.name.startswith('WORKER_') or p.name.startswith('BLOCK02_')) and p.suffix!='.zip' and p.name!='BLOCK02_V1_EVIDENCE.json':files['records/'+p.name]=p
for opt in ['O0','O2']:
 b=Path(res[opt]['path'])
 for name in ['worker-coupled','WORKER_COLD1','WORKER_OWN1TO2']+(['original-worker-reference'] if opt=='O2' else []):
  for p in (b/name).rglob('*'):
   if p.is_file() and p.suffix!='.s':files['build/'+opt+'/'+p.relative_to(b).as_posix()]=p
for name in ['app/hybrid_water/coupled_macro_policy.py','app/hybrid_water/macro_trial_origin.py','tests/macro_complete01/prepare_worker.py','tests/macro_complete01/run_worker_window.py']:files['source/'+name]=ROOT/name
manifest={n:dict(sha256=sha(p),bytes=p.stat().st_size) for n,p in files.items()}
zpath=R/'BLOCK02_V1_EVIDENCE.zip'
with zipfile.ZipFile(zpath,'w',zipfile.ZIP_DEFLATED,compresslevel=3) as z:
 for n,p in files.items():z.write(p,n)
 z.writestr('MANIFEST.json',json.dumps(manifest,indent=2))
with zipfile.ZipFile(zpath) as z:
 for n,m in manifest.items():assert hashlib.sha256(z.read(n)).hexdigest()==m['sha256']
meta=dict(sha256=sha(zpath),bytes=zpath.stat().st_size,members=len(manifest),checkpoint=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),scope='First original unscaled day; own native restore then true refusal; no full-period qualification',models_launched=0)
(R/'BLOCK02_V1_EVIDENCE.json').write_text(json.dumps(meta,indent=2)+'\n');print(json.dumps(meta))
