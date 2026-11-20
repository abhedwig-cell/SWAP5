"""Read-only exact source guard for the separately selected pond correction."""
import hashlib
import json

BOUNDARY_SOURCE_LF_SHA256 = 'f49bfea16ff50b9686dcdef4fe253a5e4d937aa4b2e1485bea4a93418823539f'
HISTORY_BOUNDARY_SOURCE_LF_SHA256 = 'f29bdd3b2acf178fddf8ea0292636a25ba95438b031bd01d29388c82b659e3de'


def validate(bundle):
    body = (bundle/'boundtop.f90').read_bytes().replace(b'\r\n', b'\n')
    identity = json.loads((bundle/'BUILD.json').read_bytes())['identity']
    history = identity['original_output'].get('swhyst', 0)
    expected = HISTORY_BOUNDARY_SOURCE_LF_SHA256 if history else BOUNDARY_SOURCE_LF_SHA256
    if hashlib.sha256(body).hexdigest() != expected:
        raise ValueError('Foreign actual secondary implicit zero-pond boundary provider')
