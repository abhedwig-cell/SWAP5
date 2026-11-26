"""Seal current local evidence without launching a model or deleting resources."""
from pathlib import Path
import json,hashlib,zipfile,subprocess
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01'
res=json.loads((R/'RESOURCE_PATHS.json').read_text());files={}
for p in R.iterdir():
 if p.is_file() and p.suffix!='.zip' and p.name not in ['BLOCK01_EVIDENCE.json']:files['records/'+p.name]=p
for opt in ['O0','O2']:
 base=Path(res[opt]['path'])
 for p in base.rglob('*'):
  if p.is_file() and p.suffix.lower()!='.s':files['build/'+opt+'/'+p.relative_to(base).as_posix()]=p
for folder in ['tests/macro_complete01']:
 for p in (ROOT/folder).glob('*'):
  if p.is_file():files['current_source/'+p.relative_to(ROOT).as_posix()]=p
for n in ['src/legacy/b1_10_port/headcalc.f90','app/hybrid_water/coupled_macro_policy.py','app/hybrid_water/macro_trial_origin.py']:
 files['current_source/'+n]=ROOT/n
manifest=[]
for n,p in sorted(files.items()):manifest.append(dict(path=n,bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
a=R/'BLOCK01_EVIDENCE.zip'
with zipfile.ZipFile(a,'w',zipfile.ZIP_DEFLATED,compresslevel=3) as z:
 for n,p in sorted(files.items()):z.write(p,n)
 z.writestr('manifest.json',json.dumps(manifest))
with zipfile.ZipFile(a) as z:
 for m in manifest:assert hashlib.sha256(z.read(m['path'])).hexdigest()==m['sha256']
q=dict(file=a.name,bytes=a.stat().st_size,sha256=hashlib.sha256(a.read_bytes()).hexdigest(),verified_members=len(manifest),checkpoint=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),scope='All block01 raw completed/failed/censored profiles, actual objects/binaries/modules/preprocessed sources and current source/status. Compiler assembly is reproducible and omitted. Block02 source is only IMPLEMENTED_NOT_TESTED.',models_launched=0)
(R/'BLOCK01_EVIDENCE.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q))
