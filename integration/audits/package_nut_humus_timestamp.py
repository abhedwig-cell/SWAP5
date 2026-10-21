"""Seal raw native/original/reactive/coupled humus-clock qualification."""
from pathlib import Path
import argparse,base64,hashlib,io,json,tarfile
p=argparse.ArgumentParser(description=__doc__)
for key in ['native','legacy_native','reactive','physical','joint','predecessor','output']:
 p.add_argument('--'+key.replace('_','-'),dest=key,type=Path,required=True)
p.add_argument('--failed',type=Path,action='append',default=[])
a=p.parse_args();out=a.output.resolve();out.mkdir(exist_ok=False);f={}
sha=lambda b:hashlib.sha256(b).hexdigest()
for label,folder in [(k,getattr(a,k))for k in ['native','legacy_native','reactive','physical','joint']]+[('attempts/'+q.name,q)for q in a.failed]:
 for q in folder.rglob('*'):
  if not q.is_file()or q.suffix in ['.o','.mod','.smod','.pyc','.a']:continue
  raw=q.read_bytes()
  if not raw.startswith(b'\x7fELF'):f[label+'/'+str(q.relative_to(folder))]=raw
f['predecessor.json']=a.predecessor.read_bytes()
manifest=json.dumps({k:sha(v)for k,v in sorted(f.items())},indent=2).encode();f['MEMBERS.json']=manifest
stream=io.BytesIO()
with tarfile.open(fileobj=stream,mode='w:xz')as t:
 for path,b in sorted(f.items()):
  m=tarfile.TarInfo(path);m.size=len(b);m.mode=0o644;m.mtime=0;t.addfile(m,io.BytesIO(b))
raw=stream.getvalue();encoded=base64.b64encode(raw);parts=[]
for i,start in enumerate(range(0,len(encoded),60000)):
 name=f'part-{i:03d}.b64';(out/name).write_bytes(encoded[start:start+60000]);parts.append(name)
index=dict(decoded_sha256=sha(raw),members_sha256=sha(manifest),members=len(f)-1,compressed_bytes=len(raw),parts=parts)
(out/'INDEX.json').write_text(json.dumps(index,indent=2)+'\n');print(json.dumps(index))
