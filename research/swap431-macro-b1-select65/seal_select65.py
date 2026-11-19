from pathlib import Path
import json,hashlib,zipfile,subprocess
R=Path(__file__).resolve().parent;RES=json.loads((R/'RESOURCE_PATHS.json').read_text())
def digest(s):
 h=hashlib.sha256()
 for b in iter(lambda:s.read(1024*1024),b''):h.update(b)
 return h.hexdigest()
def sha(p):
 with p.open('rb') as f:return digest(f)
files={'research/'+p.relative_to(R).as_posix():p for p in R.rglob('*') if p.is_file() and p.suffix!='.zip' and p.name!='EVIDENCE.json'}
for opt in ['O0','O2']:
 w=Path(RES[opt]['path']);files.update({'native/'+opt+'/'+p.relative_to(w).as_posix():p for p in w.rglob('*') if p.is_file()})
cases=Path(RES['cases']['path']);files.update({'case_copies/'+p.relative_to(cases).as_posix():p for p in cases.rglob('*') if p.is_file()})
manifest=[dict(path=n,sha256=sha(p),bytes=p.stat().st_size) for n,p in sorted(files.items())]
a=R/'SELECT65_EVIDENCE.zip'
with zipfile.ZipFile(a,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for n,p in sorted(files.items()):z.write(p,n)
 z.writestr('manifest.json',json.dumps(manifest))
with zipfile.ZipFile(a) as z:
 for x in manifest:
  with z.open(x['path']) as f:assert digest(f)==x['sha256']
q=dict(file=a.name,sha256=sha(a),bytes=a.stat().st_size,members_verified=len(manifest),checkpoint=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),inherited_reject64=json.loads((R.parent/'swap431-macro-b1-reject64/EVIDENCE.json').read_text())['sha256'],full_case_copies_preserved=True,models_launched=0)
(R/'EVIDENCE.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8');print(q)
