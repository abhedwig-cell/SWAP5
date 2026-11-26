"""Seal only the newly qualified current native day range; no models."""
from pathlib import Path
import hashlib,zipfile,json,subprocess,sys
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';res=json.loads((R/'RESOURCE_PATHS.json').read_text());block,start,end=sys.argv[1],int(sys.argv[2]),int(sys.argv[3]);assert block.isdigit() and 1<=start<=end<=481
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();files={}
for p in R.glob('BLOCK'+block+'_*'):
 if p.is_file() and p.suffix!='.zip' and p.name!='BLOCK'+block+'_EVIDENCE.json':files['records/'+p.name]=p
for opt in ['O0','O2']:
 b=Path(res[opt]['path'])
 for d in b.iterdir():
  if not d.is_dir() or not d.name.startswith('UPPERCOMPLETE_V21_FIXED_'):continue
  for p in d.rglob('*'):
   if p.is_file():files['raw/'+opt+'/'+p.relative_to(b).as_posix()]=p
for name in ['run_worker_window.py','assess_fixed_v21_prefix14.py','advance_fixed_v21.py','seal_fixed_v21_prefix.py']:
 p=ROOT/'tests/macro_complete01'/name;files['recipe/'+name]=p
manifest={n:dict(sha256=sha(p),bytes=p.stat().st_size) for n,p in files.items()};zp=R/('BLOCK'+block+'_EVIDENCE.zip');assert not zp.exists()
with zipfile.ZipFile(zp,'w',zipfile.ZIP_DEFLATED,compresslevel=3) as z:
 for n,p in files.items():z.write(p,n)
 z.writestr('MANIFEST.json',json.dumps(manifest,indent=2))
with zipfile.ZipFile(zp) as z:
 for n,m in manifest.items():assert hashlib.sha256(z.read(n)).hexdigest()==m['sha256']
q=dict(sha256=sha(zp),bytes=zp.stat().st_size,members=len(manifest),checkpoint=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),models_launched=0,qualified_raw_day_range=[start,end],source_provider_archive=json.loads((R/'BLOCK21_EVIDENCE.json').read_text())['sha256'],original_provider_archive=json.loads((R/'BLOCK02_V1_EVIDENCE.json').read_text())['sha256'])
(R/('BLOCK'+block+'_EVIDENCE.json')).write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q))
