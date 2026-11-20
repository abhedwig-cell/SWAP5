"""Read-only exact source guard for the separately selected pond correction."""
import hashlib

BOUNDARY_SOURCE_LF_SHA256 = 'f49bfea16ff50b9686dcdef4fe253a5e4d937aa4b2e1485bea4a93418823539f'


def validate(bundle):
    body = (bundle/'boundtop.f90').read_bytes().replace(b'\r\n', b'\n')
    if hashlib.sha256(body).hexdigest() != BOUNDARY_SOURCE_LF_SHA256:
        raise ValueError('Foreign actual secondary implicit zero-pond boundary provider')
