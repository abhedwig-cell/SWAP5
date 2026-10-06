#!/usr/bin/env python3
"""Exclusive, hash-guarded reconstruction of the bounded reference overlay."""
from pathlib import Path
import sys,json,hashlib
source,target=map(Path,sys.argv[1:]);m=json.loads((Path(__file__).parent/'manifest.json').read_text())
if source.resolve()==target.resolve() or target.exists():raise SystemExit('Refuse source/occupied output overwrite')
data=source.read_bytes()
if hashlib.sha256(data).hexdigest()!=m['original']['sha256']:raise SystemExit('Original source hash mismatch')
old=m['patch']['old'].encode();new=m['patch']['new'].encode()
if data.count(old)!=m['patch']['occurrences']:raise SystemExit('Patch preimage count mismatch')
result=data.replace(old,new)
if hashlib.sha256(result).hexdigest()!=m['corrected_sha256']:raise SystemExit('Corrected source hash mismatch')
with target.open('xb') as out:out.write(result)
print('FROST_DIVDRA_02_EXACT_RECONSTRUCTION=PASS')
