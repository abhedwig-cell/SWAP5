"""Seal the scoped D1 inflow diagnosis/candidates without new models."""
from pathlib import Path
import hashlib,json,zipfile,subprocess,sys
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';res=json.loads((R/'RESOURCE_PATHS.json').read_text());block=sys.argv[1];assert block in ['19','20','21'];files={};sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
record_prefix={'19':('OBSERVER19_','BLOCK19_'),'20':('UPPERIN_V20','BLOCK20_'),'21':('UPPERCOMPLETE_V21','BLOCK21_')}[block]
for p in R.iterdir():
 if p.is_file() and p.name.startswith(record_prefix) and p.suffix!='.zip' and p.name!='BLOCK'+block+'_EVIDENCE.json':files['records/'+p.name]=p
if block=='19':
 p=R/'BLOCK18_PREFIX_DAY12_ASSESSMENT.json';files['records/'+p.name]=p
for opt in ['O0','O2']:
 b=Path(res[opt]['path'])
 for d in b.iterdir():
  select=(d.name.startswith(('OBSERVER19_','worker-day13-observer19')) or d.name in ['LOCALDARCY_V16_PERIOD_DAY11','LOCALDARCY_V16_PERIOD_DAY12','LOCALDARCY_V16_PERIOD_DAY13']) if block=='19' else d.name.startswith(('UPPERIN_V20','worker-coupled-upper-inflow-v20')) if block=='20' else d.name.startswith(('UPPERCOMPLETE_V21','worker-coupled-upper-complete-v21'))
  if d.is_dir() and select:
   for p in d.rglob('*'):
    if p.is_file() and p.suffix!='.s':files['raw/'+opt+'/'+p.relative_to(b).as_posix()]=p
for folder in ['app/hybrid_water','tests/macro_complete01']:
 for p in (ROOT/folder).iterdir():
  if p.is_file() and (folder.startswith('tests/') or p.name.startswith('macro_') or p.name=='coupled_macro_policy.py'):files['source/'+folder+'/'+p.name]=p
manifest={n:dict(sha256=sha(p),bytes=p.stat().st_size) for n,p in files.items()};zp=R/('BLOCK'+block+'_EVIDENCE.zip');assert not zp.exists()
with zipfile.ZipFile(zp,'w',zipfile.ZIP_DEFLATED,compresslevel=3) as z:
 for n,p in files.items():z.write(p,n)
 z.writestr('MANIFEST.json',json.dumps(manifest,indent=2))
with zipfile.ZipFile(zp) as z:
 for n,m in manifest.items():assert hashlib.sha256(z.read(n)).hexdigest()==m['sha256']
q=dict(sha256=sha(zp),bytes=zp.stat().st_size,members=len(manifest),checkpoint=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),models_launched=0,original_provider_archive=json.loads((R/'BLOCK02_V1_EVIDENCE.json').read_text())['sha256'])
if block=='21':q['immutable_parent_origin_archive']=json.loads((R/'BLOCK20_EVIDENCE.json').read_text())['sha256']
(R/('BLOCK'+block+'_EVIDENCE.json')).write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q))
