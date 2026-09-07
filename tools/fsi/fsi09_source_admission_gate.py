#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / 'integration/f-si/F-SI09_SOURCE_ADMISSION.json'
SNAPSHOT = ROOT / 'reference/swap-4.3.1/snapshots/B1.10.yml'
RECONSTRUCT = ROOT / 'tools/vq/b1_10_reconstruct.py'
PATCH = ROOT / 'reference/swap-4.3.1/patches/SWAP-012/fix.patch'
QUAL = ROOT / 'reference/swap-4.3.1/patches/SWAP-012/qualification.md'

EXPECTED = {
    'b0_archive': '1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151',
    'manifest': '2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1',
    'preimage': 'a27252d216da65ce20ed3a173ade5404a0f31241ac87349edadb3b3ff9d63390',
    'patch': '263e515b7c80059c13e71fcbc3dc1f187b6d0673e07c0c265bbc140fea0df131',
    'corrected': '4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1',
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit('F-SI09_SOURCE_ADMISSION FAIL: ' + message)


def main() -> int:
    data = json.loads(CONTRACT.read_text())
    require(data['status'] == 'BLOCKED_SOURCE_MATERIALIZATION_REQUIRED', 'unexpected status')
    require(data['qualified'] is False, 'blocked source admission must not be qualified')
    require(data['exact_source_identity']['corrected_target_sha256'] == EXPECTED['corrected'], 'contract corrected target pin')
    require(data['scope_flags']['production_b1_10_constitutive_provider_admitted'] is False, 'provider must remain not admitted')
    require(data['scope_flags']['parallel_reference_backend_admitted'] is False, 'parallel reference backend must remain not admitted')

    snapshot = SNAPSHOT.read_text()
    require('snapshot: "B1.10"' in snapshot, 'B1.10 snapshot identity')
    for key, value in EXPECTED.items():
        require(value in snapshot or key == 'patch', f'B1.10 snapshot missing {key} pin')
    require('target: "SWAP/MOD_MvG_functions.f90"' in snapshot, 'B1.10 target mismatch')

    require(sha256(PATCH) == EXPECTED['patch'], 'SWAP-012 stored patch SHA-256 mismatch')
    patch = PATCH.read_text()
    require('SWAP/MOD_MvG_functions.f90' in patch, 'SWAP-012 target absent from patch')

    reconstruct = RECONSTRUCT.read_text()
    for value in (EXPECTED['b0_archive'], EXPECTED['manifest']):
        require(value in reconstruct, 'B1.10 reconstruction pin missing: ' + value)
    require('reconstruct_b1_9' in reconstruct, 'B1.10 ordered predecessor reconstruction missing')

    qualification = QUAL.read_text()
    for value in (EXPECTED['preimage'], EXPECTED['patch'], EXPECTED['corrected']):
        require(value in qualification, 'SWAP-012 qualification pin missing: ' + value)
    require('0/600 fail' in qualification, 'SWAP-012 actual-source roundtrip evidence missing')

    production_hits = []
    for path in (ROOT / 'src').rglob('*'):
        if not path.is_file():
            continue
        lower = path.name.lower()
        if lower == 'mod_mvg_functions.f90' or re.search(r'b1.?10.*constitutive.*provider', lower):
            production_hits.append(str(path.relative_to(ROOT)))
    require(not production_hits, 'concrete B1.10 constitutive source/provider appeared before source admission: ' + ', '.join(production_hits))

    print('F-SI09_B110_SNAPSHOT_PROVENANCE PASS')
    print('F-SI09_SWAP012_PATCH_IDENTITY PASS')
    print('F-SI09_SWAP012_QUALIFICATION_BINDING PASS')
    print('F-SI09_CORRECTED_SOURCE_MATERIALIZATION BLOCKED')
    print('F-SI09_PRODUCTION_B110_PROVIDER NOT_ADMITTED')
    print('F-SI09_PARALLEL_REFERENCE_BACKEND NOT_ADMITTED')
    print('F-SI09_SOURCE_ADMISSION_GATE PASS_BLOCKED_AS_DESIGNED')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
