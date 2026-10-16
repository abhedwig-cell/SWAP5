"""Deduplicated immutable raw evidence; does not manufacture qualification status."""
from pathlib import Path
import argparse,base64,hashlib,io,json,subprocess,tarfile
ROOT=Path(__file__).resolve().parents[2]
def sha(b):return hashlib.sha256(b).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--folder',action='append',required=True);p.add_argument('--bundle',action='store_true');a=p.parse_args();a.output=a.output.resolve()
 members={};blobs={}
 for mapping in a.folder:
  label,directory=mapping.split('=',1);directory=Path(directory)
  for f in directory.rglob('*'):
   if not f.is_file()or f.suffix in ['.o','.mod','.pyc']or f.name.startswith('test-')or f.name=='test':continue
   raw=f.read_bytes();h=sha(raw);members[label+'/'+str(f.relative_to(directory))]={'sha256':h,'bytes':len(raw)};blobs[h]=raw
 if a.bundle:
  bundle=a.output.parent/'co2-executed.bundle';bundle.parent.mkdir(parents=True,exist_ok=True)
  subprocess.run(['git','bundle','create',str(bundle),'HEAD','^82209d0df68d14c5ebe707e9b6303f9b150488ca'],cwd=ROOT,check=True)
  raw=bundle.read_bytes();h=sha(raw);members['co2-executed.bundle']={'sha256':h,'bytes':len(raw)};blobs[h]=raw
 tree={}
 for line in subprocess.check_output(['git','ls-tree','-r','HEAD','--','src','tests','tools','reference'],cwd=ROOT,text=True).splitlines():
  meta,path=line.split('\t',1);tree[path]=meta.split()[2]
 manifest={'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'members':members,'dependency_blobs':tree,'private_receipt_key_exported':False}
 stream=io.BytesIO()
 with tarfile.open(fileobj=stream,mode='w:xz')as t:
  for name,raw in [('MANIFEST.json',(json.dumps(manifest,indent=2)+'\n').encode()),*[(f'blobs/{h}',b)for h,b in sorted(blobs.items())]]:
   m=tarfile.TarInfo(name);m.size=len(raw);m.mode=0o644;t.addfile(m,io.BytesIO(raw))
 raw=stream.getvalue()
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  for name,m in members.items():
   b=t.extractfile('blobs/'+m['sha256']).read();assert sha(b)==m['sha256']and len(b)==m['bytes']
 a.output.parent.mkdir(parents=True,exist_ok=True)
 with a.output.open('xb')as f:f.write(base64.encodebytes(raw))
 receipt={'path':str(a.output.relative_to(ROOT)),'decoded_sha256':sha(raw),'members':len(members),'unique_blobs':len(blobs),'compressed_bytes':len(raw),'dependency_blobs':len(tree)}
 print(json.dumps(receipt))
if __name__=='__main__':main()
