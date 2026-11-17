"""Actual original binary output scratch allocation; no physical formula change."""
from pathlib import Path
import hashlib
import json

ORIGINAL_SHA='a1b1b261ec05153d2075099c04cc6bb656f657344d4c1ceb5c9e43d0fd225355'
CORRECTED_SHA='94a50f29f199a441942ed8c719b77480e4fcab3d0886c3021fab764f1d51a3bb'
ANCHOR=b'      else if (swcsv == 3) then ! binary\n         ! datetime'


def source(original):
    canonical=original.replace(b'\r\n',b'\n')
    manifest=json.loads(Path(__file__).with_name('manifest.json').read_text())
    if hashlib.sha256(canonical).hexdigest()!=ORIGINAL_SHA or canonical.count(ANCHOR)!=1:
        raise ValueError('Foreign original binary output source')
    if (manifest['original_canonical_sha256'],manifest['corrected_canonical_sha256'])!=(ORIGINAL_SHA,CORRECTED_SHA):
        raise ValueError('Foreign binary output correction manifest')
    corrected=canonical.replace(ANCHOR,b'      else if (swcsv == 3) then ! binary\n         allocate(buffer(parlen-1))\n         ! datetime',1)
    if hashlib.sha256(corrected).hexdigest()!=CORRECTED_SHA:raise ValueError('Foreign corrected binary output source')
    if original==canonical:return corrected
    if original==canonical.replace(b'\n',b'\r\n'):return corrected.replace(b'\n',b'\r\n')
    raise ValueError('Mixed original binary output source line endings')
