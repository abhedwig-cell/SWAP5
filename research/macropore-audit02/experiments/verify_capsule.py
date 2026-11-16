"""Join and independently replay all new causal assertions; zero model runs."""
import hashlib,json,tarfile,tempfile,subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parents[3];audit=root/'research/macropore-audit02'
m=json.loads((audit/'results/CAPSULE_PARTS.json').read_text());raw=b''
for p in m['join_order']:
 data=(root/p['path']).read_bytes();assert hashlib.sha256(data).hexdigest()==p['sha256'];raw+=data
assert len(raw)==m['joined_bytes'] and hashlib.sha256(raw).hexdigest()==m['joined_sha256']
with tempfile.TemporaryDirectory(prefix='macro02-verify-') as tmp:
 w=Path(tmp);capsule=w/'capsule.tar.xz';capsule.write_bytes(raw)
 with tarfile.open(capsule) as t:t.extractall(w,filter='data')
 with tarfile.open(audit/'evidence/rollback-static.tar.xz') as t:
  for member in t:
   if member.isfile() and member.name.endswith('.bin'):
    run,name=member.name.split('/');target=w/run/'original'/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(t.extractfile(member).read())
 output=w/'replayed.json';subprocess.run([sys.executable,str(audit/'experiments/analyze.py'),'--workspace',str(w),'--output',str(output)],check=True)
 assert json.loads(output.read_text())==json.loads((audit/'results/CAUSAL_RESULT.json').read_text())
print('PASS: immutable capsule reproduces complete causal result; zero models')
