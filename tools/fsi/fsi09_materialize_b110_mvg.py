#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import zipfile
from pathlib import Path

OUTER_SHA256 = '2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360'
NESTED_SHA256 = '1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151'
TARGET_PREIMAGE_SHA256 = 'a27252d216da65ce20ed3a173ade5404a0f31241ac87349edadb3b3ff9d63390'
TARGET_CORRECTED_SHA256 = '4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1'
NESTED_SUFFIX = 'tools/SWAP/source/SWAP.ZIP'
TARGET_MEMBER = 'SWAP/MOD_MvG_functions.f90'

ROOT = Path(__file__).resolve().parents[2]
SWAP012_HELPER = ROOT / 'reference/swap-4.3.1/patches/SWAP-012/apply_and_verify.py'


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_helper():
    spec = importlib.util.spec_from_file_location('fsi09_swap012_apply', SWAP012_HELPER)
    if spec is None or spec.loader is None:
        raise RuntimeError('cannot load exact SWAP-012 helper')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def materialize(distribution: Path, output: Path) -> dict:
    outer = distribution.read_bytes()
    if digest(outer) != OUTER_SHA256:
        raise ValueError('supplied distribution SHA-256 mismatch')
    with zipfile.ZipFile(distribution) as zf:
        nested_names = [n for n in zf.namelist() if n.replace('\\', '/').endswith(NESTED_SUFFIX)]
        if len(nested_names) != 1:
            raise ValueError(f'expected one nested SWAP.ZIP, found {len(nested_names)}')
        nested = zf.read(nested_names[0])
    if digest(nested) != NESTED_SHA256:
        raise ValueError('nested canonical B0 SWAP.ZIP SHA-256 mismatch')

    import io
    with zipfile.ZipFile(io.BytesIO(nested)) as zf:
        raw = zf.read(TARGET_MEMBER)
    if digest(raw) != TARGET_PREIMAGE_SHA256:
        raise ValueError('B0/B1.8 MOD_MvG_functions.f90 preimage SHA-256 mismatch')

    helper = load_helper()
    if helper.B0_SHA256 != TARGET_PREIMAGE_SHA256:
        raise ValueError('SWAP-012 helper preimage pin mismatch')
    if helper.CORRECTED_SHA256 != TARGET_CORRECTED_SHA256:
        raise ValueError('SWAP-012 helper corrected pin mismatch')
    corrected = helper.apply(raw)
    if digest(corrected) != TARGET_CORRECTED_SHA256:
        raise ValueError('corrected B1.10 MOD_MvG_functions.f90 SHA-256 mismatch')
    output.write_bytes(corrected)
    return {
        'outer_distribution_sha256': OUTER_SHA256,
        'nested_b0_archive_sha256': NESTED_SHA256,
        'target_preimage_sha256': TARGET_PREIMAGE_SHA256,
        'target_corrected_sha256': TARGET_CORRECTED_SHA256,
        'output': str(output),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('distribution', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = materialize(args.distribution, args.output)
    for key, value in result.items():
        print(f'{key}={value}')
    print('F-SI09_B110_MVG_MATERIALIZATION PASS')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
