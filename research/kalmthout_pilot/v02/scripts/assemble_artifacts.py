"""Verify all Git parts and atomically assemble the original research artifacts."""
from pathlib import Path
import argparse,hashlib,json

def assemble(root,destination):
 manifest=json.loads((root/'metadata/artifact_manifest.json').read_text())
 destination.mkdir(parents=True,exist_ok=True)
 for artifact in manifest['artifacts']:
  final=destination/artifact['name'];temp=final.with_suffix(final.suffix+'.partial');h=hashlib.sha256();size=0
  with temp.open('wb') as out:
   for part in artifact['parts']:
    source=root/'evidence'/part['name'];part_hash=hashlib.sha256();count=0
    with source.open('rb') as f:
     while chunk:=f.read(1024*1024):out.write(chunk);h.update(chunk);part_hash.update(chunk);size+=len(chunk);count+=len(chunk)
    if count!=part['bytes'] or part_hash.hexdigest()!=part['sha256']:raise ValueError('Part integrity mismatch: '+part['name'])
  if size!=artifact['bytes'] or h.hexdigest()!=artifact['sha256']:raise ValueError('Artifact integrity mismatch: '+artifact['name'])
  temp.replace(final);print('VERIFIED',final.name,size,h.hexdigest(),flush=True)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('destination',type=Path);a=p.parse_args();assemble(Path(__file__).resolve().parent.parent,a.destination)
