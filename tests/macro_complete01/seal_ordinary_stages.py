"""Seal new original-prefix and corrective-stage raw evidence once; no models."""
from pathlib import Path
import sys,json,hashlib,zipfile,subprocess
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';res=json.loads((R/'RESOURCE_PATHS.json').read_text());block=sys.argv[1];assert block in ['27','28'];files={}
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for p in R.iterdir():
 if p.is_file() and p.suffix=='.json' and p.name!='BLOCK'+block+'_EVIDENCE.json':
  selected=p.name.startswith(('BLOCK23_','BLOCK27_','ORDINARY_V27_','TWOSIDED_V25_','OBSERVER24','OBSERVER26','PERIOD21_')) if block=='27' else p.name.startswith(('BLOCK28_','PERIOD27_'))
  if selected:files['records/'+p.name]=p
for opt in ['O0','O2']:
 b=Path(res[opt]['path'])
 for d in b.iterdir():
  select=d.name.startswith(('OBSERVER24','OBSERVER26','worker-constraint-budget-observer24','worker-ordinary-absorption-observer26','worker-coupled-domain1-two-sided-v25','worker-coupled-ordinary-gradient-v27','TWOSIDED_V25','ORDINARY_V27_CONTEXT','ORDINARY_V27_OWN')) if block=='27' else d.name.startswith('ORDINARY_V27_FIXED_')
  if block=='27' and d.name.startswith('UPPERCOMPLETE_V21_FIXED_DAY'):
   select=15<=int(d.name.removeprefix('UPPERCOMPLETE_V21_FIXED_DAY'))<=23
  if d.is_dir() and select:
   for p in d.rglob('*'):
    if p.is_file() and p.suffix not in ['.s']:files['raw/'+opt+'/'+p.relative_to(b).as_posix()]=p
for folder in ['app/hybrid_water','tests/macro_complete01']:
 for p in (ROOT/folder).iterdir():
  if p.is_file() and (folder.startswith('tests/') or p.name.startswith('macro_') or p.name=='coupled_macro_policy.py'):files['source/'+folder+'/'+p.name]=p
manifest={n:dict(sha256=sha(p),bytes=p.stat().st_size) for n,p in files.items()};zp=R/('BLOCK'+block+'_EVIDENCE.zip');assert not zp.exists()
with zipfile.ZipFile(zp,'w',zipfile.ZIP_DEFLATED,compresslevel=3) as z:
 for n,p in files.items():z.write(p,n)
 z.writestr('MANIFEST.json',json.dumps(manifest,indent=2))
with zipfile.ZipFile(zp) as z:
 for n,m in manifest.items():assert hashlib.sha256(z.read(n)).hexdigest()==m['sha256']
q=dict(sha256=sha(zp),bytes=zp.stat().st_size,members=len(manifest),checkpoint=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),models_launched=0,original_provider_archive=json.loads((R/'BLOCK02_V1_EVIDENCE.json').read_text())['sha256'],scope='Block27: actualV21fixed15..22pluscensored23, observer24/26andfailedanchors, V25day23plusfailedown24, V27context24andown25/26; Block28: actualfixedV27original1..26. No inheritedprefix relabel; no full481claim.',accepted_hashes_verified_by_reading_all_members=True)
(R/('BLOCK'+block+'_EVIDENCE.json')).write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q))
