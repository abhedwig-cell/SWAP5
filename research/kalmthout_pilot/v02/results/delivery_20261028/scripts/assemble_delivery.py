"""Reassemble four variable products from ordered Git parts and verify identities."""
from pathlib import Path
import argparse,hashlib,json
ROOT=Path(__file__).resolve().parents[1]

def main(destination):
    destination.mkdir(parents=True,exist_ok=True)
    manifest=json.loads((ROOT/'products/parts_manifest.json').read_text())
    for item in manifest['products']:
        final=destination/item['file'];tmp=final.with_suffix('.nc.partial');h=hashlib.sha256();size=0
        with tmp.open('wb') as f:
            for part in item['parts']:
                b=(ROOT/'products/parts'/part['name']).read_bytes()
                if len(b)!=part['bytes'] or hashlib.sha256(b).hexdigest()!=part['sha256']:raise ValueError('Part integrity failure: '+part['name'])
                f.write(b);h.update(b);size+=len(b)
        if size!=item['bytes'] or h.hexdigest()!=item['sha256']:raise ValueError('Complete product integrity failure: '+item['file'])
        tmp.replace(final);print('VERIFIED',final.name,size,h.hexdigest())

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('destination',type=Path);a=p.parse_args();main(a.destination)
