"""Stream evidence to avoid retaining duplicate20MB snapshot payloads in memory."""
from pathlib import Path
import json,hashlib,zipfile,subprocess
R=Path(__file__).resolve().parent;W=Path('C:/Users/Veldh012/swap431-correction37-work/native')
def digest(stream):
 h=hashlib.sha256()
 for b in iter(lambda:stream.read(1024*1024),b''):h.update(b)
 return h.hexdigest()
def sha(p):
 with p.open('rb') as f:return digest(f)
files={'research/'+p.relative_to(R).as_posix():p for p in R.rglob('*') if p.is_file() and p.suffix!='.zip' and p.name!='EVIDENCE.json'}
files.update({'native/'+p.relative_to(W).as_posix():p for p in W.rglob('*') if p.is_file()})
manifest=[dict(path=n,sha256=sha(p),bytes=p.stat().st_size) for n,p in sorted(files.items())]
a=R/'CORRECTION37_EVIDENCE.zip'
with zipfile.ZipFile(a,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for n,p in sorted(files.items()):z.write(p,n)
 z.writestr('manifest.json',json.dumps(manifest))
with zipfile.ZipFile(a) as z:
 for x in manifest:
  with z.open(x['path']) as f:assert digest(f)==x['sha256']
q=dict(file=a.name,sha256=sha(a),bytes=a.stat().st_size,members_verified=len(manifest),checkpoint=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),inherited_domains36=json.loads((R.parent/'swap431-macro-b1-domains36/EVIDENCE.json').read_text())['sha256'],models_launched=0)
(R/'EVIDENCE.json').write_text(json.dumps(q,indent=2)+'\n');print(q)
