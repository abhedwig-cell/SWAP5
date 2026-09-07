#!/usr/bin/env python3
from __future__ import annotations

import base64
import gzip
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / 'reference/swap-4.3.1/b1_10_source/MOD_MvG_functions.manifest.json'
B110 = ROOT / 'reference/swap-4.3.1/snapshots/B1.10.yml'
APPLY = ROOT / 'reference/swap-4.3.1/patches/SWAP-012/apply_and_verify.py'


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> int:
    manifest = json.loads(MANIFEST.read_text())
    payload = ROOT / manifest['payload_path']
    encoded = ''.join(payload.read_text().split()).encode('ascii')
    compressed = base64.b64decode(encoded, validate=True)
    if len(compressed) != manifest['gzip_bytes']:
        raise SystemExit('F-SI09 gzip byte count mismatch')
    if sha(compressed) != manifest['gzip_sha256']:
        raise SystemExit('F-SI09 gzip SHA mismatch')
    source = gzip.decompress(compressed)
    if len(source) != manifest['decoded_source_bytes']:
        raise SystemExit('F-SI09 decoded source byte count mismatch')
    if sha(source) != manifest['decoded_source_sha256']:
        raise SystemExit('F-SI09 decoded B1.10 source SHA mismatch')
    if b'\r\n' not in source or b'\n' not in source:
        raise SystemExit('F-SI09 expected canonical CRLF source encoding')

    b110 = B110.read_text()
    required_manifest_tokens = [
        'target: "SWAP/MOD_MvG_functions.f90"',
        'ordered_preimage_sha256: "a27252d216da65ce20ed3a173ade5404a0f31241ac87349edadb3b3ff9d63390"',
        'corrected_target_sha256: "4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1"',
    ]
    for token in required_manifest_tokens:
        if token not in b110:
            raise SystemExit(f'F-SI09 B1.10 manifest token missing: {token}')

    apply = APPLY.read_text()
    for token in [
        'B0_SHA256 = "a27252d216da65ce20ed3a173ade5404a0f31241ac87349edadb3b3ff9d63390"',
        'PATCH_SHA256 = "263e515b7c80059c13e71fcbc3dc1f187b6d0673e07c0c265bbc140fea0df131"',
        'CORRECTED_SHA256 = "4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1"',
    ]:
        if token not in apply:
            raise SystemExit(f'F-SI09 SWAP-012 applicator token missing: {token}')

    for token in [b'module MOD_MvG', b'function watcon', b'function moiscap', b'function hconduc', b'function dhconduc', b'function prhead', b'end module MOD_MvG']:
        if token.lower() not in source.lower():
            raise SystemExit(f'F-SI09 decoded source token missing: {token!r}')

    print('F-SI09_B110_REFERENCE_PAYLOAD PASS')
    print('decoded_sha256=' + sha(source))
    print('decoded_bytes=' + str(len(source)))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
