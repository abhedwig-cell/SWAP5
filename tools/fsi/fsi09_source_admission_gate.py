#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / 'integration/f-si/F-SI09_SOURCE_ADMISSION.json'
SNAPSHOT = ROOT / 'reference/swap-4.3.1/snapshots/B1.10.yml'
RECONSTRUCT = ROOT / 'tools/vq/b1_10_reconstruct.py'
PATCH = ROOT / 'reference/swap-4.3.1/patches/SWAP-012/fix.patch'
QUAL = ROOT / 'reference/swap-4.3.1/patches/SWAP-012/qualification.md'
MATERIALIZER = ROOT / 'tools/fsi/fsi09_materialize_b110_mvg.py'
REFERENCE_MANIFEST = ROOT / 'reference/swap-4.3.1/b1_10_source/MOD_MvG_functions.manifest.json'
REFERENCE_VERIFY = ROOT / 'tools/fsi/fsi09_verify_b110_reference_payload.py'
PROVIDER = ROOT / 'src/solver/mod_b110_default_mvg_provider.f90'

EXPECTED = {
    'outer': '2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360',
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
    require(data['status'] == 'SOURCE_RESOLVED_PROVIDER_MATERIALIZED', 'unexpected post-materialization status')
    require(data['qualified'] is True, 'source binding should now be qualified')
    require(data['exact_source_identity']['supplied_distribution_sha256'] == EXPECTED['outer'], 'outer distribution pin')
    require(data['exact_source_identity']['b0_archive_sha256'] == EXPECTED['b0_archive'], 'nested B0 pin')
    require(data['exact_source_identity']['corrected_target_sha256'] == EXPECTED['corrected'], 'corrected target pin')
    require(data['repository_reference_binding']['corrected_target_present_as_immutable_reference_payload'] is True,
            'corrected reference payload missing')
    require(data['repository_reference_binding']['production_provider_git_blob'] ==
            '97d67eb373073b183be6d1bf5b756ecb5125dde2', 'provider blob pin mismatch')

    snapshot = SNAPSHOT.read_text()
    require('snapshot: "B1.10"' in snapshot, 'B1.10 snapshot identity')
    for key in ('b0_archive', 'manifest', 'preimage', 'corrected'):
        require(EXPECTED[key] in snapshot, f'B1.10 snapshot missing {key} pin')
    require('target: "SWAP/MOD_MvG_functions.f90"' in snapshot, 'B1.10 target mismatch')

    require(sha256(PATCH) == EXPECTED['patch'], 'SWAP-012 stored patch SHA-256 mismatch')
    require('SWAP/MOD_MvG_functions.f90' in PATCH.read_text(), 'SWAP-012 target absent from patch')

    reconstruct = RECONSTRUCT.read_text()
    require(EXPECTED['manifest'] in reconstruct, 'B1.10 reconstruction manifest pin missing')
    require('reconstruct_b1_9' in reconstruct, 'B1.10 ordered predecessor reconstruction missing')

    qualification = QUAL.read_text()
    for value in (EXPECTED['preimage'], EXPECTED['patch'], EXPECTED['corrected']):
        require(value in qualification, 'SWAP-012 qualification pin missing: ' + value)
    require('0/600 fail' in qualification, 'SWAP-012 actual-source roundtrip evidence missing')

    materializer = MATERIALIZER.read_text()
    for value in (EXPECTED['outer'], EXPECTED['b0_archive'], EXPECTED['preimage'], EXPECTED['corrected']):
        require(value in materializer, 'materializer pin missing: ' + value)
    require('apply_and_verify.py' in materializer, 'materializer must consume exact SWAP-012 helper')

    manifest = json.loads(REFERENCE_MANIFEST.read_text())
    require(manifest['decoded_source_sha256'] == EXPECTED['corrected'], 'reference payload manifest corrected hash')
    require(REFERENCE_VERIFY.exists(), 'reference payload verifier missing')
    require(PROVIDER.exists(), 'production constitutive provider missing')
    provider = PROVIDER.read_text().lower()
    for forbidden in ('use mod_mvg', 'use variables', 'use mod_grid', 'save ::'):
        require(forbidden not in provider, 'provider leaked shared legacy token: ' + forbidden)

    print('F-SI09_B110_SNAPSHOT_PROVENANCE PASS')
    print('F-SI09_SWAP012_PATCH_IDENTITY PASS')
    print('F-SI09_SWAP012_QUALIFICATION_BINDING PASS')
    print('F-SI09_EXACT_SOURCE_RESOLUTION PASS')
    print('F-SI09_REFERENCE_PAYLOAD_BOUND PASS')
    print('F-SI09_PRODUCTION_B110_PROVIDER MATERIALIZED_SEPARATE_QUALIFICATION_REQUIRED')
    print('F-SI09_SOURCE_ADMISSION_GATE PASS_SOURCE_BOUND')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
