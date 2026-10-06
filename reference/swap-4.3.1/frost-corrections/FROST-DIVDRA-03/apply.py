#!/usr/bin/env python3
"""Exact exclusive reconstruction of the bounded B17 successor reference candidate."""
import hashlib
import json
from pathlib import Path
import sys

source, target = map(Path, sys.argv[1:])
manifest = json.loads((Path(__file__).parent/'manifest.json').read_text())
if source.resolve() == target.resolve() or target.exists():
    raise SystemExit('Refuse source/occupied output overwrite')
data = source.read_bytes()
if hashlib.sha256(data).hexdigest() != manifest['parent']['sha256']:
    raise SystemExit('Parent source hash mismatch')
old = manifest['patch']['old'].encode()
if data.count(old) != manifest['patch']['occurrences']:
    raise SystemExit('Patch preimage count mismatch')
result = data.replace(old, manifest['patch']['new'].encode())
if hashlib.sha256(result).hexdigest() != manifest['candidate_sha256']:
    raise SystemExit('Candidate source hash mismatch')
with target.open('xb') as output:
    output.write(result)
print('FROST_DIVDRA_03_EXACT_RECONSTRUCTION=PASS')
