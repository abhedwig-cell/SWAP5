from pathlib import Path
import json,hashlib,zipfile,subprocess
R=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
files={p.relative_to(R).as_posix():p.read_bytes() for p in R.rglob('*') if p.is_file() and p.suffix!='.zip' and p.name!='EVIDENCE.json'}
m=[dict(path=n,sha256=sha(b),bytes=len(b)) for n,b in sorted(files.items())]
p=R/'HISTORY13_EVIDENCE.zip'
with zipfile.ZipFile(p,'w',zipfile.ZIP_DEFLATED) as z:
 for n,b in files.items():z.writestr(n,b)
 z.writestr('manifest.json',json.dumps(m))
with zipfile.ZipFile(p) as z:
 for x in m:assert sha(z.read(x['path']))==x['sha256']
q=dict(file=p.name,sha256=sha(p.read_bytes()),members_verified=len(m),checkpoint=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),models_launched=0,source_archives='SOURCE_INVENTORY.json',contents='Recovered raw daily records, separate local supplement, verified archive identities, exact ledger coverage inventory and minimum-period contract')
(R/'EVIDENCE.json').write_text(json.dumps(q,indent=2)+'\n');print(q)
