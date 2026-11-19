from pathlib import Path
import hashlib,json,sys,zipfile
R=Path(__file__).resolve().parent;dst=Path(sys.argv[1]).resolve()
assert not dst.exists() or not any(dst.iterdir())
e=json.loads((R/'EVIDENCE.json').read_text());p=R/e['file']
with p.open('rb') as f:assert hashlib.file_digest(f,'sha256').hexdigest()==e['sha256']
dst.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(p) as z:
    for x in json.loads(z.read('manifest.json')):
        p=(dst/x['path']).resolve();assert p.is_relative_to(dst)
        raw=z.read('blobs/'+x['sha256']);assert len(raw)==x['bytes'] and hashlib.sha256(raw).hexdigest()==x['sha256']
        p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(raw)
print(dst)
