"""Bounded corrected original TimeControl; numerical configuration, no saved state."""
import hashlib
import json
from pathlib import Path

POLICY = 'original-adaptive-event-closure-v1'
ROOT = Path(__file__).resolve().parents[2]
ORIGINAL_SHA = '6d2a62db0ff1e3ea00693f7b39bdb36e1811ba79011f15feef5a656ddf3181b8'
CORRECTED_SHA = '7419088428e538da100a2c30c4b32f90fc2799d34f3336f4139cb55fb0f84f57'


def source(original):
    manifest = json.loads((ROOT/'reference/swap-4.3.1/patches/TIME-EVENT-CLOSURE-01/manifest.json').read_text())
    sha = lambda body: hashlib.sha256(body).hexdigest()
    anchor = b'      if (dt > dtevent) then'
    if (manifest['original_sha256'] != ORIGINAL_SHA or manifest['corrected_sha256'] != CORRECTED_SHA
            or sha(original) != ORIGINAL_SHA or original.count(anchor) != 1):
        raise ValueError('Foreign original TimeControl event-closure reference')
    corrected = original.replace(anchor,b'      if (dt+dtCrit > dtevent) then')
    if sha(corrected) != CORRECTED_SHA:
        raise ValueError('Foreign corrected TimeControl event-closure source')
    return corrected


def metadata(original):
    return dict(policy=POLICY, audit_id='TIME-EVENT-CLOSURE-01',
                source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                original_sha256=ORIGINAL_SHA,
                generated_source_sha256=hashlib.sha256(source(original)).hexdigest())
