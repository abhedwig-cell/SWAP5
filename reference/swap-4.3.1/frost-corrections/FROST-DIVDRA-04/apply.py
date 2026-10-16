#!/usr/bin/env python3
"""Exclusive hash-bound reconstruction; immutable previous component remains."""
import hashlib,json,sys
from pathlib import Path
source,target=map(Path,sys.argv[1:]);m=json.loads((Path(__file__).parent/'manifest.json').read_text())
if source.resolve()==target.resolve()or target.exists():raise SystemExit('Refuse source/occupied target')
b=source.read_bytes()
if hashlib.sha256(b).hexdigest()!=m['parent']['sha256']:raise SystemExit('Parent source hash mismatch')
for p in m['patches']:
 old=p['old'].encode()
 if b.count(old)!=p['occurrences']:raise SystemExit('Patch occurrence mismatch')
 b=b.replace(old,p['new'].encode())
if hashlib.sha256(b).hexdigest()!=m['candidate_sha256']:raise SystemExit('Candidate source hash mismatch')
with target.open('xb')as f:f.write(b)
print('FROST_DIVDRA_04_EXACT_RECONSTRUCTION=PASS')
