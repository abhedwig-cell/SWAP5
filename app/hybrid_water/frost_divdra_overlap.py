"""Proposed original Divdra geometric bookkeeping correction; no admission."""
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
ORIGINAL_SHA='832c3d8f2709521db16f43c7fbe3952687c4a395ca3199f8727df9b83759ae8c'


def source(original):
    raw=original.encode('cp1252').replace(b'\r\n',b'\n') if isinstance(original,str) else original.replace(b'\r\n',b'\n')
    folder=ROOT/'reference/swap-4.3.1/frost-corrections/FROST-DIVDRA-OVERLAP-01'
    record=json.loads((folder/'manifest.json').read_text(encoding='utf-8'));target=(folder/'divdra.f90').read_bytes().replace(b'\r\n',b'\n')
    sha=lambda value:hashlib.sha256(value).hexdigest()
    if record['base_lf_sha256']!=ORIGINAL_SHA or sha(raw)!=ORIGINAL_SHA or sha(target)!=record['target_lf_sha256']:
        raise ValueError('Foreign actual original Divdra overlap reference')
    expected=raw.decode('cp1252')
    for edit in record['edits']:
        if expected.count(edit['before'])!=1:raise ValueError('Changed original Divdra overlap seam')
        expected=expected.replace(edit['before'],edit['after'],1)
    if expected.encode('cp1252')!=target:raise ValueError('Changed complete corrected Divdra reference')
    return target.decode('cp1252')
