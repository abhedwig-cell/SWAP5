"""Verify durable real hydraulic archive and dependencies at each original run SHA."""
import hashlib,io,json,subprocess,tarfile
from pathlib import Path
root=Path(__file__).resolve().parents[3]
m=json.loads((root/'docs/audits/evidence/PPA_WU05A27_REAL_HYDRAULICS_MANIFEST.json').read_text())
h=lambda b:hashlib.sha256(b).hexdigest()
data=[]
for p in m['parts']:
    b=(root/p['path']).read_bytes();assert len(b)==p['bytes'] and h(b)==p['sha256'];data.append(b)
blob=b''.join(data);assert h(blob)==m['archive_sha256']
with tarfile.open(fileobj=io.BytesIO(blob),mode='r:gz') as t:
    assert set(t.getnames())==set(m['files'])
    for name,expected in m['files'].items():
        b=t.extractfile(name).read();assert len(b)==expected['bytes'] and h(b)==expected['sha256']
for run in m['runs']:
    for path,expected in run['dependency_sha256'].items():
        assert h(subprocess.check_output(['git','show',run.get('dependency_refs',{}).get(path,run['code_sha'])+':'+path],cwd=root))==expected
assert all(run["exit_code"]==0 for run in m["runs"])
print('A27_REAL_HYDRAULICS_EVIDENCE_HASHES=PASS')
