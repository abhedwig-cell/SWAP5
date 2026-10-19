"""Reassemble and verify candidate annual NetCDF products stored as Git parts."""
from pathlib import Path
import argparse,json,hashlib
R=Path(__file__).resolve().parents[1]
def assemble(destination):
 manifest=json.loads((R/'products/manifest.json').read_text());destination.mkdir(parents=True,exist_ok=True)
 for item in manifest['files']:
  out=destination/item['file'];tmp=out.with_suffix('.nc.partial');h=hashlib.sha256();n=0
  with tmp.open('wb') as f:
   for part in item['parts']:
    path=R/'products/parts'/part['name'];b=path.read_bytes()
    if len(b)!=part['bytes'] or hashlib.sha256(b).hexdigest()!=part['sha256']:raise ValueError('Part integrity failure: '+part['name'])
    f.write(b);h.update(b);n+=len(b)
  if n!=item['bytes'] or h.hexdigest()!=item['sha256']:raise ValueError('Whole-file identity mismatch: '+item['file'])
  tmp.replace(out);print('VERIFIED',out.name,n,h.hexdigest())
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('destination',type=Path);a=p.parse_args();assemble(a.destination)
