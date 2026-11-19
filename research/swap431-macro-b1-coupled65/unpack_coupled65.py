"""Restore and hash-check lossless raw data to an allocated empty directory."""
from pathlib import Path
import hashlib,json,sys,zipfile
R=Path(__file__).resolve().parent
target=Path(sys.argv[1]).resolve()
assert not target.exists() or not any(target.iterdir()),'destination must be empty'
e=json.loads((R/'EVIDENCE.json').read_text());archive=R/e['file']
with archive.open('rb') as f:assert hashlib.file_digest(f,'sha256').hexdigest()==e['sha256']
target.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(archive) as z:
    for x in json.loads(z.read('manifest.json')):
        p=(target/x['path']).resolve();assert p.is_relative_to(target)
        raw=z.read('blobs/'+x['sha256']);assert len(raw)==x['bytes'] and hashlib.sha256(raw).hexdigest()==x['sha256']
        p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(raw)
print(target)
