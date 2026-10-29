"""Read the unchanged, manifest-bound DATAQUAL08 evidence for deduplication."""
import base64,hashlib,io,json,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()
def read():
 m=json.loads((ROOT/'integration/dataqual08/CAPSULE.json').read_bytes())
 raw=base64.b64decode(b''.join((ROOT/p).read_bytes()for p in m['parts']),validate=True)
 assert sha(raw)==m['sha256'] and len(raw)==m['bytes']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==m['members']==len({x.name for x in ms})
  assert all(x.isfile()and not Path(x.name).is_absolute()and'..'not in Path(x.name).parts for x in ms)
  f={x.name:t.extractfile(x).read()for x in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(b)for p,b in f.items()};return f
