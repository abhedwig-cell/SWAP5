"""Seal raw finite-donor reference/current evidence; omit reproducible binaries."""
from pathlib import Path
import argparse,base64,hashlib,io,json,os,subprocess,tarfile
ROOT=Path(__file__).resolve().parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser(description=__doc__)
for key in ['reference','production','retained','predecessor','output']:
 p.add_argument('--'+key,type=Path,required=True)
p.add_argument('--failed',type=Path,action='append',default=[])
p.add_argument('--physical',type=Path)
a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
files={}
for prefix,folder in [('reference',a.reference),('production',a.production),('retained',a.retained)]+([
    ('production/physical',a.physical)]if a.physical else[])+[
    ('attempts/'+q.name,q)for q in a.failed]:
 for q in folder.rglob('*'):
  if not q.is_file()or q.suffix in ['.o','.mod','.smod','.pyc','.a']:continue
  raw=q.read_bytes()
  if raw.startswith(b'\x7fELF'):continue
  files[prefix+'/'+str(q.relative_to(folder))]=raw
files['preservation/PREDECESSOR.json']=a.predecessor.read_bytes()
files['SESSION.json']=json.dumps(dict(execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
    FC=os.environ.get('FC'),OMP_NUM_THREADS=os.environ.get('OMP_NUM_THREADS'),
    note='All failed/source-predecessor attempts retain their own identities; only final current raw evidence qualifies production'),indent=2).encode()
inventory={n:sha(b)for n,b in sorted(files.items())}
manifest=json.dumps(inventory,indent=2,sort_keys=True).encode();files['MEMBERS.json']=manifest
stream=io.BytesIO()
with tarfile.open(fileobj=stream,mode='w:xz',preset=6)as archive:
 for n,b in sorted(files.items()):
  m=tarfile.TarInfo(n);m.size=len(b);m.mode=0o644;m.mtime=0;archive.addfile(m,io.BytesIO(b))
raw=stream.getvalue();encoded=base64.b64encode(raw);parts=[]
for i,start in enumerate(range(0,len(encoded),60000)):
 name=f'part-{i:03d}.b64';(out/name).write_bytes(encoded[start:start+60000]);parts.append(name)
index=dict(decoded_sha256=sha(raw),members_sha256=sha(manifest),members=len(inventory),compressed_bytes=len(raw),parts=parts)
(out/'INDEX.json').write_text(json.dumps(index,indent=2)+'\n')
print(json.dumps(index,indent=2))
