from pathlib import Path
import json,hashlib,zipfile,subprocess
R=Path(__file__).resolve().parent;W=Path('C:/Users/Veldh012/swap431-next18-work/native')
sha=lambda b:hashlib.sha256(b).hexdigest()
files={'research/'+p.relative_to(R).as_posix():p.read_bytes() for p in R.rglob('*') if p.is_file() and p.suffix!='.zip' and p.name!='EVIDENCE.json'}
for p in W.rglob('*'):
 if p.is_file():files['native/'+p.relative_to(W).as_posix()]=p.read_bytes()
manifest=[dict(path=n,sha256=sha(b),bytes=len(b)) for n,b in sorted(files.items())]
a=R/'NEXT18_EVIDENCE.zip'
with zipfile.ZipFile(a,'w',zipfile.ZIP_DEFLATED) as z:
 for n,b in files.items():z.writestr(n,b)
 z.writestr('manifest.json',json.dumps(manifest))
with zipfile.ZipFile(a) as z:
 for x in manifest:assert sha(z.read(x['path']))==x['sha256']
q=dict(file=a.name,sha256=sha(a.read_bytes()),bytes=a.stat().st_size,members_verified=len(manifest),checkpoint=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),inherited_native09=json.loads((R.parent/'swap431-macro-b1-native09/EVIDENCE.json').read_text())['sha256'],inherited_day10=json.loads((R.parent/'swap431-macro-b1-day10/EVIDENCE.json').read_text())['sha256'],inherited_mid11=json.loads((R.parent/'swap431-macro-b1-midnight11/EVIDENCE.json').read_text())['sha256'],inherited_ledger12=json.loads((R.parent/'swap431-macro-b1-ledger12/EVIDENCE.json').read_text())['sha256'],inherited_prefix14=json.loads((R.parent/'swap431-macro-b1-prefix14/EVIDENCE.json').read_text())['sha256'],inherited_cost15=json.loads((R.parent/'swap431-macro-b1-cost15/EVIDENCE.json').read_text())['sha256'],inherited_buffer16=json.loads((R.parent/'swap431-macro-b1-buffer16/EVIDENCE.json').read_text())['sha256'],inherited_canopy17=json.loads((R.parent/'swap431-macro-b1-canopy17/EVIDENCE.json').read_text())['sha256'],models_launched=0)
(R/'EVIDENCE.json').write_text(json.dumps(q,indent=2)+'\n');print(q)
