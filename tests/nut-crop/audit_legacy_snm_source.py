#!/usr/bin/env python3
"""Bounded, byte-pinned legacy Soil-N input reader source audit.

This is a forensic source extraction, not a replacement parser.
"""
from pathlib import Path
import base64, hashlib, io, tarfile, re
ROOT=Path(__file__).resolve().parents[2]
ARCHIVE=ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
PINS={
 'wofost_soil_parameters.f90':'4b91311612182ea3fc977051a3d52243957e32cbdbef413ab94b7cf8905f5f7a',
 'management_soil.f90':'0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b',
 'wofost_soil_declarations.f90':'0f24a437b1374fcb92dfdb760ca960a602c8e97ce03baa934093065af85c527d'
}
def audit():
 with tarfile.open(fileobj=io.BytesIO(base64.b64decode(ARCHIVE.read_bytes()))) as archive:
  for name,digest in PINS.items():
   raw=archive.extractfile('SWAP/'+name).read()
   assert hashlib.sha256(raw).hexdigest()==digest, name
   lines=raw.decode('latin1').splitlines()
   hit={i for i,line in enumerate(lines) if re.search(r'snm|ttutil|read.*(fom|bio|hum|nh4|no3|sorp|nitrif|denitr|rate)|smedate|imat|dosage|swcropsnm',line,re.I)}
   # Compact contextual excerpts, preserving line numbers and original case.
   chosen=sorted({j for i in hit for j in range(max(0,i-2),min(len(lines),i+3))})
   print('SOURCE_AUDIT_START',name,'sha256='+digest,'lines='+str(len(lines)))
   last=-2
   for i in chosen[:380]:
    if i>last+1:print('...')
    print(f'{i+1:05d} {lines[i][:190]}')
    last=i
   print('SOURCE_AUDIT_END',name,'hits='+str(len(hit)),'shown='+str(min(len(chosen),380)))
if __name__=='__main__':audit()
